#!/bin/bash
export PATH=$PATH:/root/WireGuard-Tunnel/
# Set the GitHub repository URL
repo_url="https://github.com/smaghili/WireGuard-Tunnel.git"

# Clone the GitHub repository
git clone "$repo_url"

# Navigate to the cloned repository directory
apt install resolvconf -y
apt install net-tools -y

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

