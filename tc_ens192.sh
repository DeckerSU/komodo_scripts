#!/usr/bin/env bash
#
# Copyright (c) 2017 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
#
# Copyright (c) 2021 Decker
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

export LC_ALL=C

#network interface on which to limit traffic
IF="ens192"
#limit of the network interface in question
LINKCEIL="100Mbit" # 1gbit
#limit outbound protocol traffic to this rate

# 1 Mbit/s = 125 Kb/s (1 Mbps = 0.125 MB/s)
# 2 Mbit/s = 250 Kb/s (2 Mbps = 0.25 MB/s)

LIMIT="1Mbit" 

#delete existing rules
sudo /sbin/tc qdisc del dev ${IF} root

#add root class
sudo /sbin/tc qdisc add dev ${IF} root handle 1: htb default 10

#add parent class
sudo /sbin/tc class add dev ${IF} parent 1: classid 1:1 htb rate ${LINKCEIL} ceil ${LINKCEIL}

#add our two classes. one unlimited, another limited
sudo /sbin/tc class add dev ${IF} parent 1:1 classid 1:10 htb rate ${LINKCEIL} ceil ${LINKCEIL} prio 0
sudo /sbin/tc class add dev ${IF} parent 1:1 classid 1:11 htb rate ${LIMIT} ceil ${LIMIT} prio 1

# IPv4: add handles to our classes so packets marked with <x> go into the class with "... handle <x> fw ..."
sudo /sbin/tc filter add dev ${IF} parent 1: protocol ip prio 1 handle 1 fw classid 1:10
sudo /sbin/tc filter add dev ${IF} parent 1: protocol ip prio 2 handle 2 fw classid 1:11
# IPv6: same for IPv6 
sudo /sbin/tc filter add dev ${IF} parent 1: protocol ipv6 prio 3 handle 1 fw classid 1:10
sudo /sbin/tc filter add dev ${IF} parent 1: protocol ipv6 prio 4 handle 2 fw classid 1:11

# https://linux.die.net/man/8/tc
# repclace: sudo /sbin/tc class repclace dev ${IF} parent 1:1 classid 1:11 htb rate ${LIMIT} ceil ${LIMIT} prio 1
# sudo tc qdisc show dev ${IF}
# sudo tc class show dev ${IF}
# sudo tc filter show dev ${IF}

# limit outgoing traffic to and from port 80. but not when dealing with a host on the local network
#
#   --set-mark marks packages matching these criteria with the number "2" (v4)
#   --set-mark marks packages matching these criteria with the number "4" (v6)
#   these packets are filtered by the tc filter with "handle 2"
#   this filter sends the packages into the 1:11 class, and this class is limited to ${LIMIT}

# KMD mangle rules
# sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 7770 -j MARK --set-mark 0x2 -m comment --comment "KMD IPv4 mark to" 
# sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 7770 -j MARK --set-mark 0x2 -m comment --comment "KMD IPv4 mark from"
# sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 7770 -j MARK --set-mark 0x4 -m comment --comment "KMD IPv6 mark to" 
# sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 7770 -j MARK --set-mark 0x4 -m comment --comment "KMD IPv6 mark from" 

