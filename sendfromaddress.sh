#!/bin/bash

FROM_ADDRESS=RMR3NGjTGjHcEpixpveKXX9L4wTUf3Db2x
curl -s https://kmdexplorer.io/insight-api-komodo/addr/$FROM_ADDRESS/utxo > all.utxos
utxos=$(<all.utxos)
utxo=$(echo "$utxos"   | jq -c "[.[] | select (.confirmations > 100 and .amount != 0.0001 and .amount != 0.00000055) | { txid: .txid, vout: .vout}]")
amount=$(echo "$utxos" | jq -r "[.[] | select (.confirmations > 100 and .amount != 0.0001 and .amount != 0.00000055) | .amount] | add")
# echo $amount
# https://stackoverflow.com/questions/46117049/how-i-can-round-digit-on-the-last-column-to-2-decimal-after-a-dot-using-jq
value=$(echo $amount | jq 'def round: tostring | (split(".") + ["0"])[:2] | [.[0], "\(.[1])"[:8]] | join(".") | tonumber; . | round')
# echo $value
echo "createrawtransaction '$utxo' '{\"RMR3NGjTGjHcEpixpveKXX9L4wTUf3Db2x\": $value}'"
