#!/usr/bin/env python3
"""
Convert a compressed public key to cryptocurrency addresses.
Usage: python3 pubkey_to_address.py [pubkey_hex]
"""

import hashlib
import sys

# ---------------------------------------------------------------------------
# Keccak-256 (pure Python) — needed for EVM addresses
# ---------------------------------------------------------------------------

_KECCAK_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_KECCAK_RHO = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44]
_KECCAK_PI  = [10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1]


def _keccak_f(st):
    for rc in _KECCAK_RC:
        c = [st[x] ^ st[x+5] ^ st[x+10] ^ st[x+15] ^ st[x+20] for x in range(5)]
        d = [c[(x-1) % 5] ^ ((c[(x+1) % 5] << 1 | c[(x+1) % 5] >> 63) & 0xFFFFFFFFFFFFFFFF) for x in range(5)]
        st = [st[i] ^ d[i % 5] for i in range(25)]
        last, st2 = st[1], st[:]
        for i, (rho, pi) in enumerate(zip(_KECCAK_RHO, _KECCAK_PI)):
            st2[pi] = (last << rho | last >> (64 - rho)) & 0xFFFFFFFFFFFFFFFF
            last = st[pi]
        st = st2
        st = [st[i] ^ (~st[(i // 5) * 5 + (i % 5 + 1) % 5] & st[(i // 5) * 5 + (i % 5 + 2) % 5]) for i in range(25)]
        st[0] ^= rc
    return st


def keccak256(data: bytes) -> bytes:
    rate = 136  # (1600 - 256*2) / 8
    msg = bytearray(data)
    # Keccak padding (NOT SHA-3): 0x01 ... 0x80
    msg += b"\x01"
    msg += b"\x00" * ((rate - len(msg) % rate) % rate)
    msg[-1] |= 0x80

    st = [0] * 25
    for i in range(0, len(msg), rate):
        block = msg[i:i + rate]
        for j in range(rate // 8):
            st[j] ^= int.from_bytes(block[j*8:(j+1)*8], "little")
        st = _keccak_f(st)

    return b"".join(v.to_bytes(8, "little") for v in st[:4])


# ---------------------------------------------------------------------------
# RIPEMD-160 (pure Python) — OpenSSL 3.x drops it from default providers
# ---------------------------------------------------------------------------

def _ripemd160(data: bytes) -> bytes:
    # fmt: off
    KL = [0x00000000,0x5A827999,0x6ED9EBA1,0x8F1BBCDC,0xA953FD4E]
    KR = [0x50A28BE6,0x5C4DD124,0x6D703EF3,0x7A6D76E9,0x00000000]
    RL = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
          7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
          3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,
          1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
          4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13]
    RR = [5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,
          6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
          15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,
          8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
          12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11]
    SL = [11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,
          7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
          11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,
          11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
          9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6]
    SR = [8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,
          9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
          9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,
          15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
          8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11]
    def F(j,x,y,z):
        if j<16:  return x^y^z
        if j<32:  return (x&y)|(~x&z)
        if j<48:  return (x|~y)^z
        if j<64:  return (x&z)|(y&~z)
        return x^(y|~z)
    def rol(x,n): return ((x<<n)|(x>>(32-n)))&0xFFFFFFFF
    msg=bytearray(data); l=len(data)*8
    msg.append(0x80)
    msg+=b'\x00'*((55-len(data))%64)
    msg+=l.to_bytes(8,'little')
    h=[0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0]
    for i in range(0,len(msg),64):
        X=list(int.from_bytes(msg[i+j*4:i+j*4+4],'little') for j in range(16))
        al,bl,cl,dl,el=h; ar,br,cr,dr,er=h
        for j in range(80):
            T=(al+F(j,bl,cl,dl)+X[RL[j]]+KL[j//16])&0xFFFFFFFF
            T=(rol(T,SL[j])+el)&0xFFFFFFFF; al=el; el=dl; dl=rol(cl,10); cl=bl; bl=T
            T=(ar+F(79-j,br,cr,dr)+X[RR[j]]+KR[j//16])&0xFFFFFFFF
            T=(rol(T,SR[j])+er)&0xFFFFFFFF; ar=er; er=dr; dr=rol(cr,10); cr=br; br=T
        T=(h[1]+cl+dr)&0xFFFFFFFF
        h[1]=(h[2]+dl+er)&0xFFFFFFFF; h[2]=(h[3]+el+ar)&0xFFFFFFFF
        h[3]=(h[4]+al+br)&0xFFFFFFFF; h[4]=(h[0]+bl+cr)&0xFFFFFFFF; h[0]=T
    return b''.join(v.to_bytes(4,'little') for v in h)
    # fmt: on


# ---------------------------------------------------------------------------
# secp256k1 point decompression
# ---------------------------------------------------------------------------

_SECP256K1_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F


def decompress_pubkey(pubkey_bytes: bytes) -> bytes:
    """Return 64-byte uncompressed pubkey (x || y) without 04 prefix."""
    prefix = pubkey_bytes[0]
    x = int.from_bytes(pubkey_bytes[1:], "big")
    y_sq = (pow(x, 3, _SECP256K1_P) + 7) % _SECP256K1_P
    y = pow(y_sq, (_SECP256K1_P + 1) // 4, _SECP256K1_P)
    if (y & 1) != (prefix & 1):
        y = _SECP256K1_P - y
    return x.to_bytes(32, "big") + y.to_bytes(32, "big")


# ---------------------------------------------------------------------------
# EIP-55 checksum address
# ---------------------------------------------------------------------------

def eip55(addr_hex: str) -> str:
    h = keccak256(addr_hex.encode()).hex()
    return "0x" + "".join(c.upper() if int(h[i], 16) >= 8 else c for i, c in enumerate(addr_hex))


def evm_address(pubkey_bytes: bytes) -> str:
    uncompressed = decompress_pubkey(pubkey_bytes)
    addr_hex = keccak256(uncompressed).hex()[-40:]
    return eip55(addr_hex)


# ---------------------------------------------------------------------------
# Base58
# ---------------------------------------------------------------------------

BASE58_ALPHABET = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def base58_encode(data: bytes) -> str:
    n = int.from_bytes(data, "big")
    result = []
    while n:
        n, r = divmod(n, 58)
        result.append(BASE58_ALPHABET[r])
    result.extend(BASE58_ALPHABET[0:1] * (len(data) - len(data.lstrip(b"\x00"))))
    return bytes(reversed(result)).decode("ascii")


def base58check_encode(payload: bytes) -> str:
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    return base58_encode(payload + checksum)


# ---------------------------------------------------------------------------
# Hashing helpers
# ---------------------------------------------------------------------------

def hash160(data: bytes) -> bytes:
    sha = hashlib.sha256(data).digest()
    return _ripemd160(sha)


# ---------------------------------------------------------------------------
# Address derivation
# ---------------------------------------------------------------------------

def p2pkh_address(pubkey_bytes: bytes, version: bytes) -> str:
    return base58check_encode(version + hash160(pubkey_bytes))


# version bytes for common coins (P2PKH)
COINS = {
    "BTC":  (b"\x00",      "Bitcoin"),
    "KMD":  (b"\x3c",      "Komodo"),
    "LTC":  (b"\x30",      "Litecoin"),
    "DOGE": (b"\x1e",      "Dogecoin"),
    "DGB":  (b"\x1e",      "DigiByte"),
    "DASH": (b"\x4c",      "Dash"),
    "BTG":  (b"\x26",      "Bitcoin Gold"),
    "ZEC":  (b"\x1c\xb8",  "Zcash (t-addr)"),
    "BCH":  (b"\x00",      "Bitcoin Cash (legacy)"),
    "VTC":  (b"\x47",      "Vertcoin"),
    "RVN":  (b"\x3c",      "Ravencoin"),
    "ARRR": (b"\x1c\xb8",  "Pirate Chain (t-addr)"),
    "GLEEC":(b"\x23",      "GLEEC"),
}

EVM_CHAINS = [
    "ETH / EVM chains (BNB, MATIC, AVAX, FTM, ...)",
]


def pubkey_to_addresses(pubkey_hex: str) -> None:
    pubkey_hex = pubkey_hex.strip()

    if len(pubkey_hex) != 66:
        print(f"[!] Expected 66-char hex (compressed pubkey), got {len(pubkey_hex)}")
        sys.exit(1)

    if pubkey_hex[:2] not in ("02", "03"):
        print("[!] Not a compressed public key (should start with 02 or 03)")
        sys.exit(1)

    pubkey_bytes = bytes.fromhex(pubkey_hex)
    h160 = hash160(pubkey_bytes).hex()
    evm_addr = evm_address(pubkey_bytes)

    print(f"\nPublic key : {pubkey_hex}")
    print(f"Hash160    : {h160}")
    print(f"EVM addr   : {evm_addr}")
    print()
    print(f"{'Coin':<8}  {'Address':<40}  Name")
    print("-" * 72)

    for ticker, (version, name) in COINS.items():
        addr = p2pkh_address(pubkey_bytes, version)
        print(f"{ticker:<8}  {addr:<40}  {name}")

    print(f"{'EVM':<8}  {evm_addr:<40}  ETH / BNB / MATIC / AVAX / FTM / ...")
    print()


def run_tests():
    TESTS = [
        {
            "pubkey": "02a854251adfee222bede8396fed0756985d4ea905f72611740867c7a4ad6488c1",
            "expected": {
                "BTC":  "1M68ML9dMZZPEdrjncUCe7ZWadAGUxMNyv",
                "LTC":  "LfK5cYTTSDoSVSYtxkTVv8dGnqXYZRsn86",
                "KMD":  "RVNKRr2uxPMxJeDwFnTKjdtiLtcs7UzCZn",
                "EVM":  "0x85FE0A232fA144921d880BE72A3C5515e5C17A8c",
            },
        },
    ]

    passed = failed = 0
    for t in TESTS:
        pubkey_bytes = bytes.fromhex(t["pubkey"])
        results = {
            ticker: p2pkh_address(pubkey_bytes, version)
            for ticker, (version, _) in COINS.items()
        }
        results["EVM"] = evm_address(pubkey_bytes)

        print(f"Testing pubkey {t['pubkey']}:")
        for key, expected in t["expected"].items():
            got = results.get(key, "N/A")
            ok = got == expected
            status = "PASS" if ok else "FAIL"
            print(f"  [{status}] {key:<5} expected={expected}  got={got}")
            if ok:
                passed += 1
            else:
                failed += 1

    print(f"\n{passed} passed, {failed} failed.")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    if "--test" in sys.argv:
        run_tests()
    elif len(sys.argv) > 1:
        pubkey_to_addresses(sys.argv[1])
    else:
        DEX_FEE_PUBKEY = "03a778d9bd346fa704cf3e2508cd074d93a1bbc1e504fbecbb0a8d48e7cccbbf5c"
        pubkey_to_addresses(DEX_FEE_PUBKEY)
