#!/usr/bin/env bash

# (c) Decker, 2024
#
# The main purpose of the sendawaynn_subsidy.sh script is to
# consolidate all funds on the NN pubkey that remain on bech32
# (ltc1) addresses in your wallet (subsidy funds) and send them
# to <target_ltc_address> (which should also be bech32).
#
# Example:
#
# Usage: ./sendawaynn_subsidy.sh <target_ltc_address>

set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

# Configuration
LOG_FILE="$HOME/litecoin_tx.log"

# Logging function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
  echo "Error on line $1" | tee -a "$LOG_FILE"
  exit 1
}

trap 'error_exit $LINENO' ERR

# Function to locate litecoin-cli
find_litecoin_cli() {
  local local_path="$HOME/litecoin/src/litecoin-cli"

  if [[ -x "$local_path" ]]; then
    echo "$local_path"
  elif command -v litecoin-cli >/dev/null 2>&1; then
    echo "$(command -v litecoin-cli)"
  else
    echo ""
  fi
}

# Locate litecoin-cli
LITECOIN_CLI=$(find_litecoin_cli)

if [[ -z "$LITECOIN_CLI" ]]; then
  echo "Error: litecoin-cli not found in ~/litecoin/src or in PATH."
  exit 1
fi

# Check for other required commands
for cmd in jq bc; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd is not installed or not in PATH."
    exit 1
  fi
done

# Input parameters
if [ $# -lt 1 ]; then
  echo "Usage: $0 <target_ltc_address> [fee]"
  exit 1
fi

TARGET_ADDRESS="$1"

# Validate Litecoin address (basic regex for Bech32)
if ! [[ "$TARGET_ADDRESS" =~ ^ltc1[a-z0-9]{39}$ ]]; then
  echo "Error: Invalid Litecoin address format."
  exit 1
fi

FEE="${2:-0.001}"

# Fetch UTXOs
log "Fetching UTXOs..."
UTXOS=$("$LITECOIN_CLI" listunspent)

# Parse UTXOs
PARSED_DATA=$(echo "$UTXOS" | jq --arg prefix "ltc1" '
  {
    inputs: [.[] | select(.address | startswith($prefix)) | select(.spendable == true) | {txid: .txid, vout: .vout}],
    total: ([.[] | select(.address | startswith($prefix)) | select(.spendable == true) | .amount] | add)
  }'
)

INPUTS=$(echo "$PARSED_DATA" | jq '.inputs')
TOTAL_AMOUNT=$(echo "$PARSED_DATA" | jq '.total')

log "Inputs for Transaction:"
log "$INPUTS"
log "Total Amount of Selected UTXOs: $TOTAL_AMOUNT LTC"

# Calculate amount to send
AMOUNT_TO_SEND=$(echo "$TOTAL_AMOUNT - $FEE" | bc -l | tr -d '\n')
AMOUNT_TO_SEND=$(printf "%.8f" "$AMOUNT_TO_SEND")

# Check if amount to send is positive
if (( $(echo "$AMOUNT_TO_SEND <= 0" | bc -l) )); then
  echo "Error: Insufficient funds after deducting the fee of $FEE LTC."
  exit 1
fi

log "Amount to Send (after $FEE LTC fee): $AMOUNT_TO_SEND LTC"

# Create raw transaction
log "Creating raw transaction..."
RAW_TX=$("$LITECOIN_CLI" createrawtransaction "$INPUTS" "{\"$TARGET_ADDRESS\":$AMOUNT_TO_SEND}")
log "Raw Transaction:"
log "$RAW_TX"

# Sign the transaction
log "Signing the transaction..."
SIGNED_TX=$("$LITECOIN_CLI" signrawtransaction "$RAW_TX" 2>/dev/null || true)

# Determine signing command
if ! echo "$SIGNED_TX" | jq -e '.complete' >/dev/null; then
  log "signrawtransaction failed, falling back to signrawtransactionwithwallet..."
  SIGNED_TX=$("$LITECOIN_CLI" signrawtransactionwithwallet "$RAW_TX")
  SIGN_CMD="signrawtransactionwithwallet"
else
  SIGN_CMD="signrawtransaction"
fi

log "Signing command used: $SIGN_CMD"
log "Signed Transaction:"
log "$SIGNED_TX"

# Verify if signing was complete
if ! echo "$SIGNED_TX" | jq -e '.complete' >/dev/null; then
  echo "Error: Transaction signing incomplete."
  exit 1
fi

# Prompt for confirmation
read -p "Do you want to send this transaction? (yes/no): " CONFIRMATION

if [ "$CONFIRMATION" == "yes" ]; then
  # Extract hex and send transaction
  TX_HEX=$(echo "$SIGNED_TX" | jq -r '.hex')
  SEND_RESULT=$("$LITECOIN_CLI" sendrawtransaction "$TX_HEX")
  log "Transaction sent! TXID: $SEND_RESULT"
else
  log "Transaction not sent."
fi
