#!/bin/sh

[ -e /.openvpn.running ] && exit

# store file that openvpn is running
touch /.openvpn.running

# setup iptables
iptables-restore /iptables.conf.strict

# setup openvpn
cd /openvpn/target
openvpn --config config.ovpn --daemon MAIN

