#!/bin/sh
set -xeu

IPV6_RANGE_1="2804:32b0:1000:20::/64"
IPV6_RANGE_2="2804:d41::/32"
# IPV6_RANGE_3="2804:32b0:1000:20::/64"
IPV4_RANGE="192.168.10.0/24"
USERNAME="dev"

insert_before_filter() {
  local file="$1"
  local marker="*filter"
  local tmpfile=$(mktemp)

  awk -v block="$2" -v marker="$marker" '
  $0 == marker {
    print block
  }
  { print }
  ' "$file" > "$tmpfile"

  sudo cp "$tmpfile" "$file"
  rm "$tmpfile"
}

insert_before_commit() {
  local file="$1"
  local block="$2"
  local tmpfile=$(mktemp)

  awk -v block="$block" '
  BEGIN { in_filter=0 }
  /^\*filter/ { in_filter=1 }
  /^COMMIT/ && in_filter {
    print block
  }
  { print }
  ' "$file" > "$tmpfile"

  sudo cp "$tmpfile" "$file"
  rm "$tmpfile"
}

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

configure_ip_k8s() {
BEFORE_RULES="/etc/ufw/before.rules"
DEFAULT_UFW="/etc/default/ufw"
BACKUP_BEFORE="${BEFORE_RULES}.bak.$(date +%F_%T)"
BACKUP_DEFAULT="${DEFAULT_UFW}.bak.$(date +%F_%T)"

echo "Backing up $BEFORE_RULES to $BACKUP_BEFORE"
sudo cp "$BEFORE_RULES" "$BACKUP_BEFORE"

RAW_BLOCK='
# Allow Kubernetes internal interfaces: cni0, flannel.1
*raw
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A PREROUTING -i cni0 -j ACCEPT
-A PREROUTING -i flannel.1 -j ACCEPT
-A OUTPUT -o cni0 -j ACCEPT
-A OUTPUT -o flannel.1 -j ACCEPT
COMMIT
'

FILTER_BLOCK='
# Allow traffic on internal interfaces
-A ufw-before-input -i cni0 -j ACCEPT
-A ufw-before-input -i flannel.1 -j ACCEPT
-A ufw-before-output -o cni0 -j ACCEPT
-A ufw-before-output -o flannel.1 -j ACCEPT
'

if ! grep -q "Allow Kubernetes internal interfaces: cni0, flannel.1" "$BEFORE_RULES"; then
    echo "Inserting raw rules block before *filter section"
    insert_before_filter "$BEFORE_RULES" "$RAW_BLOCK"
else
    echo "Raw block already present, skipping insertion."
fi

if ! grep -q "Allow traffic on internal interfaces" "$BEFORE_RULES"; then
    echo "Appending filter rules block before COMMIT in *filter section"
    insert_before_commit "$BEFORE_RULES" "$FILTER_BLOCK"
else
    echo "Filter block already present, skipping insertion."
fi

# Backup and modify /etc/default/ufw
echo "Backing up $DEFAULT_UFW to $BACKUP_DEFAULT"
sudo cp "$DEFAULT_UFW" "$BACKUP_DEFAULT"

if grep -q '^DEFAULT_FORWARD_POLICY=' "$DEFAULT_UFW"; then
    echo "Updating DEFAULT_FORWARD_POLICY to ACCEPT"
    sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' "$DEFAULT_UFW"
else
    echo "Adding DEFAULT_FORWARD_POLICY=ACCEPT"
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' | sudo tee -a "$DEFAULT_UFW" > /dev/null
fi

# Allow Kubernetes ports
echo "Allowing Kubernetes ports in ufw"

# API Server
sudo ufw allow 6443/tcp

# Kubelet
sudo ufw allow 10250/tcp

# etcd (control plane nodes)
sudo ufw allow 2379:2380/tcp

# kube-scheduler (control plane nodes)
sudo ufw allow 10251/tcp

# kube-controller-manager (control plane nodes)
sudo ufw allow 10252/tcp

# NodePort range (worker nodes)
sudo ufw allow 30000:32767/tcp

echo ""
echo "Reloading ufw firewall..."
sudo ufw disable
sudo ufw enable

echo ""
echo "=== All done! ==="
echo "ufw has been reloaded with Kubernetes-friendly settings."

}


