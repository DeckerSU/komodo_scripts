<?php

/*
- https://github.com/lt/PHP-Curve25519
- https://github.com/FiloSottile/zcash-mini

*/

require_once 'sha256f.php';

require_once 'Curve25519.php';
use Curve25519\Curve25519;

function base58_permutation($char, $reverse = false)
    {
        $table = [
                  '1','2','3','4','5','6','7','8','9','A','B','C','D',
                  'E','F','G','H','J','K','L','M','N','P','Q','R','S','T','U','V','W',
                  'X','Y','Z','a','b','c','d','e','f','g','h','i','j','k','m','n','o',
                  'p','q','r','s','t','u','v','w','x','y','z'
                 ];

        if($reverse)
        {
            $reversedTable = [];
            foreach($table as $key => $element)
            {
                $reversedTable[$element] = $key;
            }

            if(isset($reversedTable[$char]))
                return $reversedTable[$char];
            else
                return null;
        }

        if(isset($table[$char]))
            return $table[$char];
        else
            return null;
}

function base58_encode($data, $littleEndian = true)
{
    $res = '';
    $dataIntVal = gmp_init($data, 16);
    while(gmp_cmp($dataIntVal, gmp_init(0, 10)) > 0)
    {
        $qr = gmp_div_qr($dataIntVal, gmp_init(58, 10));
        $dataIntVal = $qr[0];
        $reminder = gmp_strval($qr[1]);
        if(!base58_permutation($reminder))
        {
            throw new \Exception('Something went wrong during base58 encoding');
        }
        $res .= base58_permutation($reminder);
    }

    //get number of leading zeros
    $leading = '';
    $i = 0;
    while(substr($data, $i, 1) === '0')
    {
        if($i!== 0 && $i%2)
        {
            $leading .= '1';
        }
        $i++;
    }

    if($littleEndian)
        return strrev($res . $leading);
    else
        return $res.$leading;
}

// set your privkey here (!!!)

$privkey = "017cf7a3970e85d40261ebc8d1573fa8c43ef2238b5f935acda1edf0bb41e08f";

//echo "     passphrase : `" . $passphrase . "`\n";
echo "        privkey : " . $privkey . "\n";
$s = $privkey."0000000000000000000000000000000000000000000000000000000000000000";
$s = pack("H*",$s);

/* here we should read ZCash sources in src/zcash/

Address.hpp
Address.cpp
prf.cpp
prf.h

*/

$s[0] = Chr(Ord($s[0]) | 0xc0); $s[32] = Chr(0);

$payingkey = php_compat_sha256($s,false,true);
echo "      payingkey : " . bin2hex(strrev(pack("H*",$payingkey))) . "\n";

$s = $privkey."0000000000000000000000000000000000000000000000000000000000000000";
$s = pack("H*",$s);
$s[0] = Chr(Ord($s[0]) | 0xc0); $s[32] = Chr(1);

$b = php_compat_sha256($s, false, true);

$Curve25519 = new Curve25519();
$transmissionkey = $Curve25519->publicKey(pack("H*",$b)); 
$transmissionkey = bin2hex($transmissionkey);

echo "transmissionkey : " . bin2hex(strrev(pack("H*",$transmissionkey))) . "\n";

$address = "169a" . $payingkey . $transmissionkey;
$address .= substr(php_compat_sha256(php_compat_sha256(pack("H*",$address), true), false), 0, 8); // checksum

$wif = "ab36" . $privkey;
$wif .= substr(php_compat_sha256(php_compat_sha256(pack("H*",$wif), true), false), 0, 8); // checksum

echo "Address: " . base58_encode($address) . "\n";
echo "   zWIF: " . base58_encode($wif) . "\n";

?>