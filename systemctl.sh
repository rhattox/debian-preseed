#!/bin/bash

SYSTEMCTL_PATH=/etc/systemd/system/


auto_shutdown(){
    local service_name="auto-shutdown.service"
    
    echo "Creating systemd service to shutdown after 8 hours..."
    
    # Create the service file
cat > "${SERVICE_PATH}/${service_name}" <<EOF
[Unit]
Description=Auto shutdown after 8 hours
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/shutdown -h +480

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd daemon and enable the service
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    
    echo "Auto-shutdown service installed and enabled. The system will shut down 8 hours after each boot."
    
}

main(){
    auto_shutdown
}

main