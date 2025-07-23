#!/bin/bash
set -xeu

USER=$(whoami)

if [[ "${USER}" != "root" ]]
then
    echo "This will be executed for: ${USER}"
else
    USER=${SUDO_USER}
    echo "This will be executed for: ${USER}"
fi

USER_HOME_FOLDER="/home/${USER}"

source ./user.sh

source ./get_base_network_info.sh

# Output
echo "Interface: $DEFAULT_IFACE"
echo "Full CIDR: $FULL_CIDR"
echo "Network CIDR: $NETWORK_CIDR"
echo "BASE_NET: $BASE_NET"

IPV4_VALUE="${BASE_NET}.100"
IPV4_GATEWAY="${BASE_NET}.1"
IPV4_NETMASK="255.255.255.0"

IPV6_TARGET_VALUE="2804:32b0:1000:20::/64"
IPV6_VALUE="2804:d41::/32"
source ./networking.sh

# Clears crontab file
sed -i '/@reboot/d' /etc/crontab

timeshift --create --comments "Initial Backup" --tags D
#timeshift --list
#timeshift --restore

reboot