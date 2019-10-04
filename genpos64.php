<?php

/*
Address Creation Script for Komodo POS64 staking (c) Decker, 2018-2019

This small PHP script will generate 64 random addresses with different segids, also
it will create set of ./komodo-cli importprivkey commands to import it in a wallet and
sendmany command to fund all of created addresses. Plz, note that all 64 addresses are
random and doesn't depends of passphrase / seed or any other things. If you will loose
privkeys / wifs from these addresses - you will loose your funds.
*/

require_once 'BitcoinECDSA.php/src/BitcoinPHP/BitcoinECDSA/BitcoinECDSA.php';
use BitcoinPHP\BitcoinECDSA\BitcoinECDSA;

define('PUBKEY_ADDRESS', 60);
define('SECRET_KEY', 188);
define('BALANCE_TO_SEND', 777);

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

function komodo_segid32($address) {
    // segid - first byte of sha256(address) and 0x3f
    return hexdec(substr(hash ( "sha256" , $address ), 0, 2)) & 0x3f;
}

function escapeJsonString($value) { # list from www.json.org: (\b backspace, \f formfeed)
    $escapers = array("\\", "/", "\"", "\n", "\r", "\t", "\x08", "\x0c");
    $replacements = array("\\\\", "\\/", "\\\"", "\\n", "\\r", "\\t", "\\f", "\\b");
    $result = str_replace($escapers, $replacements, $value);
    return $result;
}

if (php_sapi_name() !== "cli") return;

$bitcoinECDSA = new BitcoinECDSADecker();
$bitcoinECDSA->setNetworkPrefix(sprintf("%02X", PUBKEY_ADDRESS)); 

$privkeys = Array(); 

// here we will create random addresses in a loop and fill the 64 addresses array
// until we have 64 different segids. of course we will create more than 64 addresses,
// but actually we will use as result only 64 of them with segids from 0 to 63.

while (count($privkeys) < 64) {
    $bitcoinECDSA->generateRandomPrivateKey(); 
    $compressed_address = $bitcoinECDSA->getAddress();
    $segid = komodo_segid32($compressed_address);
    $privkeys[$segid] = $bitcoinECDSA->getWIF( true, SECRET_KEY);
}
ksort($privkeys); // sort by segid is don't needed, but it's nice ;)

$addresses = Array();
foreach($privkeys as $pk) {
    $bitcoinECDSA->setPrivateKeyWithWif($pk);
    $compressed_address = $bitcoinECDSA->getAddress();
    $segid = komodo_segid32($compressed_address);
    // if ($pk == $bitcoinECDSA->getWIF( true, SECRET_KEY)) {
    //     echo $bitcoinECDSA->getWIF( true, SECRET_KEY) . sprintf(" // [%d] %s", $segid, $compressed_address)  . PHP_EOL;
    // }

    // echo $pk . sprintf(" // [%d] %s", $segid, $compressed_address)  . PHP_EOL;
    echo sprintf('./komodo-cli importprivkey "%s" "%s" %s', $pk, "[".$segid."] " . $compressed_address, "false") . PHP_EOL;
        
    $addresses[$compressed_address] = BALANCE_TO_SEND;
}

echo PHP_EOL;
echo sprintf('sendmany "" "%s"', escapeJsonString(json_encode($addresses))) . PHP_EOL;

?>