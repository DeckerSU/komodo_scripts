#!/usr/bin/env bash

# Coind DNS Seed Updater v0.01 (c) Decker, 2019-2021

# This script updates A-records for selected zone via CloudFlare API,
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

DNSSEEDDUMP="dnsseed.dump"
P2PPORT=7770

# cloudflare account config

DOMAIN="example.org"
RECORD="seeds"

ZONEID="deadffffffffffffffffffffffffdead" # your Zone ID from domain Overview page
TOKEN="YOUR_API_TOKEN" # create API token with needed permissions here - https://dash.cloudflare.com/profile/api-tokens
MAX_SEEDS=16

APPLY_CHANGES=false

init_colors
log_print "Starting ..."
checkconfig || exit
getpeerinfo || exit

# https://unix.stackexchange.com/questions/296596/how-to-check-if-any-ip-address-is-present-in-a-file-using-shell-scripting
readarray -t nodeips < <(echo ${PEERINFO} | jq -r '.[] | select (.inbound == false) | .addr' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

if [ "${#nodeips[@]}" -gt "0" ]; then
    log_print "Retrieved IPs: ${#nodeips[@]}"

    # https://stackoverflow.com/questions/49184557/convert-bash-array-to-json-array-and-insert-to-file-using-jq
    # https://stackoverflow.com/questions/26808855/how-to-format-a-bash-array-as-a-json-array

    # https://www.tech-otaku.com/web-development/using-cloudflare-api-manage-dns-records/
    # https://gist.github.com/Tras2/cba88201b17d765ec065ccbedfb16d9a
    # https://api.cloudflare.com/#dns-records-for-a-zone-update-dns-record
    # https://api.cloudflare.com/#dns-records-for-a-zone-delete-dns-record

    #         # lines below will create dnsseed.dump for future processing with cf-uploader [begin]
    #         cat << EOF > ${DNSSEEDDUMP}
    # # address                                        good
    # EOF
    #         for ip in "${nodeips[@]}"; do printf '%-52s1\n' "${ip}:${P2PPORT}" >> ${DNSSEEDDUMP}; done
    #         # cf-uploader [end]

    # API Tokens use the standard Authorization: Bearer header for authentication instead of
    # x-auth-email and x-auth-key that API Keys use.

    TOKEN_RESULT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json")
    # echo ${TOKEN_RESULT} | jq .success
    # echo ${TOKEN_RESULT} | jq -r .result.status
    if [[ "x$(echo ${TOKEN_RESULT} | jq .success)" == "xtrue" ]] && [[ "x$(echo ${TOKEN_RESULT} | jq -r .result.status)" == "xactive" ]]; then
        # token verify is success and token is active
        TOKEN_ID=$(echo ${TOKEN_RESULT} | jq -r .result.id)
        log_print "CF_TOKEN_ID: ${TOKEN_ID} - ${GREEN}OK${RESET}"
        REQ_NAME="${RECORD}.${DOMAIN}"
        # https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records
        DNS_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records?type=A&name=${REQ_NAME}&proxied=false&match=all" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" | jq -r .result)
        # echo ${DNS_RECORDS} | jq .
        current_ids=$(echo "${DNS_RECORDS}" | jq -r .[].id)
        current_seeds=$(echo "${DNS_RECORDS}" | jq -r .[].content)

        SEEDS=$(for ip in "${current_seeds[@]}"; do printf '%s' "${ip}" | jq -R .; done | jq -s .)
        log_print "Current seeds: ${SEEDS}"
        NEW_SEEDS=$(for ip in "${nodeips[@]}"; do printf '%s' "${ip}" | jq -R -s .; done | jq -s .)
        log_print "New seeds: ${NEW_SEEDS}"
        # readarray -t myDemoArray < <(echo "${DNS_RECORDS}" | jq -r '[.[].id] | join("\n")')
        readarray -t ids < <(echo "${DNS_RECORDS}" | jq -r '.[].id')
        readarray -t ips < <(echo "${DNS_RECORDS}" | jq -r '.[].content')
        if ${APPLY_CHANGES}; then
            # (1) delete all old records
            for key in "${!ids[@]}"
                do
                    # echo "id=${ids[$key]}, ip=${ips[$key]}"

                    DELETE_RESULT=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records/${ids[$key]}" \
                            -H "Authorization: Bearer ${TOKEN}" \
                            -H "Content-Type: application/json")
                    if [[ "x$(echo ${DELETE_RESULT} | jq .success)" == "xtrue" ]]; then
                        DELETE_RESULT_STATUS="${GREEN}OK${RESET}"
                    else
                        DELETE_RESULT_STATUS="${RED}FAILED${RESET}"
                    fi

                    log_print "Delete DNS record: ${ips[$key]} (${ids[$key]}) - ${DELETE_RESULT_STATUS}"
                done
            # (2) add new records
            seeds_count=0
            for ip in "${nodeips[@]}"
                do
                    # echo "ip=$ip"
                    ADD_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records" \
                            -H "Authorization: Bearer ${TOKEN}" \
                            -H "Content-Type: application/json" \
                            --data '{"type":"A","name":"'${REQ_NAME}'","content":"'${ip}'","ttl":1800,"proxied":false}')
                    if [[ "x$(echo ${ADD_RESULT} | jq .success)" == "xtrue" ]]; then
                        ADD_RESULT_STATUS="${GREEN}OK${RESET}"
                        seeds_count=$((seeds_count + 1))
                    else
                        ADD_RESULT_STATUS="${RED}FAILED${RESET}"
                    fi
                    log_print "Add DNS record: ${ip} - ${ADD_RESULT_STATUS}" # [${seeds_count}]
                    if [[ "${seeds_count}" -ge MAX_SEEDS ]]; then
                        break
                    fi
                done
        fi
    fi
fi
