#!/usr/bin/env bash

# Mainnet Splitfund Script (autosplit-new.sh)
# Copyright (c) 2018-2024 Decker

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

source_pubkey() {
  local pubkey_file
  local found=0

  # Define the search order
  local search_paths=(
    "$HOME/komodo/src/pubkey.txt"
    "$HOME/KomodoOcean/src/pubkey.txt"
    "$HOME/pubkey.txt"
  )

  # Iterate through the search paths
  for pubkey_file in "${search_paths[@]}"; do
    if [[ -f "$pubkey_file" ]]; then
      echo "Found pubkey.txt at: $pubkey_file" >&2
      source "$pubkey_file"
      found=1
      break
    fi
  done

  # Check if pubkey.txt was found and sourced
  if [[ "$found" -ne 1 ]]; then
    echo -e "${RED}Error:${RESET} pubkey.txt not found in any of the specified locations." >&2
    exit 1
  fi

  # Ensure that the pubkey environment variable is set
  if [[ -z "$pubkey" ]]; then
    echo -e "${RED}Error:${RESET} pubkey environment variable is not set after sourcing pubkey.txt." >&2
    exit 1
  fi

  echo -e "Pubkey: \"${pubkey}\""
}

determine_komodo_cli() {
  local cli_path
  # Check system-wide installation
  cli_path=$(command -v komodo-cli 2>/dev/null)
  if [[ -x "$cli_path" ]]; then
    echo "Found system-wide komodo-cli at: $cli_path" >&2
    echo "$cli_path"
    return 0
  fi

  # Check in ~/komodo/src
  cli_path="$HOME/komodo/src/komodo-cli"
  if [[ -x "$cli_path" ]]; then
    echo "Found komodo-cli at: $cli_path" >&2
    echo "$cli_path"
    return 0
  fi

  # Check in ~/KomodoOcean/src
  cli_path="$HOME/KomodoOcean/src/komodo-cli"
  if [[ -x "$cli_path" ]]; then
    echo "Found komodo-cli at: $cli_path" >&2
    echo "$cli_path"
    return 0
  fi

  # komodo-cli not found
  echo -e "${RED}Error:${RESET} komodo-cli not found in system-wide path, $HOME/komodo/src, or $HOME/KomodoOcean/src." >&2
  exit 1
}

komodo_cli=$(determine_komodo_cli)

source_pubkey
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

    if [ ! -z "$1" ] && [ "$1" != "KMD" ]
    then
        if [ "$1" == "GLEEC_OLD" ]; then
            coin="GLEEC"
            asset=" -ac_name=GLEEC -datadir=$HOME/.komodo/GLEEC_OLD"
        else
            coin="$1"
            asset=" -ac_name=$1"
        fi
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

gleec_count=0
for i in "${kmd_coins[@]}"
do
  if [[ "$i" == "GLEEC" ]]; then
    ((gleec_count++))

    if [[ "$gleec_count" -eq 1 ]]; then
      do_autosplit "GLEEC_OLD"
    elif [[ "$gleec_count" -eq 2 ]]; then
      do_autosplit "GLEEC"
    else
      echo -e "${YELLOW}GLEEC has been encountered more than twice. No additional actions will be performed.${RESET}" >&2
    fi
    continue
  fi
  do_autosplit "$i"
done

