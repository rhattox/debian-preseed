#!/bin/bash
# 🔗 Tailscale VPN installation and configuration script
# 🔒 Enable strict mode for better error handling
set -xeu

# 📦 Install and configure Tailscale VPN
install_tailscale(){
    echo "� Starting Tailscale installation..."
    echo "�🔧 Installing dependencies..."
    apt-get update -y
    apt-get install -y curl gnupg lsb-release
    
    echo "📦 Adding Tailscale APT repository..."
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    
    echo "🔄 Updating package list and installing Tailscale..."
    apt-get update -y
    apt-get install -y tailscale
    
    echo "🚀 Enabling and starting Tailscale service..."
    systemctl enable --now tailscaled
    
    echo "✅ Tailscale setup complete!"
}


main(){
    install_tailscale
}

main