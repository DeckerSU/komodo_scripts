#!/bin/bash

# Assetchains Splitfund Script
# (c) Decker, 2018-2019

chips_cli=$HOME/chips3/src/chips-cli
bitcoin_cli=bitcoin-cli
gamecredits_cli=$HOME/GameCredits/src/gamecredits-cli
komodo_cli=$HOME/komodo/src/komodo-cli

# all you need is to insert your pubkey here in lock script format: 21{YOUR_33_BYTES_HEX_PUBKEY}AC
NN_PUBKEY=2100deadcafedeadcafedeadcafedeadcafedeadcafedeadcafedeadcafedeadcafeac
# script check the condition if utxo_count < utxo_min then append it to utxo_max,
# small example: utxo_min = 100; utxo_max = 100; if you have 90 utxo (90 < utxo_min)
# script will spilt additional 10 utxos to have utxo_max (100).

# every splitfunds tx is signed and trying to broadcast by iguana, then it checks by daemon,
# if tx failed to broadcast (not in chain) it resigned by daemon and broadcast to network.
# very simple solution until we fix internal iguana splitfund sign.

utxo_min=100
utxo_max=100

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

function do_autosplit() {

    if [ ! -z $1 ] && [ $1 != "KMD" ]
    then
        coin=$1
        asset=" -ac_name=$1"
    else
        coin="KMD"
        asset=""
    fi

    # utxo=$($komodo_cli -ac_name=$1 listunspent | grep .0001 | wc -l) # this is old way p2pk utxo determine (deprecated)
    utxo=$($komodo_cli $asset listunspent | jq '[.[] | select (.generated==false and .amount==0.0001 and .spendable==true and (.scriptPubKey == "'$NN_PUBKEY'"))] | length')

    # check if result is number (https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash)

    if [ -n "$utxo" ] && [ "$utxo" -eq "$utxo" ] 2>/dev/null; then
       if [ $utxo -lt $utxo_min ]; then
            need=$(($utxo_max-$utxo))
            log_print "${BRIGHT}\x5b${RESET}${YELLOW}${coin}${RESET}${BRIGHT}\x5d${RESET} have.${utxo} --> add.${need} --> total.${utxo_max}"
            # /home/decker/SuperNET/iguana/acsplit $i $need
            log_print "${DARKGREY}curl -s --url \"http://127.0.0.1:7776\" --data '{\"coin\":\"${coin}\",\"agent\":\"iguana\",\"method\":\"splitfunds\",\"satoshis\":\"10000\",\"sendflag\":1,\"duplicates\":\"${need}\"}'${RESET}"
            splitres=$(curl -s --url "http://127.0.0.1:7776" --data "{\"coin\":\""${coin}"\",\"agent\":\"iguana\",\"method\":\"splitfunds\",\"satoshis\":\"10000\",\"sendflag\":1,\"duplicates\":"${need}"}")
            #splitres='{"result":"hexdata","txid":"d5aedd61710db60181a1d34fc9a84c9333ec17509f12c1d67b29253f66e7a88c","completed":true,"tag":"5009274800182462270"}'
            error=$(echo $splitres | jq -r .error)
            txid=$(echo $splitres | jq -r .txid)
            signed=$(echo $splitres | jq -r .result)

            if [ -z "$error" ] || [ "$error" = "null" ] && [ ! -z "$splitres" ]; then
                # if no errors, continue, otherwise display error
                if [ ! -z "$txid" ] && [ "$txid" != "null" ]; then
                    # we have txid, now we should check is it really exist in blockchain or not
                    # sleep 3
                    txidcheck=$($komodo_cli $asset getrawtransaction $txid 1 2>/dev/null | jq -r .txid)
                    if [ "$txidcheck" = "$txid" ]; then
                        log_print "txid.${GREEN}$txid${RESET} - OK" 
                    else
                        log_print "txid.${RED}$txid${RESET} - FAIL" 
                        # tx possible fail, because iguana produced incorrect sign, no problem, let's resign it by daemon and broadcast (perfect solution, isn't it?)
                        daemonsigned=$($komodo_cli $asset signrawtransaction $signed | jq -r .hex)
                        newtxid=$($komodo_cli $asset sendrawtransaction $daemonsigned)
                        log_print "newtxid.$newtxid - BROADCASTED"

                    fi
                else
                    log_print "${RED}Iguana doesn't return txid ...${RESET}"
                fi
            else
                if [ ! -z "$splitres" ]; then
                    log_print "${RED}$error${RESET}"
                else
                    log_print "${RED}Failed to receive curl answer, possible iguana died ...${RESET}"
                fi
            fi
        else
            log_print "${BRIGHT}\x5b${RESET}${YELLOW}${coin}${RESET}${BRIGHT}\x5d${RESET} have.${utxo} --> don't need split ..."
        fi 
    else
            log_print "${BRIGHT}\x5b${RESET}${YELLOW}${coin}${RESET}${BRIGHT}\x5d${RESET} ${RED}Error: utxo count is not a number, may be daemon dead ... ${RESET}"
    fi
}

init_colors
log_print "Starting autosplit ..."

declare -a kmd_coins=(KMD REVS SUPERNET DEX PANGEA JUMBLR BET CRYPTO HODL MSHARK BOTS MGW COQUI WLC KV CEAL MESH MNZ AXO ETOMIC BTCH PIZZA BEER NINJA OOT BNTN CHAIN PRLPAY DSEC GLXT EQL VRSC ZILLA RFOX SEC CCL PIRATE MGNX PGT KMDICE DION ZEX)
#declare -a kmd_coins=(BEER PIZZA DEX)
for i in "${kmd_coins[@]}"
do
    do_autosplit $i
done