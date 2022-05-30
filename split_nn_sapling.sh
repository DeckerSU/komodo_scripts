#!/bin/bash

# Split NN script by Decker (c) 2018

# *** Small how-to: ***

# This script can be used to fund your notary with SPLIT_COUNT (50) utxos SPLIT_VALUE (0.0001) KMD each,
# same way as in iguana. You don't need to import any privkeys in your komodo daemon. Funds will get
# from FROM_ADDRESS with given FROM_PRIVKEY. Insight explorer API will used for listunspent and 
# komodod for signing transaction. If somebody will able to modify this script to use openssl for signing
# tx instead of komodod - it would be nice. PRs are welcome.

RESET="\033[0m"
BLACK="\033[30m"    
RED="\033[31m"      
GREEN="\033[32m"    
YELLOW="\033[33m"   
BLUE="\033[34m"     
MAGENTA="\033[35m"  
CYAN="\033[36m"     
WHITE="\033[37m"    

NN_ADDRESS=RDeckerSubnU8QVgrhj27apzUvbVK3pnTk
NN_PUBKEY=0249eee7a3ad854f1d22c467b42dc73db94af7ce7837e15bfcf82f195cd5490d76

#base58 decode by grondilu https://github.com/grondilu/bitcoin-bash-tools/blob/master/bitcoin.sh
declare -a base58=(
      1 2 3 4 5 6 7 8 9
    A B C D E F G H   J K L M N   P Q R S T U V W X Y Z
    a b c d e f g h i j k   m n o p q r s t u v w x y z
)
unset dcr; for i in {0..57}; do dcr+="${i}s${base58[i]}"; done
decodeBase58() {
    local line
    echo -n "$1" | sed -e's/^\(1*\).*/\1/' -e's/1/00/g' | tr -d '\n'
    dc -e "$dcr 16o0$(sed 's/./ 58*l&+/g' <<<$1)p" |
    while read line; do echo -n ${line/\\/}; done
}
nob58=$(decodeBase58 $NN_ADDRESS)
NN_HASH160=$(echo ${nob58:2:-8})
# Source for calculation of NN_HASH160:
# https://github.com/KMDLabs/LabsNotary/blob/master/splitfunds.sh#L60
# NN_HASH160=2fedd5f73d46db8db8625eb5816dfb21f94529e2

FROM_ADDRESS=RD6GgnrMpPaTSMn8vai6yiGA7mN4QGPVMY
fnob58=$(decodeBase58 $FROM_ADDRESS)
FROM_HASH160=$(echo ${fnob58:2:-8})
# FROM_HASH160=29cfc6376255a78451eeb4b129ed8eacffa2feef
FROM_PUBKEY=000000000000000000000000000000000000000000000000000000000000000000
FROM_PRIVKEY=Up1YVLk7uuErCHVQyFCtfinZngmdwfyfc47WCQ8oJxgowEbuo6t4

SPLIT_VALUE=0.0001
SPLIT_VALUE_SATOSHI=$(jq -n "$SPLIT_VALUE*100000000")
SPLIT_COUNT=50 # do not set split count > 252 (!), it's important
SPLIT_TOTAL=$(jq -n "$SPLIT_VALUE*$SPLIT_COUNT")
SPLIT_TOTAL_SATOSHI=$(jq -n "$SPLIT_VALUE*$SPLIT_COUNT*100000000")

TXFEE_SATOSHI=1000

# get listunspent from explorer, assumes komodo daemon is not available at this moment
# (restart for example) or we don't have imported FROM privkey in the wallet.

curl -s https://kmdexplorer.io/insight-api-komodo/addr/$FROM_ADDRESS/utxo > split_nn.utxos

utxos=$(<split_nn.utxos)
utxo=$(echo "$utxos" | jq "[.[] | select (.amount > $SPLIT_TOTAL and .confirmations > 0)][0]")
if [[ $utxo != "null" ]]; then
  txid=$(echo "$utxo" | jq -r .txid)
  vout=$(echo "$utxo" | jq -r .vout)
  amount=$(echo "$utxo" | jq -r .amount)
  satoshis=$(echo "$utxo" | jq -r .satoshis)
  scriptPubKey=$(echo "$utxo" | jq -r .scriptPubKey)

  #echo $txid $vout $amount $satoshis
  echo "Amount:" $amount "("$satoshis")"
  echo "2Split: $SPLIT_TOTAL ($SPLIT_TOTAL_SATOSHI)"

  rev_txid=$(echo $txid | dd conv=swab 2> /dev/null | rev)
  vout_hex=$(printf "%08x" $vout | dd conv=swab 2> /dev/null | rev)
  rawtx="04000080" # tx header
  rawtx=$rawtx"85202f89" # versiongroupid
  rawtx=$rawtx"01" # number of inputs (1, as we take one utxo from explorer listunspent)
  rawtx=$rawtx$rev_txid$vout_hex"00ffffffff"
  # outputs
  #if [[ $SPLIT_COUNT -lt 253 ]]; then
   if [[ $SPLIT_COUNT -lt 252 ]]; then # 253, but 1 output for "change" and we have 252

        oc=$((SPLIT_COUNT+1))
  	outputCount=$(printf "%02x" $oc)

	rawtx=$rawtx$outputCount
	for (( i=1; i<=$SPLIT_COUNT; i++ ))
	do
	value=$(printf "%016x" $SPLIT_VALUE_SATOSHI | dd conv=swab 2> /dev/null | rev)
	rawtx=$rawtx$value
	rawtx=$rawtx"2321"$NN_PUBKEY"ac"
	done

        change=$(jq -n "($satoshis-$SPLIT_TOTAL_SATOSHI)/100000000")
	change_satoshis=$(jq -n "$satoshis-$SPLIT_TOTAL_SATOSHI")
	echo "Change:" $change "("$change_satoshis")"
	value=$(printf "%016x" $change_satoshis | dd conv=swab 2> /dev/null | rev)
	rawtx=$rawtx$value
	rawtx=$rawtx"1976a914"$FROM_HASH160"88ac" # len OP_DUP OP_HASH160 len hash OP_EQUALVERIFY OP_CHECKSIG
  else
	# more than 252 outputs not handled now (!) TODO
	echo -e $RED"Error!"$RESET" More than 252 outputs not handled now!"
	exit
  	rawtx=$rawtx"00"
  fi

  nlocktime=$(printf "%08x" $(date +%s) | dd conv=swab 2> /dev/null | rev)
  rawtx=$rawtx$nlocktime
  rawtx=$rawtx"000000000000000000000000000000" # sapling end of tx

  #echo $rawtx
else
  echo -e $RED"Error!"$RESET" Nothing to split ... :("
fi

# signrawtransaction hex "[]" "[\"privkey\"]"

curdir=$(pwd)
curluser=user
curlpass=pass
curlport=7771
signed=$(curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "signrawtransaction", "params": ["'$rawtx'", [], ["'$FROM_PRIVKEY'"]]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq -r .result.hex)

echo -e '\n'
echo -e ${YELLOW}'Unsigned TX: '${RESET}$rawtx
echo -e '\n'
echo -e ${YELLOW}'Signed TX: '${RESET}$signed
echo -e '\n'