configure_ssh() {
    echo "[+] Enabled systemctl ssh"
    systemctl enable ssh
    
    echo "[+] Enabled systemctl ufw"
    systemctl enable ufw
    
    echo "[+] Enableling UFW ..."
    ufw enable
    echo "[+] Resetting UFW to start clean..."
    ufw --force reset
    
    echo "[+] Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing
    
    
    echo "[+] Allow port 3389 UFW..."
    ufw allow from "$IPV6_RANGE_1" to any port 3389 proto tcp
    echo "[+] Allowing port 3389 from specific IPv6 range 1..."
    ufw allow from "$IPV4_RANGE" to any port 3389 proto tcp

    echo "[+] Allowing port 3389 from specific IPv6 range 2..."
    ufw allow from "$IPV6_RANGE_2" to any port 3389 proto tcp
    
    # echo "[+] Allowing SSH from specific IPv6 range 3..."
    # ufw allow from "$IPV6_RANGE_3" to any port 3389 proto tcp
    
    echo "[+] Allowing SSH from specific IPv4 range..."
    ufw allow from "$IPV4_RANGE" to any port 22 proto tcp
    
    echo "[+] Allowing SSH from specific IPv6 range 1..."
    ufw allow from "$IPV6_RANGE_1" to any port 22 proto tcp
    
    echo "[+] Allowing SSH from specific IPv6 range 2..."
    ufw allow from "$IPV6_RANGE_2" to any port 22 proto tcp
    
    # echo "[+] Allowing SSH from specific IPv6 range 3..."
    # ufw allow from "$IPV6_RANGE_3" to any port 22 proto tcp
    
    echo "[+] Denying all other SSH access..."
    ufw deny in to any port 22 proto tcp
    
    echo "[+] Denying all other RDP access..."
    ufw deny in to any port 3389 proto tcp
    
    echo "[+] Enabled systemctl nginx"
    systemctl enable nginx
    
    echo "[+] Allowing HTTP (port 80) from any address..."
    ufw allow 80/tcp
    
    echo "[+] Allowing HTTPS (port 443) from any address..."
    ufw allow 443/tcp
    
    echo "[+] Done! UFW status:"
    ufw status verbose
    
    
    echo "[+] Enabling UFW..."
    ufw --force enable    
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
    
    echo "[+] Creating .xsession file for user '${USERNAME}'..."
    echo gnome-session | tee /home/${USERNAME}/.xsession
    chown ${USERNAME}:${USERNAME}  /home/${USERNAME}/.xsession
    
    echo "[+] Creating /etc/xrdp/startwm.sh..."
cat <<EOF > /etc/xrdp/startwm.sh
#!/bin/sh
exec gnome-session
EOF
    
    chmod +x /etc/xrdp/startwm.sh
    
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
    su - ${USERNAME} -c "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing"
    su - ${USERNAME} -c "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing"
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
    # mtu 1450
    address 192.168.10.100
    netmask 255.255.255.0
    gateway 192.168.10.1
    dns-nameservers 192.168.10.1 8.8.8.8

iface enp4s0 inet6 static
    address 2804:32b0:1000:20::100
    netmask 64
EOF
    
}

