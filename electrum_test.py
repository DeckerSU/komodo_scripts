#!/usr/bin/env python3
# Copyright (c) 2026 DeckerSU and AI
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""
Electrum server tester.

Tests SSL and WSS Electrum servers: protocol handshake (server.version),
block-header fetch, and — for WSS — SSL certificate expiry check.

Usage:
    python electrum_test.py [COIN]

COIN defaults to KMD; any value is normalized to upper case before fetching the list.

Optional dependency (WSS support):
    pip install websockets
"""

import argparse
import asyncio
import datetime
import hashlib
import json
import ssl
import sys
import time
import urllib.request
from dataclasses import dataclass
from enum import Enum
from typing import List, Optional, Tuple

# ANSI colours (only when writing to a real terminal)
_TTY = sys.stdout.isatty()
C_GREEN  = "\033[92m" if _TTY else ""
C_RED    = "\033[91m" if _TTY else ""
C_YELLOW = "\033[93m" if _TTY else ""
C_BOLD   = "\033[1m"  if _TTY else ""
C_RESET  = "\033[0m"  if _TTY else ""

try:
    import websockets
    HAS_WEBSOCKETS = True
except ImportError:
    HAS_WEBSOCKETS = False

# ── Configuration ──────────────────────────────────────────────────────────────
def servers_url_for_coin(coin: str) -> str:
    """Electrum server list URL for a coin ticker (already upper-case)."""
    return (
        f"https://raw.githubusercontent.com/GLEECBTC/coins"
        f"/refs/heads/master/electrums/{coin}"
    )


TEST_BLOCK_HEIGHT = 1       # height passed to blockchain.block.header
TIMEOUT = 10.0              # seconds per network operation
CLIENT_NAME = "electrum-tester/1.0"
PROTOCOL_VERSION = "1.4"
CERT_WARN_DAYS = 30         # flag cert as "expiring soon" within this many days
# ──────────────────────────────────────────────────────────────────────────────


class Protocol(Enum):
    SSL = "SSL"
    WSS = "WSS"
    TCP = "TCP"
    WS  = "WS"


@dataclass
class Server:
    host: str
    port: int
    protocol: Protocol

    def __str__(self) -> str:
        return f"{self.host}:{self.port}"


@dataclass
class TestResult:
    server: Server
    ok: bool
    server_software: Optional[str] = None
    proto_version: Optional[str] = None
    block_header: Optional[str] = None
    block_hash: Optional[str] = None   # derived from header (double SHA256 of first 80 bytes)
    cert_expiry: Optional[datetime.datetime] = None
    cert_error: Optional[str] = None   # set when cert is present but problematic
    error: Optional[str] = None
    elapsed_ms: float = 0.0

    @property
    def cert_days_left(self) -> Optional[int]:
        if self.cert_expiry is None:
            return None
        delta = self.cert_expiry - datetime.datetime.utcnow()
        return delta.days


# ── Server list ────────────────────────────────────────────────────────────────

def _split_host_port(addr: str) -> Tuple[str, int]:
    host, _, port = addr.rpartition(":")
    return host.strip(), int(port.strip())


def fetch_servers(url: str) -> List[Server]:
    """Download and parse the electrums JSON file."""
    with urllib.request.urlopen(url, timeout=15) as resp:
        data = json.loads(resp.read())

    servers: List[Server] = []

    if isinstance(data, list):
        # Expected format:
        #   [{"url": "host:port", "protocol": "SSL", "ws_url": "host:port"}, ...]
        for entry in data:
            if not isinstance(entry, dict):
                continue

            raw_url = entry.get("url", "")
            if raw_url:
                try:
                    host, port = _split_host_port(raw_url)
                    # Entries without "protocol" field are plain TCP (no TLS)
                    proto_str = entry.get("protocol", "TCP").upper()
                    proto = Protocol[proto_str] if proto_str in Protocol.__members__ else Protocol.TCP
                    servers.append(Server(host=host, port=port, protocol=proto))
                except (ValueError, KeyError):
                    pass

            ws_url = entry.get("ws_url", "")
            if ws_url:
                try:
                    host, port = _split_host_port(ws_url)
                    servers.append(Server(host=host, port=port, protocol=Protocol.WSS))
                except ValueError:
                    pass

    elif isinstance(data, dict):
        # Alternative format: {"host": {"ssl": port, "wss": port}, ...}
        for host, ports in data.items():
            if not isinstance(ports, dict):
                continue
            for key, proto in [
                ("ssl", Protocol.SSL), ("s", Protocol.SSL),
                ("wss", Protocol.WSS), ("wss_port", Protocol.WSS),
                ("t", Protocol.TCP),
            ]:
                if key in ports:
                    try:
                        servers.append(Server(host=host, port=int(ports[key]), protocol=proto))
                    except (ValueError, TypeError):
                        pass

    return servers


# ── TLS helpers ────────────────────────────────────────────────────────────────

def _make_ssl_ctx() -> ssl.SSLContext:
    """SSL context that accepts self-signed / expired certs (test tool)."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def _parse_cert_expiry(der: bytes) -> Optional[datetime.datetime]:
    """
    Extract notAfter from a DER-encoded X.509 certificate.

    Pure-Python minimal ASN.1 walker — no external dependencies.
    Handles UTCTime (tag 0x17, YYMMDDHHMMSSZ)
    and GeneralizedTime (tag 0x18, YYYYMMDDHHMMSSZ).
    """

    def read_tlv(buf: bytes, pos: int) -> Tuple[int, int, int]:
        """Return (tag, length, value_offset)."""
        tag = buf[pos]
        pos += 1
        length = buf[pos]
        pos += 1
        if length & 0x80:
            nb = length & 0x7F
            length = int.from_bytes(buf[pos:pos + nb], "big")
            pos += nb
        return tag, length, pos

    def skip(buf: bytes, pos: int) -> int:
        _, length, vpos = read_tlv(buf, pos)
        return vpos + length

    def enter_seq(buf: bytes, pos: int) -> Tuple[int, int]:
        tag, length, vpos = read_tlv(buf, pos)
        if tag not in (0x30, 0x31):
            raise ValueError(f"Expected SEQUENCE (0x30), got 0x{tag:02X} at {pos}")
        return vpos, vpos + length

    try:
        pos, _ = enter_seq(der, 0)          # Certificate
        pos, _ = enter_seq(der, pos)        # TBSCertificate

        if der[pos] == 0xA0:                # version [0] EXPLICIT (optional)
            pos = skip(der, pos)

        for _ in range(3):                  # serialNumber, signatureAlgorithm, issuer
            pos = skip(der, pos)

        pos, _ = enter_seq(der, pos)        # Validity
        pos = skip(der, pos)                # notBefore — skip

        tag, length, vpos = read_tlv(der, pos)   # notAfter
        raw = der[vpos:vpos + length].decode("ascii")

        if tag == 0x17:                     # UTCTime
            return datetime.datetime.strptime(raw, "%y%m%d%H%M%SZ")
        if tag == 0x18:                     # GeneralizedTime
            return datetime.datetime.strptime(raw, "%Y%m%d%H%M%SZ")

    except Exception:
        pass
    return None


