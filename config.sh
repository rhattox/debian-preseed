#!/bin/sh
set -xeu

IPV6_RANGE_1="2804:32b0:1000:20::/64"
# IPV6_RANGE_2="2804:32b0:1000:20::/64"
# IPV6_RANGE_3="2804:32b0:1000:20::/64"
IPV4_RANGE="192.168.10.0/24"
USERNAME="dev"

configure_fail2ban() {
  
  systemctl enable fail2ban

  echo "[+] Configuring fail2ban for SSH..."
  # Backup default jail.local if it exists
  if [ -f /etc/fail2ban/jail.local ]; then
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
  fi

  # Create new jail.local
tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 3
backend = systemd
banaction = ufw

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
EOF

echo "[+] Setting up fail2ban jails for NGINX..."

# Jail for auth attacks
tee /etc/fail2ban/jail.d/nginx-http.local > /dev/null <<EOF
[nginx-http]
enabled = true
port    = http,https
filter  = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 600
findtime = 600
EOF

# Jail for bad bots
tee /etc/fail2ban/jail.d/nginx-badbots.local > /dev/null <<EOF
[nginx-badbots]
enabled  = true
port     = http,https
filter   = nginx-badbots
logpath  = /var/log/nginx/access.log
maxretry = 10
findtime = 600
bantime  = 3600
EOF

# Create the bad bots filter
tee /etc/fail2ban/filter.d/nginx-badbots.conf > /dev/null <<'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*(\.php|\.env|wp-login\.php|xmlrpc\.php|/admin).*" 404
ignoreregex =
EOF

  systemctl restart fail2ban

}



configure_ssh() {
    echo "[+] Enabled systemctl ssh"
    systemctl enable ssh

    echo "[+] Enabled systemctl ufw"
    systemctl enable ufw

    apt update -y
    apt install iptables -y

    echo "[+] Enableling UFW ..."
    ufw enable
    echo "[+] Resetting UFW to start clean..."
    ufw --force reset

    echo "[+] Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing

    echo "[+] Allowing SSH from specific IPv4 range..."
    ufw allow from "$IPV4_RANGE" to any port 22 proto tcp

    echo "[+] Allowing SSH from specific IPv6 range 1..."
    ufw allow from "$IPV6_RANGE_1" to any port 22 proto tcp

    # echo "[+] Allowing SSH from specific IPv6 range 2..."
    # ufw allow from "$IPV6_RANGE_2" to any port 22 proto tcp

    # echo "[+] Allowing SSH from specific IPv6 range 3..."
    # ufw allow from "$IPV6_RANGE_3" to any port 22 proto tcp

    echo "[+] Denying all other SSH access..."
    ufw deny in to any port 22 proto tcp

    echo "[+] Enabling UFW..."
    ufw --force enable

    echo "[+] Done! UFW status:"
    ufw status verbose
}


configure_nginx() {
  echo "[+] Enabled systemctl nginx"
  systemctl enable nginx

  echo "[+] Allowing HTTP (port 80) from any address..."
  ufw allow 80/tcp

  echo "[+] Allowing HTTPS (port 443) from any address..."
  ufw allow 443/tcp
}


configure_sudoers() {
    echo "[+] Configuring sudoers file..."
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/${USERNAME} 
    chmod 0440 /etc/sudoers.d/${USERNAME} 
    echo "[+] Sudoers file configured successfully."
}

#
# RDP Configuration
#
configure_xrdp() {
  echo "[+] Configuring XRDP..."

  echo "[+] Enabled systemctl xrdp"
  systemctl enable xrdp

  echo "[+] Creating .xsession file for user '${USERNAME} '..."
  echo gnome-session | tee /home/${USERNAME} /.xsession
  chown ${USERNAME}:${USERNAME}  /home/${USERNAME} /.xsession

  echo "[+] Creating /etc/xrdp/startwm.sh..."
cat <<EOF > /etc/xrdp/startwm.sh
#!/bin/sh
exec gnome-session
EOF

  chmod +x /etc/xrdp/startwm.sh

  echo "[+] Allow port 3389 UFW..."
  ufw allow from "$IPV6_RANGE" to any port 3389 proto tcp
  ufw allow from "$IPV4_RANGE" to any port 3389 proto tcp

  echo "[+] XRDP configured successfully."
}

#
# GNOME Configuration
#
configure_gnome() {
  echo "[+] Disabled gdm"
  systemctl disable gdm

  echo "[+] Configuring Terminal as default..."
  systemctl set-default multi-user.target

  echo "[+] Configuring GNOME settings for user '${USERNAME}'..."
  su - ${USERNAME}  -c "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing"
  su - ${USERNAME}  -c "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing"
  echo "[+] GNOME settings configured successfully."
}

#
# Network Interfaces Configuration
#
configure_network_interfaces() {
#
# Configure Network Interfaces
#
[ -f /etc/network/interfaces ] && rm /etc/network/interfaces
cat <<EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
EOF

mkdir -p /etc/network/interfaces.d

cat <<EOF > /etc/network/interfaces.d/enp4s0
auto enp4s0
iface enp4s0 inet static
    address 192.168.10.100
    netmask 255.255.255.0
    gateway 192.168.10.1
    dns-nameservers 192.168.10.1 1.1.1.1 8.8.8.8

iface enp4s0 inet6 static
    address 2804:32b0:1000:20::100
    netmask 64
EOF

}

main() {
  configure_fail2ban
  configure_ssh
  configure_nginx
  configure_sudoers
  configure_xrdp
  configure_gnome
  configure_network_interfaces
}


main
