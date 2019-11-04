#!/bin/bash

# this script restarts all started komodo daemons with same params

CUR_DIR=$(pwd)
komodo_cli="$HOME/komodo/src/komodo-cli"
komodo_daemon="$HOME/komodo/src/komodod"

# NB! path to search assetchains.json will be derived from komodod location, in this example 
# assetchains.json should be available in $HOME/komodo/src .

function init_colors () 
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
}

# --------------------------------------------------------------------------
function log_print()
{
   datetime=$(date '+%Y-%m-%d %H:%M:%S')
   echo -e [$datetime] $1
}

# --------------------------------------------------------------------------
function wait_for_daemon()
{
    #if [[ ! -z $1 && $1 != "KMD" ]]
    if [ ! -z $1 ] && [ $1 != "KMD" ]
    then
        coin=$1
        asset=" -ac_name=$1"
    else
        coin="KMD"
        asset=""
    fi

    i=0
    while ! $komodo_cli $asset getinfo >/dev/null 2>&1
    do 
    i=$((i+1))
    log_print "Waiting for daemon start/active $coin ($i)"
    sleep 1
    # TODO: in case if daemon start too long, for example, more than 5-7 mins. we should exit from script
    done
}

# --------------------------------------------------------------------------
function stop_daemon()
{

    #if [[ ! -z $1 && $1 != "KMD" ]]
    if [ ! -z $1 ] && [ $1 != "KMD" ]
    then
        coin=$1
        asset=" -ac_name=$1"
    else
        coin="KMD"
        asset=""
    fi

    i=0
    $komodo_cli $asset stop

    if [ $coin == "KMD" ]
    then
    ddatadir=$HOME/.komodo
    else
    ddatadir=$HOME/.komodo/$coin
    fi

    while [ -f $ddatadir/komodod.pid ]
    do 
    i=$((i+1))
    log_print "Waiting for daemon $coin stop ($i)"
    sleep 1
    done

    while [ ! -z $(lsof -Fp $ddatadir/.lock | head -1 | cut -c 2-) ]
    do 
    i=$((i+1))
    log_print "Waiting for .lock release by $coin  ($i)"
    sleep 1
    done

}
# --------------------------------------------------------------------------
function restart_daemon() {

    if [ ! -z $1 ] && [ $1 != "KMD" ]
    then
        coin=$1
        asset=" -ac_name=$1"
    else
        coin="KMD"
        asset=""
    fi

    log_print "Process ($coin) ..."
    wait_for_daemon $coin
    
    # disable generate to avoid daemon crash during multiple "error adding notary vin" messages
    $komodo_cli $asset setgenerate false

    blockhash=$($komodo_cli $asset getbestblockhash)
    height=$($komodo_cli $asset getblock $blockhash | jq .height)

    log_print "ht.$height ($blockhash)"

    if [ $coin == "KMD" ]
    then
        daemon_args=$(ps -fC komodod | grep -v -- "-ac_name=" | grep -Po "komodod .*" | sed 's/komodod//g')
    else
        daemon_args=$(ps -fC komodod | grep -- "-ac_name=$coin" | grep -Po "komodod .*" | sed 's/komodod//g')
    fi

    # if previous time daemon launched with reindex or rescan, we don't need to re-launch daemon with same params,
    # so, we just remove them from launch string.

    daemon_args=$(echo $daemon_args | sed -e "s/-reindex//g")
    daemon_args=$(echo $daemon_args | sed -e "s/-rescan//g")

    log_print "($coin) Args: \"$daemon_args\""

    # TODO: check args, if we can't get arg and can't start daemon, don't need to stop it (!)

    log_print "Stopping daemon ... "
    stop_daemon $coin
        
    sleep 5
    log_print "Starting daemon ($coin) ... "

    # *** STARTING DAEMON ***
    $komodo_daemon $daemon_args &
    
    wait_for_daemon $coin
    
    log_print "Done process ($coin)"

}

STEP_START='\e[1;47;42m'
STEP_END='\e[0m'

init_colors

echo Current directory: $CUR_DIR
#log_print "$STEP_START[ Step 1 ]$STEP_END Daemons re-start"
#cd $CUR_DIR/komodo/src

# source $CUR_DIR/kmd_coins.sh
readarray -t kmd_coins < <(cat $(dirname ${komodo_daemon})/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"
for i in "${kmd_coins[@]}"
do
    # VRSC uses different daemon, so we don't need to re-start it from komodo repo folder
    if [ $i != "VRSC" ] && [ $i != "THC" ]; then
        log_print "$STEP_START[ $i ]$STEP_END"
        restart_daemon $i
    fi
done

#cd $CUR_DIR
