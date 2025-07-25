#!/bin/sh
# 🌐 Network configuration script
# 🔒 Enable strict mode for better error handling
set -xeu

# 🔌 Setup and configure network interfaces
configure_network_interfaces() {
    echo "🔧 Configuring Network Interfaces..."
    echo "📝 Creating network configuration files..."
    
    local debian_network_interface_path="/etc/network/interfaces"
    
    echo "📝 Setting up network interface configuration at ${debian_network_interface_path}"
    [ -f "${debian_network_interface_path}" ] && rm -f "${debian_network_interface_path}"
    
    echo "🔄 Setting up loopback interface..."
    cat <<EOF > "${debian_network_interface_path}"
source ${debian_network_interface_path}.d/*
auto lo
iface lo inet loopback
EOF
    
    mkdir -p ${debian_network_interface_path}.d
    
    
    echo "🌐 Configuring network interface ${DEFAULT_IFACE} with static IP..."
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
    echo "✅ Network configuration completed successfully!"
}

main