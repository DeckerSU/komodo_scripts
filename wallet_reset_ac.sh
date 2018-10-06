#!/bin/bash

##
## Decker (c) 2018
##

# How to use?

# This is small script for wallet reset automation. Before use you should send all mined funds
# from node to an other address or cold wallet using ./sendawaynn.sh or ./sendawaynn_auto.sh
# script to leave only iguana outputs (this is not mandatory, but recommended). Also, you should
# have normal utxo count, "normal" mean - to be able to send it in one single transaction. For example,
# if you have more than 1000 utxos - tx will be oversized. Optimal count of uxos to don't break
# max single tx. size limit (100000 bytes) is 100-200 utxos.

# After you start this script it will automatically do following steps:

# 1. Wait for daemon start if it's not started.
# 2. Get pubkey and privkey for given NN_ADDRESS below from daemon.
# 3. Send all your balance in one tx to NN_ADDRESS. If daemon can't send all balance (for example, 
#    in case of oversized tx - script will just exit on this step, nothing hurt)
# 4. Wait for 1 confirmation and save height of block in which this tx is included.
# 5. Create new z-address and grab privkey from it (needed to the trick with rescan).
# 6. Stop daemon and make sure it really stopped.
# 7. Copy current wallet.dat in $HOME/.komodo as backup_%date%_%time%.dat and remove wallet.dat after.
# 8. Start daemon with -gen -notary -pubkey="$NN_PUBKEY" & args .
# 9. Wait for daemon start .
# 10. Imports your NN privkey and rescan from height from step 4.
# 
# Done. 

# If you wish to continue work on this, PRs in repo are welcome.

komodo_cli="$HOME/komodo/src/komodo-cli"
komodo_daemon="$HOME/komodo/src/komodod"

NN_ADDRESS=RFCmz9od8SLgm8VrncCbhY99vWP2p1A7Ba
# you'll need only to set NN_ADDRESS, other needed info such as pubkey and privkey
# script will get automatically from daemon

# --------------------------------------------------------------------------
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
   echo [$datetime] $1
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
   log_print "Waiting for daemon start $coin ($i)"
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
pidfile=$HOME/.komodo/komodod.pid
else
pidfile=$HOME/.komodo/$coin/komodod.pid
fi

while [ -f $pidfile ]
do 
   i=$((i+1))
   log_print "Waiting for daemon $coin stop ($i)"
   sleep 1
done
}

# --------------------------------------------------------------------------
function send_balance()
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

    #echo $komodo_cli $asset getbalance
    BALANCE=$($komodo_cli $asset getbalance 2>/dev/null)
    ERRORLEVEL=$?
    
    if [ "$ERRORLEVEL" -eq "0" ] && [ "$BALANCE" != "0.00000000" ]; then
        message=$(echo -e "(${GREEN}$coin${RESET}) $BALANCE")
        log_print "$message"
    else
        BALANCE="0.00000000"
	    message=$(echo -e "(${RED}$coin${RESET}) $BALANCE")
        log_print "$message"
        exit
    fi

    # sendtoaddress
    #$komodo_cli $asset sendtoaddress $NN_ADDRESS $BALANCE "" "" true

    # redirected stderr to stdout
    RESULT=$($komodo_cli $asset sendtoaddress $NN_ADDRESS $BALANCE "" "" true 2>&1)
    ERRORLEVEL=$?
    if [ "$ERRORLEVEL" -ne "0" ]; then
	log_print "tx $RESULT"
    	exit
    fi
    log_print "txid: $RESULT"

    i=0
    confirmations=0
    while [ "$confirmations" -eq "0" ]
    do
    confirmations=$($komodo_cli $asset gettransaction $RESULT | jq .confirmations)
    i=$((i+1))
    log_print "Waiting for confirmations ($i).$confirmations"
    sleep 10
    done
    blockhash=$($komodo_cli $asset gettransaction $RESULT | jq -r .blockhash)
    height=$($komodo_cli $asset getblock $blockhash | jq .height)
}

# --------------------------------------------------------------------------
function reset_wallet() {

    if [ ! -z $1 ] && [ $1 != "KMD" ]
    then
        coin=$1
        asset=" -ac_name=$1"
    else
        coin="KMD"
        asset=""
    fi

    log_print "Start reset ($coin) ..."

    wait_for_daemon $coin

    log_print "Gathering pubkey ..."
    NN_PUBKEY=$($komodo_cli $asset validateaddress $NN_ADDRESS | jq -r .pubkey)
    if [ -z $NN_PUBKEY ]
    then
        log_print "Failed to obtain pubkey. Exit"
        exit
    else
        log_print "Pubkey is $NN_PUBKEY"
    fi

    log_print "Gathering privkey ..."
    NN_PRIVKEY=$($komodo_cli $asset dumpprivkey $NN_ADDRESS)
    if [ -z $NN_PRIVKEY ]
    then
        log_print "Failed to obtain privkey. Exit"
        exit
    else
        log_print "Privkey is obtained"
    fi

    # disable generate to avoid daemon crash during multiple "error adding notary vin" messages
    $komodo_cli $asset setgenerate false

    send_balance $coin
    log_print "ht.$height ($blockhash)"

    NN_ZADDRESS=$($komodo_cli $asset z_getnewaddress)
    NN_ZKEY=$($komodo_cli $asset z_exportkey $NN_ZADDRESS)
    log_print "New z-address $NN_ZADDRESS"

    if [ $coin == "KMD" ]
    then
        daemon_args=$(ps -fC komodod | grep -v -- "-ac_name=" | grep -Po "komodod .*" | sed 's/komodod//g')
    else
        daemon_args=$(ps -fC komodod | grep -- "-ac_name=$coin" | grep -Po "komodod .*" | sed 's/komodod//g')
    fi
    
    log_print "($coin) Args: \"$daemon_args\""

    # TODO: check args, if we can't get arg and can't start daemon, don't need to stop it (!)

    log_print "Stopping daemon ... "
    stop_daemon $coin
    log_print "Removing old wallet ... "

    wallet_file=backup_$(date '+%Y_%m_%d_%H%M%S').dat
    
    if [ $coin == "KMD" ]
    then
        cp $HOME/.komodo/wallet.dat $HOME/.komodo/$wallet_file
        rm $HOME/.komodo/wallet.dat
    else
        cp $HOME/.komodo/$coin/wallet.dat $HOME/.komodo/$coin/$wallet_file
        rm $HOME/.komodo/$coin/wallet.dat
    fi
    
    sleep 5
    log_print "Starting daemon ($coin) ... "

    # *** STARTING DAEMON ***
    $komodo_daemon $daemon_args &
    
    #$komodo_daemon -gen -notary -pubkey="$NN_PUBKEY" &
    
    wait_for_daemon $coin
    log_print "Importing private key ... "
    $komodo_cli $asset importprivkey $NN_PRIVKEY "" false
    log_print "Rescanning from ht.$height ... "
    $komodo_cli $asset z_importkey "$NN_ZKEY" \"yes\" $height
    log_print "Done reset ($coin)"

}

# Main

curdir=$(pwd)

init_colors

reset_wallet PIZZA
reset_wallet BEER
