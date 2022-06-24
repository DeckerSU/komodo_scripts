#!/usr/bin/env bash
komodo_cli_binary="$HOME/komodo/src/komodo-cli"
readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"

source ~/pubkey.txt
WIF=
TO=

for i in "${kmd_coins[@]}"
do
  echo Sending "$i"
  ${komodo_cli_binary} -ac_name="$i" importprivkey ${WIF} "" false
  BALANCE=$(${komodo_cli_binary} -ac_name="$i" getbalance)
  #echo ${komodo_cli_binary} -ac_name="$i" sendtoaddress ${TO} ${BALANCE} "" "" true
  ${komodo_cli_binary} -ac_name="$i" z_mergetoaddress '["ANY_TADDR"]' ${TO} 0.001 0
done

BALANCE=$(${komodo_cli_binary} getbalance)
echo KMD ${BALANCE} -- ${TO}
# ${komodo_cli_binary} sendtoaddress ${TO} ${BALANCE} "" "" true

${komodo_cli_binary} z_mergetoaddress '["ANY_TADDR"]' ${TO} 0.001 0
