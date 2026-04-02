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

# Always write to stderr so these are never captured by $() in create_peer
log()  { echo "  $*" >&2; }
pass() { echo -e "  ${GREEN}✓${NC} $*" >&2; }
fail() { echo -e "  ${RED}✗${NC} $*" >&2; }

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

# $1 = api peer name, $2 = local config path (basename must be ≤15 chars for interface name)
create_peer() {
    local name="$1"
    local conf_path="$2"

    # Save response to temp file to avoid shell variable encoding issues
    local tmp_resp="/tmp/api_resp_$$.json"
    curl -sf \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\"}" \
        "$API_BASE/peers" > "$tmp_resp"

    log "Response size: $(wc -c < "$tmp_resp") bytes"
    log "Raw response:" >&2
    cat "$tmp_resp" >&2
    echo >&2

    jq -r '.clientConfig' "$tmp_resp" > "$conf_path"
    # Strip DNS line: wg-quick's DNS setup fails on CI runners (no resolvconf/systemd-resolved)
    # which causes it to exit before adding the IP address and routes.
    # Routing still works without it — DNS queries go through the tunnel via AllowedIPs=0.0.0.0/0.
    sed -i '/^DNS/d' "$conf_path"
    chmod 600 "$conf_path"
    log "Config ($(wc -c < "$conf_path") bytes):"
    cat "$conf_path" >&2

    local pub_key
    pub_key=$(jq -r '.peer.publicKey' "$tmp_resp")
    rm -f "$tmp_resp"
    echo "$pub_key"
}

debug_iface() {
    local iface
    iface=$(basename "$1" .conf)
    echo "  --- wg show $iface ---"
    sudo wg show "$iface" 2>/dev/null || echo "  (not found)"
    echo "  --- ip addr show $iface ---"
    ip addr show "$iface" 2>/dev/null || echo "  (not found)"
    echo "  --- ip route show dev $iface ---"
    ip route show dev "$iface" 2>/dev/null || echo "  (none)"
}

# Cross-platform ping: $1 = count, $2 = timeout (secs), $3 = host
do_ping() {
    local count="$1" timeout="$2" host="$3"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ping -c "$count" -t "$timeout" "$host"
    else
        ping -c "$count" -W "$timeout" "$host"
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

# Test 1: connect and disconnect
test_connect_disconnect() {
    # Interface names must be ≤15 chars. wgc-<pid> = max 11 chars.
    # API peer name can be longer (server-side only).
    local iface="wgc-$$"
    local api_name="ci-connect-$$"
    CLEANUP_CONF="/tmp/${iface}.conf"

    log "Creating peer '$api_name'..."
    CLEANUP_PUBKEY=$(create_peer "$api_name" "$CLEANUP_CONF")
    pass "Peer created (pubkey: ${CLEANUP_PUBKEY:0:16}...)"

    log "Config:"
    cat "$CLEANUP_CONF"

    log "Connecting..."
    sudo wg-quick up "$CLEANUP_CONF" || { fail "wg-quick up failed"; debug_iface "$CLEANUP_CONF"; return 1; }
    CLEANUP_WG_UP=true
    sleep 2

    log "Verifying WireGuard interface..."
    if ! sudo wg show "$iface" 2>/dev/null | grep -q "peer"; then
        fail "Peer not visible in wg show"
        debug_iface "$CLEANUP_CONF"
        return 1
    fi
    pass "WireGuard tunnel is up with peer"

    log "Disconnecting..."
    sudo wg-quick down "$CLEANUP_CONF"
    CLEANUP_WG_UP=false
    pass "Disconnected"

    cleanup
    return 0
}

# Test 2: connect, ping google.nl, disconnect
test_connect_ping_disconnect() {
    local iface="wgp-$$"
    local api_name="ci-ping-$$"
    CLEANUP_CONF="/tmp/${iface}.conf"

    log "Creating peer '$api_name'..."
    CLEANUP_PUBKEY=$(create_peer "$api_name" "$CLEANUP_CONF")
    pass "Peer created (pubkey: ${CLEANUP_PUBKEY:0:16}...)"

    log "Connecting..."
    sudo wg-quick up "$CLEANUP_CONF" || { fail "wg-quick up failed"; debug_iface "$CLEANUP_CONF"; return 1; }
    CLEANUP_WG_UP=true
    sleep 2

    log "Verifying tunnel (ping VPN gateway at 10.66.66.1)..."
    if ! do_ping 2 5 10.66.66.1; then
        fail "Cannot reach VPN gateway — tunnel may not be routing"
        debug_iface "$CLEANUP_CONF"
        return 1
    fi
    pass "VPN gateway reachable (10.66.66.1)"

    log "Pinging google.nl..."
    if ! do_ping 4 5 google.nl; then
        fail "Ping to google.nl failed"
        debug_iface "$CLEANUP_CONF"
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
