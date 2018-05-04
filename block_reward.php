<?php

/* (c) Decker, 2018 */

define('RPCUSER',"user");
define('RPCPASSWORD',"password");
define('RPCPORT',7771);
define('SATOSHIDEN', "100000000");
define('LASTBLOCKS',2000);

// > curl --user myusername --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getblock", "params": [12800] }' -H 'content-type: text/plain;' http://127.0.0.1:8232/                        
$notaries = Array("RNJmgYaFF5DbnrNUX6pMYz9rcnDKC2tuAc" => "0dev1_jl777",
"RLj9h7zfnx4X9hvquR3sEwzHvcvF61W2Rc" => "0dev2_kolo",
"RTZi9uC1wEu3PD9eoL4R7KyeAse7uvdHuS" => "0dev3_kolo",
"RDECKVXcWCgPpMrKqQmMX7PxzQVLCzcR5a" => "0dev4_decker",
"RSuXRScqHNbRFqjur2C3tf3oDoauBs2B1i" => "a-team_SH",
"RXF3aHUaWDUY4fRRYmBNALoHWkgSQCiJ4f" => "artik_AR",
"RL2SkPSCGMvcHqZ56ErfMxbQGdA4nk7MZp" => "artik_EU",
"RFssbc211PJdVy1bvcvAG5X2N4ovPAoy5o" => "artik_NA",
"RNoz2DKPZ2ppMxgYx5tce9sjZBHefvPvNB" => "artik_SH",
"RVxtoUT9CXbC1LdhztNAf9yR5ySnFnSPQh" => "badass_EU",
"R9XBrbj8iKkwy9M4erUqRaBinAiZSTXav3" => "badass_NA",
"RVvcVXkqWmMmjQdFnqwQbtPrdU7DFpHA3G" => "batman_AR",
"RY5TZSnmtGZLFMpnJTE6gDRyk1zDvMktcc" => "batman_SH",
"RUvwCVA1NfDB6ZWrEgVYZHWGjMzpxm19r1" => "ca333_EU",
"RSQUoSfM7R7SnatK6Udsb5t39movCpUKQE" => "chainmakers_EU",
"RLF3sBrXAdofwDnS2114mkBMSBeJDd5Doy" => "chainmakers_NA",
"RXrQPqU4SwARri1m2n7232TDECvjzXCJh4" => "chainstrike_SH",
"RBZxvAMqt1QhkvmiMRqDGRBW9QaQjqPEpF" => "cipi_AR",
"RD2uPC7aUkX9tQTYgRvDb2HQPWa22VttEE" => "cipi_NA",
"RA7nJEoqNGu13P7Gv4mWfoJTmpZ9ac2Bh2" => "crackers_EU",
"RQcBfvJLyB96GCuTBRUNckQESw8LYjHQaC" => "crackers_NA",
"RWVt3CDvXXAw5NeyMrjUC8s7YssAJ9j4A4" => "dwy_EU",
"RBHCkuYMUbQph7MZsHcZYfGfyqBm8Y4jFQ" => "emmanux_SH",
"RPjUmFNcWEW9Bu275kPxzRXyWDz6bfQpPD" => "etszombi_EU",
"RAtXFwGsgtsHJGuKhJBMbB8vri3SRVQYeu" => "fullmoon_AR",
"RAtyzPtx7yeH7jhFkD7e2dhf2p429Cn3tQ" => "fullmoon_NA",
"R9WsywChUgTumbK2cf1RdjHrWMZV3nfs3a" => "fullmoon_SH",
"RHzbQkW7oLK43GKEPK78rSCs7WDiaa4dbw" => "goldenman_EU",
"RFQNjTfcvSAmf8D83og1NrdHj1wH2fc5X4" => "indenodes_AR",
"RPknkGAHMwUBvfKQfvw9FyatTZzicSiN4y" => "indenodes_EU",
"RMqbQz4NPNbG15QBwy9EFvLn4NX5Fa7w5g" => "indenodes_NA",
"RQipE6ycbVVb9vCkhqrK8PGZs2p5YmiBtg" => "indenodes_SH",
"RUc5sa136Agwb9dSfMKn1oc7myHkUzeZf4" => "jackson_AR",
"RCA8H1npFPW5pnJRzycF8tFEJmn6XZhD4j" => "jeezy_EU",
"RJD5jRidYW9Cu8qxjg9HDCsx6J3A4wQ4LU" => "karasugoi_NA",
"RWgpXEycP4rVkFp3j7WzV6E2LfR842WswN" => "komodoninja_EU",
"RVAUHZ4QGzxmW815b98oMv943FCms6AzUi" => "komodoninja_SH",
"RGxBQho3stt6EiApWTzFZxDvqqsM8GwAuk" => "komodopioneers_SH",
"RHuUpCbaGbv27fsjC1p6xwtwRzKQ1exqaA" => "libscott_SH",
"RPxsaGNqTKzPnbm5q7QXwu7b6EZWuLxJG3" => "lukechilds_AR",
"RQ5JmyvjzGMxZvs2auTabXVQeuxrA2oBjy" => "madmax_AR",
"RV8Khq8SbYQALx9eMQ8meseWpFiZS8seL1" => "meshbits_AR",
"RH1vUjh6JBX7dpPR3C89U8hzErp1uoa2by" => "meshbits_SH",
"RKdXYhrQxB3LtwGpysGenKFHFTqSi5g7EF" => "metaphilibert_AR",
"RRrqjqDPZ9XC6xJMeKgf7GNHjiU88hJQ16" => "metaphilibert_SH",
"RBp1xHCAb3XcLAV49F8wUYw3aBvhHKKEwa" => "patchkez_SH",
"REX8jNcUki4NyNde3ovr5ZgjwnCyRZYczv" => "pbca26_NA",
"RH2Tuan5wt9x19aBPgTHPtkh2koWCEsjEK" => "peer2cloud_AR",
"RSp8vhyL6hN3yqn5V1qje62pBgBE9fv3Eh" => "peer2cloud_SH",
"RE3P8D8rcWZBeKmT8DURPdezW87MU5Ho3F" => "polycryptoblog_NA",
"RTWpNfpcQgGYnrtgdUyqoPiF9r2CJoAw6Z" => "hyper_AR",
"RQMyeeSyKFUTd7cYTM1Fq7nSt6zJZKNubi" => "hyper_EU",
"RFCZc3SnyEtUTSVDkHEvrm7tCdhiDMufLx" => "hyper_SH",
"RTdEgZV1QEsBTphiRRdk4FcstTBJ8wAkRX" => "hyper_NA",
"RWPhKTa5Huepz19TYrxAE65rQn3D3xPrNw" => "popcornbag_AR",
"RVQAwUJdFVVK2Pjiq4rYkvMSiZucHtJA7X" => "popcornbag_NA",
"RBHzJTW73U3nyHyxBwiG92bJckxZowPY87" => "alien_AR",
"RUdfZrpAhYyT4LVz6Vyj2K14yK1uC2K4Dz" => "alien_EU",
"RAusaHRqdMmML3szif3Wai1ZSEWCyu7X9Y" => "thegaltmines_NA",
"RWk4WLiAv6MKWLozJbj1jyhayKtjwbtX7M" => "titomane_AR",
"RCTgouafkve3rCSaqmm89TUpKGvQSTFr5M" => "titomane_EU",
"RAqoFL81YGFJ7hidAYUw2rzX8wjFKPCecP" => "titomane_SH",
"RMbNsa4Nf3BAd16BQaAAmfzAgnuorUDrCr" => "webworker01_NA",
"RLQoAcs1RaqW1xfN2NJwoZWW5twexPhuGB" => "xrobesx_NA",
);

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

