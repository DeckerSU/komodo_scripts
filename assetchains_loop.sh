#!/usr/bin/env bash

###
#  This is just a template for actions on ALL assetchains (loop via all ACs)
###

komodo_cli_binary="$HOME/komodo/src/komodo-cli"
readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"

if [[ ${#kmd_coins[@]} -eq 0 ]]; then
  echo "Failed to fetch assetchains or no assetchains found." >&2
  exit 1
fi

source ~/pubkey.txt
WIF=
TO=

gleec_count=0
for i in "${kmd_coins[@]}"
do
  echo Processing "$i" 1>&2
  if [[ "$i" == "GLEEC" ]]; then
    ((gleec_count++))

    if [[ "$gleec_count" -eq 1 ]]; then
      echo "                 ---> action_1" 1>&2
    elif [[ "$gleec_count" -eq 2 ]]; then
      echo "                 ---> action_2" 1>&2
    else
      echo "GLEEC has been encountered more than twice. No additional actions will be performed." 1>&2
    fi
  fi
done

# Actions examples:

#${komodo_cli_binary} -ac_name="$i" importprivkey ${WIF} "" false
#BALANCE=$(${komodo_cli_binary} -ac_name="$i" getbalance)
#echo ${komodo_cli_binary} -ac_name="$i" sendtoaddress ${TO} ${BALANCE} "" "" true
#${komodo_cli_binary} -ac_name="$i" z_mergetoaddress '["ANY_TADDR"]' ${TO} 0.001 0

#PORT=$(${komodo_cli_binary} -ac_name="$i" getinfo | jq .p2pport)
#echo "# ${i} mangle rules"
#echo sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport $PORT -j MARK --set-mark 0x2 -m comment --comment "\"${i} IPv4 mark to\""
#echo sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport $PORT -j MARK --set-mark 0x2 -m comment --comment "\"${i} IPv4 mark from\"" 
#echo sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport $PORT -j MARK --set-mark 0x4 -m comment --comment "\"${i} IPv6 mark to\"" 
#echo sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport $PORT -j MARK --set-mark 0x4 -m comment --comment "\"${i} IPv6 mark from\"" 

#echo sudo ufw allow $PORT/tcp comment "'${i} p2p port'"
#${komodo_cli_binary} -ac_name="$i" getinfo | jq .connections

#BALANCE=$(${komodo_cli_binary} getbalance)
#echo KMD ${BALANCE} -- ${TO}
# ${komodo_cli_binary} sendtoaddress ${TO} ${BALANCE} "" "" true
#${komodo_cli_binary} z_mergetoaddress '["ANY_TADDR"]' ${TO} 0.001 0
