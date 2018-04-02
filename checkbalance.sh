#!/bin/bash
green='\x1B[22;32m'
red='\x1B[22;31m'
normal='\x1B[0m'
komodo_cli=/home/decker/ssd_m2/komodo/komodo-cli
balance_limit=1000000
#address=RFCBA37HR52PMqqR791eWertKMTYkXS3mb
addresses=(RARcozaVAMZaXJaL6KWMSw297xTYzbDwa3 RFCBA37HR52PMqqR791eWertKMTYkXS3mb)

function check_balance()
{
    if [ $1 != "KMD" ]
    then
        asset=" -ac_name=$1"
    else
        asset=""
    fi

    for address in "${addresses[@]}"
    do
    #BALANCE=$($komodo_cli $asset listunspent 1 9999999 "[\"$address\"]" | jq .[].amount | paste -sd+ | bc -l | sed 's/^\./0./')
    #$komodo_cli $asset listunspent 1 9999999 "[\"$address\"]" | jq 'group_by(.address) | map({"address": .[0].address, value: map(.amount) | add})'
    iswatchonly=$($komodo_cli $asset validateaddress $address | jq .iswatchonly)
    if [ $iswatchonly == "true" ]; then
	    BALANCE=$($komodo_cli $asset listunspent 1 9999999 "[\"$address\"]" | jq .[].amount | jq -s add)
	    #if [ -z "${BALANCE}" ]; then 
	    if [ ${BALANCE} == "null" ]; then 
		BALANCE=0
	    fi	
	    BALANCE=$(echo "scale=8; $BALANCE/1*1" | bc -l | sed 's/^\./0./')

	    if (( $(echo "$BALANCE > $balance_limit" | bc -l) )); then
    		echo -e $address "[$green $BALANCE $normal]" $1
	    else 
	        echo -e $address [$red $BALANCE $normal] $1
        	TOSEND=$(echo $balance_limit-$BALANCE | bc -l | sed 's/^\./0./')
	        echo $komodo_cli $asset sendtoaddress "$address" $TOSEND '"" "" true'
	    fi
    fi	
    done
}
check_balance KMD
check_balance VOTE2018
