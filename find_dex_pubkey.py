#!/usr/bin/env python3
"""
Find DEX_FEE_ADDR_PUBKEY (and related keys) in a compiled kdflib.wasm binary.

Strategy: Rust `const &str` literals are stored verbatim as UTF-8 in the WASM
data section. A compressed secp256k1 pubkey is 66 ASCII hex chars starting with
"02" or "03" — a distinctive pattern with near-zero false-positive rate in WASM.

Usage:
    python3 find_dex_pubkey.py <path/to/kdflib.wasm>
    python3 find_dex_pubkey.py <path/to/kdflib_bg.wasm>
"""

import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# All DEX_FEE_ADDR_PUBKEY values that have ever appeared in the git history
# of mm2src/common/common.rs.  A key found in the WASM that matches one of
# these is considered "legitimate"; any other value triggers a warning.
# ---------------------------------------------------------------------------
KNOWN_LEGITIMATE_PUBKEYS: dict[str, str] = {
    "03bc2c7ba671bae4a6fc835244c9762b41647b9827d4780a89a949b984a8ddcc06": "legacy (original)",
    "0348685437335ec43ba6211caf848576ca3d34abbe9e089f861471b4ed9ee9bbd1": "intermediate",
    "03a778d9bd346fa704cf3e2508cd074d93a1bbc1e504fbecbb0a8d48e7cccbbf5c": "current (GLEEC keys)",
}

# ---------------------------------------------------------------------------
# ANSI colour helpers
# ---------------------------------------------------------------------------
_RESET  = "\033[0m"
_GREEN  = "\033[32m"
_YELLOW = "\033[33m"
_RED    = "\033[31m"
_BOLD   = "\033[1m"


def _green(s: str)  -> str: return f"{_GREEN}{_BOLD}{s}{_RESET}"
def _yellow(s: str) -> str: return f"{_YELLOW}{_BOLD}{s}{_RESET}"
def _red(s: str)    -> str: return f"{_RED}{_BOLD}{s}{_RESET}"


def _supports_color() -> bool:
    import os
    return sys.stdout.isatty() and os.environ.get("NO_COLOR") is None

USE_COLOR = _supports_color()

def green(s: str)  -> str: return _green(s)  if USE_COLOR else s
def yellow(s: str) -> str: return _yellow(s) if USE_COLOR else s
def red(s: str)    -> str: return _red(s)    if USE_COLOR else s


# ---------------------------------------------------------------------------
# Core search helpers
# ---------------------------------------------------------------------------

# Context window around a candidate to search for confirming markers
CONTEXT_RADIUS = 512

# Known error message embedded by Rust's expect() — lives near the key in data section
SECP256K1_MARKER = b"DEX_FEE_ADDR_PUBKEY is expected to be a hexadecimal string"
BURN_MARKER      = b"DEX_BURN_ADDR_PUBKEY is expected to be a hexadecimal string"

SECP256K1_HEX_RE = re.compile(rb"(?:02|03)[0-9a-f]{64}")
ED25519_HEX_RE   = re.compile(rb"[0-9a-f]{64}")

HEX_CHARS = frozenset(b"0123456789abcdef")


def _is_isolated(data: bytes, start: int, end: int) -> bool:
    """Return True if the match is not part of a longer hex run."""
    if start > 0 and data[start - 1] in HEX_CHARS:
        return False
    if end < len(data) and data[end] in HEX_CHARS:
        return False
    return True


def _has_nearby_marker(data: bytes, offset: int, marker: bytes) -> bool:
    lo = max(0, offset - CONTEXT_RADIUS)
    hi = min(len(data), offset + CONTEXT_RADIUS)
    return marker in data[lo:hi]


def find_secp256k1_candidates(data: bytes) -> list:
    results = []
    for m in SECP256K1_HEX_RE.finditer(data):
        start, end = m.start(), m.end()
        if not _is_isolated(data, start, end):
            continue
        key = m.group().decode("ascii")
        confirmed = (_has_nearby_marker(data, start, SECP256K1_MARKER) or
                     _has_nearby_marker(data, start, BURN_MARKER))
        results.append((start, key, confirmed))
    return results


def find_ed25519_candidates(data: bytes) -> list:
    results = []
    secp_offsets = {
        m.start()
        for m in SECP256K1_HEX_RE.finditer(data)
        if _is_isolated(data, m.start(), m.end())
    }
    for m in ED25519_HEX_RE.finditer(data):
        start, end = m.start(), m.end()
        if not _is_isolated(data, start, end):
            continue
        if (start - 2) in secp_offsets:
            continue
        if start in secp_offsets or (start + 2) in secp_offsets:
            continue
        key = m.group().decode("ascii")
        results.append((start, key))
    return results


