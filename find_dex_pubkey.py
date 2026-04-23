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

# Context window around a candidate to search for confirming markers
CONTEXT_RADIUS = 512

# Known error message embedded by Rust's expect() — lives near the key in data section
SECP256K1_MARKER = b"DEX_FEE_ADDR_PUBKEY is expected to be a hexadecimal string"
BURN_MARKER = b"DEX_BURN_ADDR_PUBKEY is expected to be a hexadecimal string"

# Patterns
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


def _context_snippet(data: bytes, offset: int, radius: int = 80) -> str:
    lo = max(0, offset - radius)
    hi = min(len(data), offset + radius)
    chunk = data[lo:hi]
    printable = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
    arrow = " " * (offset - lo) + "^"
    return f"  ...{printable}...\n  ...{arrow}..."


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
        confirmed = _has_nearby_marker(data, start, SECP256K1_MARKER) or \
                    _has_nearby_marker(data, start, BURN_MARKER)
        results.append((start, key, confirmed))
    return results


def find_ed25519_candidates(data: bytes) -> list:
    # ED25519 keys are 64 hex chars; filter out those already matched as secp256k1
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
        # Skip if this is the tail of a secp256k1 match (start+2 would be a secp match start)
        if (start - 2) in secp_offsets:
            continue
        # Skip if this is a secp256k1 match itself (64-char would match inside 66-char)
        if start in secp_offsets or (start + 2) in secp_offsets:
            continue
        key = m.group().decode("ascii")
        results.append((start, key))
    return results


def validate_secp256k1_point(pubkey_hex: str) -> bool:
    """Try to validate via `cryptography` lib; return None if unavailable."""
    try:
        from cryptography.hazmat.primitives.asymmetric.ec import (
            EllipticCurvePublicKey, SECP256K1,
        )
        from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
        from cryptography.hazmat.backends import default_backend
        raw = bytes.fromhex(pubkey_hex)
        from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePublicNumbers
        # Use load_der_public_key approach via raw compressed point
        from cryptography.hazmat.primitives.serialization import load_der_public_key
        # Build DER: sequence(sequence(OID ecPublicKey, OID secp256k1), bitstring(point))
        # Easier: use EllipticCurvePublicKey.from_encoded_point if available (cryptography >= 2.5)
        from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePublicKey
        key = EllipticCurvePublicKey.from_encoded_point(SECP256K1(), raw)
        return True
    except ImportError:
        return None  # library not available
    except Exception:
        return False


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

    # Verify WASM magic
    if data[:4] != b"\x00asm":
        print("Warning: file does not start with WASM magic bytes (\\x00asm)")
    print()

    # --- secp256k1 candidates ---
    secp_candidates = find_secp256k1_candidates(data)
    unique_secp = {}
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
    unique_ed = {}
    for offset, key in ed_candidates:
        unique_ed.setdefault(key, offset)

    # Filter: only report if "ED25519" or "sia" appears nearby
    ED25519_HINT = b"ED25519"
    SIA_HINT = b"ia"  # SiaCoin
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
        # Prefer confirmed (HIGH confidence) over unconfirmed
        best_key = max(unique_secp, key=lambda k: unique_secp[k][1])
        print(f"Most likely DEX_FEE_ADDR_PUBKEY (secp256k1):")
        print(f"  {best_key}")
    if confirmed_ed:
        # Prefer the candidate that has a specific ED25519 pubkey marker nearby.
        # Note: compiled binary may spell it "ED25510" (source typo in expect message),
        # so we use a partial match covering both variants.
        ED25519_PUBKEY_MARKER = b"DEX_FEE_PUBKEY_ED2551"
        best_ed = None
        for key, off in confirmed_ed.items():
            if _has_nearby_marker(data, off, ED25519_PUBKEY_MARKER):
                best_ed = key
                break
        if best_ed is None:
            best_ed = next(iter(confirmed_ed))
        print(f"Most likely DEX_FEE_PUBKEY_ED25519:")
        print(f"  {best_ed}")


if __name__ == "__main__":
    main()
