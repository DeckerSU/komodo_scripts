#!/bin/bash

# [AJSS] Awesome Join + Split Script by Decker (c) 2019
#
# This will create specific joinsplit (transparent) tx in which:
#
# vins  :   all your existing utxos except immature or non-spendable in other reasons
# vouts :   1. NOTARYVIN_NUM x P2PK iguana utxos for address corresponding to your pubkey
#           2. 1 x P2SH utxo with 0.01 amount to track using of script (plz, don't remove it, 0.01 KMD is not so much)
#           3. 1 x P2PKH utxo with change for address corresponding to your pubkey
# fee   :   4. smart fee calc is not yet implemented, so it will use fixed fee = 0.00077777
# 
# Environment variables:
#
# pubkey - your pubkey (pubkey set is important, otherwise it will be use default dev pubkey) [!!!]
# KOMODOD_CONFIGFILE - full path to your komodo.conf or %ac_name%.conf
# NOTARYVIN_NUM - count of notary vins (P2PK) / iguana utxos that needs to be created
#
# AWJS is experimental and a work-in-progress. Use at your own risk!
#
# F.A.Q. (and useful commands)
#
# Q. How can use measure speed improvement after AJSS?
# A. Use the following command(s):
#
#   time (~/komodo/src/komodo-cli listunspent | jq '. | { "utxos" : length }' && ~/komodo/src/komodo-cli getwalletinfo | jq '{ "txcount" : .txcount }') | jq -s '.[0] * .[1]'
#   time (~/komodo/src/komodo-cli listunspent | jq '. | { "utxos" : length }' && ~/komodo/src/komodo-cli getwalletinfo | jq '{ "txcount" : .txcount }') | jq -s add
#
#   Output will be like:
#
#   {
#     "utxos": 70,
#     "txcount": 4022
#   }
#
#   real	0m0.112s
#   user	0m0.032s
#   sys	0m0.010s
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
function getbalance() {
    res=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getbalance", "params": ["*", 1] }' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/)
    if [ "$(echo ${res} | jq .error)" == null ]; then
        BALANCE="$(echo ${res} | jq .result)"
    else
        BALANCE=0
        log_print "${RED}ERROR $(echo ${res} | jq .error.code) : $(echo ${res} | jq -r .error.message)${RESET}"
        return 1
    fi
}

# --------------------------------------------------------------------------
function scriptpub2address() {
    # NN_ADDRESS=$(${komodo_cli_binary} decodescript "21${pubkey}ac" | jq -r .addresses[0])
    NN_ADDRESS=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "decodescript", "params": ["21'"$1"'ac"] }' -H 'content-type: text/plain;' "http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/")
    if [ "$(echo "${NN_ADDRESS}" | jq .error)" == null ]; then
        NN_ADDRESS=$(echo "${NN_ADDRESS}" | jq -c .result)
        if  [ "$(echo "${NN_ADDRESS}" | jq -r .type)" != "pubkey" ]; then
            log_print "${RED}ERROR obtaining address from pubkey${RESET}"    
            return 1;
        fi
        NN_ADDRESS=$(echo ${NN_ADDRESS} | jq -r .addresses[0])
    else
        log_print "${RED}ERROR $(echo ${NN_ADDRESS} | jq .error.code) : $(echo ${NN_ADDRESS} | jq -r .error.message)${RESET}"
        return 1
    fi
}

# --------------------------------------------------------------------------
function listunspent() {
    # https://askubuntu.com/questions/714458/bash-script-store-curl-output-in-variable-then-format-against-string-in-va
    # https://stackoverflow.com/questions/5076283/shell-variable-capacity

    UTXOS=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listunspent", "params": [1, 9999999, []] }' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/)
    if [ "$(echo "${UTXOS}" | jq .error)" == null ]; then
        UTXOS=$(echo "${UTXOS}" | jq -c .result)
    else
        log_print "${RED}ERROR $(echo ${UTXOS} | jq .error.code) : $(echo ${UTXOS} | jq -r .error.message)${RESET}"
        return 1
    fi
}

