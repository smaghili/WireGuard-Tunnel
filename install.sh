#!/bin/bash
# Set the GitHub repository URL
repo_url="https://github.com/smaghili/WireGuard-Tunnel.git"
# Clone the GitHub repository
git clone "$repo_url"
# Set execute permissions for scripts
chmod +x -R WireGuard-Tunnel
cd WireGuard-Tunnel
sed -i 's/\r$//' wgt.sh
# Create an alias for 'wgt' in the user's bashrc
echo 'alias wgt="./root/WireGuard-Tunnel/wgt.sh"' >> ~/.bashrc
# Source the bashrc to apply changes
source ~/.bashrc
echo "Setup complete. You can now use the 'wgt' command."
# Optionally, show the menu after completing the setup
./root/WireGuard-Tunnel/wgt.sh
