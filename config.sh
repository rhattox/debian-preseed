#!/usr/bin/env bash

apt update -y
apt install -y git

git clone https://github.com/rhattox/debian-developer.git /root/debian-developer

chmod +x /root/debian-developer/main.sh
bash /root/debian-developer/main.sh

# Cleanup

sed -i '/@reboot root \/root\/config\.sh/d' /etc/crontab
