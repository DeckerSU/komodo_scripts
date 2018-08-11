#!/bin/bash
i=0

RESET="\033[0m"
BLACK="\033[30m"    
RED="\033[31m"      
GREEN="\033[32m"    
YELLOW="\033[33m"   
BLUE="\033[34m"     
MAGENTA="\033[35m"  
CYAN="\033[36m"     
WHITE="\033[37m" 

while read -u 3 line; do
        i=$((i + 1))
	result=$(nc -w 3 $line 17775 | xxd -p)
	if [ "$result" == "0053500000700000" ]; then
	    echo -e $line - ${GREEN}Success!${RESET}
	else
	    echo -e $line - ${RED}Dead!${RESET}
	fi
done 3< <(curl -s --url "http://127.0.0.1:7776/" --data "{\"agent\":\"dpow\",\"method\":\"ipaddrs\"}" | jq -r .[])

# https://unix.stackexchange.com/questions/52026/bash-how-to-read-one-line-at-a-time-from-output-of-a-command
# https://stackoverflow.com/questions/26392867/netcat-inside-a-while-read-loop-returning-immediately