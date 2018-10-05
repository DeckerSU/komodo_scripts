#!/bin/bash
# (c) Decker, 2018 

RESET="\033[0m"
BLACK="\033[30m"    
RED="\033[31m"      
GREEN="\033[32m"    
YELLOW="\033[33m"   
BLUE="\033[34m"     
MAGENTA="\033[35m"  
CYAN="\033[36m"     
WHITE="\033[37m"    

curdir=$(pwd)
curluser=user
curlpass=pass
curlport=7771
asset=

echo -e 'SendAway Script v0.01alpha (c) '${GREEN}Decker${RESET}, 2018
echo    '-------------------------------------------'

curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listunspent", "params": [0, 9999999]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq .result > $curdir/createrawtx.txt
# we will send all spendable and generated coins
transactions=$(cat $curdir/createrawtx.txt | jq '.[] | select (.spendable == true and .generated == true) | del (.generated, .address, .account, .scriptPubKey, .amount, .interest, .confirmations, .spendable)' |  jq -r -s '. | tostring')
balance=$(cat $curdir/createrawtx.txt      | jq '.[] | select (.spendable == true and .generated == true) | .amount' | jq -s add)
balance=$(echo "scale=8; $balance/1*1" | bc -l | sed 's/^\./0./')
tosend=$balance
change=$(echo "scale=8; ($balance-$tosend)/1*1" | bc -l | sed 's/^\./0./')

echo 'Balance: '$balance
echo 'To send: '$tosend
echo ' Change: '$change

# first address is where you want to send to, second address in your NN address for change (!), if tosend != balance
# don't forget to change it ... 

if (( $(echo "$change > 0" | bc -l) )); then
    addresses='{"RTCVGuoSNehKG8YYxcoskC7LK1yZhgvQRV":'$tosend',"RNJmgYaFF5DbnrNUX6pMYz9rcnDKC2tuAc":'$change'}'
else
    addresses='{"RTCVGuoSNehKG8YYxcoskC7LK1yZhgvQRV":'$tosend'}'
fi

echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"createrawtransaction\", \"params\": [$transactions,$addresses] }" > $curdir/createrawtx.curl

# we are using curl here to avoid an error "Argument list too long" with long-long list of utxos if we executing komodo-cli

hex=$(curl -s --user $curluser:$curlpass --data-binary "@$curdir/createrawtx.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/ | jq -r .result)
# setting of nLockTime
nlocktime=$(printf "%08x" $(date +%s) | dd conv=swab 2> /dev/null | rev)
hex=${hex::-8}$nlocktime
signed=$(curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "signrawtransaction", "params": ["'$hex'"]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/  | jq -r .result.hex)

#curl -s --user $curluser:$curlpass --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "decoderawtransaction", "params": ["'$signed'"]}' -H 'content-type: text/plain;' http://127.0.0.1:$curlport/  | jq 

echo -e '\n'
echo -e ${YELLOW}'Unsigned TX: '${RESET}$hex
echo -e '\n'
echo -e ${YELLOW}'Signed TX: '${RESET}$signed
echo -e '\n'
echo -e 'Now you are able to broadcast your signed tx via "sendrawtransaction" or in any Insight Explorer. '${GREEN}'Verify it before broadcast!'${RESET}

# actually send
echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"sendrawtransaction\", \"params\": [\"$signed\"] }" > $curdir/createrawtx.curl
curl -s --user $curluser:$curlpass --data-binary "@$curdir/createrawtx.curl" -H 'content-type: text/plain;' http://127.0.0.1:$curlport/