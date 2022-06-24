#!/usr/bin/env bash

# get-kmd-address.sh - Bash Script to get KMD address via OpenSSL

# Copyright (c) 2021 Decker
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Requirements:
# sudo apt install base58 or install it manually from https://github.com/keis/base58

# Docs:
# https://stackoverflow.com/questions/48101258/how-to-convert-an-ecdsa-key-to-pem-format

# check to avoid unable to write 'random state' error
if [[ -f "$HOME/.rnd" ]]; then
    random_owner=$(stat --format '%U' $HOME/.rnd)
    if [[ "${random_owner}" == "root" ]]; then
        echo "Seems $HOME/.rnd owned by root ... remove it: sudo rm ~/.rnd" 1>&2
        exit
    fi
fi

pre_string="30740201010420"
pre_string_other="302e0201010420"
mid_string="a00706052b8104000aa144034200" # identifies secp256k1
secp256k1_oid_string="06052b8104000a"
# 06 05 2B 81 04 00 0A, https://thalesdocs.com/gphsm/luna/7/docs/network/Content/sdk/using/ecc_curve_cross-reference.htm

# openssl ecparam -genkey -name secp256k1 -rand /dev/urandom -outform DER > privkey.bin
# privkey_hex=$(cat privkey.bin | head -c 64 | xxd -p -c 64)
privkey_hex=$(openssl ecparam -genkey -name secp256k1 -rand /dev/urandom -outform DER 2>/dev/null | head -c 64 | xxd -p -c 64)

# DER could start from ${secp256k1_oid_string}${pre_string} or with just ${pre_string}, depends
# on OpenSSL version, so just need to extract privkey bettween ${pre_string}<PRIV>${mid_string}

# https://stackoverflow.com/questions/13242469/how-to-use-sed-grep-to-extract-text-between-two-words
privkey_hex=$(echo ${privkey_hex} | grep -Po "${pre_string}\K.*(?=${mid_string})")

if [ "${#privkey_hex}" -ne "64" ]; then
    echo "Error generating privkey ..." 1>&2
    exit
fi

echo "Privkey (hex): $privkey_hex (${#privkey_hex})"

# echo "${pre_string_other} ${privkey_hex} ${mid_string:0:18}" | xxd -r -p > privkey-der.bin
# openssl asn1parse -inform DER -in privkey.bin 
# openssl ec -inform DER < privkey-der.bin -text -noout -conv_form compressed
# openssl ec -inform DER < privkey-der.bin -pubout -conv_form compressed -outform DER > pubkey-der.bin
# pubkey_hex=$(cat pubkey-der.bin | xxd -p -c 56)

pubkey_hex=$(openssl ec -inform DER -in <(echo "${pre_string_other} ${privkey_hex} ${mid_string:0:18}" | xxd -r -p) -pubout -conv_form compressed -outform DER 2>/dev/null | xxd -p -c 56)
pubkey_hex=$(echo $pubkey_hex | sed 's/3036301006072a8648ce3d020106052b8104000a032200//')
if [ "${#pubkey_hex}" -ne "66" ]; then
    echo "Error obtaining pubkey ..." 1>&2
    exit
fi
echo " Pubkey (hex): ${pubkey_hex} (${#pubkey_hex})"

network_byte_hex="3c" #  60 (dec) KMD (Komodo)
secret_key_hex="bc"   # 188 (dec) KMD (Komodo)

# test the case in which rmd160 ends with 00 (!)
# pubkey=036da5d2956e8fdaee1988aa5957e456e58fcf41793a36cd2db7471cda3a4c5caa, rmd160=bf7fd8eaf542d4578708242010e5feb1c3672900

hash160_hex=$(echo -n "${pubkey_hex}" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -rmd160 -binary | xxd -p -c 20)
if [ "${#hash160_hex}" -ne "40" ]; then
    echo "Error obtaining rmd-160 ..." 1>&2
    exit
fi
echo "rmd-160 (hex): $hash160_hex (${#hash160_hex})"
checksum_hex=$(echo -n "${network_byte_hex}${hash160_hex}" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | xxd -p -c 32)
address=$(echo -n "${network_byte_hex}${hash160_hex}${checksum_hex:0:8}" | xxd -r -p | base58)
echo "      Address: ${address}"

wif_checksum_hex=$(echo -n "${secret_key_hex}${privkey_hex}01" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | xxd -p -c 32)
wif=$(echo -n "${secret_key_hex}${privkey_hex}01${wif_checksum_hex:0:8}" | xxd -r -p | base58)
echo "          WIF: ${wif}"

# uncomment the lines below if you have qrencode installed and want to generate
# QR code for address as well
# echo
# qrencode -t ANSIUTF8 ${address}

