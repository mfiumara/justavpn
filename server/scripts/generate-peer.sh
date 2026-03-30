#!/usr/bin/env bash
set -euo pipefail

# JustAVPN - Generate a new WireGuard peer

WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
CONFIG_DIR="${CONFIG_DIR:-/opt/justavpn/configs}"
DNS="${DNS:-1.1.1.1, 1.0.0.1}"

PEER_NAME="${1:-}"
if [ -z "$PEER_NAME" ]; then
    echo "Usage: $0 <peer-name>"
    echo "Example: $0 iphone"
    exit 1
fi

# Load server metadata
if [ ! -f "$CONFIG_DIR/server.env" ]; then
    echo "Error: server.env not found. Run setup.sh first."
    exit 1
fi
source "$CONFIG_DIR/server.env"

# Check for duplicate peer name
if [ -d "$CONFIG_DIR/peers/$PEER_NAME" ]; then
    echo "Error: peer '$PEER_NAME' already exists"
    exit 1
fi

# Allocate next IP
PEER_IP="${WG_SUBNET%.*}.$NEXT_IP"
NEXT_IP=$((NEXT_IP + 1))

# Update NEXT_IP in server.env
sed -i "s/^NEXT_IP=.*/NEXT_IP=$NEXT_IP/" "$CONFIG_DIR/server.env"

# Generate peer keys
PEER_PRIVATE_KEY=$(wg genkey)
PEER_PUBLIC_KEY=$(echo "$PEER_PRIVATE_KEY" | wg pubkey)
PEER_PRESHARED_KEY=$(wg genpsk)

# Add peer to server config
cat >> "$WG_DIR/$WG_INTERFACE.conf" << EOF

# Peer: $PEER_NAME
[Peer]
PublicKey = $PEER_PUBLIC_KEY
PresharedKey = $PEER_PRESHARED_KEY
AllowedIPs = $PEER_IP/32
EOF

# Reload WireGuard without downtime
wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")

# Create client config
mkdir -p "$CONFIG_DIR/peers/$PEER_NAME"

CLIENT_CONF="$CONFIG_DIR/peers/$PEER_NAME/$PEER_NAME.conf"
cat > "$CLIENT_CONF" << EOF
[Interface]
PrivateKey = $PEER_PRIVATE_KEY
Address = $PEER_IP/32
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PEER_PRESHARED_KEY
Endpoint = $SERVER_PUBLIC_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
chmod 600 "$CLIENT_CONF"

# Save peer metadata
cat > "$CONFIG_DIR/peers/$PEER_NAME/metadata.env" << EOF
PEER_NAME=$PEER_NAME
PEER_PUBLIC_KEY=$PEER_PUBLIC_KEY
PEER_IP=$PEER_IP
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo ""
echo "=== Peer '$PEER_NAME' Created ==="
echo "IP Address: $PEER_IP"
echo "Public Key: $PEER_PUBLIC_KEY"
echo ""
echo "--- Client Config ---"
cat "$CLIENT_CONF"
echo ""

# Show QR code if qrencode is available
if command -v qrencode &>/dev/null; then
    echo "--- QR Code (scan with phone) ---"
    qrencode -t ansiutf8 < "$CLIENT_CONF"
fi
