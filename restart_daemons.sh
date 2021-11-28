#!/usr/bin/env bash

# sample of daemons restart script for cron
# (c) Decker, 2020-2021

KOMODOD_PATH=${HOME}/komodo/src/komodod
source ${HOME}/komodo/src/pubkey.txt

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

init_colors

ASSETCHAINS_FILE=/tmp/assetchains.json

if [ -z $(command -v jq) ]; then
    log_print "${RED}ERROR:${RESET} jq should be installed (sudo apt install jq)"
    exit 1
fi

curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json -o ${ASSETCHAINS_FILE}
readarray -t kmd_coins < <(cat ${ASSETCHAINS_FILE} | jq -r '[.[].ac_name] | join("\n")')

kmd_coins+=("KMD")

for coin in "${kmd_coins[@]}"
do
    if [ ${coin} != "KMD" ]
    then
        PID_FILE=${HOME}/.komodo/${coin}/komodod.pid
        DAEMON_DIR=${HOME}/.komodo/${coin}

    else
        PID_FILE=${HOME}/.komodo/komodod.pid
        DAEMON_DIR=${HOME}/.komodo
    fi

    # https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
    # https://www.gnu.org/software/bash/manual/bash.html#Bash-Conditional-Expressions

    NEED_RESTART=false
    if [ -f "${PID_FILE}" ]; then
        DAEMON_PID=$(ps -p $(cat ${PID_FILE}) -o pid=)
        if [ -n "${DAEMON_PID}" ] && [ "${DAEMON_PID}" -eq "${DAEMON_PID}" ]; then
            log_print "\x5B${YELLOW}${coin}${RESET}\x5D ${GREEN}RUNNING${RESET}"
            # pid file exists, process exists
        else
            log_print "\x5B${YELLOW}${coin}${RESET}\x5D ${RED}CRASHED${RESET}"
            NEED_RESTART=true
            # pid file exists, but such process absent
        fi
    else
        if [ -d "${DAEMON_DIR}" ]; then
            log_print "\x5B${YELLOW}${coin}${RESET}\x5D ${RED}STOPPED${RESET}"
            NEED_RESTART=true
            # coin directory exists, but pid file absent
        else
            log_print "\x5B${YELLOW}${coin}${RESET}\x5D ${DARKGREY}SKIPPED${RESET}"
            # skipped - means, coin directory doesn't exist, this coin never launched on this system, so nothing to restart
        fi
    fi

    if [ "${NEED_RESTART}" = "true" ]; then

        # set pubkey if defined
        PUBKEY=
        if [ -n "${pubkey}" ]; then
            PUBKEY="-pubkey=${pubkey}"
        fi

        # set additional args for KMD
        ADDITIONAL_ARGS=
        if [ ${coin} = "KMD" ]
        then
            ADDITIONAL_ARGS="-gen -genproclimit=1 -notary=.litecoin/litecoin.conf -opretmintxfee=0.004 -minrelaytxfee=0.000035"
        fi

        # https://stackoverflow.com/questions/25378013/how-to-convert-a-json-object-to-key-value-format-in-jq
        # https://jqplay.org/

        # here we just omit addnode, bcz this is array and it should be handled differently
        COMMAND_LINE=$(cat ${ASSETCHAINS_FILE} | jq -r 'map(select(.ac_name | contains ("'${coin}'"))) |  map(del(.addnode)) | .[] | to_entries | map("-\(.key)=\(.value|tostring)") | join(" ")')
        # and here we process only addnode(s)
        ADDNODES=$(cat ${ASSETCHAINS_FILE} | jq -r 'map(select(.ac_name | contains ("'${coin}'"))) | .[].addnode | map("-addnode=" + .) | .[]' 2>/dev/null)
        log_print "Command line: ${KOMODOD_PATH} ${COMMAND_LINE} ${ADDNODES} ${ADDITIONAL_ARGS} ${PUBKEY}"

        # https://unix.stackexchange.com/questions/444946/how-can-we-run-a-command-stored-in-a-variable
        # https://stackoverflow.com/questions/10586153/how-to-split-a-string-into-an-array-in-bash
        # https://stackoverflow.com/questions/3683910/executing-shell-command-in-background-from-script

        #declare -a DAEMON_CMD=(${KOMODOD_PATH} ${COMMAND_LINE} ${ADDNODES} ${ADDITIONAL_ARGS} ${PUBKEY})
        #set -x
        #"${DAEMON_CMD[@]}" &
        #set +x

        ${KOMODOD_PATH} ${COMMAND_LINE} ${ADDNODES} ${ADDITIONAL_ARGS} ${PUBKEY} &
    fi
done

