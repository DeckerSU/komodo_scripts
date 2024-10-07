#!/usr/bin/env bash

###
#  This is just a template for actions on ALL assetchains (loop via all ACs)
###

readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"

# Initialize WIF and TO variables
WIF=
TO=

# Function to source pubkey.txt from multiple locations
source_pubkey() {
  local pubkey_file
  local found=0

  # Define the search order
  local search_paths=(
    "$HOME/komodo/src/pubkey.txt"
    "$HOME/KomodoOcean/src/pubkey.txt"
    "$HOME/pubkey.txt"
  )

  # Iterate through the search paths
  for pubkey_file in "${search_paths[@]}"; do
    if [[ -f "$pubkey_file" ]]; then
      echo "Found pubkey.txt at: $pubkey_file" >&2
      source "$pubkey_file"
      found=1
      break
    fi
  done

  # Check if pubkey.txt was found and sourced
  if [[ "$found" -ne 1 ]]; then
    echo "Error: pubkey.txt not found in any of the specified locations." >&2
    exit 1
  fi

  # Ensure that the pubkey environment variable is set
  if [[ -z "$pubkey" ]]; then
    echo "Error: pubkey environment variable is not set after sourcing pubkey.txt." >&2
    exit 1
  fi

  echo "Pubkey: \"${pubkey}\""
}

determine_komodo_cli() {
  local cli_path
  # Check system-wide installation
  cli_path=$(command -v komodo-cli 2>/dev/null)
  if [[ -x "$cli_path" ]]; then
    echo "Found system-wide komodo-cli at: $cli_path" >&2
    echo "$cli_path"
    return 0
  fi

  # Check in ~/komodo/src
  cli_path="$HOME/komodo/src/komodo-cli"
  if [[ -x "$cli_path" ]]; then
    echo "Found komodo-cli at: $cli_path" >&2
    echo "$cli_path"
    return 0
  fi

  # Check in ~/KomodoOcean/src
  cli_path="$HOME/KomodoOcean/src/komodo-cli"
  if [[ -x "$cli_path" ]]; then
    echo "Found komodo-cli at: $cli_path" >&2
    echo "$cli_path"
    return 0
  fi

  # komodo-cli not found
  echo "Error: komodo-cli not found in system-wide path, $HOME/komodo/src, or $HOME/KomodoOcean/src." >&2
  exit 1
}

# Set komodo_cli_binary by determining its path
komodo_cli_binary=$(determine_komodo_cli)
# Call the function to source pubkey.txt
source_pubkey

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
