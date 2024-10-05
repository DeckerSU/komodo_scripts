#!/bin/bash

# Read the kmd_coins array from assetchains.json
readarray -t kmd_coins < <(cat "$HOME/dPoW/iguana/assetchains.json" | jq -r '[.[].ac_name] | join("\n")')

# Set color variables
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Folders to skip
skip_folders=("chainstate" "database" "notarisations" "blocks" "GLEEC_OLD")

# Scan folders in ~/.komodo and check against kmd_coins array
for folder in "$HOME/.komodo"/*; do
    # Only check if it is a directory
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")

        # Skip specific folders
        if [[ " ${skip_folders[@]} " =~ " ${folder_name} " ]]; then
            continue
        fi
        
        # Check if the folder name exists in the kmd_coins array
        if [[ " ${kmd_coins[@]} " =~ " ${folder_name} " ]]; then
            echo -e "${GREEN}Ok${NC} - $folder_name"
        else
            echo -e "${RED}Delete${NC} - $folder_name"
        fi
    fi
done
