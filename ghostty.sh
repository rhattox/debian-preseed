#!/bin/bash
set -xeu

echo "🔗 Adding Ghostty repository..."
echo 'deb http://download.opensuse.org/repositories/home:/clayrisser:/bookworm/Debian_12/ /' | sudo tee /etc/apt/sources.list.d/home:clayrisser:bookworm.list

echo "🔑 Importing repository GPG key..."
curl -fsSL https://download.opensuse.org/repositories/home:clayrisser:bookworm/Debian_12/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_clayrisser_bookworm.gpg > /dev/null

echo "🔄 Updating package lists..."
sudo apt update

echo "📦 Installing Ghostty..."
sudo apt install -y ghostty

echo "✅ Ghostty installation complete!"