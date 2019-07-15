#!/bin/bash

# Assetchains Validate Script (c) Decker, 2019
#
# Small script that allows to check privkeys import in all coins (3 season, mainnet).
# You don't need to change anything in this script, if you followed NN guide. It will
# automatically locate your pubkey from pubkey.txt file and will calculate your address
# for BTC and KMD/AC, then it will check IsMine() of this address. Assetchains list
# is automatically parsed from assetchains.json used only JQ.

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
function validateaddress ()
{
    ISMINE=$($komodo_cli_binary -ac_name=$1 validateaddress ${KMD_ADDRESS} | jq .ismine)
    if [ "$ISMINE" = "true" ]; then
	ISMINE=${GREEN}$ISMINE${RESET}
    else
	ISMINE=${RED}$ISMINE${RESET}
    fi
    printf '%-10s | %b\n' $1 ${ISMINE}
}

init_colors
komodo_cli_binary="$HOME/komodo/src/komodo-cli"
source $HOME/komodo/src/pubkey.txt
echo Pub: ${pubkey}
KMD_ADDRESS=$(${komodo_cli_binary} decodescript "21${pubkey}ac" | jq -r .addresses[0])
BTC_ADDRESS=$(bitcoin-cli decodescript "21${pubkey}ac" | jq -r .addresses[0])
echo -e KMD: ${YELLOW}${KMD_ADDRESS}${RESET}
echo -e BTC: ${YELLOW}${BTC_ADDRESS}${RESET}
echo
# https://stackoverflow.com/questions/18669756/bash-how-to-extract-data-from-a-column-in-csv-file-and-put-it-in-an-array
readarray -t kmd_coins < <(cat $HOME/komodo/src/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"
for i in "${kmd_coins[@]}"
do
   validateaddress "$i"
done

# Komodo
ISMINE=$($komodo_cli_binary validateaddress ${KMD_ADDRESS} | jq .ismine)
printf '%-10s | %s\n' "KMD" ${ISMINE}

# Bitcoin
ISMINE=$(bitcoin-cli validateaddress ${BTC_ADDRESS} | jq .ismine)
printf '%-10s | %s\n' "BTC" ${ISMINE}