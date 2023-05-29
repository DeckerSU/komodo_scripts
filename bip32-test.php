<?php

// Example of BIP32 key(s) derivation from Test vector 2 of BIP32 standart.

// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
// https://habr.com/ru/companies/distributedlab/articles/413627/

/*

BIP32 - is a method for generating a tree of private keys from a master private key.
BIP39 - is a method for encoding 128-256 bits of random data into 12-24 word phrases from a list of interchangeable 2018 words, and then turn those phrases into a 64-byte hash.
BIP44 - is a method for structuring a private key tree in a specific way that will facilitate usage/restoration/discovery of multiple accounts for multiple purposes.

bip32 = hd wallets, what they are how they work
bip39 = specific type of mnemonic, and the process for turning it into a bip32 seed
bip44 = a specific format of a bip32 wallet

*/

require_once 'BitcoinECDSA.php/src/BitcoinPHP/BitcoinECDSA/BitcoinECDSA.php';
use BitcoinPHP\BitcoinECDSA\BitcoinECDSA;

function bip32_derive($bip32_root_key, $derivation_path) {
    $bitcoinECDSA = new BitcoinECDSA();
    if (substr($bip32_root_key, 0, 4) =="xprv") {
        $xprv_decoded = $bitcoinECDSA->base58_decode($bip32_root_key);
        $xprv_decoded = hex2bin($xprv_decoded);
        $xprv_decoded = unpack("H8version/Cdepth/H8fingerprint/H8child/H64chaincode/H66privatekey", $xprv_decoded);
        if ($xprv_decoded["version"] == "0488ade4") {
            $cc_par = hex2bin($xprv_decoded["chaincode"]);
            $k_par = hex2bin(substr($xprv_decoded["privatekey"], 2, 64));
            $depth = $xprv_decoded["depth"];
            // TODO: implement derivation
        }
    }
    return [];
}

// (NB!) Change zend.assertions to 1 in your php.ini to make assertions work.

$bitcoinECDSA = new BitcoinECDSA();

$seed = pack("H*", "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542");

// hash_hmac(string $algo, string $data, string $key, bool $binary = false): string

$i = pack("H*", hash_hmac('sha512', $seed, 'Bitcoin seed'));
$il = substr($i, 0, 32);  // private key (bin)
$ir = substr($i, 32, 32); // chain code (bin)

echo "privkey: " . bin2hex($il) . PHP_EOL;
echo "chncode: " . bin2hex($ir) . PHP_EOL;

$depth = 0;
$fingerprint = 0;
$child_number = 0;

/*
    4 byte: version bytes (mainnet: 0x0488B21E public, 0x0488ADE4 private; testnet: 0x043587CF public, 0x04358394 private)
    1 byte: depth: 0x00 for master nodes, 0x01 for level-1 derived keys, ....
    4 bytes: the fingerprint of the parent's key (0x00000000 if master key)
    4 bytes: child number. This is ser32(i) for i in xi = xpar/i, with xi the key being serialized. (0x00000000 if master key)
    32 bytes: the chain code
    33 bytes: the public key or private key data (serP(K) for public keys, 0x00 || ser256(k) for private keys)
*/

$base58data = "0488ade4" .
              bin2hex(pack("C", $depth)) .
              bin2hex(pack('l', $fingerprint)) .
              bin2hex(pack('l', $child_number)) .
              bin2hex($ir) .
              "00" .
              bin2hex($il);

$checksum = substr(hash('sha256', hash('sha256', hex2bin($base58data), true), true), 0, 4);

$base58data .= bin2hex($checksum);

assert($bitcoinECDSA->base58_encode($base58data) == 'xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U');

echo 'Chain m' . PHP_EOL;
echo "ext prv: " . $bitcoinECDSA->base58_encode($base58data) . PHP_EOL;

$k = bin2hex($il);
$bitcoinECDSA->setNetworkPrefix("00");
$bitcoinECDSA->setPrivateKey($k);
$pubkey = $bitcoinECDSA->getPubKey();

$base58data = "0488b21e" .
              bin2hex(pack("C", $depth)) .
              bin2hex(pack('l', $fingerprint)) .
              bin2hex(pack('l', $child_number)) .
              bin2hex($ir) .
              $pubkey;