configure_public_key() {
    mkdir -p /home/dev/.ssh
    chown -R dev:dev /home/dev/.ssh
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDY8L7fmkb0fiyQc4CWZ0Oa6Clbvtp401ex0GUaepV/EifZeccx6rg33V5AWOrP3hEg/2ViWX8lP10QbsKxPXSUNm6E2EJbJ/aVRSPCKJdVkbwrBGu+ZMxHsEL8Szxogle1v/mCRI471PYLT6Y2991RWfz/Q/Od+Z+jY67w/Hw3Qxr9ApsTrT64GPFKbWeKTH11q9XFcsNvM9pX54wAdldsBRl92nhbTECh7h3sSxre0ejNB+JtfGij1MfHLV76GN9EPfRc6L7T3eIWg5LyWGkuCJwq80JpbCnPgNZGyspSV+L//DmFzk8WbfwUiqfsVswbQdmo3s+zYlxo9npv+U/kMNRNCT3sle9KrkcQfQtqOQnt5nFDmAsKLOX5fmbXdKRKNBob0vg7/VvgTyzbZ1uQ7J9iPWdR0oW/8lNOaG82GoWjO7GmkVlg9kpTfn1BqUzEcRHpPe5t20gd/hvqrWRL5Po3CYeQcAr6K24YuZR53Z3jMwidM6K3xNRXPa2p7zM= shared" > /home/dev/.ssh/authorized_keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDYRil5DvoVS6E3A3YJou8Ifz4fIsHZWjn3I47CA5ECYHf2txCnuscJM+zcLeHAuQZSnCSmwUn5xKfJoaXsAEsukogUcNEldG4B4zq9w2/ZPOtO+gbkwGBD9dUyzXGgm1f6Fu7Ah5oGruCtGU21QVcxLWaBNxLXrJSrfuAZgGWkrZcOIuA/tCH3n1ZBkTdvDXxh0vnRSWk+31jZGfL6mY9GmNuBIEk7btHNI2OG+t9WKQ5iIt13w3eG+AgKWng4pb/tLIa3+0vyo4lCDgQW96z9zGaaZxR6Y5z27dF5hrqyGzIAnF7HYfZGFhFWOfDCdfmiWLGcfACxIQYwo1SLimQ3WS46WbVAoKZKEeqJq4/srVR2kSEDDpCrXBxgX565vHoyMd2ES6KlPoo4tXzDTatD/XYoOMfgAaP+ASupXUHZXhTPi5ICDHExHL5BYzLYrAqpZA5dwE3gLIPNKq75RI4P+zNZ5D4t0tkao/v2Zqdlra4U3enOuDYrf0wcvBPS3hE= notebook-wsl" >> /home/dev/.ssh/authorized_keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0SQaElZ1C123iSZEO6PpcmNFsSlRpTYSbfMDHsOn5ys+IWV43Sr/p9/qhWmouAM6qwGBsociZmVrceuByG94wt2nGjtCgo67IzZKwefzzy04XKoYdJrIBUeHh/P2CNSiwJH+a2H9p2V0m4CjfcTB9DtZFk5eV+9cpHrFRLpY8jK4tDRujLNxIfRGa+CzaiEIdtvoHKV6T+qlnQlPDx1H7sMvL3Ju0AJFLqXvq/fWp8DjwyZk6HlZTN7xGIol1I4o0iznSUr1HPNZP6Yez56BP7gi+X+1yCuKz7nF3ANGDgqaxuo83mXn1UOw2mibkOFvWUr+4rjaD+V1vmmKm3Hjc/v8ApWRUQz617ZTZxGpwkG4sVn0GI2bNIh3MEtLY0Dp1P4+lLteFrebzX2GR65LPT+oHL2HoLTK8Nr092lYcai7uE9san7+MxXpxI80RNTEGtSstCoNPZS20QQvhQDbsC7m1sdT4ASR5vRq2FsGjR7+5CM1c6zjcmd846L7RLHM= notebook-windows" >> /home/dev/.ssh/authorized_keys

    chown -R dev:dev /home/dev/.ssh
    
}


configure_home_folder(){
    rm -rf /home/dev/Desktop /home/dev/Documents /home/dev/Downloads /home/dev/Music /home/dev/Pictures /home/dev/Public /home/dev/Templates /home/dev/Videos 
    mkdir -p /home/dev/git
    chown -R dev:dev /home/dev
}

main() {
    configure_public_key
    configure_home_folder
    configure_gnome
    configure_network_interfaces
    configure_xrdp
    configure_sudoers
    configure_ssh
    configure_fail2ban
    configure_ip_k8s
}


main

# Clears crontab file
sed -i '/@reboot/d' /etc/crontab

timeshift --create --comments "Initial Backup" --tags D
#timeshift --list
#timeshift --restore

reboot
