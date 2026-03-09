#!/usr/bin/env python3
# Copyright (c) Decker
# Assisted by: AI agent (Cursor)
"""
Check seed nodes for Komodo DeFi framework.

Reads seed-nodes.json, computes the second port (other_ports + 20) via lp_ports formula,
and checks whether that port is open on each node's host.
Also checks WSS port (3rd port) SSL certificate is not expired.
"""

import json
import socket
import ssl
import sys
import time
import urllib.request
from pathlib import Path

SEED_NODES_JSON_URL = (
    "https://raw.githubusercontent.com/GLEECBTC/coins/refs/heads/master/seed-nodes.json"
)

LP_RPCPORT = 7783
MAX_NETID = (65535 - 40 - LP_RPCPORT) // 4


def lp_ports(netid: int) -> tuple[int, int, int]:
    """Ports per Rust formula: (other_ports+10, other_ports+20, other_ports+30)."""
    if netid > MAX_NETID:
        raise ValueError(f"netid {netid} > MAX_NETID {MAX_NETID}")
    if netid == 0:
        other_ports = LP_RPCPORT
    else:
        net_mod = netid % 10
        net_div = netid // 10
        other_ports = (net_div * 40) + LP_RPCPORT + net_mod
    return (other_ports + 10, other_ports + 20, other_ports + 30)


def ensure_seed_nodes_json(json_path: Path) -> None:
    """Download seed-nodes.json from GitHub if not present."""
    if json_path.exists():
        return
    print(f"Downloading seed-nodes.json from {SEED_NODES_JSON_URL} ...", file=sys.stderr)
    try:
        urllib.request.urlretrieve(SEED_NODES_JSON_URL, json_path)
    except OSError as e:
        print(f"Failed to download: {e}", file=sys.stderr)
        sys.exit(1)


def is_port_open(host: str, port: int, timeout: float = 3.0) -> bool:
    """Check if port is open on host (TCP connect)."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, socket.error, OSError):
        return False


def is_wss_ssl_valid(host: str, port: int, timeout: float = 5.0) -> tuple[bool, str, float | None]:
    """Check WSS port SSL certificate is not expired. Returns (ok, message, days_left or None)."""
    try:
        ctx = ssl.create_default_context()
        with ctx.wrap_socket(socket.socket(), server_hostname=host) as ssock:
            ssock.settimeout(timeout)
            ssock.connect((host, port))
            cert = ssock.getpeercert()
            exp_seconds = ssl.cert_time_to_seconds(cert["notAfter"])
            now = time.time()
            if now > exp_seconds:
                return False, "SSL certificate expired", None
            days_left = (exp_seconds - now) / 86400
            return True, "SSL OK", days_left
    except ssl.SSLError as e:
        return False, f"SSL error: {e}", None
    except (socket.timeout, socket.error, OSError) as e:
        return False, str(e), None


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    json_path = script_dir / "seed-nodes.json"

    ensure_seed_nodes_json(json_path)

    with open(json_path, encoding="utf-8") as f:
        nodes = json.load(f)

    if not nodes:
        print("No entries in seed-nodes.json")
        return

    timeout = 3.0
    working = 0
    dead = 0

    for node in nodes:
        name = node.get("name", "?")
        host = node.get("host", "")
        netid = node.get("netid")
        if netid is None:
            print(f"{name} ({host}): no netid — skip")
            continue
        try:
            _, port, wss_port = lp_ports(netid)
        except ValueError as e:
            print(f"{name} ({host}): {e}")
            dead += 1
            continue
        open_ = is_port_open(host, port, timeout=timeout)
        port_status = "OK" if open_ else "closed"
        ssl_ok, ssl_msg, days_left = is_wss_ssl_valid(host, wss_port, timeout=5.0)
        if ssl_ok and days_left is not None:
            ssl_status = f"{ssl_msg} ({int(days_left)} days left)"
        else:
            ssl_status = ssl_msg if ssl_ok else f"WSS SSL: {ssl_msg}"
        node_ok = open_ and ssl_ok
        print(f"{name} ({host}): netid={netid} port={port} — {port_status}, wss={wss_port} — {ssl_status}")
        if node_ok:
            working += 1
        else:
            dead += 1

    print()
    print(f"Working nodes: {working}, dead nodes: {dead}")
    sys.exit(0 if dead == 0 else 1)


if __name__ == "__main__":
    main()
