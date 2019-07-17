#!/bin/bash
# KMD+AC bootstrap gen (c) Decker, 2019

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
function bootstrap() {

    if [ ! -z $1 ] && [ $1 != "KMD" ]
        then
            coin=$1
            data_folder=${HOME}/.komodo/$coin
            transform='s,^.,'${coin}',S'
        else
            coin="KMD"
            data_folder=${HOME}/.komodo
            transform=''
    fi

    archive_name=bootstrap.${coin,,}.tar.gz
    du_files_list="${data_folder}/blocks ${data_folder}/chainstate ${data_folder}/notarisations" # ${data_folder}/komodostate ${data_folder}/komodostate.ind
    tar_files_list="./blocks ./chainstate ./notarisations" #  ./komodostate ./komodostate.ind
    files_size=$(du -cak ${du_files_list} | cut -f1 | tail -1)
    checkpoint=$((files_size / 100))
    log_print "Archiving \x5B${YELLOW}$i${RESET}\x5D --> ${archive_name}"
    log_print "Directory: ${data_folder}"
    log_print "Content: ${tar_files_list}"
    log_print "Size: ${files_size} Kb, Checkpoint: ${checkpoint} Kb"

    # --checkpoint-action=ttyout='[%{%Y-%m-%d %H:%M:%S}t] (%d sec): %u Kb, %T%*\r'
    GZIP=-9 tar --directory ${data_folder} \
        --record-size=1K --checkpoint="${checkpoint}" --checkpoint-action=ttyout='[%{%Y-%m-%d %H:%M:%S}t] Size: %u Kb, %T Elapsed: %d sec%*\r' \
        --show-transformed-names --transform="${transform}" \
        --exclude={wallet.dat,*.conf,*.bak,db.log,debug.log,fee_estimates.dat,peers.dat,banlist.dat} \
        --exclude={backup_*.dat,.lock,komodod.pid} \
        -czvf $(pwd)/${archive_name} ${tar_files_list} > /dev/null

}
# --------------------------------------------------------------------------
function walletbackup_mm() {

    # before use read about multiple members with the same name in tar, each time when you will launch
    # backup - it will add each wallet.dat as a new member (!), so in .tar you can possible have multiple
    # wallet.dat from each coin.

    if [ ! -z $1 ] && [ $1 != "KMD" ]
        then
            coin=$1
            data_folder=${HOME}/.komodo/$coin
            transform='s,^.,'${coin}',S'
        else
            coin="KMD"
            data_folder=${HOME}/.komodo
            transform=''
    fi

    archive_name=wallets.$(date -u +%Y%m%d).tar # _%H%M%S
    tar_files_list="./wallet.dat"
    log_print "Backup \x5B${YELLOW}$i${RESET}\x5D wallet.dat --> ${archive_name}"
    # https://www.gnu.org/software/tar/manual/html_node/multiple.html#SEC62 - Multiple Members with the Same Name
    GZIP=-9 tar --directory ${data_folder} \
    --show-transformed-names --transform="${transform}" \
    -rvf $(pwd)/${archive_name} ${tar_files_list} # > /dev/null
}
# --------------------------------------------------------------------------

# --- Variables ---
#komodo_cli_binary="$HOME/komodo/src/komodo-cli"
komodo_cli_binary="/home/decker/ssd_nvme/komodo_src_beta/src/komodo-cli"
# -----------------
#
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
# https://stackoverflow.com/questions/2264428/how-to-convert-a-string-to-lower-case-in-bash
# https://stackoverflow.com/questions/984204/shell-command-to-tar-directory-excluding-certain-files-folders
# https://stackoverflow.com/questions/18681595/tar-a-directory-but-dont-store-full-absolute-paths-in-the-archive
# https://www.gnu.org/software/tar/manual/html_section/tar_51.html#transform
# https://unix.stackexchange.com/questions/72661/show-sum-of-file-sizes-in-directory-listing
# https://www.gnu.org/software/tar/manual/html_section/tar_26.html#SEC48
# https://stackoverflow.com/questions/1951506/add-a-new-element-to-an-array-without-specifying-the-index-in-bash
# -----------------

init_colors
echo "KMD+AC bootstrap gen (c) Decker, 2019"
echo
log_print "Start making bootstrap for KMD/AC ..."

# https://stackoverflow.com/questions/18669756/bash-how-to-extract-data-from-a-column-in-csv-file-and-put-it-in-an-array

# you can fill coins array from your local assetchains.json file
# readarray -t kmd_coins < <(cat $HOME/komodo/src/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# or directly from jl777/komodo beta branch assetchains.json
readarray -t kmd_coins < <(curl -s https://raw.githubusercontent.com/jl777/komodo/beta/src/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
# you can spectify coins array manually if you want
# declare -a kmd_coins=(BEER PIZZA)
kmd_coins+=(KMD)
# printf '%s\n' "${kmd_coins[@]}"

# rm wallets.$(date -u +%Y%m%d).tar
for i in "${kmd_coins[@]}"
do
    bootstrap $i
    # walletbackup_mm $i
done

