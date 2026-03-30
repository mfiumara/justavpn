#!/usr/bin/env bash
set -euo pipefail

# JustAVPN - WireGuard Server Setup
# Run this once on a fresh Linux VPS (Ubuntu 22.04+ / Debian 12+)

WG_INTERFACE="wg0"
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.66.66.0/24}"
WG_SERVER_IP="${WG_SUBNET%.*}.1"
WG_DIR="/etc/wireguard"
CONFIG_DIR="${CONFIG_DIR:-/opt/justavpn/configs}"

# Detect public IP
SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:-$(curl -s https://ifconfig.me)}"

# Detect default network interface
DEFAULT_IFACE=$(ip -4 route show default | awk '{print $5}' | head -1)

echo "=== JustAVPN Server Setup ==="
echo "Public IP:    $SERVER_PUBLIC_IP"
echo "WG Port:      $WG_PORT"
echo "WG Subnet:    $WG_SUBNET"
echo "Server IP:    $WG_SERVER_IP/24"
echo "Interface:    $DEFAULT_IFACE"
echo ""

# Install dependencies
if ! command -v wg &>/dev/null; then
    echo "[*] Installing WireGuard..."
    apt-get update
    apt-get install -y wireguard wireguard-tools qrencode
fi

# Enable IP forwarding
echo "[*] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
fi

# Generate server keys
echo "[*] Generating server keys..."
mkdir -p "$WG_DIR" "$CONFIG_DIR"
chmod 700 "$WG_DIR"

SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

# Save server public key for peer generation
echo "$SERVER_PUBLIC_KEY" > "$CONFIG_DIR/server_public.key"
chmod 600 "$CONFIG_DIR/server_public.key"

# Write WireGuard config
echo "[*] Writing $WG_DIR/$WG_INTERFACE.conf..."
cat > "$WG_DIR/$WG_INTERFACE.conf" << EOF
[Interface]
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY

PostUp = iptables -t nat -A POSTROUTING -s $WG_SUBNET -o $DEFAULT_IFACE -j MASQUERADE
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s $WG_SUBNET -o $DEFAULT_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
EOF
chmod 600 "$WG_DIR/$WG_INTERFACE.conf"

# Enable and start WireGuard
echo "[*] Starting WireGuard..."
systemctl enable "wg-quick@$WG_INTERFACE"
systemctl start "wg-quick@$WG_INTERFACE"

# Open firewall port
if command -v ufw &>/dev/null; then
    echo "[*] Configuring UFW..."
    ufw allow "$WG_PORT/udp"
    ufw reload
fi

# Save server metadata
cat > "$CONFIG_DIR/server.env" << EOF
SERVER_PUBLIC_IP=$SERVER_PUBLIC_IP
SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
WG_PORT=$WG_PORT
WG_SUBNET=$WG_SUBNET
WG_SERVER_IP=$WG_SERVER_IP
DEFAULT_IFACE=$DEFAULT_IFACE
NEXT_IP=2
EOF
chmod 600 "$CONFIG_DIR/server.env"

echo ""
echo "=== Setup Complete ==="
echo "Server Public Key: $SERVER_PUBLIC_KEY"
echo "Endpoint:          $SERVER_PUBLIC_IP:$WG_PORT"
echo ""
echo "Next: run generate-peer.sh <peer-name> to create client configs"
