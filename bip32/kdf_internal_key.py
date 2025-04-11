from pycoin.symbols.btc import network
from pycoin.networks.bitcoinish import create_bitcoinish_network
from pycoin.encoding.bytes32 import to_bytes_32
import base58
import hashlib
import unicodedata

# 1. Calculates MarketMaker’s internal purposes public key in the same way as in mm2_internal_der_path.
# 2. Prints the first 20 addresses of the HD wallet.

# https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
# https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki

def mnemonic_to_seed(mnemonic: str, passphrase: str = "") -> bytes:
    mnemonic_normalized = unicodedata.normalize("NFKD", mnemonic)
    passphrase_normalized = unicodedata.normalize("NFKD", passphrase)
    salt = ("mnemonic" + passphrase_normalized).encode("utf-8")
    seed = hashlib.pbkdf2_hmac("sha512", mnemonic_normalized.encode("utf-8"), salt, 2048)
    return seed

def base58_check_encode(payload: bytes) -> str:
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    return base58.b58encode(payload + checksum).decode('utf-8')

def get_custom_address(hash160: bytes, custom_prefix: bytes) -> str:
    payload = custom_prefix + hash160
    return base58_check_encode(payload)

def main():

    KMD = create_bitcoinish_network(
        symbol="KMD",
        network_name="Komodo",
        subnet_name="mainnet",
        wif_prefix=b'\xbc',
        address_prefix=b'\x3c',
        pay_to_script_prefix=b'\x55',
        bip32_prv_prefix=b'\x04\x88\xad\xe4',
        bip32_pub_prefix=b'\x04\x88\xb2\x1e',
        magic_header=b'\xdb\xb6\xc0\xfb',
        default_port=7771,
        bip44_coin_type=141
    )

    mnemonic_bytes = b"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    mnemonic_str = mnemonic_bytes.decode("utf-8")
    seed_bytes = mnemonic_to_seed(mnemonic_str, passphrase="")
    print(f"BIP39 Seed: {seed_bytes.hex()}")
    # Obtain the BIP32 Root Key (xprv) from a hex seed
    key = network.keys.bip32_seed(seed_bytes)
    bip32_root_key = key.hwif(as_private=1)
    print(f"BIP32 Root Key: {bip32_root_key}")

    # mm2_internal_der_path
    # /// The derivation path generally consists of:
    # /// `m/purpose'/coin_type'/account'/change/address_index`.
    # /// For MarketMaker internal purposes, we decided to use a pubkey derived from the following path, where:
    # /// * `coin_type = 141` - KMD coin;
    # /// * `account = (2 ^ 31 - 1) = 2147483647` - latest available account index.
    # ///   This number is chosen so that it does not cross with real accounts;
    # /// * `change = 0` - nothing special.
    # /// * `address_index = 0`.

    # m/44'/141'/2147483647/0/0
    derivation_path = "44H/141H/2147483647/0/0"
    derived_key = key.subkey_for_path(derivation_path)
    public_key_hex = derived_key.sec().hex()
    hash160 = derived_key.hash160()
    print(f"INFO Public key: {public_key_hex}") # 025a3fdcfb4f39c44075c306cf050efeb1311a49694ba606e2abb4d78da428b4e8
    print(f"INFO Public key hash: {hash160.hex()}") # e0cbb8142006152cf294b2db527ba421e94a52f3

    # address = derived_key.address()
    # kmd_address = get_custom_address(hash160, b'\x3c')
    # kmd_address = KMD.address.for_p2pkh(hash160)
    # print(f"BTC address: {address}")
    # print(f"KMD address:", kmd_address)

    # m/44'/141'/0'
    m0_key = key.subkey_for_path("44H/141H/0H/0")
    num_addresses = 20
    print("Path\t\tAddress\t\t\t\tPublic Key (hex)\t\t\t\tPrivate Key (WIF)")
    print("---------------------------------------------------------------------------------------------------------")

    # Derive m/44'/141'/0'/0/i and print details
    for i in range(num_addresses):

        child_key = m0_key.subkey(i)
        path = f"m/44'/141'/0'/0/{i}"
        # address = get_custom_address(child_key.hash160(), b'\x3c')
        address = KMD.address.for_p2pkh(child_key.hash160())
        public_key_hex = child_key.sec().hex()
        # private_key_wif = child_key.wif()
        private_key_wif = KMD.wif_for_blob(to_bytes_32(child_key.secret_exponent()) + b'\01')
        print(f"{path}\t{address}\t{public_key_hex}\t{private_key_wif}")
        # print(f"{wif_to_bech32_address(private_key_wif)}")

if __name__ == "__main__":
    main()