# --------------------------------------------------------------------------
function createjoinsplittx() {

    NOTARYVIN_NUM=${NOTARYVIN_NUM:-100}
    NOTARYVIN_SIZE=0.0001
    NOTARYVIN_SUM=$(jq -n "${NOTARYVIN_NUM} * ${NOTARYVIN_SIZE}")
    NOTARYVIN_RAW=
    log_print "Iguana UTXOs amount: ${NOTARYVIN_SUM}"

    for n in $(seq 1 ${NOTARYVIN_NUM})
    do
    NOTARYVIN_RAW=${NOTARYVIN_RAW}"\"21${NN_PUBKEY}ac\":${NOTARYVIN_SIZE},"
    done
    NOTARYVIN_RAW=${NOTARYVIN_RAW::-1}

    FIXED_FEE=0.00077777 # TODO: add tx fee calculation (!)
    TRACK_UTXO_AMOUNT=0.01
    CHANGE_AMOUNT=$(jq -n "${UTXOSBALANCE} - ${NOTARYVIN_SUM} - ${FIXED_FEE} - ${TRACK_UTXO_AMOUNT}") 
    CHANGE_AMOUNT=$(echo ${CHANGE_AMOUNT} | jq 'def round: tostring | (split(".") + ["0"])[:2] | [.[0], "\(.[1])"[:8]] | join(".") | tonumber; . | round')
    log_print "Change amount: ${CHANGE_AMOUNT}"

    UNSIGNED_RAW_TX=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" \
    --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "createrawtransaction", "params": ['"${VINS}"', {"'"${NN_ADDRESS}"'":'"${CHANGE_AMOUNT}"',"a9141cef3747c7894ce843f87f3bf43c8a355321179c87":'"${TRACK_UTXO_AMOUNT}"','"${NOTARYVIN_RAW}"'}] }' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/)
    if [ "$(echo "${UNSIGNED_RAW_TX}" | jq .error)" == null ]; then
        UNSIGNED_RAW_TX=$(echo "${UNSIGNED_RAW_TX}" | jq -r .result)
        UNSIGNED_RAW_TX_SIZE=$((${#UNSIGNED_RAW_TX}/2))
    else
        log_print "${RED}ERROR $(echo ${UNSIGNED_RAW_TX} | jq .error.code) : $(echo ${UNSIGNED_RAW_TX} | jq -r .error.message)${RESET}"
        return 1;
    fi
}

# --------------------------------------------------------------------------
function checktxsize() {
    MAX_TX_SIZE_BEFORE_SAPLING=100000
    MAX_TX_SIZE_AFTER_SAPLING=$((2 * ${MAX_TX_SIZE_BEFORE_SAPLING})) # consensus.h rules

    # https://stackoverflow.com/questions/18668556/comparing-numbers-in-bash
    if [ "${MAX_TX_SIZE_AFTER_SAPLING}" -gt "${UNSIGNED_RAW_TX_SIZE}" ]; then
        log_print "Unsigned raw transaction (Size: ${UNSIGNED_RAW_TX_SIZE} bytes) - ${GREEN}OK${RESET}"
    else
        log_print "${RED}ERROR MAX_TX_SIZE_AFTER_SAPLING (${MAX_TX_SIZE_AFTER_SAPLING}) exeeded !"
        return 1
    fi
}

# --------------------------------------------------------------------------
function signrawtransaction {
    SIGNED_RAW_TX=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "signrawtransaction", "params": ["'"${UNSIGNED_RAW_TX}"'"] }' -H 'content-type: text/plain;' "http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/")
    if [ "$(echo "${SIGNED_RAW_TX}" | jq .error)" == null ]; then
        SIGNED_RAW_TX=$(echo "${SIGNED_RAW_TX}" | jq -c .result)
        # echo $SIGNED_RAW_TX
        SIGNED_RAW_TX_COMPLETE=$(echo "${SIGNED_RAW_TX}" | jq -c .complete)
        SIGNED_RAW_TX=$(echo "${SIGNED_RAW_TX}" | jq -r .hex)
        # echo ${SIGNED_RAW_TX} ${SIGNED_RAW_TX_COMPLETE}
    else
        log_print "${RED}ERROR $(echo ${SIGNED_RAW_TX} | jq .error.code) : $(echo ${SIGNED_RAW_TX} | jq -r .error.message)${RESET}"
        return 1
    fi
}

# --------------------------------------------------------------------------
function sendrawtransaction {
    SEND_RAW_TX=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "sendrawtransaction", "params": ["'"${SIGNED_RAW_TX}"'"] }' -H 'content-type: text/plain;' "http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/")
    if [ "$(echo "${SEND_RAW_TX}" | jq .error)" == null ]; then
        # echo ${SEND_RAW_TX}
        SEND_RAW_TX_HASH=$(echo "${SEND_RAW_TX}" | jq -r .result)
    else
        log_print "${RED}ERROR $(echo ${SEND_RAW_TX} | jq .error.code) : $(echo ${SEND_RAW_TX} | jq -r .error.message)${RESET}"
        return 1
    fi
}

# --------------------------------------------------------------------------
function cleanwallettransactions {
    CLEAN_WALLWET_TXS=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "cleanwallettransactions", "params": ["'"${SEND_RAW_TX_HASH}"'"] }' -H 'content-type: text/plain;' "http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/")
    if [ "$(echo "${CLEAN_WALLWET_TXS}" | jq .error)" == null ]; then
        CLEAN_WALLWET_TXS=$(echo "${CLEAN_WALLWET_TXS}" | jq -c .result)
    else
        log_print "${RED}ERROR $(echo ${CLEAN_WALLWET_TXS} | jq .error.code) : $(echo ${CLEAN_WALLWET_TXS} | jq -r .error.message)${RESET}"
        return 1
    fi
}


