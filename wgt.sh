#!/bin/bash

export PATH=$PATH:/root/WireGuard-Tunnel/

CYAN="\e[96m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
BLUE="\e[94m"
MAGENTA="\e[95m"
NC="\e[0m"

# Check if WireGuard is installed
if ! command -v wg &> /dev/null; then
    echo "WireGuard not installed. Installing..."
     apt install wireguard -y
fi


# WireGuard directory path
wg_path="/etc/wireguard"

# Create directory if not exists
if [ ! -d "$wg_path" ]; then
     mkdir -p "$wg_path"
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
     mv udp2raw_amd64 /sbin
fi

# Automatically retrieve network interface
YOUR_INTERFACE=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')

# Configure WireGuard server
configure_wireguard_server() {
    echo "Configuring WireGuard Server..."

    # Create WireGuard configuration file at /etc/wireguard/wg0
    wg_config="/etc/wireguard/wg0.conf"
    cat <<EOF |  tee "$wg_config" >/dev/null
# Server configuration

[Interface]
Address = 192.168.75.1/24
MTU = 1200
ListenPort = 51820
PrivateKey = $(cat privatekey)
PreUp =  udp2raw_amd64 -s -l 0.0.0.0:4096 -r 127.0.0.1:51820 -k "your-password" --raw-mode faketcp -a --log-level 0 &
Postdown = pkill -f "udp2raw.*:51820"
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $YOUR_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $YOUR_INTERFACE -j MASQUERADE
EOF

    echo ""
    echo -e "\e[93m╔══════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[93m║            \e[96m WireGuard Server configured              \e[93m║\e[0m"
    echo -e "\e[93m╚══════════════════════════════════════════════════════╝\e[0m"
    echo ""
    server_ip= ip addr show $YOUR_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
    echo "WireGuard server configured in $wg_config"
    server_public_key=$(cat publickey)
    echo -e  "Your server's IP is: ${MAGENTA} $server_ip ${NC}"
    echo -e  "Your server's public key is: ${MAGENTA} $server_public_key ${NC}"
    echo  "Please remember this key for future use."
}

# Add client to peers
add_client_to_peers() {
    read -p "Enter the PublicKey of the WireGuard client: " client_public_key
    wg_config="/etc/wireguard/wg0.conf"
    # Check if wg0.conf file exists
    if [ ! -f "$wg_config" ]; then
        echo -e "\e[91mError: The file $wg_config does not exist. Please configure the WireGuard server first.\e[0m"
    elif grep -q "$client_public_key" "$wg_config"; then
        echo "Client already exists in the configuration."
    else
        # Add client to WireGuard configuration
        cat <<EOF |  tee -a "$wg_config" >/dev/null
[Peer]
PublicKey = $client_public_key
AllowedIPs = 192.168.75.2/32
EOF
    echo ""
    echo -e "\e[93m╔══════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[93m║        \e[96m      Client added to peers                   \e[93m║\e[0m"
    echo -e "\e[93m╚══════════════════════════════════════════════════════╝\e[0m"
    echo ""
        echo "Client added to peers in $wg_config"
    fi
}

# Configure WireGuard client
configure_wireguard_client() {
    client_private_key=$(cat privatekey)
    gw=$(/sbin/ip route | awk '/default/ { print $3 }')
    read -p "Enter the PublicKey of the WireGuard server: " server_public_key
    read -p "Enter the server's IP address: " server_ip

    echo "Configuring WireGuard Client..."

    # Create WireGuard configuration for the client at /etc/wireguard/wg0
    wg_client_config="/etc/wireguard/wg0.conf"
    cat <<EOF |  tee "$wg_client_config" >/dev/null
# Client configuration

[Interface]
PrivateKey = $client_private_key
Address = 192.168.75.2/32
MTU = 1200
DNS = 8.8.8.8, 8.8.4.4

PreUp = ./root/WireGuard-Tunnel/set-route.sh $server_ip $gw $YOUR_INTERFACE
PreUp = udp2raw_amd64 -c -l 127.0.0.1:51820 -r $server_ip:4096 -k "your-password" --raw-mode faketcp -a --log-level 0 &
Postdown = pkill -f "udp2raw.*:51820"

[Peer]
PublicKey = $server_public_key
AllowedIPs = 0.0.0.0/0
Endpoint = 127.0.0.1:51820
PersistentKeepalive = 20
EOF

    echo ""
    echo -e "\e[93m╔══════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[93m║            \e[96m WireGuard Client configured              \e[93m║\e[0m"
    echo -e "\e[93m╚══════════════════════════════════════════════════════╝\e[0m"
    echo ""
    echo "WireGuard Client configured in $wg_client_config"
    client_public_key=$(cat publickey)
    echo -e  "Your client's public key is: ${MAGENTA} $client_public_key ${NC}"
    echo  "Please remember this key for future use."
}