# BET mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 14249 -j MARK --set-mark 0x2 -m comment --comment "BET IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 14249 -j MARK --set-mark 0x2 -m comment --comment "BET IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 14249 -j MARK --set-mark 0x4 -m comment --comment "BET IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 14249 -j MARK --set-mark 0x4 -m comment --comment "BET IPv6 mark from"
# BOTS mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 11963 -j MARK --set-mark 0x2 -m comment --comment "BOTS IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 11963 -j MARK --set-mark 0x2 -m comment --comment "BOTS IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 11963 -j MARK --set-mark 0x4 -m comment --comment "BOTS IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 11963 -j MARK --set-mark 0x4 -m comment --comment "BOTS IPv6 mark from"
# CCL mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 20848 -j MARK --set-mark 0x2 -m comment --comment "CCL IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 20848 -j MARK --set-mark 0x2 -m comment --comment "CCL IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 20848 -j MARK --set-mark 0x4 -m comment --comment "CCL IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 20848 -j MARK --set-mark 0x4 -m comment --comment "CCL IPv6 mark from"
# CRYPTO mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 8515 -j MARK --set-mark 0x2 -m comment --comment "CRYPTO IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 8515 -j MARK --set-mark 0x2 -m comment --comment "CRYPTO IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 8515 -j MARK --set-mark 0x4 -m comment --comment "CRYPTO IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 8515 -j MARK --set-mark 0x4 -m comment --comment "CRYPTO IPv6 mark from"
# DEX mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 11889 -j MARK --set-mark 0x2 -m comment --comment "DEX IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 11889 -j MARK --set-mark 0x2 -m comment --comment "DEX IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 11889 -j MARK --set-mark 0x4 -m comment --comment "DEX IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 11889 -j MARK --set-mark 0x4 -m comment --comment "DEX IPv6 mark from"
# GLEEC mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 23225 -j MARK --set-mark 0x2 -m comment --comment "GLEEC IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 23225 -j MARK --set-mark 0x2 -m comment --comment "GLEEC IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 23225 -j MARK --set-mark 0x4 -m comment --comment "GLEEC IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 23225 -j MARK --set-mark 0x4 -m comment --comment "GLEEC IPv6 mark from"
# HODL mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 14430 -j MARK --set-mark 0x2 -m comment --comment "HODL IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 14430 -j MARK --set-mark 0x2 -m comment --comment "HODL IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 14430 -j MARK --set-mark 0x4 -m comment --comment "HODL IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 14430 -j MARK --set-mark 0x4 -m comment --comment "HODL IPv6 mark from"
# ILN mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 12985 -j MARK --set-mark 0x2 -m comment --comment "ILN IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 12985 -j MARK --set-mark 0x2 -m comment --comment "ILN IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 12985 -j MARK --set-mark 0x4 -m comment --comment "ILN IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 12985 -j MARK --set-mark 0x4 -m comment --comment "ILN IPv6 mark from"
# JUMBLR mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 15105 -j MARK --set-mark 0x2 -m comment --comment "JUMBLR IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 15105 -j MARK --set-mark 0x2 -m comment --comment "JUMBLR IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 15105 -j MARK --set-mark 0x4 -m comment --comment "JUMBLR IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 15105 -j MARK --set-mark 0x4 -m comment --comment "JUMBLR IPv6 mark from"
# KOIN mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 10701 -j MARK --set-mark 0x2 -m comment --comment "KOIN IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 10701 -j MARK --set-mark 0x2 -m comment --comment "KOIN IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 10701 -j MARK --set-mark 0x4 -m comment --comment "KOIN IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 10701 -j MARK --set-mark 0x4 -m comment --comment "KOIN IPv6 mark from"
# MESH mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 9454 -j MARK --set-mark 0x2 -m comment --comment "MESH IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 9454 -j MARK --set-mark 0x2 -m comment --comment "MESH IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 9454 -j MARK --set-mark 0x4 -m comment --comment "MESH IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 9454 -j MARK --set-mark 0x4 -m comment --comment "MESH IPv6 mark from"
# MGW mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 12385 -j MARK --set-mark 0x2 -m comment --comment "MGW IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 12385 -j MARK --set-mark 0x2 -m comment --comment "MGW IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 12385 -j MARK --set-mark 0x4 -m comment --comment "MGW IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 12385 -j MARK --set-mark 0x4 -m comment --comment "MGW IPv6 mark from"
# MORTY mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 16347 -j MARK --set-mark 0x2 -m comment --comment "MORTY IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 16347 -j MARK --set-mark 0x2 -m comment --comment "MORTY IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 16347 -j MARK --set-mark 0x4 -m comment --comment "MORTY IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 16347 -j MARK --set-mark 0x4 -m comment --comment "MORTY IPv6 mark from"
# MSHARK mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 8845 -j MARK --set-mark 0x2 -m comment --comment "MSHARK IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 8845 -j MARK --set-mark 0x2 -m comment --comment "MSHARK IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 8845 -j MARK --set-mark 0x4 -m comment --comment "MSHARK IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 8845 -j MARK --set-mark 0x4 -m comment --comment "MSHARK IPv6 mark from"
# NINJA mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 8426 -j MARK --set-mark 0x2 -m comment --comment "NINJA IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 8426 -j MARK --set-mark 0x2 -m comment --comment "NINJA IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 8426 -j MARK --set-mark 0x4 -m comment --comment "NINJA IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 8426 -j MARK --set-mark 0x4 -m comment --comment "NINJA IPv6 mark from"
# PANGEA mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 14067 -j MARK --set-mark 0x2 -m comment --comment "PANGEA IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 14067 -j MARK --set-mark 0x2 -m comment --comment "PANGEA IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 14067 -j MARK --set-mark 0x4 -m comment --comment "PANGEA IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 14067 -j MARK --set-mark 0x4 -m comment --comment "PANGEA IPv6 mark from"
# PIRATE mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 45452 -j MARK --set-mark 0x2 -m comment --comment "PIRATE IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 45452 -j MARK --set-mark 0x2 -m comment --comment "PIRATE IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 45452 -j MARK --set-mark 0x4 -m comment --comment "PIRATE IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 45452 -j MARK --set-mark 0x4 -m comment --comment "PIRATE IPv6 mark from"
# REVS mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 10195 -j MARK --set-mark 0x2 -m comment --comment "REVS IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 10195 -j MARK --set-mark 0x2 -m comment --comment "REVS IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 10195 -j MARK --set-mark 0x4 -m comment --comment "REVS IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 10195 -j MARK --set-mark 0x4 -m comment --comment "REVS IPv6 mark from"
# RICK mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 25434 -j MARK --set-mark 0x2 -m comment --comment "RICK IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 25434 -j MARK --set-mark 0x2 -m comment --comment "RICK IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 25434 -j MARK --set-mark 0x4 -m comment --comment "RICK IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 25434 -j MARK --set-mark 0x4 -m comment --comment "RICK IPv6 mark from"
# SUPERNET mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 11340 -j MARK --set-mark 0x2 -m comment --comment "SUPERNET IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 11340 -j MARK --set-mark 0x2 -m comment --comment "SUPERNET IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 11340 -j MARK --set-mark 0x4 -m comment --comment "SUPERNET IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 11340 -j MARK --set-mark 0x4 -m comment --comment "SUPERNET IPv6 mark from"
# THC mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 36789 -j MARK --set-mark 0x2 -m comment --comment "THC IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 36789 -j MARK --set-mark 0x2 -m comment --comment "THC IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 36789 -j MARK --set-mark 0x4 -m comment --comment "THC IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 36789 -j MARK --set-mark 0x4 -m comment --comment "THC IPv6 mark from"
# ZILLA mangle rules
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --dport 10040 -j MARK --set-mark 0x2 -m comment --comment "ZILLA IPv4 mark to"
sudo /sbin/iptables -t mangle -A OUTPUT -p tcp -m tcp --sport 10040 -j MARK --set-mark 0x2 -m comment --comment "ZILLA IPv4 mark from"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --dport 10040 -j MARK --set-mark 0x4 -m comment --comment "ZILLA IPv6 mark to"
sudo /sbin/ip6tables -t mangle -A OUTPUT -p tcp -m tcp --sport 10040 -j MARK --set-mark 0x4 -m comment --comment "ZILLA IPv6 mark from"

