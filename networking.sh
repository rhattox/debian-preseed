#!/bin/sh
set -xeu


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
    systemctl enable ssh
    
    systemctl enable ufw
    
    ufw enable
    ufw --force reset
    
    ufw default deny incoming
    ufw default allow outgoing
    
    
    ufw allow from "$IPV6_RANGE_1" to any port 3389 proto tcp
    ufw allow from "$IPV4_RANGE" to any port 3389 proto tcp

    ufw allow from "$IPV6_RANGE_2" to any port 3389 proto tcp
    
    # ufw allow from "$IPV6_RANGE_3" to any port 3389 proto tcp
    
    ufw allow from "$IPV4_RANGE" to any port 22 proto tcp
    
    ufw allow from "$IPV6_RANGE_1" to any port 22 proto tcp
    
    ufw allow from "$IPV6_RANGE_2" to any port 22 proto tcp
    
    # ufw allow from "$IPV6_RANGE_3" to any port 22 proto tcp
    
    ufw deny in to any port 22 proto tcp
    
    ufw deny in to any port 3389 proto tcp
    
    systemctl enable nginx
    
    ufw allow 80/tcp
    
    ufw allow 443/tcp
    
    ufw status verbose
    
    
    ufw --force enable    
}


configure_network_interfaces() {

    local debian_network_interface_path="/etc/network/interfaces"

    [ -f "${debian_network_interface_path}" ] && rm "${debian_network_interface_path}"

    cat <<EOF > "${debian_network_interface_path}"
source ${debian_network_interface_path}.d/*
auto lo
iface lo inet loopback
EOF
    
    mkdir -p ${debian_network_interface_path}.d


    cat <<EOF > ${debian_network_interface_path}.d/${DEFAULT_IFACE}
auto ${DEFAULT_IFACE}
iface ${DEFAULT_IFACE} inet static
    # mtu 1450
    address ${IPV4_VALUE}
    netmask ${IPV4_NETMASK}
    gateway ${IPV4_GATEWAY}
    dns-nameservers ${IPV4_GATEWAY}
EOF
    
}

