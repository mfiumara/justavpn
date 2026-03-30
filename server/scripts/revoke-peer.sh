#!/usr/bin/env bash
set -euo pipefail

# JustAVPN - Revoke a WireGuard peer

WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
CONFIG_DIR="${CONFIG_DIR:-/opt/justavpn/configs}"

PEER_NAME="${1:-}"
if [ -z "$PEER_NAME" ]; then
    echo "Usage: $0 <peer-name>"
    exit 1
fi

PEER_DIR="$CONFIG_DIR/peers/$PEER_NAME"
if [ ! -d "$PEER_DIR" ]; then
    echo "Error: peer '$PEER_NAME' not found"
    exit 1
fi

# Get peer public key
source "$PEER_DIR/metadata.env"

# Remove peer block from config (the comment line + the 4 config lines)
sed -i "/^# Peer: $PEER_NAME$/,/^$/d" "$WG_DIR/$WG_INTERFACE.conf"

# Also remove the peer from the running interface
wg set "$WG_INTERFACE" peer "$PEER_PUBLIC_KEY" remove

# Remove peer files
rm -rf "$PEER_DIR"

echo "Peer '$PEER_NAME' revoked and removed."
