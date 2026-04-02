#!/usr/bin/env bash
set -euo pipefail

WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
CONFIG_DIR="/opt/justavpn/configs"

# First run: generate server config
if [ ! -f "$WG_DIR/$WG_INTERFACE.conf" ]; then
    echo "[*] First run - initializing WireGuard server..."

    SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:?SERVER_PUBLIC_IP env var required}"
    WG_PORT="${WG_PORT:-51820}"
    WG_SUBNET="${WG_SUBNET:-10.66.66.0/24}"
    WG_SERVER_IP="${WG_SUBNET%.*}.1"

    # Detect default interface
    DEFAULT_IFACE=$(ip -4 route show default | awk '{print $5}' | head -1)

    # Generate server keys
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

    mkdir -p "$CONFIG_DIR"
    echo "$SERVER_PUBLIC_KEY" > "$CONFIG_DIR/server_public.key"

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

    cat > "$CONFIG_DIR/server.env" << EOF
SERVER_PUBLIC_IP=$SERVER_PUBLIC_IP
SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
WG_PORT=$WG_PORT
WG_SUBNET=$WG_SUBNET
WG_SERVER_IP=$WG_SERVER_IP
DEFAULT_IFACE=$DEFAULT_IFACE
NEXT_IP=2
EOF

    echo "[*] Server initialized. Public key: $SERVER_PUBLIC_KEY"
fi

# Start WireGuard
echo "[*] Starting WireGuard..."
wg-quick up "$WG_INTERFACE"

# Handle shutdown gracefully
trap "wg-quick down $WG_INTERFACE; exit 0" SIGTERM SIGINT

# Start the management API
echo "[*] Starting management API on :8443..."
export CONFIG_DIR
justavpn-api &

# Wait for signals
wait
