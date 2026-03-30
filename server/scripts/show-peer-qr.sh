#!/usr/bin/env bash
set -euo pipefail

# JustAVPN - Show QR code for an existing peer

CONFIG_DIR="${CONFIG_DIR:-/opt/justavpn/configs}"

PEER_NAME="${1:-}"
if [ -z "$PEER_NAME" ]; then
    echo "Usage: $0 <peer-name>"
    exit 1
fi

CLIENT_CONF="$CONFIG_DIR/peers/$PEER_NAME/$PEER_NAME.conf"
if [ ! -f "$CLIENT_CONF" ]; then
    echo "Error: config for peer '$PEER_NAME' not found"
    exit 1
fi

if ! command -v qrencode &>/dev/null; then
    echo "Error: qrencode not installed. Install with: apt-get install qrencode"
    exit 1
fi

echo "=== QR Code for '$PEER_NAME' ==="
qrencode -t ansiutf8 < "$CLIENT_CONF"
echo ""
echo "--- Config ---"
cat "$CLIENT_CONF"
