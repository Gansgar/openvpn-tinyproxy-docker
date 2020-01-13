#!/bin/sh
LOG="/var/log/openvpn"

[ -e /.openvpn.running ] && exit

# store file that openvpn is running
touch /.openvpn.running

# generate config and setup iptables
/control-script/generate-config.sh &> "$LOG"

# setup openvpn
cd /openvpn/target
openvpn --config config.ovpn --daemon MAIN --log-append /var/log/openvpn

