#!/usr/bin/env bash
set -euo pipefail

# JustAVPN integration tests
# Requires: wg-quick, jq, curl, sudo
# Env vars:
#   API_TOKEN   - bearer token for the management API (required)
#   SERVER_HOST - VPN server IP (default: 91.98.139.162)

SERVER_HOST="${SERVER_HOST:-91.98.139.162}"
API_BASE="http://${SERVER_HOST}:8443/api/v1"

PASS=0
FAIL=0

# Global cleanup state
CLEANUP_CONF=""
CLEANUP_PUBKEY=""
CLEANUP_WG_UP=false

# ── helpers ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo "  $*"; }
pass() { echo -e "  ${GREEN}✓${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; }

check_deps() {
    local missing=()
    for cmd in curl jq wg-quick sudo; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: missing required commands: ${missing[*]}"
        exit 1
    fi
    if [ -z "${API_TOKEN:-}" ]; then
        echo "Error: API_TOKEN environment variable is required"
        exit 1
    fi
}

cleanup() {
    if $CLEANUP_WG_UP && [ -n "$CLEANUP_CONF" ]; then
        sudo wg-quick down "$CLEANUP_CONF" 2>/dev/null || true
        CLEANUP_WG_UP=false
    fi
    if [ -n "$CLEANUP_PUBKEY" ]; then
        curl -sf -X DELETE \
            -H "Authorization: Bearer $API_TOKEN" \
            "$API_BASE/peers/$CLEANUP_PUBKEY" >/dev/null 2>&1 || true
        CLEANUP_PUBKEY=""
    fi
    if [ -n "$CLEANUP_CONF" ]; then
        rm -f "$CLEANUP_CONF"
        CLEANUP_CONF=""
    fi
}
trap cleanup EXIT

create_peer() {
    local name="$1"
    local conf_path="$2"

    local response
    response=$(curl -sf \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\"}" \
        "$API_BASE/peers")

    echo "$response" | jq -r '.clientConfig' > "$conf_path"
    chmod 600 "$conf_path"
    echo "$response" | jq -r '.peer.publicKey'
}

ping_host() {
    local host="$1"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ping -c 4 -t 10 "$host"
    else
        ping -c 4 -W 10 "$host"
    fi
}

run_test() {
    local name="$1"
    local fn="$2"
    echo ""
    echo -e "${YELLOW}TEST:${NC} $name"
    if $fn; then
        echo -e "  ${GREEN}PASS${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}"
        FAIL=$((FAIL + 1))
        cleanup
    fi
}

# ── tests ─────────────────────────────────────────────────────────────────────

test_connect_disconnect() {
    local peer_name="test-connect-$$"
    CLEANUP_CONF="/tmp/${peer_name}.conf"

    log "Creating peer '$peer_name'..."
    CLEANUP_PUBKEY=$(create_peer "$peer_name" "$CLEANUP_CONF")
    pass "Peer created (pubkey: ${CLEANUP_PUBKEY:0:16}...)"

    log "Connecting to VPN..."
    sudo wg-quick up "$CLEANUP_CONF"
    CLEANUP_WG_UP=true
    pass "WireGuard interface is up"

    log "Verifying interface..."
    sudo wg show | grep -q "peer" || { fail "No peers visible in wg show"; return 1; }
    pass "Peer handshake visible"

    log "Disconnecting..."
    sudo wg-quick down "$CLEANUP_CONF"
    CLEANUP_WG_UP=false
    pass "Disconnected"

    cleanup
    return 0
}

test_connect_ping_disconnect() {
    local peer_name="test-ping-$$"
    CLEANUP_CONF="/tmp/${peer_name}.conf"

    log "Creating peer '$peer_name'..."
    CLEANUP_PUBKEY=$(create_peer "$peer_name" "$CLEANUP_CONF")
    pass "Peer created (pubkey: ${CLEANUP_PUBKEY:0:16}...)"

    log "Connecting to VPN..."
    sudo wg-quick up "$CLEANUP_CONF"
    CLEANUP_WG_UP=true
    pass "WireGuard interface is up"

    log "Pinging google.nl..."
    if ! ping_host google.nl; then
        fail "Ping to google.nl failed"
        return 1
    fi
    pass "Ping to google.nl succeeded"

    log "Disconnecting..."
    sudo wg-quick down "$CLEANUP_CONF"
    CLEANUP_WG_UP=false
    pass "Disconnected"

    cleanup
    return 0
}

# ── main ──────────────────────────────────────────────────────────────────────

main() {
    check_deps
    echo "JustAVPN Integration Tests"
    echo "Server: $SERVER_HOST"

    run_test "connect and disconnect" test_connect_disconnect
    run_test "connect, ping google.nl, disconnect" test_connect_ping_disconnect

    echo ""
    echo "────────────────────────────"
    if [ "$FAIL" -eq 0 ]; then
        echo -e "${GREEN}All $PASS tests passed${NC}"
    else
        echo -e "${RED}$FAIL failed${NC}, $PASS passed"
        exit 1
    fi
}

main
