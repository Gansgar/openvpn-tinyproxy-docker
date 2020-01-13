#!/bin/sh

source /control-script/helper.sh

# reset iptables
iptables -F
exitOnError $?
iptables --delete-chain
exitOnError $?
iptables -t nat -F
exitOnError $?
iptables -t nat --delete-chain
exitOnError $?
iptables -P OUTPUT ACCEPT
exitOnError $?
iptables -P INPUT ACCEPT
exitOnError $?
iptables -P FORWARD ACCEPT
exitOnError $?