#!/bin/bash
# (c) Decker, 2018 ;)

# Usage instruction:
#
# 1. Download it on your NN in any folder.
# 2. Edit rpc username and pass in script.
# 3. Let's explain we have 450 KMD on balance, including 0.0001 KMD utxos.
# 4. Run the script ... it locks all 0.0001 KMD utxos from sending and shows you locked utxos txid + vout num.
# 5. Send funds from NN via ~/komodo/src/komodo-cli sendtoaddress YOUR_WALLET_ADDRESS 450 "" "" true
# 6. Now we need to unlock (!) 0.0001 KMD utxos, uncomment last line with curl command execution and launch it again. All your utxos will be unlocked.
# 7. Additionally check that you haven't locked utxos: ~/komodo/src/komodo-cli listlockunspent
# ...
# 777. Bingo! )
#
# @kolo You can call it "utxo protector", komodod will never "eat" your utxos during sendtoaddress if they are all locked.

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

# curl -s --user $curluser:$curlpass --data-binary "@$curdir/listlockunspent.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/
