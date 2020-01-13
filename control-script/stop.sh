#!/bin/sh
rm /.openvpn.running || exit

# stop openvpn daemon
killall openvpn

# reset iptables
iptables-restore /iptables.conf.relax