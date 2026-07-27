#!/usr/bin/env bash

apt update -y
apt install -y git

git clone https://github.com/rhattox/debian-developer.git /root/debian-developer

chmod +x /root/debian-developer/main.sh

TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
LOG_FILE="log-$TIMESTAMP.txt"

bash /root/debian-developer/main.sh server > /root/${LOG_FILE} 2>&1

# Cleanup

sed -i '/@reboot root \/root\/config\.sh/d' /etc/crontab

reboot