def _extract_cert_expiry(ssl_obj: ssl.SSLObject) -> Optional[datetime.datetime]:
    """Get certificate expiry from an established SSL connection."""
    try:
        der = ssl_obj.getpeercert(binary_form=True)
        if der:
            return _parse_cert_expiry(der)
    except Exception:
        pass
    return None


def _cert_expired(expiry: Optional[datetime.datetime]) -> bool:
    """True if notAfter is strictly before current UTC time (cert is no longer valid)."""
    if expiry is None:
        return False
    return datetime.datetime.utcnow() > expiry


# ── Electrum JSON-RPC ──────────────────────────────────────────────────────────

def _rpc_frame(method: str, params: list, req_id: int) -> bytes:
    return (json.dumps({"id": req_id, "method": method, "params": params}) + "\n").encode()


async def _tcp_call(
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
    method: str,
    params: list,
    req_id: int,
) -> dict:
    writer.write(_rpc_frame(method, params, req_id))
    await writer.drain()
    line = await asyncio.wait_for(reader.readline(), timeout=TIMEOUT)
    return json.loads(line)


def _parse_version(result) -> Tuple[str, str]:
    """Return (software, protocol_version) from server.version result."""
    if isinstance(result, list) and len(result) >= 2:
        return str(result[0]), str(result[1])
    return str(result), "?"


