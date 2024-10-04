<?php

// https://github.com/BitcoinPHP/BitcoinECDSA.php
require_once 'BitcoinECDSA.php/src/BitcoinPHP/BitcoinECDSA/BitcoinECDSA.php';
use BitcoinPHP\BitcoinECDSA\BitcoinECDSA;

require_once 'Keccak256.php';
use Keccak\Keccak256;

/* ETH EIP55 implementation (2 variants) */
/* https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md */
function bytesToBits(string $bytestring) {
  if ($bytestring === '') return '';

  $bitstring = '';
  foreach (str_split($bytestring, 4) as $chunk) {
    $bitstring .= str_pad(base_convert(unpack('H*', $chunk)[1], 16, 2), strlen($chunk) * 8, '0', STR_PAD_LEFT);
  }
  return $bitstring;
}

function EIP55_1($address) {
$address_eip55 = ""; $kec = new Keccak256();
$addressHash = $kec->hash(strtolower($address), 256);
$addressHashBits = bytesToBits(pack("H*",$addressHash));
for ($i = 0; $i < 40; $i++ ) {
$c = $address[$i];

if (ctype_alpha($address[$i])) {
        if ($addressHashBits[4 * $i] == "1") $c = strtoupper($c);
}
$address_eip55 .= $c;
}
return $address_eip55;
}

function EIP55_2($address) {
$address_eip55 = ""; $kec = new Keccak256();
$addressHash = $kec->hash(strtolower($address), 256);
for ($i = 0; $i < 40; $i++ ) {
	if (intval($addressHash[$i], 16) >=8) $address_eip55 .= strtoupper($address[$i]); else $address_eip55 .= strtolower($address[$i]);
}
return $address_eip55;
}
/* ETH EIP55 implementation ------------ */

class BitcoinECDSADecker extends BitcoinECDSA {

    /***
     * Tests if the address is valid or not.
     *
     * @param string $address (base58)
     * @return bool
     */
    public function validateAddress($address)
    {
        $address    = hex2bin($this->base58_decode($address));

        /*
        if(strlen($address) !== 25)
            return false;
        $checksum   = substr($address, 21, 4);
        $rawAddress = substr($address, 0, 21);
	*/

	$len = strlen($address);
        $checksum   = substr($address, $len-4, 4);
        $rawAddress = substr($address, 0, $len-4);

        if(substr(hex2bin($this->hash256($rawAddress)), 0, 4) === $checksum)
            return true;
        else
            return false;
    }

    /**
     * Returns the current network prefix for WIF, '80' = main network, 'ef' = test network.
     *
     * @return string (hexa)
     */
    public function getPrivatePrefix($PrivatePrefix = 128){

        if($this->networkPrefix =='6f')
            return 'ef';
        else
           return sprintf("%02X",$PrivatePrefix);
    }
    /***
     * returns the private key under the Wallet Import Format
     *
     * @return string (base58)
     * @throws \Exception
     */

    public function getWIF($compressed = true, $PrivatePrefix = 128)
    {
        if(!isset($this->k))
        {
            throw new \Exception('No Private Key was defined');
        }

        $k          = $this->k;
        
        while(strlen($k) < 64)
            $k = '0' . $k;
        
        $secretKey  =  $this->getPrivatePrefix($PrivatePrefix) . $k;
        
        if($compressed) {
            $secretKey .= '01';
        }
        
        $secretKey .= substr($this->hash256(hex2bin($secretKey)), 0, 8);

        return $this->base58_encode($secretKey);
    }
}

// bech32 related functions
const BECH32_CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

function bech32_polymod($values) {
    $generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    $chk = 1;
    foreach ($values as $v) {
        $top = $chk >> 25;
        $chk = (($chk & 0x1ffffff) << 5) ^ $v;
        for ($i = 0; $i < 5; $i++) {
            if (($top >> $i) & 1) {
                $chk ^= $generator[$i];
            }
        }
    }
    return $chk;
}

function bech32_hrp_expand($hrp) {
    $expanded = [];
    for ($i = 0; $i < strlen($hrp); $i++) {
        $expanded[] = ord($hrp[$i]) >> 5;
    }
    $expanded[] = 0;
    for ($i = 0; $i < strlen($hrp); $i++) {
        $expanded[] = ord($hrp[$i]) & 31;
    }
    return $expanded;
}

