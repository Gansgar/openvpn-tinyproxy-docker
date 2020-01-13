#!/bin/sh

source /control-script/helper.sh

printf " =========================================\n"
printf " =========================================\n"
printf " ============= PIA CONTAINER =============\n"
printf " =========================================\n"
printf " =========================================\n"
printf " = by github.com/gansgar - G. Friedrich ==\n\n"

printf "OpenVPN version: $(openvpn --version | head -n 1 | grep -oE "OpenVPN [0-9\.]* " | cut -d" " -f2)\n"
printf "Unbound version: $(unbound -h | grep "Version" | cut -d" " -f2)\n"
printf "Iptables version: $(iptables --version | cut -d" " -f2)\n"
printf "TinyProxy version: $(tinyproxy -v | cut -d" " -f2)\n"
printf "ShadowSocks version: $(ss-server --help | head -n 2 | tail -n 1 | cut -d" " -f 2)\n"
printf "NPM version: $(npm --version)\n"
printf "Node version: $(node --version)\n"

############################################
# BACKWARD COMPATIBILITY PARAMETERS
############################################
if [ -z $TINYPROXY ] && [ ! -z $PROXY ]; then
  TINYPROXY=$PROXY
fi
if [ -z $TINYPROXY_LOG ] && [ ! -z $PROXY_LOG_LEVEL ]; then
  TINYPROXY_LOG=$PROXY_LOG_LEVEL
fi
if [ -z $TINYPROXY_PORT ] && [ ! -z $PROXY_PORT ]; then
  TINYPROXY_PORT=$PROXY_PORT
fi
if [ -z $TINYPROXY_USER ] && [ ! -z $PROXY_USER ]; then
  TINYPROXY_USER=$PROXY_USER
fi
if [ -z $TINYPROXY_PASSWORD ] && [ ! -z $PROXY_PASSWORD ]; then
  TINYPROXY_PASSWORD=$PROXY_PASSWORD
fi

############################################
# CHECK PARAMETERS
############################################
exitIfUnset USER
exitIfUnset PASSWORD
exitIfUnset FILE
exitIfNotIn NONROOT "yes,no"
cat "/openvpn/configs/$FILE" &> /dev/null
exitOnError $? "/openvpn/configs/$FILE is not accessible"
PROTOCOL=$(grep proto /openvpn/configs/$FILE | tr -s ' ' | cut -d' ' -f2)

