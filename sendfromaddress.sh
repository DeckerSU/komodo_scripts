#!/bin/bash

FROM_ADDRESS=RWgpXEycP4rVkFp3j7WzV6E2LfR842WswN
curl -s https://kmdexplorer.io/insight-api-komodo/addr/$FROM_ADDRESS/utxo > all.utxos
utxos=$(<all.utxos)
utxo=$(echo "$utxos"   | jq -c "[.[] | select (.confirmations > 100 and .amount != 0.0001) | { txid: .txid, vout: .vout}]")
amount=$(echo "$utxos" | jq -r "[.[] | select (.confirmations > 100 and .amount != 0.0001) | .amount] | add")
# echo $amount
# https://stackoverflow.com/questions/46117049/how-i-can-round-digit-on-the-last-column-to-2-decimal-after-a-dot-using-jq
value=$(echo $amount | jq 'def round: tostring | (split(".") + ["0"])[:2] | [.[0], "\(.[1])"[:8]] | join(".") | tonumber; . | round')
# echo $value
echo "createrawtransaction '$utxo' '{\"bYX27YgVqfwn7spHJc2hGZwzsV4gwod9zC\": $value}'"
