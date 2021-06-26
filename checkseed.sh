#!/usr/bin/env bash

# Copyright (c) 2020-2021 Decker <https://github.com/DeckerSU/komodo_scripts>
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


# seeder=seeds.komodoplatform.com # almost dead seeder, from 16 addresses return just one alive
# seeder=kmd.komodoseeds.com      # also almost dead, contains only 2 addresses
# seeder=static.kolo.supernet.org
# seeder=dynamic.kolo.supernet.org

seeder=seeds1.kmd.sh

#readarray -t nodeips < <(nslookup ${seeder} | grep "Address: " | awk '{print $2}' | sed 's/:[0-9]*[0-9]*[0-9]*[0-9]*//g' | sort)
readarray -t nodeips < <(host seeds1.kmd.sh | grep -Po "has address [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sed 's/has address//' | sort)

#nodeips=(5.9.102.210 78.47.196.146 178.63.69.164 88.198.65.74 5.9.122.241 144.76.94.38 89.248.166.91)

for ip in "${nodeips[@]}"
do
    # https://bitcointalk.org/index.php?topic=55852.0
    # https://en.bitcoin.it/wiki/Protocol_documentation#Message_structure
    # Newer protocol, # 18980200 - 170008 -> 1a980200 - 170010

    payload='1a980200010000000000000011b2d05000000000010000000000000000000000000000000000ffff000000000000000000000000000000000000000000000000ffff0000000000003b2eb35d8ce617650f2f5361746f7368693a302e372e322fc03e0300';
    payload_size=$((${#payload} / 2))
    payload_size_hex=$(printf "%08x" $payload_size | dd conv=swab 2> /dev/null | rev)
    payload_sha256d=$(echo -n $payload | xxd -r -p | sha256sum --binary | cut -d" " -f1 | xxd -r -p | sha256sum --binary | cut -d" " -f1)
    payload_checksum=${payload_sha256d:0:8}

    #message='f9eee48d76657273696f6e0000000000640000005cee709118980200010000000000000011b2d05000000000010000000000000000000000000000000000ffff000000000000000000000000000000000000000000000000ffff0000000000003b2eb35d8ce617650f2f5361746f7368693a302e372e322fc03e0300'
    message="f9eee48d76657273696f6e0000000000${payload_size_hex}${payload_checksum}${payload}"
    #echo -n "Checking ${ip} - "
    printf "Checking %15s - " ${ip}
    echo ${message} | xxd -r -p | nc -w 3 -q 3 ${ip} 7770 > pattern.txt
    if [ ! -s pattern.txt ]; then
        echo "failed!"
    else
        len=$(cat pattern.txt | xxd -p -s 0x68 -l 1)
        len=$((16#$len))

        ua=$(cat pattern.txt | xxd -p -s 0x69 -l $len | xxd -r -p)
        echo $ua
    fi
done
