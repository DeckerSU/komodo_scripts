#!/usr/bin/env bash
komodo_cli_binary="$HOME/komodo/src/komodo-cli"
readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"

init_colors()
{
    RESET="\033[0m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"

    # Text Color Variables http://misc.flogisoft.com/bash/tip_colors_and_formatting
    tcLtG="\033[00;37m"    # LIGHT GRAY
    tcDkG="\033[01;30m"    # DARK GRAY
    tcLtR="\033[01;31m"    # LIGHT RED
    tcLtGRN="\033[01;32m"  # LIGHT GREEN
    tcLtBL="\033[01;34m"   # LIGHT BLUE
    tcLtP="\033[01;35m"    # LIGHT PURPLE
    tcLtC="\033[01;36m"    # LIGHT CYAN
    tcW="\033[01;37m"      # WHITE
    tcRESET="\033[0m"
    tcORANGE="\033[38;5;209m"
}

init_colors

for i in "${kmd_coins[@]}"
do
   echo -e "- Cleaning ${GREEN}${i}${RESET}"
   (${komodo_cli_binary} -ac_name=${i} listunspent | jq '. | { "utxos" : length }' && ${komodo_cli_binary} -ac_name=${i} getwalletinfo | jq '{ "txcount" : .txcount }') | jq -s add
   echo KOMODOD_CONFIGFILE=~/.komodo/$i/$i.conf ./resend_funds.sh
   KOMODOD_CONFIGFILE=~/.komodo/$i/$i.conf ./resend_funds.sh
done