#!/bin/bash

# Split NN script by phm87 (c) 2019
# Call split_nn_sapling.sh if the utxo count on the NN_ADRESS it belox SPLIT_THRESHOLD
# Inspired from cronsplit (webworker01) and from split_nn_sapling.sh (Decker)

# Config

NN_ADDRESS=RUjf7qQkUcVjkVeBgbrhCE4CpDH7fRuGyU
SPLIT_VALUE=0.0001
SPLIT_COUNT=3 # do not set split count > 252 (!), it's important
SPLIT_THRESHOLD=5
# Please configure split_nn_sapling.sh also

# End of config


SPLIT_VALUE_SATOSHI=$(jq -n "$SPLIT_VALUE*100000000")
SPLIT_TOTAL=$(jq -n "$SPLIT_VALUE*$SPLIT_COUNT")
SPLIT_TOTAL_SATOSHI=$(jq -n "$SPLIT_VALUE*$SPLIT_COUNT*100000000")

# get listunspent from explorer, assumes komodo daemon is not available at this moment
# (restart for example) or we don't have imported FROM privkey in the wallet.

curl -s https://kmdexplorer.io/insight-api-komodo/addr/$NN_ADDRESS/utxo > nn.utxos

nnutxos=$(<nn.utxos)
nnutxo=$(echo "$nnutxos" | jq --arg amt "$SPLIT_VALUE" '[.[] | select (.amount==($amt|tonumber))] | length')
if [[ nnutxo != "null" ]]; then
        if (( nnutxo < SPLIT_THRESHOLD )); then
                echo "call to split_nn_sapling.sh because $nnutxo < $SPLIT_THRESHOLD"
                ./split_nn_sapling.sh
        fi
fi