echo '<link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" rel="stylesheet"/>
<link href="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.12/css/dataTables.bootstrap.min.css" rel="stylesheet"/>
<div class="container">
   <!-- (c) Decker, 2018 -->
   <h1>Unclaimed Interest Table</h1>
   <p>This table shows unclaimed interest for last '.LASTBLOCKS.' blocks. Generated by <i>Decker</i>.</p>
   <table id="example" class="table table-striped table-bordered table-hover" cellspacing="0" width="100%">
      <thead>
         <tr>
            <th>Block #</th>
            <th>Address</th>
            <th>Notary / GPU</th>
            <th>KMD</th>
         </tr>
      </thead>
      <tbody>';
$blocks_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getblockcount", Array());
if ($blocks_res["http_code"] == 200) {
    $blocks_json_object = json_decode($blocks_res["result"]);
    $blocks = $blocks_json_object->result;
    
    for ($block_height = ($blocks-LASTBLOCKS); $block_height < $blocks; $block_height++) {
    //for ($block_height = 1; $block_height < $blocks; $block_height++) {
        if ($block_height % 1000 == 0) fwrite(STDERR, "Parsing block #$block_height\n");
        $res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getblock", Array("".$block_height));
        if ($res["http_code"] == 200) {
            $json_object = json_decode($res["result"]);
            $hash = $json_object->result->hash;
            $height = $json_object->result->height;
            $txs = $json_object->result->tx;
            /*foreach ($txs as $tx) {
                echo $tx . "\n";
            }*/
            if ($txs[0]) {
                $tx_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getrawtransaction", Array($txs[0], 1));
                $value = "0"; $address = "";
                if ($tx_res["http_code"] == 200) {
                    $tx_json_object = json_decode($tx_res["result"]);
                    //var_dump($tx_json_object);
                    $value = "".$tx_json_object->result->vout[0]->value;
                    $address = "".$tx_json_object->result->vout[0]->scriptPubKey->addresses[0];
                    $notary = "GPU";
                    if (array_key_exists($address,$notaries))
                        $notary = $notaries[$address];
                    if (bccomp($value,"4",8) == 1) 
                    {
                        //echo sprintf("#%6d",$height)." - ".$address." - ".$value." KMD\n";
                        echo '
         <tr>
            <td><a href="https://kmdexplorer.ru/block/'.$hash.'" target="_blank" >'.sprintf("%6d",$height).'</a></td>
            <td><a href="https://kmdexplorer.ru/address/'.$address.'" target="_blank">'.$address.'</a></td>
            <td>'.$notary.'</td>
            <td>'.$value.'</td>
         </tr>
';
                    }
                }

            }

        }
    }
}
echo '      </tbody>
   </table>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script><script src="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.12/js/jquery.dataTables.min.js"></script><script src="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.12/js/dataTables.bootstrap.min.js"></script>

<script>
$(document).ready(function() {
  $("#example").DataTable();
});
</script>
'
?>