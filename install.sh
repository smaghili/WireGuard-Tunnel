#!/bin/bash
export PATH=$PATH:/root/WireGuard-Tunnel/
# Set the GitHub repository URL
repo_url="https://github.com/smaghili/WireGuard-Tunnel.git"


# Clone the GitHub repository
git clone "$repo_url"

# Navigate to the cloned repository directory
apt install resolvconf -y
apt install net-tools -y

# Define the sysctl settings
SYSCTL_SETTINGS=$(cat <<EOL
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.conf.all.forwarding = 1
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 26214400
net.core.rmem_default = 26214400
net.core.wmem_max = 26214400
net.core.wmem_default = 26214400
net.core.netdev_max_backlog = 2048
EOL
)

# Check if sysctl.conf exists, if not create it
SYSCTL_FILE="/etc/sysctl.conf"
if [ ! -f "$SYSCTL_FILE" ]; then
    echo "$SYSCTL_SETTINGS" | sudo tee -a "$SYSCTL_FILE"
    echo "sysctl.conf created and updated."
else
    # Check if settings already exist, if not append them
    if ! grep -qF "$SYSCTL_SETTINGS" "$SYSCTL_FILE"; then
        echo "$SYSCTL_SETTINGS" | sudo tee -a "$SYSCTL_FILE"
        echo "Settings added to sysctl.conf."
    else
        echo "Settings already exist in sysctl.conf."
    fi
fi

# Apply the changes
sudo sysctl -p
echo "Sysctl settings applied."
# Set execute permissions for scripts
chmod +x -R WireGuard-Tunnel

cd WireGuard-Tunnel

# ...

# Create an alias for 'wgt' in the user's bashrc
echo 'alias wgt="/root/WireGuard-Tunnel/wgt.sh"' >> ~/.bashrc

# Source the bashrc to apply changes
source ~/.bashrc

# Optionally, show the menu after completing the setup
./wgt.sh