def _trim_header(hex_str: str) -> str:
    return hex_str[:48] + "…" if len(hex_str) > 48 else hex_str


def _block_hash_from_header_hex(header_hex: str) -> Optional[str]:
    """
    Block id from Electrum ``blockchain.block.header`` hex (display byte order).

    - **80 bytes** — classic Bitcoin header: ``SHA256(SHA256(header))`` then reverse
      the 32-byte digest for display (same as bitcoind).
    - **More than 80 bytes** — Komodo-style extended header (e.g. KMD ~1487 bytes):
      hash is ``SHA256(SHA256(entire_serialized_header))``, then reverse for display.
      The first block at height 1 then matches the explorer block hash
      (e.g. ``0a47c132…fbde8e6``), not the result of hashing only the first 80 bytes.
    """
    try:
        raw = bytes.fromhex(header_hex.strip())
    except ValueError:
        return None
    if len(raw) < 80:
        return None
    payload = raw[:80] if len(raw) == 80 else raw
    inner = hashlib.sha256(payload).digest()
    return hashlib.sha256(inner).digest()[::-1].hex()


def _proto_label(proto: Protocol) -> str:
    return {
        Protocol.TCP: "TCP (plaintext)",
        Protocol.SSL: "TCP/SSL",
        Protocol.WSS: "WSS",
        Protocol.WS:  "WS",
    }.get(proto, proto.value)


# ── Server tests ───────────────────────────────────────────────────────────────

async def test_tcp(server: Server) -> TestResult:
    """Test a plain TCP (no TLS) Electrum server."""
    t0 = time.monotonic()
    try:
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(server.host, server.port),
            timeout=TIMEOUT,
        )
        try:
            resp = await _tcp_call(reader, writer, "server.version",
                                   [CLIENT_NAME, PROTOCOL_VERSION], 1)
            if resp.get("error"):
                raise RuntimeError(f"server.version: {resp['error']}")
            software, proto_ver = _parse_version(resp.get("result"))

            resp2 = await _tcp_call(reader, writer, "blockchain.block.header",
                                    [TEST_BLOCK_HEIGHT], 2)
            if resp2.get("error"):
                raise RuntimeError(f"blockchain.block.header: {resp2['error']}")
            full_header = resp2.get("result", "") or ""
            header = _trim_header(full_header)
            blk_hash = _block_hash_from_header_hex(full_header)
            if not blk_hash:
                raise RuntimeError(
                    "could not derive block hash from header (invalid hex or < 80 bytes)"
                )

            return TestResult(
                server=server, ok=True,
                server_software=software, proto_version=proto_ver,
                block_header=header,
                block_hash=blk_hash,
                elapsed_ms=(time.monotonic() - t0) * 1000,
            )
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass

    except Exception as exc:
        return TestResult(server=server, ok=False,
                          error=str(exc),
                          elapsed_ms=(time.monotonic() - t0) * 1000)


async def test_ssl(server: Server) -> TestResult:
    t0 = time.monotonic()
    try:
        ctx = _make_ssl_ctx()
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(server.host, server.port, ssl=ctx),
            timeout=TIMEOUT,
        )
        try:
            ssl_obj: ssl.SSLObject = writer.get_extra_info("ssl_object")

            # Step 1 — negotiate protocol version (required handshake)
            resp = await _tcp_call(reader, writer, "server.version",
                                   [CLIENT_NAME, PROTOCOL_VERSION], 1)
            if resp.get("error"):
                raise RuntimeError(f"server.version: {resp['error']}")
            software, proto_ver = _parse_version(resp.get("result"))

            # Step 2 — fetch a block header by height
            resp2 = await _tcp_call(reader, writer, "blockchain.block.header",
                                    [TEST_BLOCK_HEIGHT], 2)
            if resp2.get("error"):
                raise RuntimeError(f"blockchain.block.header: {resp2['error']}")
            full_header = resp2.get("result", "") or ""
            header = _trim_header(full_header)
            blk_hash = _block_hash_from_header_hex(full_header)
            if not blk_hash:
                raise RuntimeError(
                    "could not derive block hash from header (invalid hex or < 80 bytes)"
                )

            cert_expiry = _extract_cert_expiry(ssl_obj)
            if _cert_expired(cert_expiry):
                raise RuntimeError(
                    "SSL certificate expired "
                    f"(notAfter {cert_expiry.strftime('%Y-%m-%d %H:%M:%S')} UTC)"
                )

            return TestResult(
                server=server, ok=True,
                server_software=software, proto_version=proto_ver,
                block_header=header,
                block_hash=blk_hash,
                cert_expiry=cert_expiry,
                elapsed_ms=(time.monotonic() - t0) * 1000,
            )
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass

    except Exception as exc:
        return TestResult(server=server, ok=False,
                          error=str(exc),
                          elapsed_ms=(time.monotonic() - t0) * 1000)


