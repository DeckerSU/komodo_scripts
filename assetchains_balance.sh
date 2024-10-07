#!/usr/bin/env bash

init_colors() {
    RESET="\033[0m"
    BLACK="\033[30m"    
    RED="\033[31m"      
    GREEN="\033[32m"    
    YELLOW="\033[33m"   
    BLUE="\033[34m"     
    MAGENTA="\033[35m"  
    CYAN="\033[36m"     
    WHITE="\033[37m" 
    BRIGHT="\033[1m"
    DARKGREY="\033[90m"
}

show_balance () {
    # Function: show_balance
    # Description: Retrieves and displays the balance and UTXO count for a specified coin.
    #              If no coin is provided, defaults to "KMD".
    #              If a second parameter is provided, it is added to the komodo-cli command.
    # Parameters:
    #   $1 - (Optional) Coin name (e.g., "KMD" for Komodo main chain or asset chain name)
    #   $2 - (Optional) Additional parameter to pass to komodo-cli (e.g., account name)
    # Usage:
    #   show_balance               # Defaults to "KMD"
    #   show_balance "XYZ"          # For asset chain "XYZ"
    #   show_balance "XYZ" "account1"  # For asset chain "XYZ" with additional parameter "account1"

    # Assign the first argument to 'coin', defaulting to "KMD" if not provided
    local coin="${1:-KMD}"
    local param="$2"
    local ac_option=""
    local BALANCE=""
    local UTXOS=""

    # Validate coin name (only alphanumeric characters and underscores)
    if [[ ! "$coin" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo -e "${RED}Error:${RESET} Invalid coin name '$coin'. Only alphanumeric characters and underscores are allowed." >&2
        return 1
    fi

    # Determine whether to use the -ac_name parameter
    if [[ "$coin" != "KMD" ]]; then
        ac_option="-ac_name=$coin"
    fi

    if [[ "$coin" == "GLEEC_OLD" ]]; then
        ac_option="-ac_name=GLEEC"
    fi

    # Construct the komodo-cli command for getbalance
    BALANCE=$($komodo_cli_binary $ac_option ${param:+$param} getbalance 2> /dev/null)

    # Check if the balance retrieval was successful
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error:${RESET} Failed to retrieve balance for '$coin'. Please ensure the daemon is running and the coin name is correct." >&2
        return 1
    fi

    # Ensure 'pubkey' is set and properly formatted
    if [[ -z "$pubkey" ]]; then
        echo -e "${RED}Error:${RESET} 'pubkey' variable is not set. Please source pubkey.txt correctly." >&2
        return 1
    fi

    # Construct the expected scriptPubKey
    local expected_scriptPubKey="21${pubkey}ac"

    # If param is set and not empty, ${param:+$param} expands to the value of param,
    # If param is unset or empty, ${param:+$param} expands to nothing (i.e., it omits param).
    UTXOS=$($komodo_cli_binary $ac_option ${param:+$param} listunspent | jq --arg script "$expected_scriptPubKey" '[.[] | select(.generated == false and .amount == 0.0001 and .spendable == true and (.scriptPubKey == $script))] | length')

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error:${RESET} Failed to retrieve UTXOs for '$coin'." >&2
        return 1
    fi

    # Compare BALANCE using jq
    if [[ $(jq -n --arg b "$BALANCE" '$b | tonumber > 10') == "true" ]]; then
        # BALANCE is greater than 10; display in green
        printf "[%-15s]  [${GREEN}%15s${RESET}]  [%5d]\n" "$coin" "$BALANCE" "$UTXOS"
    else 
        # BALANCE is 10 or less; display normally
        printf "[%-15s]  [%15s]  [%5d]\n" "$coin" "$BALANCE" "$UTXOS"
    fi
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

determine_litecoin_cli() {
    local cli_path
    # Check system-wide installation
    cli_path=$(command -v litecoin-cli 2>/dev/null)
    if [[ -x "$cli_path" ]]; then
        echo "Found system-wide litecoin-cli at: $cli_path" >&2
        echo "$cli_path"
        return 0
    fi

    # Check in ~/litecoin/src
    cli_path="$HOME/litecoin/src/litecoin-cli"
    if [[ -x "$cli_path" ]]; then
        echo "Found litecoin-cli at: $cli_path" >&2
        echo "$cli_path"
        return 0
    fi

    # litecoin-cli not found
    echo -e "${RED}Error:${RESET} litecoin-cli not found in system-wide path or $HOME/litecoin/src." >&2
    exit 1
}

init_colors
komodo_cli_binary=$(determine_komodo_cli)
litecoin_cli_binary=$(determine_litecoin_cli)
source_pubkey

KMD_ADDRESS=$(${komodo_cli_binary} decodescript "21${pubkey}ac" | jq -r .addresses[0])
LTC_ADDRESS=$(${litecoin_cli_binary} decodescript "21${pubkey}ac" | jq -r .addresses[0])
printf "KMD Address:  ${YELLOW}%-40s${RESET}\n" "$KMD_ADDRESS"
printf "LTC Address:  ${YELLOW}%-40s${RESET}\n" "$LTC_ADDRESS"
echo

# Read assetchains from JSON
readarray -t kmd_coins < <(cat $HOME/dPoW/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# printf '%s\n' "${kmd_coins[@]}"

gleec_count=0
for i in "${kmd_coins[@]}"
do
  if [[ "$i" == "GLEEC" ]]; then
    ((gleec_count++))

    if [[ "$gleec_count" -eq 1 ]]; then
      show_balance "GLEEC_OLD" "-datadir=$HOME/.komodo/GLEEC_OLD"
    elif [[ "$gleec_count" -eq 2 ]]; then
      show_balance "GLEEC"
    else
      echo -e "${YELLOW}GLEEC has been encountered more than twice. No additional actions will be performed.${RESET}" >&2
    fi

    continue
  fi
  show_balance "$i"
done

# KMD Balance
show_balance

# LTC Balance with Fixed-Width Formatting
BALANCE=$(${litecoin_cli_binary} getbalance)
UTXOS=$(${litecoin_cli_binary} listunspent | jq '[.[] | select (.amount==0.00010000 and .spendable==true and (.scriptPubKey == "21'"${pubkey}"'ac"))] | length')
if [[ $(jq -n --arg b "$BALANCE" '$b | tonumber > 10') == "true" ]]; then
    # BALANCE is greater than 10; display in green
    printf "[%-15s]  [${GREEN}%15s${RESET}]  [%5d]\n" "LTC" "$BALANCE" "$UTXOS"
else 
    # BALANCE is 10 or less; display normally
    printf "[%-15s]  [%15s]  [%5d]\n" "LTC" "$BALANCE" "$UTXOS"
fi