# to remove mangle iptables rule, use the following:
# sudo /sbin/iptables -t mangle -L -v --line-numbers # list mangle rules
# sudo /sbin/iptables -t mangle -D OUTPUT 1 # delete mangle rule number 1
# sudo iptables -t mangle -F OUTPUT # clear entire mangle table

#sudo ufw allow 14249/tcp comment 'BET p2p port'
#sudo ufw allow 11963/tcp comment 'BOTS p2p port'
#sudo ufw allow 20848/tcp comment 'CCL p2p port'
#sudo ufw allow 8515/tcp comment 'CRYPTO p2p port'
#sudo ufw allow 11889/tcp comment 'DEX p2p port'
#sudo ufw allow 23225/tcp comment 'GLEEC p2p port'
#sudo ufw allow 14430/tcp comment 'HODL p2p port'
#sudo ufw allow 12985/tcp comment 'ILN p2p port'
#sudo ufw allow 15105/tcp comment 'JUMBLR p2p port'
#sudo ufw allow 10701/tcp comment 'KOIN p2p port'
#sudo ufw allow 9454/tcp comment 'MESH p2p port'
#sudo ufw allow 12385/tcp comment 'MGW p2p port'
#sudo ufw allow 16347/tcp comment 'MORTY p2p port'
#sudo ufw allow 8845/tcp comment 'MSHARK p2p port'
#sudo ufw allow 8426/tcp comment 'NINJA p2p port'
#sudo ufw allow 14067/tcp comment 'PANGEA p2p port'
#sudo ufw allow 45452/tcp comment 'PIRATE p2p port'
#sudo ufw allow 10195/tcp comment 'REVS p2p port'
#sudo ufw allow 25434/tcp comment 'RICK p2p port'
#sudo ufw allow 11340/tcp comment 'SUPERNET p2p port'
#sudo ufw allow 36789/tcp comment 'THC p2p port'
#sudo ufw allow 10040/tcp comment 'ZILLA p2p port'
