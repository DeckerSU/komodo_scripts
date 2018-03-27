<?php

function file_get_contents_curl($url) {
    $ch = curl_init();

    curl_setopt($ch, CURLOPT_AUTOREFERER, TRUE);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);       


    $data["result"] = curl_exec($ch);
    $data["http_code"] = curl_getinfo($ch)["http_code"];
    curl_close($ch);

    return $data;
}

// https://github.com/BitcoinPHP/BitcoinECDSA.php
require_once 'BitcoinECDSA.php/src/BitcoinPHP/BitcoinECDSA/BitcoinECDSA.php';

use BitcoinPHP\BitcoinECDSA\BitcoinECDSA;

class BitcoinECDSADecker extends BitcoinECDSA {
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

$bitcoinECDSA = new BitcoinECDSADecker();

$passphrase = "myverysecretandstrongpassphrase_noneabletobrute";
$k = hash("sha256", $passphrase);
$k = pack("H*",$k);
$k[0] = Chr (Ord($k[0]) & 248); 
$k[31] = Chr (Ord($k[31]) & 127); 
$k[31] = Chr (Ord($k[31]) | 64);
$k = bin2hex($k);

$bitcoinECDSA->setPrivateKey($k);
$bitcoinECDSA->setNetworkPrefix(sprintf("%02X", 60)); // 60 - Komodo

// Returns the compressed public key. The compressed PubKey starts with 0x02 if it's y coordinate is even and 0x03 if it's odd, the next 32 bytes corresponds to the x coordinates.
$NetworkPrefix = $bitcoinECDSA->getNetworkPrefix();
echo "             Passphrase: '" . $passphrase . "'" . PHP_EOL;
echo "         Network Prefix: " . $NetworkPrefix . PHP_EOL;
echo "  Compressed Public Key: " . $bitcoinECDSA->getPubKey() . PHP_EOL;
echo "Uncompressed Public Key: " . $bitcoinECDSA->getUncompressedPubKey() . PHP_EOL;
echo "            Private Key: " . $bitcoinECDSA->getPrivateKey() . PHP_EOL;
echo "         Compressed WIF: " . $bitcoinECDSA->getWIF(true, 188) . PHP_EOL;
echo "       Uncompressed WIF: " . $bitcoinECDSA->getWIF(false, 188) . PHP_EOL;

$balance = 0.0;
$address = $bitcoinECDSA->getAddress(); //compressed Bitcoin address
echo "  Compressed Address: " . sprintf("%34s",$address) . PHP_EOL;
$address = $bitcoinECDSA->getUncompressedAddress();
echo "Uncompressed Address: " . sprintf("%34s",$address) . PHP_EOL;

?>