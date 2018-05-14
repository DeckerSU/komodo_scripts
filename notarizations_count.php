<?php

/* (c) Decker, 2018 */

/* sqlite3 as DB will be required

sudo apt-get install php-pdo-sqlite 

Creating config file /etc/php/7.0/mods-available/sqlite3.ini with new version     
Creating config file /etc/php/7.0/mods-available/pdo_sqlite.ini with new version  

*/

define('RPCUSER',"user");
define('RPCPASSWORD',"password");
define('RPCPORT',7771);
define('SATOSHIDEN', "100000000");
define('LASTBLOCK',832596);

// iguana_globals.h
define ('CRYPTO777_PUBSECPSTR', "020e46e79a2a8d12b9b5d12c7a91adb4e454edfae43c0a0cb805427d2ac7613fd9");
define ('CRYPTO777_RMD160STR', "f1dce4182fce875748c4986b240ff7d7bc3fffb0");
define ('CRYPTO777_BTCADDR', "1P3rU1Nk1pmc2BiWC8dEy9bZa1ZbMp5jfg");
define ('CRYPTO777_KMDADDR', "RXL3YXG2ceaB6C5hfJcN4fvmLH2C34knhA");


// > curl --user myusername --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getblock", "params": [12800] }' -H 'content-type: text/plain;' http://127.0.0.1:8232/                         

// creating sqlite3 database

// https://www.if-not-true-then-false.com/2012/php-pdo-sqlite3-example/
// http://adatum.ru/primery-zaprosov-sqlite-s-pdo.html
// http://zametkinapolyah.ru/zametki-o-mysql/chast-11-3-pervichnye-klyuchi-v-bazax-dannyx-sqlite-primary-key-ogranichenie-pervichnogo-klyucha.html
// https://www.w3schools.com/sql/sql_groupby.asp

date_default_timezone_set('UTC');
$file_db = new PDO('sqlite:./notary.sqlite');
// Set errormode to exceptions
$file_db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
// Create table 
$file_db->exec("CREATE TABLE IF NOT EXISTS stats (
                    id INTEGER PRIMARY KEY, 
                    blockhash TEXT,
                    height INTEGER,
                    txid TEXT,
                    name TEXT,
                    pubkey TEXT,
                    UNIQUE(blockhash, height, txid, name, pubkey)
                    )");

$file_db->exec("CREATE TABLE IF NOT EXISTS notaries (
                    id INTEGER PRIMARY KEY, 
                    name TEXT,
                    pubkey TEXT,
                    UNIQUE (pubkey)
                    )");

