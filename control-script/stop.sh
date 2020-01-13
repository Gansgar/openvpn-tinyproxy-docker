#!/bin/sh
rm /.openvpn.running || exit

# stop openvpn daemon
killall openvpn

# reset iptables
/control-script/reset-iptables.sh