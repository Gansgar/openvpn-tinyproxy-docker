#!/bin/sh

source /control-script/helper.sh

PROTOCOL=$(grep proto /openvpn/configs/$FILE | tr -s ' ' | cut -d' ' -f2)

############################################
# Reading chosen OpenVPN configuration
############################################
printf "[INFO] Reading OpenVPN configuration...\n"
CONNECTIONSTRING=$(grep -i "/openvpn/configs/$FILE" -e 'remote ')
exitOnError $?
PORT=$(echo $CONNECTIONSTRING | tr -s ' ' | cut -d' ' -f3)
if [ "$PORT" = "" ]; then
  printf "[WARNING] Using default port\n"
  PORT="1194"
fi
DOMAIN=$(echo $CONNECTIONSTRING | cut -d' ' -f2)
if [ "$DOMAIN" = "" ]; then
  printf "[ERROR] Domain not found in /openvpn/configs/$FILE\n"
  exit 1
fi
printf " * Port: $PORT\n"
printf " * Domain: $DOMAIN\n"
printf "[INFO] Detecting IP addresses corresponding to $DOMAIN...\n"
VPNIPS=$(nslookup $DOMAIN localhost | tail -n +3 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
exitOnError $?
for ip in $VPNIPS; do
  printf "   $ip\n";
done

############################################
# Writing target OpenVPN files
############################################
TARGET_PATH="/openvpn/target"
printf "[INFO] Creating target OpenVPN files in $TARGET_PATH..."
rm -rf $TARGET_PATH/*
cd "/openvpn/configs/"
if [ -d "keys/" ]; then
  cp "keys/*" "$TARGET_PATH/" 
  exitOnError $? "Cannot copy keys in keys/ to $TARGET_PATH"
fi
cp -f "$FILE" "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot copy $FILE file to $TARGET_PATH"
sed -i "/$CONNECTIONSTRING/d" "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot delete '$CONNECTIONSTRING' from $TARGET_PATH/config.ovpn"
sed -i '/resolv-retry/d' "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot delete 'resolv-retry' from $TARGET_PATH/config.ovpn"
for ip in $VPNIPS; do
  echo "remote $ip $PORT" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'remote $ip $PORT' to $TARGET_PATH/config.ovpn"
done
# Uses the username/password from this file to get the token from PIA
echo "auth-user-pass /auth.conf" >> "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot add 'auth-user-pass /auth.conf' to $TARGET_PATH/config.ovpn"
# Reconnects automatically on failure
echo "auth-retry nointeract" >> "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot add 'auth-retry nointeract' to $TARGET_PATH/config.ovpn"
# Prevents auth_failed infinite loops - make it interact? Remove persist-tun? nobind?
echo "pull-filter ignore \"auth-token\"" >> "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot add 'pull-filter ignore \"auth-token\"' to $TARGET_PATH/config.ovpn"
# Runs openvpn without root, as nonrootuser if specified
if [ "$NONROOT" = "yes" ]; then
  echo "user nonrootuser" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'user nonrootuser' to $TARGET_PATH/config.ovpn"
fi
echo "mute-replay-warnings" >> "$TARGET_PATH/config.ovpn"
exitOnError $? "Cannot add 'mute-replay-warnings' to $TARGET_PATH/config.ovpn"
# Note: TUN device re-opening will restart the container due to permissions
printf "DONE\n"

############################################
# NETWORKING
############################################
printf "[INFO] Finding network properties...\n"
printf " * Detecting default gateway..."
DEFAULT_GATEWAY=$(ip r | grep 'default via' | cut -d" " -f 3)
exitOnError $?
printf "$DEFAULT_GATEWAY\n"
printf " * Detecting local interface..."
INTERFACE=$(ip r | grep 'default via' | cut -d" " -f 5)
exitOnError $?
printf "$INTERFACE\n"
printf " * Detecting local subnet..."
SUBNET=$(ip r | grep -v 'default via' | grep $INTERFACE | tail -n 1 | cut -d" " -f 1)
exitOnError $?
printf "$SUBNET\n"
for EXTRASUBNET in ${EXTRA_SUBNETS//,/ }
do
  printf " * Adding $EXTRASUBNET as route via $INTERFACE..."
  ip route add $EXTRASUBNET via $DEFAULT_GATEWAY dev $INTERFACE
  exitOnError $?
  printf "DONE\n"
done
printf " * Detecting target VPN interface..."
VPN_DEVICE=$(cat $TARGET_PATH/config.ovpn | grep 'dev ' | cut -d" " -f 2)0
exitOnError $?
printf "$VPN_DEVICE\n"


############################################
# FIREWALL
############################################
printf "[INFO] Setting firewall\n"
printf " * Blocking everyting\n"
printf "   * Deleting all iptables rules..."
iptables --flush
exitOnError $?
iptables --delete-chain
exitOnError $?
iptables -t nat --flush
exitOnError $?
iptables -t nat --delete-chain
exitOnError $?
printf "DONE\n"
printf "   * Block input traffic..."
iptables -P INPUT DROP
exitOnError $?
printf "DONE\n"
printf "   * Block output traffic..."
iptables -F OUTPUT
exitOnError $?
iptables -P OUTPUT DROP
exitOnError $?
printf "DONE\n"
printf "   * Block forward traffic..."
iptables -P FORWARD DROP
exitOnError $?
printf "DONE\n"

printf " * Creating general rules\n"
printf "   * Accept established and related input and output traffic..."
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
exitOnError $?
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
exitOnError $?
printf "DONE\n"
printf "   * Accept local loopback input and output traffic..."
iptables -A OUTPUT -o lo -j ACCEPT
exitOnError $?
iptables -A INPUT -i lo -j ACCEPT
exitOnError $?
printf "DONE\n"

printf " * Creating VPN rules\n"
for ip in $VPNIPS; do
  printf "   * Accept output traffic to VPN server $ip through $INTERFACE, port $PROTOCOL $PORT..."
  iptables -A OUTPUT -d $ip -o $INTERFACE -p $PROTOCOL -m $PROTOCOL --dport $PORT -j ACCEPT
  exitOnError $?
  printf "DONE\n"
done
printf "   * Accept all output traffic through $VPN_DEVICE..."
iptables -A OUTPUT -o $VPN_DEVICE -j ACCEPT
exitOnError $?
printf "DONE\n"

printf " * Creating local subnet rules\n"
printf "   * Accept input and output traffic to and from $SUBNET..."
iptables -A INPUT -s $SUBNET -d $SUBNET -j ACCEPT
iptables -A OUTPUT -s $SUBNET -d $SUBNET -j ACCEPT
printf "DONE\n"
for EXTRASUBNET in ${EXTRA_SUBNETS//,/ }
do
  printf "   * Accept input traffic through $INTERFACE from $EXTRASUBNET to $SUBNET..."
  iptables -A INPUT -i $INTERFACE -s $EXTRASUBNET -d $SUBNET -j ACCEPT
  exitOnError $?
  printf "DONE\n"
  # iptables -A OUTPUT -d $EXTRASUBNET -j ACCEPT
  # iptables -A OUTPUT -o $INTERFACE -s $SUBNET -d $EXTRASUBNET -j ACCEPT
done
