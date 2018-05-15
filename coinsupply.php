<?php

/* (c) Decker, 2018 */

// curl and gmp php extensions required (!), google "how to install php-gmp extension" ;)

define('RPCUSER',"user");
define('RPCPASSWORD',"password");
define('RPCPORT',7771);
define('SATOSHIDEN', "100000000");
define('LASTBLOCKS',2000);

function daemon_request($daemon_ip, $rpcport, $rpcuser, $rpcpassword, $method, $params)
{
    
    $ch = curl_init();
    $url = $daemon_ip.":".RPCPORT;
    // var_dump($url);
    
    curl_setopt($ch, CURLOPT_AUTOREFERER, TRUE);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);   
    curl_setopt($ch, CURLOPT_USERPWD, $rpcuser . ":" . $rpcpassword);  
    curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
    $payload = json_encode( array( "method"=> $method, "params" => $params ) );
    // var_dump($payload);
    curl_setopt( $ch, CURLOPT_POSTFIELDS, $payload );
    curl_setopt( $ch, CURLOPT_HTTPHEADER, array('Content-Type:application/json'));


    $data["result"] = curl_exec($ch);
    $data["http_code"] = curl_getinfo($ch)["http_code"];
    curl_close($ch);
    // var_dump($data);
    return $data;

}

if(php_sapi_name() != "cli") return;

// https://stackoverflow.com/questions/31888566/bootstrap-how-to-sort-table-columns

$blocks_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getblockcount", Array());
if ($blocks_res["http_code"] == 200) {
    $blocks_json_object = json_decode($blocks_res["result"]);
    $blocks = $blocks_json_object->result;
    
    $sumvalueZat = "0";
    for ($block_height = 0; $block_height < $blocks; $block_height++) {
    //for ($block_height = 1; $block_height < $blocks; $block_height++) {
        if ($block_height % 1000 == 0) 
            { 
                fwrite(STDERR, "Parsing block #$block_height (".bcdiv($sumvalueZat, SATOSHIDEN, 8)." KMD)\n");
            }
        
        $fgetblocksuccess = false;
        
        while (!$fgetblocksuccess) {
        $res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getblock", Array("".$block_height));
        if ($res["http_code"] == 200) {
            $fgetblocksuccess = true;
            $json_object = json_decode($res["result"]);
            $hash = $json_object->result->hash;
            $height = $json_object->result->height;
            $txs = $json_object->result->tx;
            /*foreach ($txs as $tx) {
                echo $tx . "\n";
            }*/
            if ($txs[0]) {
                $fgettxsuccess = false;
                
                if ($txs[0] == "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b") $fgettxsuccess = true;
                
                while (!$fgettxsuccess) {
                $tx_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getrawtransaction", Array($txs[0], 1));
                $value = "0"; $address = "";
                if ($tx_res["http_code"] == 200) {
                    $fgettxsuccess = true;
                    $tx_json_object = json_decode($tx_res["result"]);
                    //var_dump($tx_json_object);
                    //$value = "".$tx_json_object->result->vout[0]->value;
                    //$address = "".$tx_json_object->result->vout[0]->scriptPubKey->addresses[0];
                    $vouts = $tx_json_object->result->vout;
                    if (count($vouts) > 0) {
                        foreach($vouts as $vout) {
                            $sumvalueZat = bcadd($sumvalueZat, $vout->valueZat);
                        }
                    }
                }
                if (!$fgettxsuccess) { 
                    fwrite(STDERR, "Re-requesting tx #".$block_height."/".$txs[0]."\n");
                sleep(60);
                }
                
                } // while (!$fgettxsuccess) 

            }

        }
        if (!$fgetblocksuccess) { 
            fwrite(STDERR, "Re-requesting block #$block_height (".bcdiv($sumvalueZat, SATOSHIDEN, 8)." KMD)\n");
            sleep(60);
        }
        } // while (!$fgetblocksuccess) 
    }
} else die("Can't request block count [ERROR ".$blocks_res["http_code"]."] ".var_export($blocks_res["result"],1));
echo "Coin Supply: " . bcdiv($sumvalueZat, SATOSHIDEN, 8) . " KMD\r\n";

?>