async def test_wss(server: Server) -> TestResult:
    if not HAS_WEBSOCKETS:
        return TestResult(
            server=server, ok=False,
            error="websockets not installed — run: pip install websockets",
        )

    t0 = time.monotonic()
    uri = f"wss://{server.host}:{server.port}"
    req_id = 0

    try:
        ctx = _make_ssl_ctx()
        cert_expiry: Optional[datetime.datetime] = None

        async with websockets.connect(uri, ssl=ctx, open_timeout=TIMEOUT) as ws:

            # --- SSL certificate expiry check ---
            ssl_obj = None
            for attr in ("transport", "writer"):
                transport = getattr(ws, attr, None)
                if transport is not None:
                    ssl_obj = transport.get_extra_info("ssl_object")
                    if ssl_obj:
                        break
            if ssl_obj:
                cert_expiry = _extract_cert_expiry(ssl_obj)

            # Step 1 — negotiate protocol version
            req_id += 1
            await ws.send(json.dumps({"id": req_id, "method": "server.version",
                                      "params": [CLIENT_NAME, PROTOCOL_VERSION]}))
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=TIMEOUT))
            if resp.get("error"):
                raise RuntimeError(f"server.version: {resp['error']}")
            software, proto_ver = _parse_version(resp.get("result"))

            # Step 2 — fetch block header
            req_id += 1
            await ws.send(json.dumps({"id": req_id, "method": "blockchain.block.header",
                                      "params": [TEST_BLOCK_HEIGHT]}))
            resp2 = json.loads(await asyncio.wait_for(ws.recv(), timeout=TIMEOUT))
            if resp2.get("error"):
                raise RuntimeError(f"blockchain.block.header: {resp2['error']}")
            full_header = resp2.get("result", "") or ""
            header = _trim_header(full_header)
            blk_hash = _block_hash_from_header_hex(full_header)
            if not blk_hash:
                raise RuntimeError(
                    "could not derive block hash from header (invalid hex or < 80 bytes)"
                )

            if _cert_expired(cert_expiry):
                raise RuntimeError(
                    "SSL certificate expired "
                    f"(notAfter {cert_expiry.strftime('%Y-%m-%d %H:%M:%S')} UTC)"
                )

        return TestResult(
            server=server, ok=True,
            server_software=software, proto_version=proto_ver,
            block_header=header,
            block_hash=blk_hash,
            cert_expiry=cert_expiry,
            elapsed_ms=(time.monotonic() - t0) * 1000,
        )

    except Exception as exc:
        return TestResult(server=server, ok=False,
                          error=str(exc),
                          elapsed_ms=(time.monotonic() - t0) * 1000)


async def test_server(server: Server) -> TestResult:
    if server.protocol == Protocol.TCP:
        return await test_tcp(server)
    if server.protocol == Protocol.SSL:
        return await test_ssl(server)
    if server.protocol == Protocol.WSS:
        return await test_wss(server)
    return TestResult(server=server, ok=False,
                      error=f"Protocol {server.protocol.value} not supported by this tester")


# ── Output ─────────────────────────────────────────────────────────────────────

def _cert_line(result: TestResult) -> str:
    if result.cert_expiry is None:
        return ""
    days = result.cert_days_left
    expiry_str = result.cert_expiry.strftime("%Y-%m-%d")
    if days is not None and days < 0:
        flag = f"  {C_RED}!! EXPIRED !!{C_RESET}"
    elif days is not None and days < CERT_WARN_DAYS:
        flag = f"  {C_YELLOW}!! expires in {days}d !!{C_RESET}"
    else:
        flag = f"  ({days}d remaining)" if days is not None else ""
    return f"  Cert exp : {expiry_str}{flag}"


