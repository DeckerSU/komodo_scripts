#!/usr/bin/env bash

# Mainnet Splitfund Script (autosplit-new.sh)
# Copyright (c) 2018-2021 Decker
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

komodo_cli=$HOME/komodo/src/komodo-cli

# NN_PUBKEY=21033178586896915e8456ebf407b1915351a617f46984001790f0cce3d6f3ada5c2ac
# we don't need to specify pubkey anymore, as we have it in $HOME/komodo/src/pubkey.txt,
# we will just fill environment variable ${pubkey} from there

source $HOME/komodo/src/pubkey.txt
NN_PUBKEY=21${pubkey}ac

# if ACs utxos lower than ${ac_utxo_min}, then top up till ${ac_utxo_max}
ac_utxo_min=5
ac_utxo_max=10
# if KMD utxos lower than ${kmd_utxo_min}, then top up till ${kmd_utxo_max}
kmd_utxo_min=25
kmd_utxo_max=50

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
        utxo_min=${ac_utxo_min}
        utxo_max=${ac_utxo_max}

    else
        coin="KMD"
        asset=""
        utxo_min=${kmd_utxo_min}
        utxo_max=${kmd_utxo_max}
    fi

    # utxo=$($komodo_cli -ac_name=$1 listunspent | grep .0001 | wc -l) # this is old way p2pk utxo determine (deprecated)
    utxo=$($komodo_cli $asset listunspent | jq '[.[] | select (.generated==false and .amount==0.0001 and .spendable==true and (.scriptPubKey == "'$NN_PUBKEY'"))] | length')

    # check if result is number (https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash)

    if [ -n "$utxo" ] && [ "$utxo" -eq "$utxo" ] 2>/dev/null; then
       if [ $utxo -lt $utxo_min ]; then
            need=$(($utxo_max-$utxo))
            log_print "${BRIGHT}\x5b${RESET}${YELLOW}${coin}${RESET}${BRIGHT}\x5d${RESET} have.${utxo} --> add.${need} --> total.${utxo_max}"
            # $HOME/SuperNET/iguana/acsplit $i $need
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

#declare -a kmd_coins=(KMD REVS SUPERNET DEX PANGEA JUMBLR BET CRYPTO HODL MSHARK BOTS MGW COQUI WLC KV CEAL MESH AXO ETOMIC BTCH PIZZA BEER NINJA OOT BNTN CHAIN PRLPAY DSEC GLXT EQL VRSC ZILLA RFOX SEC CCL PIRATE PGT KMDICE DION KSB OUR ILN RICK MORTY VOTE2019 HUSH3 KOIN ZEXO K64)
do_autosplit KMD
#source $(dirname $(readlink -f $0))/kmd-coins.sh

# mainnet
readarray -t kmd_coins < <(cat $HOME/dPoW/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# 3rd
# declare -a kmd_coins=(KMD VRSC MCL)

for i in "${kmd_coins[@]}"
do
   do_autosplit "$i"
done

