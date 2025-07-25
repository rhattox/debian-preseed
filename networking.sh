#!/bin/sh
set -xeu



configure_network_interfaces() {
    
    local debian_network_interface_path="/etc/network/interfaces"
    
    [ -f "${debian_network_interface_path}" ] && rm -f "${debian_network_interface_path}"
    
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


setup_ufw() {
    # Allow SSH (22), SFTP (22), FTP (21), HTTP (80), HTTPS (443), DNS (53), RDP (3389), Kubernetes (6443)
    local k8s_port=6443
    local allowed_subnet="100.64.0.0/10"
    ufw allow from ${allowed_subnet} to any port 22 proto tcp  # SSH/SFTP
    ufw allow from ${allowed_subnet} to any port 21 proto tcp  # FTP
    ufw allow from ${allowed_subnet} to any port 80 proto tcp  # HTTP
    ufw allow from ${allowed_subnet} to any port 443 proto tcp # HTTPS
    ufw allow from ${allowed_subnet} to any port 53 proto udp  # DNS UDP
    ufw allow from ${allowed_subnet} to any port 53 proto tcp  # DNS TCP
    ufw allow from ${allowed_subnet} to any port 3389 proto tcp # RDP
    ufw allow from ${allowed_subnet} to any port ${k8s_port} proto tcp # Kubernetes API
}

main(){
    configure_network_interfaces
    # Uncomment to setup UFW
    setup_ufw
}

main