def print_server_list(
    ssl_servers: List[Server],
    wss_servers: List[Server],
    tcp_servers: List[Server],
    other_servers: List[Server],
) -> None:
    """Order: SSL first, then WSS, then plaintext TCP, then other."""
    groups = [
        (ssl_servers,   "TCP/SSL"),
        (wss_servers,   "WSS (TCP/SSL)"),
        (tcp_servers,   "TCP — plaintext"),
        (other_servers, "Other"),
    ]
    for group, label in groups:
        if not group:
            continue
        print(f"{C_BOLD}{label}{C_RESET} ({len(group)}):")
        for s in group:
            print(f"  {s}  [{_proto_label(s.protocol)}]")
        print()


def print_results_group(title: str, results: List[TestResult]) -> None:
    if not results:
        return
    bar = "─" * 64
    ok_count = sum(r.ok for r in results)
    print(f"\n{bar}")
    print(
        f"  {C_BOLD}{title}{C_RESET}  "
        f"({C_GREEN}{ok_count}{C_RESET}/{len(results)} passed)"
    )
    print(bar)

    for r in sorted(results, key=lambda x: (not x.ok, x.elapsed_ms)):
        if r.ok:
            tag = f"{C_GREEN}PASSED{C_RESET}"
        else:
            tag = f"{C_RED}FAIL{C_RESET}"
        print(f"\n  [{tag}]  {r.server}  [{_proto_label(r.server.protocol)}]   {r.elapsed_ms:.0f} ms")
        if r.ok:
            print(f"  Software : {r.server_software}  (proto {r.proto_version})")
            print(f"  Block[{TEST_BLOCK_HEIGHT}]  : {r.block_header}")
            if r.block_hash:
                print(f"  Block hash : {r.block_hash}")
            cert = _cert_line(r)
            if cert:
                print(cert)
        else:
            print(f"  Error    : {r.error}")


# ── Current tip ───────────────────────────────────────────────────────────────

async def _tip_via_tcp(server: Server) -> Tuple[int, str]:
    """Return (height, block_hash) for the chain tip using a TCP/SSL connection."""
    ctx = _make_ssl_ctx() if server.protocol == Protocol.SSL else None
    reader, writer = await asyncio.wait_for(
        asyncio.open_connection(server.host, server.port, ssl=ctx),
        timeout=TIMEOUT,
    )
    try:
        # mandatory handshake
        r0 = await _tcp_call(reader, writer, "server.version",
                             [CLIENT_NAME, PROTOCOL_VERSION], 1)
        if r0.get("error"):
            raise RuntimeError(f"server.version: {r0['error']}")

        resp = await _tcp_call(reader, writer, "blockchain.headers.subscribe", [], 2)
        if resp.get("error"):
            raise RuntimeError(f"blockchain.headers.subscribe: {resp['error']}")
        result = resp.get("result", {})
        height: int = int(result["height"])
        blk_hash = _block_hash_from_header_hex(result.get("hex", "")) or "?"
        return height, blk_hash
    finally:
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass


async def _tip_via_wss(server: Server) -> Tuple[int, str]:
    """Return (height, block_hash) for the chain tip using a WSS connection."""
    if not HAS_WEBSOCKETS:
        raise RuntimeError("websockets not installed")
    ctx = _make_ssl_ctx()
    uri = f"wss://{server.host}:{server.port}"
    async with websockets.connect(uri, ssl=ctx, open_timeout=TIMEOUT) as ws:
        # mandatory handshake
        await ws.send(json.dumps({"id": 1, "method": "server.version",
                                  "params": [CLIENT_NAME, PROTOCOL_VERSION]}))
        r0 = json.loads(await asyncio.wait_for(ws.recv(), timeout=TIMEOUT))
        if r0.get("error"):
            raise RuntimeError(f"server.version: {r0['error']}")

        await ws.send(json.dumps({"id": 2, "method": "blockchain.headers.subscribe", "params": []}))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=TIMEOUT))
        if resp.get("error"):
            raise RuntimeError(f"blockchain.headers.subscribe: {resp['error']}")
        result = resp.get("result", {})
        height: int = int(result["height"])
        blk_hash = _block_hash_from_header_hex(result.get("hex", "")) or "?"
        return height, blk_hash


