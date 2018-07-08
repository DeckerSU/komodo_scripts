#!/bin/bash
# (c) Decker, 2018 ;)

# CSV output examples
# -------------------

#"\"6ec838e14dff07a6656c534bda8b44d36d1cd07e614a832566d259b1e96680ae\",0,3.50454387"
#cat listunspent.txt | jq '.[] | select (.spendable == true and .amount > 3) | [.txid,.vout,.amount] | @csv'

# "6ec838e14dff07a6656c534bda8b44d36d1cd07e614a832566d259b1e96680ae",0,3.50454387
#cat listunspent.txt | jq -r '.[] | select (.spendable == true and .amount > 3) | [.txid,.vout,.amount] | @csv'

# CSV parsing example
# -------------------
#cat listunspent.txt | jq -r '.[] | select (.spendable == true and .amount > 3) | [.txid,.vout,.amount] | @csv' > listunspent.csv
#i=0
#OLDIFS=$IFS
#IFS=","
#while read txid vout amount; do
#    i=$((i + 1))
#    echo "txid: $txid vout: $vout amount: $amount"
#done < listunspent.csv
#IFS=$OLDIFS

# CURL

curluser=user
curlpass=pass
curlport=36356
asset=-ac_name=POSTEST64B

# Lock
if true;then
./komodo-cli $asset listunspent > listunspent.txt
#arg=$(cat listunspent.txt | jq '.[] | select (.spendable == true and .amount == 3.50454387) | del (.generated, .address, .account, .scriptPubKey, .amount, .interest, .confirmations, .spendable)' |  jq -s '. | tostring')
arg=$(cat listunspent.txt | jq '.[] | select (.spendable == true and .amount == 0.0001) | del (.generated, .address, .account, .scriptPubKey, .amount, .interest, .confirmations, .spendable)' |  jq -r -s '. | tostring')

#echo $arg
echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"lockunspent\", \"params\": [false, $arg] }" > listunspent.curl
#command=$(echo './komodo-cli lockunspent false '$arg)
#echo $command
#eval $command
curl --trace-time -v --user $curluser:$curlpass --data-binary "@listunspent.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/
fi

# Unlock example
if false;then
./komodo-cli $asset listlockunspent > listlockunspent.txt
#arg=$(cat listunspent.txt | jq '.[]' | jq -s '. | tostring')
arg=$(cat listlockunspent.txt | jq '.[]' | jq -r -s '. | tostring')
#command=$(echo './komodo-cli lockunspent true '$arg)
#echo $command
#eval $command
echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"lockunspent\", \"params\": [true, $arg] }" > listlockunspent.curl
curl --trace-time -v --user $curluser:$curlpass --data-binary "@listlockunspent.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/
fi