# https://github.com/DeckerSU/chips3/blob/ec2bf830e41087e8d3ded6323703050f9b2846fb/contrib/init/bitcoind.openrc
KOMODOD_DEFAULT_DATADIR=${KOMODOD_DEFAULT_DATADIR:-"$HOME/.komodo"}
KOMODOD_CONFIGFILE=${KOMODOD_CONFIGFILE:-"$KOMODOD_DEFAULT_DATADIR/komodo.conf"}
KOMODOD_RPCHOST=127.0.0.1

init_colors
log_print "Starting ..."
checkconfig || exit

# here we should obtain NN_ADDRESS from NN_PUBKEY via scriptpub2address
source $HOME/komodo/src/pubkey.txt 2> /dev/null
NN_DEFAULT_PUBKEY=02ba1815af3e5068930010c7a79ee7f3f72bbd10980bb0345e7d3c513c7989e1d9
NN_PUBKEY=${pubkey:-${NN_DEFAULT_PUBKEY}}
log_print "Pubkey: ${BLUE}${NN_PUBKEY}${RESET}"
scriptpub2address ${NN_PUBKEY} || exit
log_print "Address: ${BLUE}${NN_ADDRESS}${RESET}"

getbalance || exit
log_print "Balance (getbalance): ${BALANCE}"
listunspent || exit

UTXOSFILTER=".spendable == true" # and (.generated == false or (.generated == true and .confirmations > 100))
# https://www.youtube.com/watch?v=PS_9pyIASvQ // !!Con 2017: Serious Programming with jq?! A Practical and ...! by Charles Chamberlain
VINS=$(echo "${UTXOS}" | jq -c '[.[] | select ('"${UTXOSFILTER}"') | {"txid": .txid, "vout": .vout}]') # for create vins in future raw tx
VINSCOUNT=$(echo ${VINS} | jq '. | length')

if [ "$VINSCOUNT" -eq "0" ]; then
    log_print "${RED}ERROR: There is no available utxos to join ...${RESET}"
    exit
fi

UTXOSBALANCE=$(echo "${UTXOS}" | jq 'def round: tostring | (split(".") + ["0"])[:2] | [.[0], "\(.[1])"[:8]] | join(".") | tonumber; 
                        [.[] | select ('"${UTXOSFILTER}"') | .amount] | add | round')
log_print "Balance (utxos sum): ${UTXOSBALANCE}"

if [ "${BALANCE}" == "${UTXOSBALANCE}" ]; then
    log_print "Balances are ${GREEN}equal${RESET}"
else
    log_print "Balances are ${RED}not equal${RESET}"
    log_print "This is not a big mistake, can be some small rounding errors"
    log_print "or you have some generated coins, that are still immature."
    log_print "But you should know, that if you'll do cleanwallettransactions"
    log_print "with created txid as an argument - all not included utxos will"
    log_print "stay behind your cleaned wallet and for using it you'll need to rescan."
fi

createjoinsplittx || exit
checktxsize || exit

log_print "Transaction info: (vins: ${VINSCOUNT}${RESET}, vouts: ${NOTARYVIN_NUM}+${RESET})"
signrawtransaction || exit

# if you want to auto-broadcast tx just change this condition on true, it's disabled by default to allow
# you to check signed raw transaction before you will setup auto-broadcast.

if false; then
    sendrawtransaction || exit
    log_print "Broadcasted: ${BLUE}${SEND_RAW_TX_HASH}${RESET} - ${GREEN}OK${RESET}"
    cleanwallettransactions || exit
    log_print "Clean wallet result: ${CLEAN_WALLWET_TXS}"
else
    log_print "Signed raw tx: ${SIGNED_RAW_TX}"
fi