# Start WireGuard service
start_wireguard_service() {
     systemctl start wg-quick@wg0
     systemctl enable wg-quick@wg0
}

# Function to restart WireGuard service
restart_wireguard_service() {
     systemctl restart wg-quick@wg0
}

# Function to stop WireGuard service
stop_wireguard_service() {
     systemctl stop wg-quick@wg0
}

# Function to show WireGuard status
show_wireguard_status() {
     systemctl status wg-quick@wg0
}

show_public_key() {
    echo -e "\e[93m╔══════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[93m║               \e[96m Public Key Display                    \e[93m║\e[0m"
    echo -e "\e[93m╚══════════════════════════════════════════════════════╝\e[0m"
    echo ""
    echo "Your public key is:"
    cat publickey
}

show_private_key() {
    echo -e "\e[93m╔══════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[93m║         \e[96m Private Key Display                   \e[93m║\e[0m"
    echo -e "\e[93m╚══════════════════════════════════════════════════════╝\e[0m"
    echo ""
    echo "Your Private key is:"
    cat privatekey
}

show_peers() {
    echo -e "\e[93m╔═══════════════════════════════════════════════╗\e[0m"  
    echo -e "\e[93m║             \e[96m     Show Peers                   \e[93m║\e[0m"   
    echo -e "\e[93m╠═══════════════════════════════════════════════╣\e[0m"
    echo ""
    wg
}

# Function to uninstall WireGuard completely
uninstall_script() {
    # Stop WireGuard service
     systemctl stop wg-quick@wg0
     systemctl disable wg-quick@wg0
    # Uninstall WireGuard
     apt remove wireguard -y
     apt autoremove -y

    # Remove WireGuard directory
	 rm -rf /etc/wireguard
    	 rm -rf /root/WireGuard-Tunnel/
    clear
}


logo=$(cat << "EOF"
 
       _         _   _            _______                     _ 
      | |  /\   | \ | |   /\     |__   __|                   | |
      | | /  \  |  \| |  /  \       | |_   _ _   _ _ __   ___| |
  _   | |/ /\ \ | . ` | / /\ \      | | | | | | | | '_ \ / _ \ |
 | |__| / ____ \| |\  |/ ____ \     | | |_| | |_| | | | |  __/ |
  \____/_/    \_\_| \_/_/    \_\    |_|\__,_|\__,_|_| |_|\___|_|

EOF
)

logo() {
echo -e "\033[1;94m$logo\033[0m"
}

while true; do
    linux_version=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    kernel_version=$(uname -r)
    tg_title="https://t.me/OPIranCluB"
    yt_title="youtube.com/@opiran-inistitute"
    clear
    logo
    echo -e "\e[93m╔═══════════════════════════════════════════════╗\e[0m"  
    echo -e "\e[93m║            \e[96mWireguard Menu Tunnel              \e[93m║\e[0m"   
    echo -e "\e[93m╠═══════════════════════════════════════════════╣\e[0m"
    echo ""
    echo -e "${GREEN} 1) ${NC} Configure WireGuard Server ${NC}"
    echo -e "${GREEN} 2) ${NC} Configure WireGuard Client ${NC}"
    echo ""
    echo -e "${GREEN} 3) ${NC} Add Client To Peers (Run in Wireguard Server) ${NC}"
    echo -e "${GREEN} 4) ${NC} Show Peers ${NC}"
    echo ""
    echo -e "${GREEN} 5) ${NC} Start WireGuard Service ${NC}"
    echo -e "${GREEN} 6) ${NC} Restart WireGuard Service ${NC}"
    echo -e "${GREEN} 7) ${NC} Stop WireGuard Service ${NC}"
    echo -e "${GREEN} 8) ${NC} Status WireGuard Service ${NC}"
    printf "\e[93m+-----------------------------------------------+\e[0m\n" 
    echo ""
    echo -e "${CYAN} 9)  ${MAGENTA} Show PublicKey  ${MAGENTA}"
    echo -e "${CYAN} 10) ${MAGENTA} Show PrivateKey ${MAGENTA}"
    echo ""
    echo -e "${GREEN} 11) ${NC} Uninstall Script${NC}"
    echo ""
    echo -e "${GREEN} E) ${NC}  Exit the menu${NC}"
    echo ""
    echo -ne "${GREEN}Select an option: ${NC}  "
    read choice
    echo ""
    echo ""
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
	   show_peers
	    ;;
        5)
            start_wireguard_service
            ;;
        6)
            restart_wireguard_service
            ;;
        7)
            stop_wireguard_service
            ;;
        8)
            show_wireguard_status
            ;;
        9)
            show_public_key
            ;;
        10)
            show_private_key
            ;;
	11)
	    uninstall_script
	    exit 0
	    ;;
        E|e)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a valid option."
            ;;
    esac

    echo -e "\n${RED}Press Enter to continue... ${NC}"
    read
done
