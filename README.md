# 🚀 Debian Preseed Configuration

This repository contains an automated configuration setup for Debian systems. It provides a collection of scripts that handle various aspects of system configuration, from networking to user setup and remote access.

## 📋 Overview

The preseed configuration and accompanying scripts automate the following tasks:

- 🌐 Network Configuration
  - Automatic network interface detection
  - Static IP configuration
  - Network information gathering
  - UFW firewall setup

- 👤 User Environment Setup
  - SSH key configuration
  - Sudo privileges
  - GNOME desktop environment customization
  - Remote Desktop (XRDP) setup
  - Home directory cleanup

- 🔗 System Services
  - Tailscale VPN installation and setup
  - Automatic shutdown service (8-hour timer)
  - System service management

## 🛠️ Main Components

- `main.sh`: Central configuration script that orchestrates all setup tasks
- `networking.sh`: Handles network interface configuration
- `get_base_network_info.sh`: Detects and extracts network settings
- `user.sh`: Manages user environment, SSH, and desktop settings
- `systemctl.sh`: Configures system services and auto-shutdown
- `tailscale.sh`: Sets up Tailscale VPN connectivity
- `preseed.cfg`: Debian preseed configuration file

## 🔧 Usage

1. Access the preseed configuration:
   ```
   https://raw.githubusercontent.com/rhattox/debian-preseed/refs/heads/main/preseed.cfg
   ```

2. For Windows VSCode Remote Access:
   ```
   Host debian-server
       HostName rhattox.ddns.net
       User dev
       IdentityFile "C:\Users\rhattox\.ssh\id_rsa"
   ```

## ⚙️ Features

- Automated system configuration
- Secure remote access setup
- Network auto-detection and configuration
- VPN integration with Tailscale
- Desktop environment optimization
- Automatic system maintenance

## 🔒 Security

- SSH key-based authentication
- UFW firewall configuration
- Secure sudo setup
- Tailscale VPN integration

## � Workflow

```
                                    main.sh
                                       ↓
                    +------------------+------------------+
                    ↓                  ↓                 ↓
            get_base_network     user.sh          systemctl.sh
                    ↓                  ↓                 ↓
            networking.sh     [SSH + Desktop]    [Auto-shutdown]
                    ↓                  ↓                 ↓
          [Network Config]    [User Config]     [System Config]
                    |                  |                 |
                    +------------------+--------+--------+
                                      ↓
                              tailscale.sh
                                      ↓
                               [VPN Setup]
                                      ↓
                            System Ready ✓
```

## �📝 Note

This configuration is designed for automated Debian system setup. Ensure you review the settings and modify them according to your needs before implementation.