//try {
$file_db->exec('INSERT OR IGNORE INTO notaries(name, pubkey) VALUES ("0dev1_jl777","03b7621b44118017a16043f19b30cc8a4cfe068ac4e42417bae16ba460c80f3828"),("0dev2_kolo","030f34af4b908fb8eb2099accb56b8d157d49f6cfb691baa80fdd34f385efed961"),("0dev3_kolo","025af9d2b2a05338478159e9ac84543968fd18c45fd9307866b56f33898653b014"),("0dev4_decker","028eea44a09674dda00d88ffd199a09c9b75ba9782382cc8f1e97c0fd565fe5707"),("a-team_SH","03b59ad322b17cb94080dc8e6dc10a0a865de6d47c16fb5b1a0b5f77f9507f3cce"),("artik_AR","029acf1dcd9f5ff9c455f8bb717d4ae0c703e089d16cf8424619c491dff5994c90"),("artik_EU","03f54b2c24f82632e3cdebe4568ba0acf487a80f8a89779173cdb78f74514847ce"),("artik_NA","0224e31f93eff0cc30eaf0b2389fbc591085c0e122c4d11862c1729d090106c842"),("artik_SH","02bdd8840a34486f38305f311c0e2ae73e84046f6e9c3dd3571e32e58339d20937"),("badass_EU","0209d48554768dd8dada988b98aca23405057ac4b5b46838a9378b95c3e79b9b9e"),("badass_NA","02afa1a9f948e1634a29dc718d218e9d150c531cfa852843a1643a02184a63c1a7"),("batman_AR","033ecb640ec5852f42be24c3bf33ca123fb32ced134bed6aa2ba249cf31b0f2563"),("batman_SH","02ca5898931181d0b8aafc75ef56fce9c43656c0b6c9f64306e7c8542f6207018c"),("ca333_EU","03fc87b8c804f12a6bd18efd43b0ba2828e4e38834f6b44c0bfee19f966a12ba99"),("chainmakers_EU","02f3b08938a7f8d2609d567aebc4989eeded6e2e880c058fdf092c5da82c3bc5ee"),("chainmakers_NA","0276c6d1c65abc64c8559710b8aff4b9e33787072d3dda4ec9a47b30da0725f57a"),("chainstrike_SH","0370bcf10575d8fb0291afad7bf3a76929734f888228bc49e35c5c49b336002153"),("cipi_AR","02c4f89a5b382750836cb787880d30e23502265054e1c327a5bfce67116d757ce8"),("cipi_NA","02858904a2a1a0b44df4c937b65ee1f5b66186ab87a751858cf270dee1d5031f18"),("crackers_EU","03bc819982d3c6feb801ec3b720425b017d9b6ee9a40746b84422cbbf929dc73c3"),("crackers_NA","03205049103113d48c7c7af811b4c8f194dafc43a50d5313e61a22900fc1805b45"),("dwy_EU","0259c646288580221fdf0e92dbeecaee214504fdc8bbdf4a3019d6ec18b7540424"),("emmanux_SH","033f316114d950497fc1d9348f03770cd420f14f662ab2db6172df44c389a2667a"),("etszombi_EU","0281b1ad28d238a2b217e0af123ce020b79e91b9b10ad65a7917216eda6fe64bf7"),("fullmoon_AR","03380314c4f42fa854df8c471618751879f9e8f0ff5dbabda2bd77d0f96cb35676"),("fullmoon_NA","030216211d8e2a48bae9e5d7eb3a42ca2b7aae8770979a791f883869aea2fa6eef"),("fullmoon_SH","03f34282fa57ecc7aba8afaf66c30099b5601e98dcbfd0d8a58c86c20d8b692c64"),("goldenman_EU","02d6f13a8f745921cdb811e32237bb98950af1a5952be7b3d429abd9152f8e388d"),("indenodes_AR","02ec0fa5a40f47fd4a38ea5c89e375ad0b6ddf4807c99733c9c3dc15fb978ee147"),("indenodes_EU","0221387ff95c44cb52b86552e3ec118a3c311ca65b75bf807c6c07eaeb1be8303c"),("indenodes_NA","02698c6f1c9e43b66e82dbb163e8df0e5a2f62f3a7a882ca387d82f86e0b3fa988"),("indenodes_SH","0334e6e1ec8285c4b85bd6dae67e17d67d1f20e7328efad17ce6fd24ae97cdd65e"),("jackson_AR","038ff7cfe34cb13b524e0941d5cf710beca2ffb7e05ddf15ced7d4f14fbb0a6f69"),("jeezy_EU","023cb3e593fb85c5659688528e9a4f1c4c7f19206edc7e517d20f794ba686fd6d6"),("karasugoi_NA","02a348b03b9c1a8eac1b56f85c402b041c9bce918833f2ea16d13452309052a982"),("komodoninja_EU","038e567b99806b200b267b27bbca2abf6a3e8576406df5f872e3b38d30843cd5ba"),("komodoninja_SH","033178586896915e8456ebf407b1915351a617f46984001790f0cce3d6f3ada5c2"),("komodopioneers_SH","033ace50aedf8df70035b962a805431363a61cc4e69d99d90726a2d48fb195f68c"),("libscott_SH","03301a8248d41bc5dc926088a8cf31b65e2daf49eed7eb26af4fb03aae19682b95"),("lukechilds_AR","031aa66313ee024bbee8c17915cf7d105656d0ace5b4a43a3ab5eae1e14ec02696"),("madmax_AR","03891555b4a4393d655bf76f0ad0fb74e5159a615b6925907678edc2aac5e06a75"),("meshbits_AR","02957fd48ae6cb361b8a28cdb1b8ccf5067ff68eb1f90cba7df5f7934ed8eb4b2c"),("meshbits_SH","025c6e94877515dfd7b05682b9cc2fe4a49e076efe291e54fcec3add78183c1edb"),("metaphilibert_AR","02adad675fae12b25fdd0f57250b0caf7f795c43f346153a31fe3e72e7db1d6ac6"),("metaphilibert_SH","0284af1a5ef01503e6316a2ca4abf8423a794e9fc17ac6846f042b6f4adedc3309"),("patchkez_SH","0296270f394140640f8fa15684fc11255371abb6b9f253416ea2734e34607799c4"),("pbca26_NA","0276aca53a058556c485bbb60bdc54b600efe402a8b97f0341a7c04803ce204cb5"),("peer2cloud_AR","034e5563cb885999ae1530bd66fab728e580016629e8377579493b386bf6cebb15"),("peer2cloud_SH","03396ac453b3f23e20f30d4793c5b8ab6ded6993242df4f09fd91eb9a4f8aede84"),("polycryptoblog_NA","02708dcda7c45fb54b78469673c2587bfdd126e381654819c4c23df0e00b679622"),("hyper_AR","020f2f984d522051bd5247b61b080b4374a7ab389d959408313e8062acad3266b4"),("hyper_EU","03d00cf9ceace209c59fb013e112a786ad583d7de5ca45b1e0df3b4023bb14bf51"),("hyper_SH","0383d0b37f59f4ee5e3e98a47e461c861d49d0d90c80e9e16f7e63686a2dc071f3"),("hyper_NA","03d91c43230336c0d4b769c9c940145a8c53168bf62e34d1bccd7f6cfc7e5592de"),("popcornbag_AR","02761f106fb34fbfc5ddcc0c0aa831ed98e462a908550b280a1f7bd32c060c6fa3"),("popcornbag_NA","03c6085c7fdfff70988fda9b197371f1caf8397f1729a844790e421ee07b3a93e8"),("alien_AR","0348d9b1fc6acf81290405580f525ee49b4749ed4637b51a28b18caa26543b20f0"),("alien_EU","020aab8308d4df375a846a9e3b1c7e99597b90497efa021d50bcf1bbba23246527"),("thegaltmines_NA","031bea28bec98b6380958a493a703ddc3353d7b05eb452109a773eefd15a32e421"),("titomane_AR","029d19215440d8cb9cc6c6b7a4744ae7fb9fb18d986e371b06aeb34b64845f9325"),("titomane_EU","0360b4805d885ff596f94312eed3e4e17cb56aa8077c6dd78d905f8de89da9499f"),("titomane_SH","03573713c5b20c1e682a2e8c0f8437625b3530f278e705af9b6614de29277a435b"),("webworker01_NA","03bb7d005e052779b1586f071834c5facbb83470094cff5112f0072b64989f97d7"),("xrobesx_NA","03f0cc6d142d14a40937f12dbd99dbd9021328f45759e26f1877f2a838876709e1");');
/*} catch (PDOException $e) { 
        fwrite(STDERR, $e->getMessage()."\r\n");
}*/

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

