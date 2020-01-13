ARG NODE_VERSION=10

FROM node:${NODE_VERSION}-alpine
ARG VERSION
ARG BUILD_DATE
ARG VCS_REF
LABEL \
    org.opencontainers.image.authors="quentin.mcgaw@gmail.com,georg.a.friedrich@gmail.com" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="OpenVPN Proxy client" \
    org.opencontainers.image.description="VPN client to tunnel to private internet access servers using OpenVPN, IPtables, DNS over TLS and Alpine Linux"
ENV USER= \
    PASSWORD= \
    FILE="us-netflix.ovpn" \
    NONROOT=yes \
    DOT=on \
    BLOCK_MALICIOUS=off \
    BLOCK_NSA=off \
    UNBLOCK= \
    EXTRA_SUBNETS= \
    TINYPROXY=on \
    TINYPROXY_LOG=Critical \
    TINYPROXY_PORT=8888 \
    TINYPROXY_USER= \
    TINYPROXY_PASSWORD= \
    SHADOWSOCKS=off \
    SHADOWSOCKS_LOG=on \
    SHADOWSOCKS_PORT=8388 \
    SHADOWSOCKS_PASSWORD= \
    TZ=

EXPOSE 8888/tcp 8388/tcp 8388/udp
HEALTHCHECK --interval=3m --timeout=3s --start-period=20s --retries=1 CMD /healthcheck.sh

# Install vpn

RUN apk add -q --progress --no-cache --update openvpn wget ca-certificates iptables unbound tinyproxy curl jq tzdata && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk add -q --progress --no-cache --update shadowsocks-libev && \
    mkdir -p /openvpn/target && \
    rm -rf /*.zip /var/cache/apk/* /etc/unbound/* /usr/sbin/unbound-anchor /usr/sbin/unbound-checkconf /usr/sbin/unbound-control /usr/sbin/unbound-control-setup /usr/sbin/unbound-host /etc/tinyproxy/tinyproxy.conf && \
    adduser nonrootuser -D -H --uid 1001 && \
    wget -q https://raw.githubusercontent.com/qdm12/files/master/named.root.updated -O /etc/unbound/root.hints && \
    wget -q https://raw.githubusercontent.com/qdm12/files/master/root.key.updated -O /etc/unbound/root.key && \
    cd /tmp && \
    wget -q https://raw.githubusercontent.com/qdm12/files/master/malicious-hostnames.updated -O malicious-hostnames && \
    wget -q https://raw.githubusercontent.com/qdm12/files/master/surveillance-hostnames.updated -O nsa-hostnames && \
    wget -q https://raw.githubusercontent.com/qdm12/files/master/malicious-ips.updated -O malicious-ips && \
    while read hostname; do echo "local-zone: \""$hostname"\" static" >> blocks-malicious.conf; done < malicious-hostnames && \
    while read ip; do echo "private-address: $ip" >> blocks-malicious.conf; done < malicious-ips && \
    tar -cjf /etc/unbound/blocks-malicious.bz2 blocks-malicious.conf && \
    while read hostname; do echo "local-zone: \""$hostname"\" static" >> blocks-nsa.conf; done < nsa-hostnames && \
    tar -cjf /etc/unbound/blocks-nsa.bz2 blocks-nsa.conf && \
    rm -f /tmp/*
COPY unbound.conf /etc/unbound/unbound.conf
COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY shadowsocks.json /etc/shadowsocks.json
COPY entrypoint.sh healthcheck.sh /
RUN chown nonrootuser -R /etc/unbound /etc/tinyproxy && \
    chmod 700 /etc/unbound /etc/tinyproxy && \
    chmod 600 /etc/unbound/unbound.conf /etc/tinyproxy/tinyproxy.conf /etc/shadowsocks.json && \
    chmod 500 /entrypoint.sh /healthcheck.sh && \
    chmod 400 /etc/unbound/root.hints /etc/unbound/root.key /etc/unbound/*.bz2

# install npm
WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install && mkdir src
COPY src ./src

# run and stop script
COPY control-script /control-script
RUN chown nonrootuser -R /control-script && \
    chmod 700 -R /control-script

# startup cmd
EXPOSE 8080
ENTRYPOINT /entrypoint.sh