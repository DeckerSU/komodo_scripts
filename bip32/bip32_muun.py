from pycoin.symbols.btc import network
from pycoin.contrib.bech32m import encode

# m/1'/1'
# m/1'/1'/0 -- generateChangeAddrs
# m/1'/1'/1 -- generateExternalAddrs
# m/1'/1'/2 -- generateContactAddrs

# UserKey, MuunKey

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

def multisig_2of2_address(user_pubkey_hex, muun_pubkey_hex):
    # Convert hex public keys to bytes
    user_pubkey = bytes.fromhex(user_pubkey_hex)
    muun_pubkey = bytes.fromhex(muun_pubkey_hex)

    # Create a 2-of-2 multisig redeem script
    # script_for_multisig(m, [pubkey1, pubkey2])
    pay_to_multisig_script = network.contract.for_multisig(2, [user_pubkey, muun_pubkey])
    info = network.contract.info_for_script(pay_to_multisig_script)
    # print(f"Script: {pay_to_multisig_script.hex()}\n{info}")

    #multisig_address = network.address.for_p2s(pay_to_multisig_script)
    multisig_address = network.address.for_p2s_wit(pay_to_multisig_script)

    return multisig_address

def multisig_2of2_address_p2tr(user_pubkey_hex, muun_pubkey_hex):

    user_pubkey = bytes.fromhex(user_pubkey_hex)
    muun_pubkey = bytes.fromhex(muun_pubkey_hex)
    if user_pubkey[0] not in (0x02, 0x03):
     raise ValueError("user_pubkey: Not a valid compressed secp256k1 public key")
    if muun_pubkey[0] not in (0x02, 0x03):
     raise ValueError("muun_pubkey: Not a valid compressed secp256k1 public key")
    
    user_pubkey_xonly = user_pubkey[1:]
    muun_pubkey_xonly = muun_pubkey[1:]

    # TODO ... 

    multisig_address = None
    return multisig_address

def main():

    root_user_xprv = "xprv9s21ZrQH143K2scgAKadJkpcMHGsjyeYZrmZpHxzHEgyHUH3W8XrL54GpMSPzmhkGYAJEHzANFtdJ6BgkXGt8uAKUzjfVzPBjZnwK7VMHhD"
    root_muun_xprv = "xprv9s21ZrQH143K3EVNKGfL24khbPNqHxjGmh3YrFY8hyBvhY6oSy699tEQDVqbiXhJXzPNfrKJ41b2N5UNYn33PxXMR9DqWDhF931ZARYfHkx"
    
    # Parse the root key
    user_root_key = network.parse.bip32(root_user_xprv)
    muun_root_key = network.parse.bip32(root_muun_xprv)


    addresses_type = "external"
    # Derive the keys 
    # Change   - user "0", muun - "1H/1H/0"
    # External - user "1", muun - "1H/1H/1"

    if addresses_type == "change":
        user_derived_key = user_root_key.subkey_for_path("0")
        muun_derived_key = muun_root_key.subkey_for_path("1H/1H/0")
    elif addresses_type == "external":
        user_derived_key = user_root_key.subkey_for_path("1")
        muun_derived_key = muun_root_key.subkey_for_path("1H/1H/1")
    else:
        raise ValueError("Invalid addresses_type. Expected 'change' or 'external'.")

    print("User BIP32 Extended Private Key (xprv):", user_derived_key.hwif(as_private=True))
    print("Muun BIP32 Extended Private Key (xprv):", muun_derived_key.hwif(as_private=True))

    num_addresses = 5
    
    print("Path\t\tAddress\t\t\t\tPublic Key (hex)\t\t\t\tPrivate Key (WIF)")
    print("---------------------------------------------------------------------------------------------------------")
    
    # Derive m/1'/1'/0/i and print details
    for i in range(num_addresses):

        user_child_key = user_derived_key.subkey(i, is_hardened=False)
        muun_child_key = muun_derived_key.subkey(i, is_hardened=False)
        path = f"{i}"

        user_address = user_child_key.address()
        user_public_key_hex =user_child_key.sec().hex()
        user_private_key_wif = user_child_key.wif()
        # print(f"{path}\t{wif_to_bech32_address(user_private_key_wif)}\t{user_public_key_hex}\t{user_private_key_wif}")

        muun_address = muun_child_key.address()
        muun_public_key_hex =muun_child_key.sec().hex()
        muun_private_key_wif = muun_child_key.wif()
        # print(f"{path}\t{wif_to_bech32_address(muun_private_key_wif)}\t{muun_public_key_hex}\t{muun_private_key_wif}")

        # Get the 2-of-2 multisig address
        two_of_two_address = multisig_2of2_address(user_public_key_hex, muun_public_key_hex)
        print(f"{path}\t{two_of_two_address}\t({user_public_key_hex},{muun_public_key_hex}\t({user_private_key_wif},{muun_private_key_wif}))")

        # two_of_two_address_p2tr = multisig_2of2_address_p2tr(user_public_key_hex, muun_public_key_hex)
        # print(f"{path}\t{two_of_two_address_p2tr}")

if __name__ == "__main__":
    main()
