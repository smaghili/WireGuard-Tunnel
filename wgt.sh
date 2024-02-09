#!/bin/bash

export PATH=$PATH:/root/WireGuard-Tunnel/
source menu.sh

# Check if WireGuard is installed
if ! command -v wg &> /dev/null; then
    echo "WireGuard not installed. Installing..."
    sudo apt install wireguard -y
fi

# WireGuard directory path
wg_path="/etc/wireguard"

# Create directory if not exists
if [ ! -d "$wg_path" ]; then
    sudo mkdir -p "$wg_path"
fi

# Navigate to WireGuard directory
cd "$wg_path"

# Generate private and public keys if not exists
if [ ! -f "privatekey" ] || [ ! -f "publickey" ]; then
    wg genkey | tee privatekey | wg pubkey | tee publickey
    echo "Private and public keys generated."
fi

# Check if udp2raw is installed
if ! command -v udp2raw_amd64 &> /dev/null; then
    echo "udp2raw not installed. Installing..."
    wget https://github.com/wangyu-/udp2raw/releases/download/20200818.0/udp2raw_binaries.tar.gz
    tar xzvf udp2raw_binaries.tar.gz
    sudo mv udp2raw_amd64 /sbin
fi

# Automatically retrieve network interface
YOUR_INTERFACE=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')

# Configure WireGuard server
configure_wireguard_server() {
    echo "Configuring WireGuard Server..."

    # Create WireGuard configuration file at /etc/wireguard/wg0
    wg_config="/etc/wireguard/wg0.conf"
    cat <<EOF | sudo tee "$wg_config" >/dev/null
# Server configuration

[Interface]
Address = 10.8.0.1/24
MTU = 1200
ListenPort = 51820
PrivateKey = $(cat privatekey)
PreUp = sudo udp2raw_amd64 -s -l 0.0.0.0:4096 -r 127.0.0.1:51820 -k "your-password" --raw-mode faketcp -a --log-level 0 &
Postdown = pkill -f "udp2raw.*:51820"
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $YOUR_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $YOUR_INTERFACE -j MASQUERADE
EOF

    echo "WireGuard Server configured in $wg_config"

    # Display server's public key to the user
    server_public_key=$(cat publickey)
    echo "Your server's public key is: $server_public_key"
    echo "Please remember this key for future use."
    press_any_key
}

# Add client to peers
add_client_to_peers() {
    read -p "Enter the PublicKey of the WireGuard client: " client_public_key

    # Check if the client's public key already exists in the configuration
    wg_config="/etc/wireguard/wg0.conf"
    if grep -q "$client_public_key" "$wg_config"; then
        echo "Client already exists in the configuration."
    else
        # Add client to WireGuard configuration
        cat <<EOF | sudo tee -a "$wg_config" >/dev/null
[Peer]
PublicKey = $client_public_key
AllowedIPs = 0.0.0.0/0
EOF

        echo "Client added to peers in $wg_config"
    fi
    press_any_key
}

# Configure WireGuard client
configure_wireguard_client() {
    client_private_key=$(cat privatekey)
    read -p "Enter the PublicKey of the WireGuard server: " server_public_key
    read -p "Enter the server's IP address: " server_ip

    echo "Configuring WireGuard Client..."

    # Create WireGuard configuration for the client at /etc/wireguard/wg0
    wg_client_config="/etc/wireguard/wg0.conf"
    cat <<EOF | sudo tee "$wg_client_config" >/dev/null
# Client configuration

[Interface]
PrivateKey = $client_private_key
Address = 10.8.0.2/32
MTU = 1200
DNS = 8.8.8.8, 8.8.4.4

PreUp = sh /root/iran-route.sh
PreUp = ip route add $server_ip via \$gw dev $YOUR_INTERFACE
PostDown = ip route del $server_ip via \$gw dev $YOUR_INTERFACE
PreUp = udp2raw_amd64 -c -l 127.0.0.1:51820 -r $server_ip:4096 -k "your-password" --raw-mode faketcp -a --log-level 0 &
Postdown = pkill -f "udp2raw.*:51820"

[Peer]
PublicKey = $server_public_key
AllowedIPs = 0.0.0.0/0
Endpoint = 127.0.0.1:51820
PersistentKeepalive = 20
EOF

    echo "WireGuard Client configured in $wg_client_config"
    # Display client's public key to the user
    echo "Your client's public key is: $client_private_key"
    echo "Please remember this key for future use."
    press_any_key
}

# Start WireGuard service
start_wireguard_service() {
    sudo systemctl start wg-quick@wg0
    sudo systemctl enable wg-quick@wg0
    press_any_key
}

# Function to restart WireGuard service
restart_wireguard_service() {
    sudo systemctl restart wg-quick@wg0
    press_any_key
}

# Function to stop WireGuard service
stop_wireguard_service() {
    sudo systemctl stop wg-quick@wg0
    press_any_key
}

# Function to show WireGuard status
show_wireguard_status() {
    sudo systemctl status wg-quick@wg0
    press_any_key
}

press_any_key() {
   read -n 1 -s -r -p $'\nPress any key to show menu...\n'
}

while true; do
    # Create a menu with the main options
    declare -a main_menu=("Configure WireGuard Server" "Configure WireGuard Client" "Add Client To Peers" "Start WireGuard Service" "Restart WireGuard Service" "Stop WireGuard Service" "Show WireGuard Status" "Quit")
    generateDialog "options" "Wireguard Tunnel Menu" "${main_menu[@]}"

    # Read user input
    read -p "Enter your choice: " choice

    # Perform actions based on the selected option
    case $choice in
        1)
            configure_wireguard_server
            ;;
        2)
            configure_wireguard_client
            ;;
        3)
            add_client_to_peers
            ;;
        4)
            start_wireguard_service
            ;;
        5)
            restart_wireguard_service
            ;;
        6)
            stop_wireguard_service
            ;;
        7)
            show_wireguard_status
            ;;
        8)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
