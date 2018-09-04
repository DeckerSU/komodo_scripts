#!/bin/bash

RESET="\033[0m"
BLACK="\033[30m"    
RED="\033[31m"      
GREEN="\033[32m"    
YELLOW="\033[33m"   
BLUE="\033[34m"     
MAGENTA="\033[35m"  
CYAN="\033[36m"     
WHITE="\033[37m"    

function show_walletsize ()
{
    if [ "$1" != "KMD" ]; then
	if [ -f ~/.komodo/$1/wallet.dat ]; then

	# SIZE=$(stat ~/.komodo/$1/wallet.dat | grep -Po "Size: \d*" | cut -d" " -f2)
	# Pattern "Size: " - is only for english locale, so, we won't use it.

	SIZE=$(stat ~/.komodo/$1/wallet.dat | grep -Po "\d+" | head -1)
	else
	SIZE=0
	fi
    else
	SIZE=$(stat ~/.komodo/wallet.dat | grep -Po "\d+" | head -1)
    fi
    OUTSTR=$(echo $SIZE | numfmt --to=si --suffix=B)
    if [ "$SIZE" -gt "19922944" ]; then
        OUTSTR=${RED}$OUTSTR${RESET}
    else
	OUTSTR=${GREEN}$OUTSTR${RESET}
    fi
    printf "[%8s] %16b\n" $1 $OUTSTR
}

show_walletsize REVS
show_walletsize SUPERNET
show_walletsize DEX
show_walletsize PANGEA
show_walletsize JUMBLR
show_walletsize BET
show_walletsize CRYPTO
show_walletsize HODL
show_walletsize MSHARK
show_walletsize BOTS
show_walletsize MGW 
show_walletsize COQUI
show_walletsize WLC
show_walletsize KV
show_walletsize CEAL
show_walletsize MESH 
show_walletsize MNZ
show_walletsize AXO
show_walletsize ETOMIC
show_walletsize BTCH
#show_walletsize VOTE2018
show_walletsize PIZZA
show_walletsize BEER
show_walletsize NINJA
show_walletsize OOT
show_walletsize BNTN
show_walletsize CHAIN
show_walletsize PRLPAY
show_walletsize DSEC
show_walletsize GLXT
show_walletsize EQL
show_walletsize ZILLA
show_walletsize VRSC
show_walletsize RFOX
show_walletsize SEC
show_walletsize CCL
show_walletsize KMD