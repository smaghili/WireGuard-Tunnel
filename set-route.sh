#!/bin/bash
server_ip="2.144.0.0"
if ! ip route show | grep -q "$server_ip"; then
    ./root/WireGuard-Tunnel/iran-route.sh.x
else
    echo "Route already exists. No action needed."
fi
if ! ip route show | grep -q "$1"; then
    ip route add $1 via $2 dev $3
else
    echo "Route already exists. No action needed."
fi
