#!/bin/bash
# (c) Decker, 2018 ;)

curdir=$(pwd)
curluser=user
curlpass=pass
curlport=7771
asset=

# Lock
curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listunspent", "params": [0, 9999999]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq .result > $curdir/listunspent.txt
# set condition on amout on a next line
arg=$(cat $curdir/listunspent.txt | jq '.[] | select (.spendable == true and .amount == 0.0001) | del (.generated, .address, .account, .scriptPubKey, .amount, .interest, .confirmations, .spendable)' |  jq -r -s '. | tostring')
echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"lockunspent\", \"params\": [false, $arg] }" > $curdir/listunspent.curl

# we are using curl here to avoid an error "Argument list too long" with long-long list of utxos need to be locked
# if we executing komodo-cli

curl -s --user $curluser:$curlpass --data-binary "@$curdir/listunspent.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/

# locked utxos list (and unlock if needed)

curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listlockunspent", "params": []}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq .result > $curdir/listlockunspent.txt
arg=$(cat $curdir/listlockunspent.txt | jq '.[]' | jq -r -s '. | tostring')
echo $arg | jq .
echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"lockunspent\", \"params\": [true, $arg] }" > $curdir/listlockunspent.curl
# uncomment if u want to unlock locked utxos
#curl -s --user $curluser:$curlpass --data-binary "@$curdir/listlockunspent.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/
