#!/bin/bash

# Split NN script by Decker (c) 2019

# *** Small how-to: ***

# This script can be used to fund your notary with SPLIT_COUNT (50) utxos SPLIT_VALUE (0.0001) BTC each,
# same way as in iguana. It will produce unsigned tx, you should CHECK and sign it before broadcast.
# Check is MANDATORY, bcz it can contains round errors. Make sure you have needed funds on FROM_ADDRESS (!).

# p.s. Use it ONLY if you understand the aftermaths and how it works!

RESET="\033[0m"
BLACK="\033[30m"    
RED="\033[31m"      
GREEN="\033[32m"    
YELLOW="\033[33m"   
BLUE="\033[34m"     
MAGENTA="\033[35m"  
CYAN="\033[36m"     
WHITE="\033[37m"    

NN_ADDRESS=12Rqm2rZCfBzAVAL5CCb7DUaMU2VKfvJFL # fill your NN address here
NN_PUBKEY=0287b551ba26f24b792d24aec94f96a72a6f40142717f290b684cab3904d4e095c # fill your pubkey here
NN_HASH160=	0faacf9bf91ba026e7a79eeae26c3bc70dfce19b # take it from https://cryptofrontline.com/Tools/Upload/tool/address-to-hash

FROM_ADDRESS=12CANsiKa1vjdwKnu2AGPDgqDCGpEpqCsW # address from funds are taken
FROM_HASH160=0d14876d237dbe8d895ce5caf1fe3dadc6a782e0 # it's HASH160
# FROM_PUBKEY=000000000000000000000000000000000000000000000000000000000000000000
# FROM_PRIVKEY=KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73Nd2Mcv1

SPLIT_VALUE=0.0001
SPLIT_VALUE_SATOSHI=$(jq -n "$SPLIT_VALUE*100000000")
SPLIT_COUNT=50 # do not set split count > 252 (!), it's important
SPLIT_TOTAL=$(jq -n "$SPLIT_VALUE*$SPLIT_COUNT")
SPLIT_TOTAL_SATOSHI=$(jq -n "$SPLIT_VALUE*$SPLIT_COUNT*100000000")

TXFEE_SATOSHI_VBYTE=120 # take it from https://btc.com/stats/unconfirmed-tx

curl -s https://blockchain.info/unspent?active=$FROM_ADDRESS > split_nn.utxos

utxos=$(<split_nn.utxos)
#utxo=$(echo "$utxos" | jq "[.[] | select (.amount > $SPLIT_TOTAL and .confirmations > 0)][0]")
utxo=$(echo "$utxos" | jq "[.unspent_outputs[] | select (.value > $SPLIT_TOTAL_SATOSHI and .confirmations > 0)][0]")

if [[ $utxo != "null" ]]; then
  txid=$(echo "$utxo" | jq -r .tx_hash_big_endian)
  vout=$(echo "$utxo" | jq -r .tx_output_n)
  #amount=$(echo "$utxo" | jq -r .amount)
  satoshis=$(echo "$utxo" | jq -r .value)
  amount=$(jq -n "$satoshis/100000000")
  scriptPubKey=$(echo "$utxo" | jq -r .script)

  #echo $txid $vout $amount $satoshis
  echo "Amount:" $amount "("$satoshis")"
  echo "2Split: $SPLIT_TOTAL ($SPLIT_TOTAL_SATOSHI)"

  rev_txid=$(echo $txid | dd conv=swab 2> /dev/null | rev)
  vout_hex=$(printf "%08x" $vout | dd conv=swab 2> /dev/null | rev)
  rawtx="01000000" # tx version
  rawtx=$rawtx"01" # number of inputs (1, as we take one utxo from explorer listunspent)
  rawtx=$rawtx$rev_txid$vout_hex"00ffffffff"
  # outputs
  #if [[ $SPLIT_COUNT -lt 253 ]]; then
   if [[ $SPLIT_COUNT -lt 252 ]]; then # 253, but 1 output for "change" and we have 252

        oc=$((SPLIT_COUNT+1))
  	outputCount=$(printf "%02x" $oc)

	rawtx=$rawtx$outputCount

  rawtxsize=$(($(echo -n $rawtx | wc -m) / 2))
  rawtxsize=$((rawtxsize + SPLIT_COUNT * (8 + 1 + 35))) # outputs size
  rawtxsize=$((rawtxsize + 8 + 1 + 25)) # change size
  rawtxsize=$((rawtxsize + 4)) # nLockTime
  echo Size: $rawtxsize

	for (( i=1; i<=$SPLIT_COUNT; i++ ))
	do
	value=$(printf "%016x" $SPLIT_VALUE_SATOSHI | dd conv=swab 2> /dev/null | rev)
	rawtx=$rawtx$value
	rawtx=$rawtx"2321"$NN_PUBKEY"ac"
	done

  change_satoshis=$(jq -n "$satoshis-$SPLIT_TOTAL_SATOSHI-$rawtxsize*$TXFEE_SATOSHI_VBYTE")
  change=$(jq -n "($change_satoshis)/100000000")

	echo "Change:" $change "("$change_satoshis")"
  txfee=$(jq -n "($amount - $SPLIT_TOTAL - $change)")
  txfee=$(awk -v txfee="$txfee" 'BEGIN { printf("%.8f\n", txfee) }' </dev/null)

    
  echo "Tx Fee:" $txfee

	value=$(printf "%016x" $change_satoshis | dd conv=swab 2> /dev/null | rev)
	rawtx=$rawtx$value
	rawtx=$rawtx"1976a914"$FROM_HASH160"88ac" # len OP_DUP OP_HASH160 len hash OP_EQUALVERIFY OP_CHECKSIG
  else
	# more than 252 outputs not handled now (!) TODO
	echo -e $RED"Error!"$RESET" More than 252 outputs not handled now!"
	exit
  	rawtx=$rawtx"00"
  fi

  #nlocktime=$(printf "%08x" $(date +%s) | dd conv=swab 2> /dev/null | rev)
  nlocktime=$(printf "%08x" 0 | dd conv=swab 2> /dev/null | rev) # for BTC nLockTime is 0 (!)
  rawtx=$rawtx$nlocktime

  #echo $rawtx
else
  echo -e $RED"Error!"$RESET" Nothing to split ... :("
fi

# signrawtransaction hex "[]" "[\"privkey\"]"

curdir=$(pwd)
curluser=user
curlpass=pass
curlport=8332

#sign is turned off, you should sign tx manually
#signed=$(curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "signrawtransaction", "params": ["'$rawtx'", [], ["'$FROM_PRIVKEY'"]]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq -r .result.hex)

echo -e '\n'
echo -e ${YELLOW}'Unsigned TX: '${RESET}$rawtx
echo -e '\n'

#echo -e ${YELLOW}'Signed TX: '${RESET}$signed
#echo -e '\n'