$checksum = substr(hash('sha256', hash('sha256', hex2bin($base58data), true), true), 0, 4);

$base58data .= bin2hex($checksum);

assert($base58data == $bitcoinECDSA->base58_decode('xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB'));
echo "ext pub: " . $bitcoinECDSA->base58_encode($base58data) . PHP_EOL;

$cc_par = $ir; $k_par = $il;

$depth = 1;
// fingerprint of the parent's key (0x00000000 if master key)
$fingerprint = bin2hex(substr(hash('ripemd160', hash('sha256', hex2bin($pubkey), true), true), 0, 4)); // Hash160 (RIPEMD160 after SHA256)
$fingerprint = unpack("l", hex2bin($fingerprint))[1];
$child_number = 0;
$hardened = 0;
echo 'Chain m/' . $child_number . ($hardened ? "'" : "") . PHP_EOL;

// hash_hmac(string $algo, string $data, string $key, bool $binary = false): string
if ($hardened) {
    $i = pack("H*", hash_hmac('sha512', pack("C", 0x00) . $k_par . strrev(pack('l', 0x80000000 + $child_number)), $cc_par));
} else {
    $i = pack("H*", hash_hmac('sha512', hex2bin($pubkey) . strrev(pack('l', $child_number)), $cc_par));
}

$il = substr($i, 0, 32);  // private key (bin)
$ir = substr($i, 32, 32); // chain code (bin)


// The order of the curve secp256k1 is
// 2^256 − 2^32 − 2^9 − 2^8 − 2^7 − 2^6 − 2^4 − 1, which is equal to 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141.
// The modulo n of an integer x is therefore x mod n = x (mod 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141).
// https://en.bitcoin.it/wiki/Allprivatekeys

$order = gmp_init('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', 16);
$gmp1 = gmp_init(bin2hex($il), 16);
$gmp2 = gmp_init(bin2hex($k_par), 16);
$add = gmp_add($gmp1, $gmp2);
$add = gmp_mod($add, $order);
$ki = gmp_strval($add,16);
$ki = str_pad($ki, 64, '0', STR_PAD_LEFT);

$bitcoinECDSA->setPrivateKey($ki);
$wif = $bitcoinECDSA->getWIF();
$this_pubkey = $bitcoinECDSA->getPubKey();
echo "privkey: " . $ki . " (" . $wif . ")" . PHP_EOL;
echo " pubkey: " . $this_pubkey . PHP_EOL;
echo "address: " . $bitcoinECDSA->getAddress() . PHP_EOL;

echo "chncode: " . bin2hex($ir) . PHP_EOL;

$base58data = "0488ade4" .
              bin2hex(pack("C", $depth)) .
              bin2hex(pack('l', $fingerprint)) .
              bin2hex(strrev(pack('l', ($hardened ? 0x80000000 : 0x0) + $child_number))) . // serialize a 32-bit unsigned integer i as a 4-byte sequence, most significant byte first.
              bin2hex($ir) .
              "00" .
              $ki;

$checksum = substr(hash('sha256', hash('sha256', hex2bin($base58data), true), true), 0, 4);
$base58data .= bin2hex($checksum);
echo "ext prv: " . $bitcoinECDSA->base58_encode($base58data) . PHP_EOL;
assert($base58data == $bitcoinECDSA->base58_decode('xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt'));

$k = $ki;
$bitcoinECDSA = new BitcoinECDSA();
$bitcoinECDSA->setNetworkPrefix("00");
$bitcoinECDSA->setPrivateKey($k);
$pubkey = $bitcoinECDSA->getPubKey();

$base58data = "0488b21e" .
              bin2hex(pack("C", $depth)) .
              bin2hex(pack('l', $fingerprint)) .
              bin2hex(strrev(pack('l', ($hardened ? 0x80000000 : 0x0) + $child_number))) .
              bin2hex($ir) .
              $pubkey;

$checksum = substr(hash('sha256', hash('sha256', hex2bin($base58data), true), true), 0, 4);
$base58data .= bin2hex($checksum);
assert($base58data == $bitcoinECDSA->base58_decode('xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH'));
echo "ext pub: " . $bitcoinECDSA->base58_encode($base58data) . PHP_EOL;

var_dump(bip32_derive("xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt", "m/0"));

?>