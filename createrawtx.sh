#!/bin/bash
# (c) Decker, 2018 ;)

# bash script to create unsigned raw tx from utxos selected via filter

curdir=$(pwd)
curluser=user
curlpass=pass
curlport=7771
asset=

curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listunspent", "params": [0, 9999999]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq .result > $curdir/createrawtx.txt
# set condition on amount on a next line
transactions=$(cat $curdir/createrawtx.txt | jq '.[] | select (.spendable == true and .amount > 0) | del (.generated, .address, .account, .scriptPubKey, .amount, .interest, .confirmations, .spendable)' |  jq -r -s '. | tostring')

addresses='{"RTCVGuoSNehKG8YYxcoskC7LK1yZhgvQRV":1000.0}' # how to calc sum of amounts of each utxo - is your hometask :) PRs are welcome )

echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"createrawtransaction\", \"params\": [$transactions,$addresses] }" > $curdir/createrawtx.curl

# we are using curl here to avoid an error "Argument list too long" with long-long list of utxos need to be locked
# if we executing komodo-cli

curl -s --user $curluser:$curlpass --data-binary "@$curdir/createrawtx.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq -r .result

