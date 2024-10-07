#!/usr/bin/env bash

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
  echo -e "${RED}Error:${RESET} komodo-cli not found in system-wide path, $HOME/komodo/src, or $HOME/KomodoOcean/src." >&2
  exit 1
}

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
    echo -e "${RED}Error:${RESET} pubkey.txt not found in any of the specified locations." >&2
    exit 1
  fi

  # Ensure that the pubkey environment variable is set
  if [[ -z "$pubkey" ]]; then
    echo -e "${RED}Error:${RESET} pubkey environment variable is not set after sourcing pubkey.txt." >&2
    exit 1
  fi

  echo -e "Pubkey: \"${pubkey}\""
}

komodo_cli_binary=$(determine_komodo_cli)
source_pubkey
KMD_ADDRESS=$(${komodo_cli_binary} decodescript "21${pubkey}ac" | jq -r .addresses[0])
printf "KMD Address: ${YELLOW}%-40s${RESET}\n" "$KMD_ADDRESS"

#readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
readarray -t kmd_coins < <(cat $HOME/dPoW/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')

gleec_count=0
for i in "${kmd_coins[@]}"
do
  if [[ "$i" == "GLEEC" ]]; then
    ((gleec_count++))

    if [[ "$gleec_count" -eq 1 ]]; then
      echo Processing "GLEEC_OLD" 1>&2
      ${komodo_cli_binary} -ac_name="GLEEC" -datadir="$HOME/.komodo/GLEEC_OLD" cleanwallettransactions
    elif [[ "$gleec_count" -eq 2 ]]; then
    echo Processing "GLEEC" 1>&2
      ${komodo_cli_binary} -ac_name="GLEEC" cleanwallettransactions
    else
      echo -e "GLEEC has been encountered more than twice. No additional actions will be performed." >&2
    fi
    continue
  fi

  echo Processing "$i" 1>&2
  #time (${komodo_cli_binary} -ac_name="$i" listunspent | jq '. | { "utxos" : length }' && ${komodo_cli_binary} -ac_name="$i" getwalletinfo | jq '{ "txcount" : .txcount }') | jq -s add
  #${komodo_cli_binary} -ac_name="$i" z_mergetoaddress '["ANY_TADDR"]' $KMD_ADDRESS 0.001 0
  ${komodo_cli_binary} -ac_name="$i" cleanwallettransactions
done

echo Processing "KMD" 1>&2
#${komodo_cli_binary} z_mergetoaddress '["ANY_TADDR"]' $KMD_ADDRESS 0.001 0
#sleep 5
${komodo_cli_binary} cleanwallettransactions
echo Processing "LTC" 1>&2
$HOME/litecoin/src/litecoin-cli cleanwallettransactions


