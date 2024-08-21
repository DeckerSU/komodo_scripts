#!/usr/bin/env bash

# (q) Decker 2023-2024

# The main purpose of this script is to quickly restart all running Komodo daemon instances.
# To use it, navigate to the Komodo (or KomodoOcean) repository's `./src` directory and then 
# launch the script.

# Don't forget to shut down Iguana using `pkill -9 iguana` before restarting the daemons.

if [[ ! -x ./komodod || ! -x ./komodo-cli ]]; then
    echo "Error: ./komodod and/or ./komodo-cli not found in the current directory."
    echo "Please make sure to run this script from the Komodo repo src directory."
    exit 1
fi

### 1. Check launched
launched_ac=()
while read -r pid args; do
    ac_name=$(echo $args | grep -oP '(?<=-ac_name=)[^\s]+')
    if [ -n "$ac_name" ]; then
        # echo "ac_name: $ac_name"
        launched_ac+=("$ac_name")
    fi
done < <(ps -eo pid,cmd | grep '[k]omodod' | awk '{$2=""; print $0}')
# echo "Launched: ${launched_ac[@]}"

assetchains_json=$(curl -s https://raw.githubusercontent.com/KomodoPlatform/dPoW/master/iguana/assetchains.json)
echo -e "\nChecking launched AC komodod instances against dPoW repo:\n"
echo "$assetchains_json" | jq -r '.[].ac_name' | while read -r asset_ac_name; do
    # echo "Checking: $asset_ac_name"
    if [[ " ${launched_ac[@]} " =~ " $asset_ac_name " ]]; then
        echo -e "\e[32m█ $asset_ac_name\e[0m" # launched
    else
        echo -e "\e[31m█ $asset_ac_name\e[0m" # not launched
    fi
done

# VRSC now uses `verusd` as its daemon name, and TOKEL uses `tokeld`, but let's make sure 
# that we're not trying to re-launch third-party chains with the original `komodod`.

### 2. Restart
ps -eo pid,cmd | grep '[k]omodod' | awk '{$2=""; print $0}' | while read -r pid args; do
    ac_name=$(echo $args | grep -oP '(?<=-ac_name=)[^\s]+')

    if [[ "$ac_name" == "MCL" || "$ac_name" == "VRSC" || "$ac_name" == "TOKEL" ]]; then
        echo -e "\e[33mSkipping $ac_name\e[0m [PID: $pid]"
        continue
    fi

    if [ -n "$ac_name" ]; then
        echo -e "\e[33m$ac_name\e[0m [PID: $pid]"
        ./komodo-cli -ac_name=$ac_name stop
    else
        echo -e "\e[33mKMD\e[0m [PID: $pid]"
        ./komodo-cli stop
    fi
    while kill -0 $pid 2>/dev/null; do
        echo -n "█"
        sleep 1
    done
    echo -e "\n"
    ./komodod $args &
    sleep 1
done