def validate_secp256k1_point(pubkey_hex: str):
    """Validate via `cryptography` lib; return True/False/None (unavailable)."""
    try:
        from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePublicKey, SECP256K1
        raw = bytes.fromhex(pubkey_hex)
        EllipticCurvePublicKey.from_encoded_point(SECP256K1(), raw)
        return True
    except ImportError:
        return None
    except Exception:
        return False


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <kdflib.wasm | kdflib_bg.wasm>")
        sys.exit(1)

    wasm_path = Path(sys.argv[1])
    if not wasm_path.exists():
        print(f"Error: file not found: {wasm_path}")
        sys.exit(1)

    data = wasm_path.read_bytes()
    print(f"File : {wasm_path}  ({len(data):,} bytes)")

    if data[:4] != b"\x00asm":
        print("Warning: file does not start with WASM magic bytes (\\x00asm)")
    print()

    # --- secp256k1 candidates ---
    secp_candidates = find_secp256k1_candidates(data)
    unique_secp: dict[str, tuple[int, bool]] = {}
    for offset, key, confirmed in secp_candidates:
        if key not in unique_secp:
            unique_secp[key] = (offset, confirmed)
        elif confirmed and not unique_secp[key][1]:
            unique_secp[key] = (offset, confirmed)

    print(f"=== secp256k1 compressed pubkey candidates ({len(unique_secp)} unique) ===")
    if not unique_secp:
        print("  (none found)")
    for key, (offset, confirmed) in unique_secp.items():
        valid = validate_secp256k1_point(key)
        validity_str = ""
        if valid is True:
            validity_str = "  [valid secp256k1 point]"
        elif valid is False:
            validity_str = "  [INVALID secp256k1 point]"
        confidence = "HIGH (marker found nearby)" if confirmed else "medium"
        print(f"  offset 0x{offset:08x} ({offset:10d})  confidence={confidence}{validity_str}")
        print(f"  {key}")
        print()

    # --- ed25519 candidates ---
    print()
    ed_candidates = find_ed25519_candidates(data)
    unique_ed: dict[str, int] = {}
    for offset, key in ed_candidates:
        unique_ed.setdefault(key, offset)

    ED25519_HINT = b"ED25519"
    SIA_HINT     = b"ia"
    confirmed_ed = {
        key: off for key, off in unique_ed.items()
        if _has_nearby_marker(data, off, ED25519_HINT) or
           _has_nearby_marker(data, off, SIA_HINT)
    }

    print(f"=== ED25519 pubkey candidates ({len(confirmed_ed)} with nearby context hint) ===")
    if not confirmed_ed:
        print("  (none found with confirming context)")
    for key, offset in confirmed_ed.items():
        print(f"  offset 0x{offset:08x} ({offset:10d})")
        print(f"  {key}")
        print()

    # --- Summary ---
    print()
    print("=== Summary ===")

    if unique_secp:
        best_key = max(unique_secp, key=lambda k: unique_secp[k][1])

        label = KNOWN_LEGITIMATE_PUBKEYS.get(best_key)
        if label is not None:
            status = green(f"LEGITIMATE  [{label}]")
            verdict = green(best_key)
        else:
            status = red("UNKNOWN — not found in git history of DEX_FEE_ADDR_PUBKEY")
            verdict = red(best_key)

        print(f"Most likely DEX_FEE_ADDR_PUBKEY (secp256k1):")
        print(f"  {verdict}")
        print(f"  Status : {status}")
        if label is None:
            print()
            print(yellow("  *** WARNING: the pubkey embedded in this WASM has never appeared"))
            print(yellow("  *** in the git history of mm2src/common/common.rs."))
            print(yellow("  *** This binary may have been compiled from a modified source."))

    if confirmed_ed:
        ED25519_PUBKEY_MARKER = b"DEX_FEE_PUBKEY_ED2551"
        best_ed = None
        for key, off in confirmed_ed.items():
            if _has_nearby_marker(data, off, ED25519_PUBKEY_MARKER):
                best_ed = key
                break
        if best_ed is None:
            best_ed = next(iter(confirmed_ed))
        print()
        print(f"Most likely DEX_FEE_PUBKEY_ED25519:")
        print(f"  {best_ed}")

    print()
    print("Known legitimate DEX_FEE_ADDR_PUBKEY values (from git history):")
    for pk, lbl in KNOWN_LEGITIMATE_PUBKEYS.items():
        marker = green("✓") if pk == (best_key if unique_secp else "") else " "
        print(f"  {marker} {pk}  [{lbl}]")


if __name__ == "__main__":
    main()