function bech32_create_checksum($hrp, $data) {
    $values = array_merge(bech32_hrp_expand($hrp), $data);
    $values = array_merge($values, [0, 0, 0, 0, 0, 0]);
    $polymod = bech32_polymod($values) ^ 1;
    $checksum = [];
    for ($i = 0; $i < 6; $i++) {
        $checksum[] = ($polymod >> (5 * (5 - $i))) & 31;
    }
    return $checksum;
}

function bech32_encode($hrp, $data) {
    $checksum = bech32_create_checksum($hrp, $data);
    $combined = array_merge($data, $checksum);
    $bech32 = $hrp . '1';
    foreach ($combined as $p) {
        $bech32 .= BECH32_CHARSET[$p];
    }
    return $bech32;
}

function convert_bits($data, $from_bits, $to_bits, $pad = true) {
    $acc = 0;
    $bits = 0;
    $ret = [];
    $maxv = (1 << $to_bits) - 1;
    foreach ($data as $value) {
        if ($value < 0 || ($value >> $from_bits)) {
            return null;
        }
        $acc = ($acc << $from_bits) | $value;
        $bits += $from_bits;
        while ($bits >= $to_bits) {
            $bits -= $to_bits;
            $ret[] = ($acc >> $bits) & $maxv;
        }
    }
    if ($pad) {
        if ($bits > 0) {
            $ret[] = ($acc << ($to_bits - $bits)) & $maxv;
        }
    } elseif ($bits >= $from_bits || (($acc << ($to_bits - $bits)) & $maxv)) {
        return null;
    }
    return $ret;
}

function bytesArrayToHexString(array $bytes): string {
    return implode('', array_map(fn($byte) => sprintf('%02x', $byte), $bytes));
}

$bitcoinECDSA = new BitcoinECDSADecker();

$passphrase = "myverysecretandstrongpassphrase_noneabletobrute";

/* available coins, you can add your own with params from src/chainparams.cpp */

$coins = Array(
    Array("name" => "BTC",  "PUBKEY_ADDRESS" =>  0, "SECRET_KEY" => 128),
    Array("name" => "LTC",  "PUBKEY_ADDRESS" => 48, "SECRET_KEY" => 176),
    Array("name" => "KMD",  "PUBKEY_ADDRESS" => 60, "SECRET_KEY" => 188),
    // Array("name" => "GAME", "PUBKEY_ADDRESS" => 38, "SECRET_KEY" => 166),
    // Array("name" => "HUSH", "PUBKEY_ADDRESS" => Array(0x1C,0xB8), "SECRET_KEY" => 0x80),
    // Array("name" => "EMC2", "PUBKEY_ADDRESS" => 33, "SECRET_KEY" => 176),
    // Array("name" => "GIN", "PUBKEY_ADDRESS" => 38, "SECRET_KEY" => 198),
    // Array("name" => "AYA", "PUBKEY_ADDRESS" => 23, "SECRET_KEY" => 176),
    // Array("name" => "GleecBTC", "PUBKEY_ADDRESS" => 35, "SECRET_KEY" => 65),
    // Array("name" => "MIL", "PUBKEY_ADDRESS" => 50, "SECRET_KEY" => 239),
    // Array("name" => "SFUSD", "PUBKEY_ADDRESS" => 63, "SECRET_KEY" => 188),
);

$k = hash("sha256", $passphrase);
$k = pack("H*",$k);
$k[0] = Chr (Ord($k[0]) & 248); 
$k[31] = Chr (Ord($k[31]) & 127); 
$k[31] = Chr (Ord($k[31]) | 64);
$k = bin2hex($k);

$bitcoinECDSA->setPrivateKey($k);
// uncomment the line below if you want to calc everything from WIF, instead of passphrase
// $bitcoinECDSA->setPrivateKeyWithWif("Uqe8cy26KvC2xqfh3aCpKvKjtoLC5YXiDW3iYf4MGSSy1RgMm3V5");
echo "             Passphrase: '" . $passphrase . "'" . PHP_EOL;
echo PHP_EOL;


