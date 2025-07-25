#!/bin/bash
# 🔍 Network information detection script
# 🔒 Enable strict mode for better error handling
set -xeu

echo "🔍 Starting network detection..."
# 🌐 Get default network interface
DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}')

# Get full CIDR (e.g., 192.168.1.100/24)
FULL_CIDR=$(ip -o -f inet addr show "$DEFAULT_IFACE" | awk '{print $4}')

# Extract IP and prefix
IP=$(echo "$FULL_CIDR" | cut -d/ -f1)
PREFIX=$(echo "$FULL_CIDR" | cut -d/ -f2)

# Get base network (e.g., 192.168.1.0/24)
IFS='.' read -r o1 o2 o3 o4 <<< "$IP"
NETWORK_CIDR="${o1}.${o2}.${o3}.0/${PREFIX}"

# Extract base net (e.g., 192.168.1)
BASE_NET="${o1}.${o2}.${o3}"

# Output
# echo "Interface: $DEFAULT_IFACE"
# echo "Full CIDR: $FULL_CIDR"
# echo "Network CIDR: $NETWORK_CIDR"
# echo "BASE_NET: $BASE_NET"