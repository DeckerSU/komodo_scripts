#!/usr/bin/env bash

# Coind DNS Seed Updater v0.01 (c) Decker, 2019

# This script updates A-records for selected zone via Gandi.net API,
# new seeds retrieve from coin daemon outgoing peers. Script updates
# only A (IPv4) records and doesn't check IP in case if it is from 
# Bogon/Bogus networks.

# --------------------------------------------------------------------------
function init_colors() {
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
# --------------------------------------------------------------------------
function log_print() {
   datetime=$(date '+%Y-%m-%d %H:%M:%S')
   echo -e [$datetime] $1
}

# --------------------------------------------------------------------------
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html

function checkconfig()
{
	if ! grep -qs '^rpcpassword=' "${KOMODOD_CONFIGFILE}" ; then
		log_print "Parsing: ${KOMODOD_CONFIGFILE} - ${RED}FAILED${RESET}"
		return 1
    fi
    if ! grep -qs '^rpcuser=' "${KOMODOD_CONFIGFILE}" ; then
		log_print "Parsing: ${KOMODOD_CONFIGFILE} - ${RED}FAILED${RESET}"
		return 1
    fi

    grep -qs '^rpcpassword=' "${KOMODOD_CONFIGFILE}"
    KOMODOD_RPCPASSWORD=$(grep -s '^rpcpassword=' "${KOMODOD_CONFIGFILE}")
    KOMODOD_RPCPASSWORD=${KOMODOD_RPCPASSWORD/rpcpassword=/}
    
    grep -qs '^rpcuser=' "${KOMODOD_CONFIGFILE}"
    KOMODOD_RPCUSER=$(grep -s '^rpcuser=' "${KOMODOD_CONFIGFILE}")
    KOMODOD_RPCUSER=${KOMODOD_RPCUSER/rpcuser=/}

    if ! grep -qs '^rpcport=' "${KOMODOD_CONFIGFILE}" ; then
		KOMODO_RPCPORT=7771
    else
        KOMODO_RPCPORT=$(grep -s '^rpcport=' "${KOMODOD_CONFIGFILE}")
        KOMODO_RPCPORT=${KOMODO_RPCPORT/rpcport=/}
    fi
    
    log_print "Parsing RPC credentials: ${KOMODOD_CONFIGFILE} - ${GREEN}OK${RESET}"
    
}
# --------------------------------------------------------------------------
function getpeerinfo() {
    res=$(curl -s --user "${KOMODOD_RPCUSER}:${KOMODOD_RPCPASSWORD}" --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getpeerinfo", "params": [] }' -H 'content-type: text/plain;' http://${KOMODOD_RPCHOST}:${KOMODO_RPCPORT}/)
    if [ "$(echo ${res} | jq .error)" == null ]; then
        PEERINFO="$(echo ${res} | jq .result)"
    else
        PEERINFO=[]
        log_print "${RED}ERROR $(echo ${res} | jq .error.code) : $(echo ${res} | jq -r .error.message)${RESET}"
        return 1
    fi
}
# --------------------------------------------------------------------------

# daemon config
KOMODOD_DEFAULT_DATADIR=${KOMODOD_DEFAULT_DATADIR:-"$HOME/.komodo"}
KOMODOD_CONFIGFILE=${KOMODOD_CONFIGFILE:-"$KOMODOD_DEFAULT_DATADIR/komodo.conf"}
KOMODOD_RPCHOST=127.0.0.1

# Gandi API doc:
# https://doc.livedns.gandi.net/

# gandi account config
DOMAIN="example.org"
RECORD="seeds"
APIKEY="YOUR_GANDI_API_KEY"
APPLY_CHANGES=true

init_colors
log_print "Starting ..."
checkconfig || exit
getpeerinfo || exit

# https://unix.stackexchange.com/questions/296596/how-to-check-if-any-ip-address-is-present-in-a-file-using-shell-scripting
readarray -t nodeips < <(echo ${PEERINFO} | jq -r '.[] | select (.inbound == false) | .addr' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# first we should get zone UUID from API or set it directly
# auto rerieve UUID
UUID=$(curl -s -H "X-Api-Key: $APIKEY" https://dns.api.gandi.net/api/v5/zones | jq -r '.[] | select (.name == "'${DOMAIN}'") | .uuid')
# manual set of UUID
# UUID=00000000-1111-2222-3333-444444444444

log_print "Zone UUID: ${UUID}"

# List all records in the zone UUID and filter needed by jq
# SEEDS=$(curl -s -H "X-Api-Key: $APIKEY" https://dns.api.gandi.net/api/v5/zones/${UUID}/records | jq -r '.[] | select (.rrset_type == "A" and .rrset_name == "'${RECORD}'") | .rrset_values')

# List all records with name "NAME" and type "TYPE" in the zone UUID
SEEDS=$(curl -s -H "X-Api-Key: $APIKEY" "https://dns.api.gandi.net/api/v5/zones/${UUID}/records/${RECORD}/A" | jq -r '.rrset_values')
log_print "Current seeds: ${SEEDS}"

if [ "${#nodeips[@]}" -gt "0" ]; then
    log_print "Retrieved IPs: ${#nodeips[@]}"

    # https://stackoverflow.com/questions/49184557/convert-bash-array-to-json-array-and-insert-to-file-using-jq
    # https://stackoverflow.com/questions/26808855/how-to-format-a-bash-array-as-a-json-array
    
    # convert bash array of strings to json array (variant 1)
    # nodeips=(127.0.0.1 127.0.0.2)
    # printf '%s\n' "${nodeips[@]}" | jq -R . | jq -s .
    
    # convert bash array of strings to json array (variant 2)
    # nodeips=(127.0.0.1 127.0.0.2)
    # for ip in "${nodeips[@]}"; do printf '%s' "${ip}" | jq -R -s .; done | jq -s .

    NEW_SEEDS=$(for ip in "${nodeips[@]}"; do printf '%s' "${ip}" | jq -R -s .; done | jq -s .)
    log_print "New seeds: ${NEW_SEEDS}"

    if ${APPLY_CHANGES}; then
    # Change all "NAME" records from the zone UUID
    MESSAGE=$(curl -s -X PUT -H "Content-Type: application/json" \
            -H "X-Api-Key: $APIKEY" \
            -d '{"items": [{"rrset_type": "A",
                            "rrset_ttl": 1800,
                            "rrset_values": '"${NEW_SEEDS}"'}]}' \
            "https://dns.api.gandi.net/api/v5/zones/${UUID}/records/${RECORD}" | jq -r '.message')
    log_print "Operation result: ${MESSAGE}"
    fi

fi


# record example
# {
# "rrset_type": "A",
# "rrset_ttl": 1800,
# "rrset_name": "seeds1",
# "rrset_href": "https://dns.api.gandi.net/api/v5/zones/UUID/records/seeds1/A",
# "rrset_values": [
#   "78.47.196.146"
# ]
# }