foreach ($coins as $coin) {

    if (is_array($coin["PUBKEY_ADDRESS"])) {
        $NetworkPrefix = bin2hex(implode("",array_map("chr", $coin["PUBKEY_ADDRESS"])));
        $bitcoinECDSA->setNetworkPrefix($NetworkPrefix);
    } else
        $bitcoinECDSA->setNetworkPrefix(sprintf("%02X", $coin["PUBKEY_ADDRESS"]));

    // Returns the compressed public key. The compressed PubKey starts with 0x02 if it's y coordinate is even and 0x03 if it's odd, the next 32 bytes corresponds to the x coordinates.
    $NetworkPrefix = $bitcoinECDSA->getNetworkPrefix();

    echo "\x1B[01;37m[\x1B[01;32m "  . $coin["name"] . " \x1B[01;37m]\x1B[0m" . PHP_EOL;
    echo "         Network Prefix: " . $NetworkPrefix . PHP_EOL;
    echo "  Compressed Public Key: " . $bitcoinECDSA->getPubKey() . PHP_EOL;
    echo "Uncompressed Public Key: " . $bitcoinECDSA->getUncompressedPubKey() . PHP_EOL;
    echo "            Private Key: " . $bitcoinECDSA->getPrivateKey() . PHP_EOL;
    echo "         Compressed WIF: " . $bitcoinECDSA->getWIF( true, $coin["SECRET_KEY"]) . PHP_EOL;
    echo "       Uncompressed WIF: " . $bitcoinECDSA->getWIF(false, $coin["SECRET_KEY"]) . PHP_EOL;

    $address = $bitcoinECDSA->getAddress(); //compressed Bitcoin address
    echo "     Compressed Address: " . sprintf("%34s",$address) . PHP_EOL;
    $address = $bitcoinECDSA->getUncompressedAddress();
    echo "   Uncompressed Address: " . sprintf("%34s",$address) . PHP_EOL;

    /* P2SH-P2WPKH */
    if ($coin["name"] === "BTC") {
        $ripemd160 = $bitcoinECDSA->hash160(hex2bin($bitcoinECDSA->getPubKey()));
        $redeem_script = "00" . "14" . $ripemd160;
        $address = "05" . $bitcoinECDSA->hash160(hex2bin($redeem_script));
        $address .= substr($bitcoinECDSA->hash256(hex2bin($address)), 0, 8);
        $address = $bitcoinECDSA->base58_encode($address);
        if ($bitcoinECDSA->validateAddress($address)) {
            echo "Nested (P2WPKH-in-P2SH): " . $address . PHP_EOL;
        }
    }

    /* P2WPKH (bech32) */
    /*
        - https://bitcointalk.org/index.php?topic=4992632
        - https://en.bitcoin.it/wiki/Bech32
        - https://en.bitcoin.it/wiki/BIP_0173
        - https://www.reddit.com/r/Bitcoin/comments/62fydd/pieter_wuille_lecture_on_new_bech32_address_format/?rdt=49947
        - https://learnmeabitcoin.com/technical/keys/#address-bech32
    */
    if ($coin["name"] === "BTC" || $coin["name"] === "LTC") {
        $ripemd160 = $bitcoinECDSA->hash160(pack("H*",$bitcoinECDSA->getPubKey()));
        // echo "             RIPEMD-160: " . $ripemd160 . PHP_EOL;
        $data = convert_bits(array_values(unpack('C*', hex2bin($ripemd160))), 8, 5);
        $hrp = ($coin["name"] === "BTC") ? 'bc' : (($coin["name"] === "LTC") ? 'ltc' : ''); $witness_version = 0;
        $witness_data = array_merge([$witness_version], convert_bits(array_values(unpack('C*', hex2bin($ripemd160))), 8, 5));
        $bech32_address = bech32_encode($hrp, $witness_data);
        echo "Bech32 Address (P2WPKH): " . $bech32_address . PHP_EOL;
    }
}

/* ETH/ERC20 */

// https://ethereum.stackexchange.com/questions/3542/how-are-ethereum-addresses-generated
// https://www.npmjs.com/package/node-eth-address
// https://theethereum.wiki/w/index.php/Accounts,_Addresses,_Public_And_Private_Keys,_And_Tokens
// https://ethereum.stackexchange.com/questions/3720/how-do-i-get-the-raw-private-key-from-my-mist-keystore-file
// https://ethereum.stackexchange.com/questions/12830/how-to-get-private-key-from-account-address-and-password
// https://github.com/ethereum/EIPs/issues/55#issuecomment-187159063
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md

echo "\x1B[01;37m[\x1B[01;32m "  . "ETH/ERC20" . " \x1B[01;37m]\x1B[0m" . PHP_EOL;
$kec = new Keccak256();
$bitcoinECDSA->setPrivateKey($k);
$pubkey = substr($bitcoinECDSA->getUncompressedPubKey(),2);

$address = substr($kec->hash(pack("H*",$pubkey), 256), -40);
echo "   ETH/ERC20 Address: 0x" . EIP55_2($address) . PHP_EOL;
?>
