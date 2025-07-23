#!/bin/bash
set -xeu

configure_xrdp() {
    echo "-- Configuring RDP" 
    systemctl enable xrdp
    
    echo gnome-session | tee /home/${USER}/.xsession
    chown ${USER}:${USER}  /home/${USER}/.xsession
    
cat <<EOF > /etc/xrdp/startwm.sh
#!/bin/sh
exec gnome-session
EOF
    
chmod +x /etc/xrdp/startwm.sh
    
}


configure_sudoers() {
    echo "-- Configuring SUDOERS"
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/${USER}
    chmod 0440 /etc/sudoers.d/${USER}
}

configure_gnome() {
    echo "-- Configuring GNOME"
    # systemctl disable gdm
    # systemctl set-default multi-user.target   
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
}


configure_public_key() {
    echo "-- Configuring Public Key" 
    local user_ssh_home_folder="${USER_HOME_FOLDER}/.ssh"
    local authorized_keys_path="${authorized_keys_path}/authorized_keys"
    
    mkdir -p ${user_ssh_home_folder}
    chown -R ${USER}:${USER} ${user_ssh_home_folder}
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDY8L7fmkb0fiyQc4CWZ0Oa6Clbvtp401ex0GUaepV/EifZeccx6rg33V5AWOrP3hEg/2ViWX8lP10QbsKxPXSUNm6E2EJbJ/aVRSPCKJdVkbwrBGu+ZMxHsEL8Szxogle1v/mCRI471PYLT6Y2991RWfz/Q/Od+Z+jY67w/Hw3Qxr9ApsTrT64GPFKbWeKTH11q9XFcsNvM9pX54wAdldsBRl92nhbTECh7h3sSxre0ejNB+JtfGij1MfHLV76GN9EPfRc6L7T3eIWg5LyWGkuCJwq80JpbCnPgNZGyspSV+L//DmFzk8WbfwUiqfsVswbQdmo3s+zYlxo9npv+U/kMNRNCT3sle9KrkcQfQtqOQnt5nFDmAsKLOX5fmbXdKRKNBob0vg7/VvgTyzbZ1uQ7J9iPWdR0oW/8lNOaG82GoWjO7GmkVlg9kpTfn1BqUzEcRHpPe5t20gd/hvqrWRL5Po3CYeQcAr6K24YuZR53Z3jMwidM6K3xNRXPa2p7zM= shared" > ${authorized_keys_path}
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDYRil5DvoVS6E3A3YJou8Ifz4fIsHZWjn3I47CA5ECYHf2txCnuscJM+zcLeHAuQZSnCSmwUn5xKfJoaXsAEsukogUcNEldG4B4zq9w2/ZPOtO+gbkwGBD9dUyzXGgm1f6Fu7Ah5oGruCtGU21QVcxLWaBNxLXrJSrfuAZgGWkrZcOIuA/tCH3n1ZBkTdvDXxh0vnRSWk+31jZGfL6mY9GmNuBIEk7btHNI2OG+t9WKQ5iIt13w3eG+AgKWng4pb/tLIa3+0vyo4lCDgQW96z9zGaaZxR6Y5z27dF5hrqyGzIAnF7HYfZGFhFWOfDCdfmiWLGcfACxIQYwo1SLimQ3WS46WbVAoKZKEeqJq4/srVR2kSEDDpCrXBxgX565vHoyMd2ES6KlPoo4tXzDTatD/XYoOMfgAaP+ASupXUHZXhTPi5ICDHExHL5BYzLYrAqpZA5dwE3gLIPNKq75RI4P+zNZ5D4t0tkao/v2Zqdlra4U3enOuDYrf0wcvBPS3hE= notebook-wsl" >> ${authorized_keys_path}
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0SQaElZ1C123iSZEO6PpcmNFsSlRpTYSbfMDHsOn5ys+IWV43Sr/p9/qhWmouAM6qwGBsociZmVrceuByG94wt2nGjtCgo67IzZKwefzzy04XKoYdJrIBUeHh/P2CNSiwJH+a2H9p2V0m4CjfcTB9DtZFk5eV+9cpHrFRLpY8jK4tDRujLNxIfRGa+CzaiEIdtvoHKV6T+qlnQlPDx1H7sMvL3Ju0AJFLqXvq/fWp8DjwyZk6HlZTN7xGIol1I4o0iznSUr1HPNZP6Yez56BP7gi+X+1yCuKz7nF3ANGDgqaxuo83mXn1UOw2mibkOFvWUr+4rjaD+V1vmmKm3Hjc/v8ApWRUQz617ZTZxGpwkG4sVn0GI2bNIh3MEtLY0Dp1P4+lLteFrebzX2GR65LPT+oHL2HoLTK8Nr092lYcai7uE9san7+MxXpxI80RNTEGtSstCoNPZS20QQvhQDbsC7m1sdT4ASR5vRq2FsGjR7+5CM1c6zjcmd846L7RLHM= notebook-windows" >> ${authorized_keys_path}
}


delete_std_folders(){
    echo "-- Configuring STD Folders" 
    local standard_home_folders=( 
        "Desktop"
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Public"
        "Templates"
        "Videos"
    )

    for folder in ${standard_home_folders[@]}
    do
        echo "Deleting folder: ${folder}"
        rm -rf ${USER_HOME_FOLDER}/${folder}
    done
}

main(){
    delete_std_folders
    configure_public_key
    configure_gnome
    configure_sudoers
    configure_xrdp
}

main