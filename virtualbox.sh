#!/bin/bash

# Exit on error
set -xeu

# Update package list
apt update

# Install required dependencies
apt install -y wget gnupg2 lsb-release

# Add VirtualBox repository and key
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | gpg --dearmor -o /usr/share/keyrings/virtualbox-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/virtualbox-archive-keyring.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | tee /etc/apt/sources.list.d/virtualbox.list

# Update package list again
apt update

# Install VirtualBox (latest version)
apt install -y virtualbox-7.0

# Optional: Add current user to vboxusers group
usermod -aG vboxusers "$USER"

echo "VirtualBox installation complete. Please reboot or log out/in for group" 