$json = file_get_contents("labels.json");
$json_data = json_decode($json,true);
$candidates_addresses = array_keys($json_data);

// https://stackoverflow.com/questions/31888566/bootstrap-how-to-sort-table-columns

$unique_addresses = Array();

$blocks_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getblockcount", Array());
if ($blocks_res["http_code"] == 200) {
    $blocks_json_object = json_decode($blocks_res["result"]);
    $blocks = $blocks_json_object->result;
    
    //for ($block_height = 6000; $block_height <= 6100; $block_height++) {
    for ($block_height = 833283; $block_height <= $blocks; $block_height++) {
        
        if ($block_height % 1000 == 0) fwrite(STDERR, "Parsing block #$block_height/$blocks\n");
        $res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getblock", Array("".$block_height));
        if ($res["http_code"] == 200) {
            $json_object = json_decode($res["result"]);
            $hash = $json_object->result->hash;
            $height = $json_object->result->height;
            $txs = $json_object->result->tx;

            foreach ($txs as $tx) { // cycle for all tx in block
                //echo "[" . $tx . "]\n"; // tx hash
                $tx_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getrawtransaction", Array($tx, 1));
                if ($tx_res["http_code"] == 200) { // if can get info about tx
                            // var_dump($tx_res);
                            $tx_json_object = json_decode($tx_res["result"]);
                            //fwrite(STDERR, "![".$tx_json_object->result->version."/".$height."/".$tx."]\n"); // this is notarization tx
                            $vouts = $tx_json_object->result->vout;
                                                        
                            // we can check that is notarization tx by $vouts[0]->value), it's 0.000988 for new notarizations txes,
                            // and 0.00418 for old. but better to check scriptPubKey or addresses field. address should be
                            // equal CRYPTO777_KMDADDR or scriptPubKey -> hex should be "21020e46e79a2a8d12b9b5d12c7a91adb4e454edfae43c0a0cb805427d2ac7613fd9ac",
                            // "21". CRYPTO777_PUBSECPSTR . "ac", where is 21 - length of script and AC is OP_CHECKSIG .

                            /*
                            Examples of notaries TX:
                            
                            b3ec4b85f0a2ac519549944ce4eef7599c9fd219c4a43609ddde63cdebdbe2f1 - notarytx new (0.000988) 825588 block.
                            be090f6a3c4ecc08a0fc456284ff0d7f25f451490801ac58bbf6155e2ebc6df4 - notarytx old (0.00418) 753178 block.
                            */
                            
                            if (count($vouts) > 0)
                            if ($vouts[0]->scriptPubKey->hex == "21". CRYPTO777_PUBSECPSTR . "ac") {
                                if (count($vouts) == 2) {
                                    if (substr($vouts[1]->scriptPubKey->hex,0,2) == "6a") {
                                        fwrite(STDERR, "[".$height."/".$tx."]\n"); // this is notarization tx
                                        
                                        // let's collect vins
                                        $vins = $tx_json_object->result->vin;
                                        
                                        /*
                                        $addresses = Array();
                                        foreach ($vins as $vin) {
                                            //var_dump($vin->txid,$vin->vout);
                                            $vin_tx_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getrawtransaction", Array($vin->txid, 1));
                                            if ($vin_tx_res["http_code"] == 200) {
                                                $vin_tx_json_object = json_decode($vin_tx_res["result"]);
                                                //var_dump($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->addresses);
                                                $addresses = array_unique(array_merge($addresses , ($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->addresses))); 
                                                $unique_addresses = array_unique(array_merge($unique_addresses, $addresses));
                                                // $vout_sum -= $vout->value; // don't sum OP_RETURN Agama ID TX
                                            }
                                        }
                                        var_dump($addresses);
                                        */
                                        $pubkeys = Array();
                                        foreach ($vins as $vin) {
                                            $vin_tx_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getrawtransaction", Array($vin->txid, 1));
                                            if ($vin_tx_res["http_code"] == 200) {
                                                $vin_tx_json_object = json_decode($vin_tx_res["result"]);
                                                //var_dump($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey);
                                                if ($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->type == "pubkey") {
                                                    //var_dump($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->hex);
                                                    $scriptPubKeyBinary = pack("H*", $vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->hex);
                                                    if ($scriptPubKeyBinary[0] == "\x21") {
                                                        $pubkey = substr($scriptPubKeyBinary,1,0x21);
                                                        $pubkeys[] = bin2hex($pubkey);
                                                    } else die("[1] Failed to analyse vins in notarization tx ... check it manually.");
                                                } else die("[2] Failed to analyse vins in notarization tx ... check it manually.");
                                            }
                                        }
                                        $pubkeys = array_values(array_unique($pubkeys));
                                        //var_dump($pubkeys);
                                        
                                        $scriptPubKeyBinary = pack("H*",$vouts[1]->scriptPubKey->hex);
                                        // var_dump(bin2hex($scriptPubKeyBinary));

                                        /*
                                        https://en.bitcoin.it/wiki/Script
                                        
                                        OP_0, OP_FALSE	0	0x00	Nothing.	(empty value)	An empty array of bytes is pushed onto the stack. (This is not a no-op: an item is added to the stack.)
                                        N/A	1-75	0x01-0x4b	(special)	data	The next opcode bytes is data to be pushed onto the stack
                                        OP_PUSHDATA1	76	0x4c	(special)	data	The next byte contains the number of bytes to be pushed onto the stack.
                                        OP_PUSHDATA2	77	0x4d	(special)	data	The next two bytes contain the number of bytes to be pushed onto the stack in little endian order.
                                        OP_PUSHDATA4	78	0x4e	(special)	data	The next four bytes contain the number of bytes to be pushed onto the stack in little endian order.
                                        OP_1NEGATE	79	0x4f	Nothing.	-1	The number -1 is pushed onto the stack.
                                        OP_1, OP_TRUE	81	0x51	Nothing.	1	The number 1 is pushed onto the stack.
                                        OP_2-OP_16	82-96	0x52-0x60	Nothing.	2-16	The number in the word name (2-16) is pushed onto the stack.

                                        OP_RETURN	106	0x6a	Nothing	fail
                                        Marks transaction as invalid. A standard way of attaching extra data to transactions is to add a zero-value output with a scriptPubKey consisting of OP_RETURN followed by exactly one pushdata op. Such outputs are provably unspendable, reducing their cost to the network. Currently it is usually considered non-standard (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more than one pushdata op.

                                        Example of parsing: https://github.com/coinspark/php-OP_RETURN/blob/6814b771b459c3c144f0e1719cb7a6ad0aa7195e/OP_RETURN.php#L766
                                        
                                        */
                                        
                                        $first_ord = ord($scriptPubKeyBinary[1]);
                                        if ($first_ord<=75)
                                            $op_return=substr($scriptPubKeyBinary, 2, $first_ord);
                                        elseif ($first_ord==0x4c)
                                            $op_return=substr($scriptPubKeyBinary, 3, ord($scriptPubKeyBinary[2]));
                                        elseif ($first_ord==0x4d)
                                            $op_return=substr($scriptPubKeyBinary, 4, ord($scriptPubKeyBinary[2])+256*ord($scriptPubKeyBinary[3]));
                                        
                                        //var_dump("[".$height."/".$tx."]");
                                        //var_dump(bin2hex($op_return));
                                        //var_dump($op_return);
                                        
                                        // https://bitcointalk.org/index.php?topic=1605144.msg32538076#msg32538076 - KMD notarization TX explanation
                                        
                                        $notarization_data = Array();
                                        if (substr($op_return,-strlen("KMD")-1) == "KMD\x0")
                                        {
                                            $name_length = strlen("KMD");
                                            $notarization_data = unpack("a32prevhash/Vprevheight/a32btctxid/a".($name_length+1)."name",$op_return); // unpack for KMD
                                            $notarization_data["prevhash"] = bin2hex(strrev($notarization_data["prevhash"]));
                                            $notarization_data["btctxid"] = bin2hex(strrev($notarization_data["btctxid"]));
                                            $notarization_data["name"] = trim($notarization_data["name"]);
                                        } 
                                        elseif (substr($op_return,-strlen("CHIPS")-1) == "CHIPS\x0")
                                        {
                                            $name_length = strlen("CHIPS");
                                            $notarization_data = unpack("a32prevhash/Vprevheight/a".($name_length+1)."name",$op_return); // unpack for CHIPS
                                            $notarization_data["prevhash"] = bin2hex(strrev($notarization_data["prevhash"]));
                                            $notarization_data["name"] = trim($notarization_data["name"]);
                                        }
                                        else {
                                            // prevheight V - unsigned long (always 32 bit, little endian order)
                                            for ($name_length=0; $op_return[32+4+$name_length]!="\x0"; $name_length++);
                                            $notarization_data = unpack("a32prevhash/Vprevheight/a".($name_length+1)."name/a32MoMhash/VMoMdepth",$op_return); // unpack for assets
                                            $notarization_data["prevhash"] = bin2hex(strrev($notarization_data["prevhash"]));
                                            $notarization_data["MoMhash"] = bin2hex(strrev($notarization_data["MoMhash"]));
                                            $notarization_data["name"] = trim($notarization_data["name"]);
                                        };
                                        
                                        //var_dump($notarization_data);
                                           
                                        /*
                                        $db_record = Array(
                                            "blockhash" => $hash,
                                            "height" => $height,
                                            "txid" => $tx,
                                            "name" => $notarization_data["name"],
                                            "pubkeys" => $pubkeys
                                        );
                                        var_dump($db_record);
                                        echo json_encode($db_record)."\r\n";
                                        */
                                        
                                        // Prepare INSERT statement to SQLite3 file db
                                        // $insert = "INSERT OR IGNORE INTO stats (blockhash,height,txid,name,pubkey) 
                                        $insert = "INSERT INTO stats (blockhash,height,txid,name,pubkey) 
                                                    VALUES (:blockhash, :height, :txid, :name, :pubkey)";
                                        $stmt = $file_db->prepare($insert);
                                        
                                        foreach ($pubkeys as $pubkey) {
                                            // Bind parameters to statement variables
                                            $stmt->bindParam(':blockhash', $hash);
                                            $stmt->bindParam(':height', $height);
                                            $stmt->bindParam(':txid', $tx);
                                            $stmt->bindParam(':name', $notarization_data["name"]);
                                            $stmt->bindParam(':pubkey', $pubkey);
                                            try { 
                                                // Execute statement
                                                $stmt->execute();
                                            } catch (PDOException $e) { 
                                                if ($e->getCode() != 23000) 
                                                    { 
                                                        fwrite(STDERR, $e->getMessage()."\r\n");
                                                    } else
                                                        fwrite(STDERR, "[Error] Already in DB ...\r\n");
                                            }
                                        }
                                        
                                    }
                                }
                            }

                            //
                            

		                /*	
			                $vout_sum = 0;	                    
                            foreach ($vouts as $vout) {
                            //if ($vout->value == 0.00001) {
                            //var_dump($vout);
                            
                            
                            if (property_exists($vout->scriptPubKey,"addresses")) {
                                //var_dump($vout->scriptPubKey->addresses);
                                
                                // assume we have only one address in one vout (!)
                                if (in_array($vout->scriptPubKey->addresses[0],$candidates_addresses)) $vout_sum += $vout->value;
                            }
                            
                            $hex = pack("H*",$vout->scriptPubKey->hex);
                            if (Ord($hex[0]) == 0x6a) {
                                    $field = substr($hex,2,Ord($hex[1]));
                                    if (strpos($field,"ne2k18") !== false) {
                                    $vins = $tx_json_object->result->vin;
                                    $addresses = Array();
                                    foreach ($vins as $vin) {
                                        //var_dump($vin->txid,$vin->vout);
                                        $vin_tx_res = daemon_request("127.0.0.1", RPCPORT, RPCUSER, RPCPASSWORD, "getrawtransaction", Array($vin->txid, 1));
                                        if ($vin_tx_res["http_code"] == 200) {
                                            $vin_tx_json_object = json_decode($vin_tx_res["result"]);
                                            //var_dump($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->addresses);
                                            $addresses = array_unique(array_merge($addresses , ($vin_tx_json_object->result->vout[$vin->vout]->scriptPubKey->addresses))); 
                                            $unique_addresses = array_unique(array_merge($unique_addresses, $addresses));
                                            // $vout_sum -= $vout->value; // don't sum OP_RETURN Agama ID TX
                                        }
                                    }
                                    var_dump($addresses);
                                    
                                    }
                            //}
                            
                            }
                        //}
                        }*/

                } // if can get info about tx
            } // cycle for all tx in block



        }
        //die;
    }

    
}

?>

