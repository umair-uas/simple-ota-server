#!/bin/bash
set -e

# Get the primary LAN IP (the one used for default route)
IP=$(ip -4 route get 1.1.1.1 | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

if [ -z "$IP" ]; then
    echo "ERROR: Could not determine LAN IP"
    exit 1
fi

echo "Publishing ota-gw.local -> $IP via host avahi"
exec avahi-publish -a -R ota-gw.local "$IP"
