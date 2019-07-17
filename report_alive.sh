#!/bin/bash

# this script can be used for check komodo daemon alive on your node
# and report via Telegram bot.

# (c) Decker

date=$(date +"%F %T")
token=000000000:aaaaaaa-bbbbbbbbbbbbbbbbbbbbbbbbbbb # your telegram bot token
chat_id=0 # telegram chat_id to report
proxy="-x socks5h://x.x.x.x:1080 --proxy-user user:proxypass" # proxy args for curl, if needed,

komodo_cli="$HOME/komodo/src/komodo-cli"

function init_colors () {
    RESET="\033[0m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"
}
# --------------------------------------------------------------------------
function log_print() {
   datetime=$(date '+%Y-%m-%d %H:%M:%S')
   echo -e [$datetime] $1
}
# --------------------------------------------------------------------------
function check_for_daemon() {
    #if [[ ! -z $1 && $1 != "KMD" ]]
    if [ ! -z $1 ] && [ $1 != "KMD" ]
    then
        coin=$1
        asset=" -ac_name=$1"
    else
        coin="KMD"
        asset=""
    fi

    # command && echo OK || echo Failed
    # http://mywiki.wooledge.org/BashGuide/TestsAndConditionals
    # https://www.opennet.ru/docs/RUS/bash_scripting_guide/c2171.html

    #$komodo_cli $asset getinfo >/dev/null 2>&1
        
    result=$($komodo_cli $asset getinfo 2>&1) # save both stdout and stderr to a variable
    error=$?
    
    if [ $error -eq 0 ]; then
        log_print "\x5B${YELLOW}${coin}${RESET}\x5D ${GREEN}OK${RESET}"
    else
        log_print "\x5B${YELLOW}${coin}${RESET}\x5D ${RED}$result${RESET}"
    fi

    if [ $error -ne 0 ]; then
    nl=$'\n'
    text="<b>node report</b> (${date})${nl}"
    text="${text}⚠️ ${coin} ${result}${nl}"
    # echo -e "\"$text\""
    curl -X POST -s $proxy "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&parse_mode=HTML&text=$text" > /dev/null
    fi
}

init_colors
# check_for_daemon KMD
readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/jl777/komodo/beta/src/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
kmd_coins+=(KMD)
for i in "${kmd_coins[@]}"
do
    check_for_daemon $i
done