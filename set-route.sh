#!/bin/bash
server_ip="2.144.0.0"
if ! ip route show | grep -q "$server_ip"; then
    ./root/WireGuard-Tunnel/iran-route.sh.x
else
    echo "Route already exists. No action needed."
fi
