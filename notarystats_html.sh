#!/bin/bash
komodo_cli=/home/decker/komodo/src/komodo-cli 
chips_cli=/home/decker/chips3/src/chips-cli
bitcoin_cli=bitcoin-cli

# ----------------------
function getstats_kmd ()
{

txcount=1000

# $1 - coin name (empty for KMD)
# -- in grep is for stop processing statements, https://unix.stackexchange.com/questions/11376/what-does-double-dash-mean-also-known-as-bare-double-dash/11382#11382

if [ "$1" == "KMD" ] || [ "$1" == "" ]
then
    name=" "
    name_str="KMD"
else
    name=" -ac_name=$1"
    name_str=$1
fi

ntrz_count=$($komodo_cli $name listtransactions "" $txcount | grep -- -0.00098800 | wc -l)
utxo_count=$($komodo_cli $name listunspent | grep .0001 | wc -l)
#balance=$($komodo_cli $name getinfo | grep balance)
balance=$($komodo_cli $name getinfo | jq .balance)
height=$($komodo_cli $name getinfo | jq .blocks)

echo "<tr><td class=\"title\">$name_str</td><td>$ntrz_count</td><td>$utxo_count</td><td>$balance</td><td>$height</td></tr>"

}

function getstats_btc ()
{
txcount=1000
ntrz_count=$($bitcoin_cli listtransactions "" $txcount | grep -- -0.00098800 | wc -l)
utxo_count=$($bitcoin_cli listunspent | grep .0001 | wc -l)
#balance=$($bitcoin_cli getinfo | grep balance)
balance=$($bitcoin_cli getinfo | jq .balance)
height=$($bitcoin_cli getinfo | jq .blocks)
echo "<tr><td class=\"title\">BTC</td><td>$ntrz_count</td><td>$utxo_count</td><td>$balance</td><td>$height</td></tr>"
}

function getstats_chips ()
{
txcount=1000
ntrz_count=$($chips_cli listtransactions "" $txcount | grep -- -0.00098800 | wc -l)
utxo_count=$($chips_cli listunspent | grep .0001 | wc -l)
#balance=$($chips_cli getinfo | grep balance)
balance=$($chips_cli getinfo | jq .balance)
height=$($chips_cli getinfo | jq .blocks)
echo "<tr><td class=\"title\">CHIPS</td><td>$ntrz_count</td><td>$utxo_count</td><td>$balance</td><td>$height</td></tr>"
}

cat <<EOF
<style type="text/css">
<!--
table.design1{font-family:Verdana,Geneva,sans-serif;font-size:12px;border-collapse:collapse;max-width:600px}table.design1 td{padding:8px;border:1px solid #9E9E9E;text-align:left}table.design1 td.title{padding:8px;background:#d0d7e0;font-weight:700}table.design1 tr.headline td{text-align:center;padding:16px 8px;background:#e8e5de;font-weight:700;font-size:13px}table.design1 span{color:#1477fe;font-weight:700}table.design1 .green{background-color:#00e676}table.design1 .red{background-color:#FF6F00}
-->
</style>
<table align="center" border="0" cellpadding="1" cellspacing="1" class="design1" style="border-collapse: collapse;"> 
  <tbody>
<tr class="headline"><td width="20%"></td><td style="text-align: center;">NTRZd</td><td style="text-align: center;">UTXOs</td><td style="text-align: center;">Balance</td><td style="text-align: center;">Height</td></tr>
EOF

getstats_btc
getstats_chips
declare -a kmd_coins=(KMD REVS SUPERNET DEX PANGEA JUMBLR BET CRYPTO HODL MSHARK BOTS MGW COQUI WLC KV CEAL MESH MNZ AXO ETOMIC BTCH VOTE2018 PIZZA BEER NINJA OOT BNTN CHAIN PRLPAY)
for i in "${kmd_coins[@]}"
do
   getstats_kmd "$i"
done

cat <<EOF
</tbody>
 </table>
EOF
