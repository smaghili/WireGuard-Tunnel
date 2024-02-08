#!/bin/bash

# Set the GitHub repository URL
repo_url="https://github.com/smaghili/WireGuard-Tunnel.git"

# Clone the GitHub repository
git clone "$repo_url" || { echo "Failed to clone the repository. Exiting."; exit 1; }

# Navigate to the cloned repository directory
cd WireGuard-Tunnel || { echo "Failed to navigate to the repository directory. Exiting."; exit 1; }

# Set execute permissions for scripts
chmod -R +x . || { echo "Failed to set execute permissions. Exiting."; exit 1; }

# Remove carriage return (CR) characters from wgt.sh
sed -i 's/\r$//' wgt.sh || { echo "Failed to remove CR characters from wgt.sh. Exiting."; exit 1; }

# Create an alias for 'wgt' in the user's bashrc
echo 'alias wgt="~/WireGuard-Tunnel/wgt.sh"' >> ~/.bashrc

# Source the bashrc to apply changes
source ~/.bashrc

echo "Setup complete. You can now use the 'wgt' command."
