#!/usr/bin/env bash
# (c) Decker, 2018-2020

# --------------------------------------------------------------------------
function init_colors() {
    RESET="\033[0m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"
    BRIGHT="\033[1m"
    DARKGREY="\033[90m"
}
# --------------------------------------------------------------------------
function log_print() {
   datetime=$(date '+%Y-%m-%d %H:%M:%S')
   echo -e [$datetime] $1
}

# --------------------------------------------------------------------------
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html

function checkconfig()
{
	if ! grep -qs '^rpcpassword=' "${KOMODOD_CONFIGFILE}" ; then
		log_print "Parsing: ${KOMODOD_CONFIGFILE} - ${RED}FAILED${RESET}"
		return 1
    fi
    if ! grep -qs '^rpcuser=' "${KOMODOD_CONFIGFILE}" ; then
		log_print "Parsing: ${KOMODOD_CONFIGFILE} - ${RED}FAILED${RESET}"
		return 1
    fi

    grep -qs '^rpcpassword=' "${KOMODOD_CONFIGFILE}"
    KOMODOD_RPCPASSWORD=$(grep -s '^rpcpassword=' "${KOMODOD_CONFIGFILE}")
    KOMODOD_RPCPASSWORD=${KOMODOD_RPCPASSWORD/rpcpassword=/}

    grep -qs '^rpcuser=' "${KOMODOD_CONFIGFILE}"
    KOMODOD_RPCUSER=$(grep -s '^rpcuser=' "${KOMODOD_CONFIGFILE}")
    KOMODOD_RPCUSER=${KOMODOD_RPCUSER/rpcuser=/}

    if ! grep -qs '^rpcport=' "${KOMODOD_CONFIGFILE}" ; then
		KOMODO_RPCPORT=7771
    else
        KOMODO_RPCPORT=$(grep -s '^rpcport=' "${KOMODOD_CONFIGFILE}")
        KOMODO_RPCPORT=${KOMODO_RPCPORT/rpcport=/}
    fi

    log_print "Parsing RPC credentials: ${KOMODOD_CONFIGFILE} - ${GREEN}OK${RESET}"

}
# --------------------------------------------------------------------------

# daemon config
KOMODOD_DEFAULT_DATADIR=${KOMODOD_DEFAULT_DATADIR:-"$HOME/.komodo"}
KOMODOD_CONFIGFILE=${KOMODOD_CONFIGFILE:-"$KOMODOD_DEFAULT_DATADIR/komodo.conf"}
KOMODOD_RPCHOST=127.0.0.1
# addresses config
WITHDRAW_ADDRESS=RTCVGuoSNehKG8YYxcoskC7LK1yZhgvQRV

echo -e 'SendAway Script v0.02alpha (c) '${GREEN}Decker${RESET}, 2018-2020
echo    '-------------------------------------------'

init_colors
log_print "Starting ..."
checkconfig || exit

curdir=$(pwd)

curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listunspent", "params": [0, 9999999]}' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/ | jq .result > $curdir/createrawtx.txt

# we will send all spendable and generated coins
UTXOSFILTER=".spendable == true and .generated == true"
#FIXED_FEE=0.00077777 # TODO: add tx fee calculation (!)
FIXED_FEE=0.00001000

#transactions=$(cat $curdir/createrawtx.txt | jq '.[] | select ('"${UTXOSFILTER}"') | del (.generated, .address, .account, .scriptPubKey, .amount, .interest, .confirmations, .spendable)' |  jq -r -s '. | tostring')
transactions=$(cat $curdir/createrawtx.txt | jq '.[] | select ('"${UTXOSFILTER}"') | {"txid": .txid, "vout": .vout}' |  jq -r -s '. | tostring')
#echo "${transactions}"

balance=$(cat $curdir/createrawtx.txt | jq '.[] | select ('"${UTXOSFILTER}"') | .amount' | jq -s add)
balance=$(echo "${balance}" | jq 'def round: tostring | (split(".") + ["0"])[:2] | [.[0], "\(.[1])"[:8]] | join(".") | tonumber;
                        . | round')

#balance=$(echo "scale=8; $balance/1*1" | bc -l | sed 's/^\./0./')

log_print "Balance: ${GREEN}${balance}${RESET}"
log_print "    Fee: ${FIXED_FEE}"

#tosend=$balance
tosend=$(echo "${balance}" | jq 'def round: tostring | (split(".") + ["0"])[:2] | [.[0], "\(.[1])"[:8]] | join(".") | tonumber;
                        .-'"${FIXED_FEE}"' | round')

log_print "To send: ${GREEN}${tosend}${RESET}"

addresses='{"'${WITHDRAW_ADDRESS}'":'$tosend'}'

echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"createrawtransaction\", \"params\": [$transactions,$addresses] }" > $curdir/createrawtx.curl
# we are using curl here to avoid an error "Argument list too long" with long-long list of utxos if we executing komodo-cli

hex=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary "@$curdir/createrawtx.curl" -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/ | jq -r .result)
# setting of nLockTime
nlocktime=$(printf "%08x" $(date +%s) | dd conv=swab 2> /dev/null | rev)
# hex=${hex::-8}$nlocktime # leave it here for non-sapling chains, like ZILLA and OOT
txtail=000000000000000000000000000000
hex=${hex::-38}${nlocktime}${txtail}

signed=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "signrawtransaction", "params": ["'$hex'"]}' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/  | jq -r .result.hex)

#curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "decoderawtransaction", "params": ["'$signed'"]}' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/  | jq 

echo -e '\n'
echo -e ${YELLOW}'Unsigned TX: '${RESET}$hex
echo -e '\n'
echo -e ${YELLOW}'Signed TX: '${RESET}$signed
echo -e '\n'
echo -e 'Now you are able to broadcast your signed tx via "sendrawtransaction" or in any Insight Explorer. '${GREEN}'Verify it before broadcast!'${RESET}

# actually send
# echo "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"sendrawtransaction\", \"params\": [\"$signed\"] }" > $curdir/createrawtx.curl
# curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary "@$curdir/createrawtx.curl" -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/