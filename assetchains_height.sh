#!/bin/bash

komodo_cli_binary="$HOME/komodo/src/komodo-cli"
curtime=$(date +%s)

function show_height ()
{
    INFO=$($komodo_cli_binary -ac_name=$1 getinfo)
    blocks=$(echo $INFO | jq .blocks)
    longestchain=$(echo $INFO | jq .longestchain)
    lasttime=$($komodo_cli_binary -ac_name=$1 getblock $blocks | jq .time)
    mempool_size=$($komodo_cli_binary -ac_name=$1 getmempoolinfo | jq .size)
    getmininginfo=$($komodo_cli_binary -ac_name=$1 getmininginfo)

    generate=$(echo $getmininginfo | jq .generate)
    genproclimit=$(echo $getmininginfo | jq .genproclimit)

    delta=$(($curtime-$lasttime))

    printf "[%8s] %08d %08d " $1 $blocks $longestchain
    printf '%02dh:%02dm:%02ds ' $(($delta/3600)) $(($delta%3600/60)) $(($delta%60))
    printf "[%d - %s,%d]" $mempool_size $generate $genproclimit
    if [ $blocks != $longestchain ]; then
    echo -e -n "\x1B[22;31m [!]\x1B[0m"
    fi
    echo -e -n "\n"

}

show_height REVS
show_height SUPERNET
show_height DEX
show_height PANGEA
show_height JUMBLR
show_height BET
show_height CRYPTO
show_height HODL
show_height MSHARK
show_height BOTS
show_height MGW 
show_height COQUI
show_height WLC
show_height KV
show_height CEAL
show_height MESH 
show_height MNZ
show_height AXO
show_height ETOMIC
show_height BTCH
#show_height VOTE2018
show_height PIZZA
show_height BEER
show_height NINJA
show_height OOT
show_height BNTN
show_height CHAIN
show_height PRLPAY
show_height DSEC
show_height GLXT
show_height EQL
show_height ZILLA
show_height VRSC
show_height RFOX
show_height SEC
show_height CCL
show_height PIRATE
show_height MGNX
show_height PGT
show_height KMDICE
show_height DION
show_height ZEX
echo ------------

INFO=$($komodo_cli_binary getinfo)
blocks=$(echo $INFO | jq .blocks)
longestchain=$(echo $INFO | jq .longestchain)
lasttime=$($komodo_cli_binary getblock $blocks | jq .time)
delta=$(($curtime-$lasttime))
printf "[%8s] %08d %08d " "KMD" $blocks $longestchain
printf '%02dh:%02dm:%02ds' $(($delta/3600)) $(($delta%3600/60)) $(($delta%60))
if [ $blocks != $longestchain ]; then
echo -e -n "\x1B[22;31m [!]\x1B[0m"
fi
echo -e -n "\n"