async def fetch_current_tip(server: Server) -> Optional[Tuple[int, str]]:
    """Query the chain tip from *server*; return (height, hash) or None on error."""
    try:
        if server.protocol in (Protocol.TCP, Protocol.SSL):
            return await _tip_via_tcp(server)
        if server.protocol == Protocol.WSS:
            return await _tip_via_wss(server)
    except Exception:
        pass
    return None


async def print_current_tip(results: List[TestResult]) -> None:
    """Pick the first passing server (SSL preferred) and display the current tip."""
    order = [Protocol.SSL, Protocol.TCP, Protocol.WSS]
    candidates: List[TestResult] = []
    for proto in order:
        candidates += [r for r in results if r.ok and r.server.protocol == proto]
    candidates += [r for r in results if r.ok and r.server.protocol not in order]

    tip = None
    source: Optional[Server] = None
    for r in candidates:
        tip = await fetch_current_tip(r.server)
        if tip is not None:
            source = r.server
            break

    print(f"\n{'─' * 64}")
    if tip is not None:
        height, blk_hash = tip
        print(f"  {C_BOLD}Current tip{C_RESET}  (via {source}  [{_proto_label(source.protocol)}])")
        print(f"  Height : {C_BOLD}{height}{C_RESET}")
        print(f"  Hash   : {blk_hash}")
    else:
        print(f"  {C_YELLOW}Current tip: could not retrieve (no reachable server){C_RESET}")
    print()


# ── Entry point ────────────────────────────────────────────────────────────────

async def main(coin: str) -> None:
    servers_url = servers_url_for_coin(coin)
    print(f"Electrum server tester  |  coin: {coin}")
    print(f"Source : {servers_url}")
    print()

    print("Fetching server list … ", end="", flush=True)
    try:
        servers = fetch_servers(servers_url)
    except Exception as exc:
        print(f"FAILED\n{exc}")
        return
    print(f"{len(servers)} servers found.\n")

    tcp_servers = [s for s in servers if s.protocol == Protocol.TCP]
    ssl_servers = [s for s in servers if s.protocol == Protocol.SSL]
    wss_servers = [s for s in servers if s.protocol == Protocol.WSS]
    other_servers = [
        s for s in servers
        if s.protocol not in (Protocol.TCP, Protocol.SSL, Protocol.WSS)
    ]

    print_server_list(ssl_servers, wss_servers, tcp_servers, other_servers)

    all_servers = ssl_servers + wss_servers + tcp_servers + other_servers
    if not all_servers:
        print("No testable servers.")
        return

    print(f"Testing {len(all_servers)} servers concurrently "
          f"(block height {TEST_BLOCK_HEIGHT}) …")

    results: List[TestResult] = list(
        await asyncio.gather(*[test_server(s) for s in all_servers])
    )

    tcp_res = [r for r in results if r.server.protocol == Protocol.TCP]
    ssl_res = [r for r in results if r.server.protocol == Protocol.SSL]
    wss_res = [r for r in results if r.server.protocol == Protocol.WSS]
    other_res = [
        r for r in results
        if r.server.protocol not in (Protocol.TCP, Protocol.SSL, Protocol.WSS)
    ]

    print_results_group("TCP (plaintext) tests", tcp_res)
    print_results_group("TCP/SSL tests", ssl_res)
    print_results_group("WSS tests", wss_res)
    print_results_group("Other protocol tests", other_res)

    total_ok = sum(r.ok for r in results)
    ok_col = C_GREEN if total_ok == len(results) else C_RED
    print(f"\n{'─' * 64}")
    print(f"  Total: {ok_col}{total_ok}/{len(results)}{C_RESET} passed")
    print()

    await print_current_tip(results)


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Test Electrum servers from the GLEECBTC/coins electrums list.",
    )
    p.add_argument(
        "coin",
        nargs="?",
        default="KMD",
        help="Coin ticker (e.g. KMD, GLEEC). Case-insensitive; normalized to UPPER. Default: KMD",
    )
    return p.parse_args()


if __name__ == "__main__":
    _args = _parse_args()
    _ticker = _args.coin.strip().upper() or "KMD"
    asyncio.run(main(_ticker))
