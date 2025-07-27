#!/bin/bash
# 🎯 Main configuration script for Debian Preseed setup
# 🔒 Enable strict mode for better error handling
set -xeu

echo "🚀 Starting Debian Preseed Configuration Script..."

USER=$(whoami)

if [[ "${USER}" != "root" ]]
then
    echo "👤 This will be executed for: ${USER}"
else
    USER=${SUDO_USER}
    echo "👤 This will be executed for: ${USER}"
fi

USER_HOME_FOLDER="/home/${USER}"

source ./user.sh
source ./systemctl.sh
source ./tailscale.sh
source ./get_base_network_info.sh
source ./virtualbox.sh 
source ./ghostty.sh

# Output Network Information
echo "🌐 Network Configuration Details:"
echo "🔌 Interface: $DEFAULT_IFACE"
echo "🌍 Full CIDR: $FULL_CIDR"
echo "🔗 Network CIDR: $NETWORK_CIDR"
echo "💻 Base Network: $BASE_NET"

IPV4_VALUE="${BASE_NET}.100"
IPV4_GATEWAY="${BASE_NET}.1"
IPV4_NETMASK="255.255.255.0"

source ./networking.sh

# # Clears crontab file
# sed -i '/@reboot/d' /etc/crontab

# timeshift --create --comments "Initial Backup" --tags D
# #timeshift --list
# #timeshift --restore

# reboot