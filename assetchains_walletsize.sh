#!/usr/bin/env bash
# Find out the size of KMD and other KMD assetchains

RESET="\033[0m"
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

function show_walletsize () {
  if [ "$1" != "KMD" ]; then
    if [ -f ~/.komodo/$1/wallet.dat ]; then

      # SIZE=$(stat ~/.komodo/$1/wallet.dat | grep -Po "Size: \d*" | cut -d" " -f2)
      # Pattern "Size: " - is only for english locale, so, we won't use it.

      SIZE=$(stat ~/.komodo/$1/wallet.dat | grep -Po "\d+" | head -1)
    else
      SIZE=0
    fi
  else
    SIZE=$(stat ~/.komodo/wallet.dat | grep -Po "\d+" | head -1)
  fi

  OUTSTR=$(echo $SIZE | numfmt --to=si --suffix=B)

  if [ "$SIZE" -gt "19922944" ]; then
    OUTSTR=${RED}$OUTSTR${RESET}
  else
    OUTSTR=${GREEN}$OUTSTR${RESET}
  fi

  printf "[%8s] %16b\n" $1 $OUTSTR
}

ignore_list=(
VOTE2018
PIZZA
BEER
)

show_walletsize KMD

# Only assetchains
${HOME}/komodo/src/listassetchains | while read list; do
  if [[ "${ignore_list[@]}" =~ "${list}" ]]; then
    continue
  fi
  show_walletsize $list
done
