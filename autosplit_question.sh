#!/bin/bash
chips_cli=/home/decker/chips3/src/chips-cli
bitcoin_cli=bitcoin-cli
gamecredits_cli=/home/decker/GameCredits/src/gamecredits-cli
komodo_cli=/home/decker/komodo/src/komodo-cli

utxo_min=100
utxo_max=100

# Here we trying to split only (!) assetchains, KMD, GAME, BTC need additional code.

declare -a kmd_coins=(REVS SUPERNET DEX PANGEA JUMBLR BET CRYPTO HODL MSHARK BOTS MGW COQUI WLC KV CEAL MESH MNZ AXO ETOMIC BTCH PIZZA BEER NINJA OOT BNTN CHAIN PRLPAY DSEC GLXT EQL VRSC ZILLA RFOX SEC)
for i in "${kmd_coins[@]}"
do
    echo -n [$i] 
    utxo=$($komodo_cli -ac_name=$i listunspent | grep .0001 | wc -l)
    echo -n ' '$utxo
    if [ $utxo -eq 0 ]; then
	echo " Need funds!"
    else
	    if [ $utxo -lt $utxo_min ]; then
	        need=$(($utxo_max-$utxo))
		echo ' --> '$need
		# /home/decker/SuperNET/iguana/acsplit $i $need
		echo "Do you wish to split $i?"
		select yn in "Yes" "No"; do
		    case $yn in
			Yes ) curl --url "http://127.0.0.1:7776" --data "{\"coin\":\""${i}"\",\"agent\":\"iguana\",\"method\":\"splitfunds\",\"satoshis\":\"10000\",\"sendflag\":1,\"duplicates\":"${need}"}"; break;;
			No ) break;;
		    esac
		done
	    else
		echo
	    fi
    fi
done