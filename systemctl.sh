#!/bin/bash
# ⚙️ System service configuration script

# 📁 Path to systemd service files
SYSTEMCTL_PATH=/etc/systemd/system/

# ⏰ Configure automatic shutdown after 8 hours
auto_shutdown(){
    local service_name="auto-shutdown.service"
    
    echo "⏰ Setting up automatic shutdown service..."
    echo "📝 Creating systemd service file for 8-hour shutdown timer..."
    
    # Create the service file
cat > "${SYSTEMCTL_PATH}/${service_name}" <<EOF
[Unit]
Description=Auto shutdown after 8 hours
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/shutdown -h +480

[Install]
WantedBy=multi-user.target
EOF
    
    echo "🔄 Reloading systemd configuration..."
    # Reload systemd daemon and enable the service
    systemctl daemon-reexec
    systemctl daemon-reload
    
    echo "✅ Enabling auto-shutdown service..."
    systemctl enable ${service_name}
    
    echo "⏰ Auto-shutdown service installed and enabled. The system will shut down 8 hours after each boot."
    
}

main(){
    auto_shutdown
}

main