for EXTRA_SUBNET in ${EXTRA_SUBNETS//,/ }; do
  if [ $(echo "$EXTRA_SUBNET" | grep -Eo '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-2]?[0-9])|([3]?[0-1]))?$') = "" ]; then
    printf "Extra subnet $EXTRA_SUBNET is not a valid IPv4 subnet of the form 255.255.255.255/31 or 255.255.255.255\n"
    exit 1
  fi
done
exitIfNotIn DOT "on,off"
exitIfNotIn BLOCK_MALICIOUS "on,off"
exitIfNotIn BLOCK_NSA "on,off"
if [ "$DOT" == "off" ]; then
  if [ "$BLOCK_MALICIOUS" == "on" ]; then
    printf "DOT is off so BLOCK_MALICIOUS cannot be on\n"
    exit 1
  elif [ "$BLOCK_NSA" == "on" ]; then
    printf "DOT is off so BLOCK_NSA cannot be on\n"
    exit 1
  fi
fi
exitIfNotIn TINYPROXY "on,off"
if [ "$TINYPROXY" == "on" ]; then
  exitIfNotIn TINYPROXY_LOG "Info,Warning,Error,Critical"
  if [ -z $TINYPROXY_PORT ]; then
    TINYPROXY_PORT=8888
  fi
  if [ `echo $TINYPROXY_PORT | grep -E "^[0-9]+$"` != $TINYPROXY_PORT ]; then
    printf "TINYPROXY_PORT is not a valid number\n"
    exit 1
  elif [ $TINYPROXY_PORT -lt 1024 ]; then
    printf "TINYPROXY_PORT cannot be a privileged port under port 1024\n"
    exit 1
  elif [ $TINYPROXY_PORT -gt 65535 ]; then
    printf "TINYPROXY_PORT cannot be a port higher than the maximum port 65535\n"
    exit 1
  fi
  if [ ! -z "$TINYPROXY_USER" ] && [ -z "$TINYPROXY_PASSWORD" ]; then
    printf "TINYPROXY_USER is set but TINYPROXY_PASSWORD is not set\n"
    exit 1
  elif [ -z "$TINYPROXY_USER" ] && [ ! -z "$TINYPROXY_PASSWORD" ]; then
    printf "TINYPROXY_USER is not set but TINYPROXY_PASSWORD is set\n"
    exit 1
  fi
fi
exitIfNotIn SHADOWSOCKS "on,off"
if [ "$SHADOWSOCKS" == "on" ]; then
  exitIfNotIn SHADOWSOCKS "on,off"
  if [ -z $SHADOWSOCKS_PORT ]; then
    SHADOWSOCKS_PORT=8388
  fi
  if [ `echo $SHADOWSOCKS_PORT | grep -E "^[0-9]+$"` != $SHADOWSOCKS_PORT ]; then
    printf "SHADOWSOCKS_PORT is not a valid number\n"
    exit 1
  elif [ $SHADOWSOCKS_PORT -lt 1024 ]; then
    printf "SHADOWSOCKS_PORT cannot be a privileged port under port 1024\n"
    exit 1
  elif [ $SHADOWSOCKS_PORT -gt 65535 ]; then
    printf "SHADOWSOCKS_PORT cannot be a port higher than the maximum port 65535\n"
    exit 1
  fi
  if [ -z $SHADOWSOCKS_PASSWORD ]; then
    printf "SHADOWSOCKS_PASSWORD is not set\n"
    exit 1
  fi
fi

############################################
# SHOW PARAMETERS
############################################
printf "\n"
printf "OpenVPN parameters:\n"
printf " * File: $FILE\n"
printf " * Protocol: $PROTOCOL\n"
printf " * Running without root: $NONROOT\n"
printf "DNS over TLS:\n"
printf " * Activated: $DOT\n"
if [ "$DOT" = "on" ]; then
  printf " * Malicious hostnames DNS blocking: $BLOCK_MALICIOUS\n"
  printf " * NSA related DNS blocking: $BLOCK_NSA\n"
  printf " * Unblocked hostnames: $UNBLOCK\n"
fi
printf "Local network parameters:\n"
printf " * Extra subnets: $EXTRA_SUBNETS\n"
printf " * Tinyproxy HTTP proxy: $TINYPROXY\n"
if [ "$TINYPROXY" == "on" ]; then
  printf " * Tinyproxy port: $TINYPROXY_PORT\n"
  tinyproxy_auth=yes
  if [ -z $TINYPROXY_USER ]; then
    tinyproxy_auth=no
  fi
  printf " * Tinyproxy has authentication: $tinyproxy_auth\n"
  unset -v tinyproxy_auth
fi
printf " * ShadowSocks SOCKS5 proxy: $SHADOWSOCKS\n"
printf "\n"

#####################################################
# Writes to protected file and remove USER, PASSWORD
#####################################################
if [ -f /auth.conf ]; then
  printf "[INFO] /auth.conf already exists\n"
else
  printf "[INFO] Writing USER and PASSWORD to protected file /auth.conf..."
  echo "$USER" > /auth.conf
  exitOnError $?
  echo "$PASSWORD" >> /auth.conf
  exitOnError $?
  chown nonrootuser /auth.conf
  exitOnError $?
  chmod 400 /auth.conf
  exitOnError $?
  printf "DONE\n"
  printf "[INFO] Clearing environment variables USER and PASSWORD..."
  unset -v USER
  unset -v PASSWORD
  printf "DONE\n"
fi

############################################
# CHECK FOR TUN DEVICE
############################################
if [ "$(cat /dev/net/tun 2>&1 /dev/null)" != "cat: read error: File descriptor in bad state" ]; then
  printf "[WARNING] TUN device is not available, creating it..."
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  exitOnError $?
  chmod 0666 /dev/net/tun
  printf "DONE\n"
fi

############################################
# BLOCKING MALICIOUS HOSTNAMES AND IPs WITH UNBOUND
############################################
if [ "$DOT" == "on" ]; then
  rm -f /etc/unbound/blocks-malicious.conf
  if [ "$BLOCK_MALICIOUS" = "on" ]; then
    tar -xjf /etc/unbound/blocks-malicious.bz2 -C /etc/unbound/
    printf "[INFO] $(cat /etc/unbound/blocks-malicious.conf | grep "local-zone" | wc -l ) malicious hostnames and $(cat /etc/unbound/blocks-malicious.conf | grep "private-address" | wc -l) malicious IP addresses blacklisted\n"
  else
    echo "" > /etc/unbound/blocks-malicious.conf
  fi
  if [ "$BLOCK_NSA" = "on" ]; then
    tar -xjf /etc/unbound/blocks-nsa.bz2 -C /etc/unbound/
    printf "[INFO] $(cat /etc/unbound/blocks-nsa.conf | grep "local-zone" | wc -l ) NSA hostnames blacklisted\n"
    cat /etc/unbound/blocks-nsa.conf >> /etc/unbound/blocks-malicious.conf
    rm /etc/unbound/blocks-nsa.conf
    sort -u -o /etc/unbound/blocks-malicious.conf /etc/unbound/blocks-malicious.conf
  fi
  for hostname in ${UNBLOCK//,/ }
  do
    printf "[INFO] Unblocking hostname $hostname\n"
    sed -i "/$hostname/d" /etc/unbound/blocks-malicious.conf
  done
fi

############################################
# SETTING DNS OVER TLS TO 1.1.1.1 / 1.0.0.1
############################################
if [ "$DOT" == "on" ]; then
  printf "[INFO] Launching Unbound to connect to Cloudflare DNS 1.1.1.1 over TLS..."
  unbound
  exitOnError $?
  printf "DONE\n"
  printf "[INFO] Changing DNS to localhost..."
  printf "`sed '/^nameserver /d' /etc/resolv.conf`\nnameserver 127.0.0.1\n" > /etc/resolv.conf
  exitOnError $?
  printf "DONE\n"
fi

# testing config generation
/control-script/generate-config.sh
# reseting iptables
/control-script/reset-iptables.sh

############################################
# TINYPROXY LAUNCH
############################################
if [ "$TINYPROXY" == "on" ]; then
  printf "[INFO] Setting TinyProxy log level to $TINYPROXY_LOG..."
  sed -i "/LogLevel /c\LogLevel $TINYPROXY_LOG" /etc/tinyproxy/tinyproxy.conf
  exitOnError $?
  printf "DONE\n"
  printf "[INFO] Setting TinyProxy port to $TINYPROXY_PORT..."
  sed -i "/Port /c\Port $TINYPROXY_PORT" /etc/tinyproxy/tinyproxy.conf
  exitOnError $?
  printf "DONE\n"
  if [ ! -z "$TINYPROXY_USER" ]; then
    printf "[INFO] Setting TinyProxy credentials..."
    echo "BasicAuth $TINYPROXY_USER $TINYPROXY_PASSWORD" >> /etc/tinyproxy/tinyproxy.conf
    unset -v TINYPROXY_USER
    unset -v TINYPROXY_PASSWORD
    printf "DONE\n"
  fi
  tinyproxy -d &
fi

############################################
# SHADOWSOCKS
############################################
if [ "$SHADOWSOCKS" == "on" ]; then
  ARGS="-c /etc/shadowsocks.json"
  if [ "$SHADOWSOCKS_LOG" == " on" ]; then
    printf "[INFO] Setting ShadowSocks logging..."
    ARGS="$ARGS -v"
    printf "DONE\n"
  fi
  printf "[INFO] Setting ShadowSocks port to $SHADOWSOCKS_PORT..."
  jq ".port_password = {\"$SHADOWSOCKS_PORT\":\"\"}" /etc/shadowsocks.json > /tmp/shadowsocks.json && mv /tmp/shadowsocks.json /etc/shadowsocks.json
  exitOnError $?
  printf "DONE\n"
  printf "[INFO] Setting ShadowSocks password..."
  jq ".port_password[\"$SHADOWSOCKS_PORT\"] = \"$SHADOWSOCKS_PASSWORD\"" /etc/shadowsocks.json > /tmp/shadowsocks.json && mv /tmp/shadowsocks.json /etc/shadowsocks.json
  exitOnError $?
  printf "DONE\n"
  ARGS="$ARGS -s `jq --raw-output '.server' /etc/shadowsocks.json`"
  unset -v SERVER
  ARGS="$ARGS -p $SHADOWSOCKS_PORT"
  ARGS="$ARGS -k $SHADOWSOCKS_PASSWORD"
  ss-server $ARGS &
  unset -v ARGS
fi

############################################
# OPENVPN LAUNCH
############################################
# printf "[INFO] Launching OpenVPN\n"
# cd "$TARGET_PATH"
# openvpn --config config.ovpn "$@"
# status=$?
# printf "\n =========================================\n"
# printf " OpenVPN exit with status $status\n"
# printf " =========================================\n\n"
# 
# while true; do sleep 1; done

cd /usr/src/app
node src/server.js