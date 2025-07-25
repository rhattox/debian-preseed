#!/bin/sh
set -xeu

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

main(){
    configure_network_interfaces
}

main