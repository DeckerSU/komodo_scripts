from pycoin.symbols.btc import network
from pycoin.contrib.bech32m import bech32_decode, bech32_encode, decode, encode, Encoding

def wif_to_bech32_address(private_key_wif):
    """
    Convert a WIF private key to a Bech32 address.

    Parameters:
    private_key_wif (str): The WIF private key.

    Returns:
    str: The Bech32 address.
    """
    key = network.parse.wif(private_key_wif)
    pubkey_hash160 = key.hash160()
    witness_version = 0
    bech32_address = encode("bc", witness_version, pubkey_hash160)
    return bech32_address

def main():
    # Replace this with your own xprv key
    root_xprv = (
        "xprv9s21ZrQH143K2scgAKadJkpcMHGsjyeYZrmZpHxzHEgyHUH3W8XrL54GpMSPzmhkGYAJEHzANFtdJ6BgkXGt8uAKUzjfVzPBjZnwK7VMHhD"
    )
    
    # Parse the root key
    root_key = network.parse.bip32(root_xprv)

    # Derive the key at m/0 (unhardened)
    derived_key = root_key.subkey(0)
    m0_key = derived_key
    
    # Print out information for the derived node
    print("=== Derived Keys at m/0 ===")
    print("BIP32 Extended Private Key (xprv):", derived_key.hwif(as_private=True))
    print("BIP32 Extended Public Key (xpub):", derived_key.hwif())
    print("Private Key (WIF):", derived_key.wif())
    print("Public Key (sec):", derived_key.sec().hex())
    print("Address:", derived_key.address())

    # How many child addresses do you want to show?
    num_addresses = 5  # for example, we'll show m/0/0 through m/0/4
    
    print("Path\t\tAddress\t\t\t\tPublic Key (hex)\t\t\t\tPrivate Key (WIF)")
    print("---------------------------------------------------------------------------------------------------------")
    
    # Derive m/0/i and print details
    for i in range(num_addresses):

        child_key = m0_key.subkey(i)
        path = f"m/0/{i}"
        address = child_key.address()
        public_key_hex = child_key.sec().hex()
        private_key_wif = child_key.wif()
        print(f"{path}\t{address}\t{public_key_hex}\t{private_key_wif}")
        # print(f"{wif_to_bech32_address(private_key_wif)}")

        child_key = m0_key.subkey(i, is_hardened=True)
        path = f"m/0/{i}'"
        address = child_key.address()
        public_key_hex = child_key.sec().hex()
        private_key_wif = child_key.wif()
        
        print(f"{path}\t{address}\t{public_key_hex}\t{private_key_wif}")
        # print(f"{wif_to_bech32_address(private_key_wif)}")

if __name__ == "__main__":
    main()
