#!/bin/bash
# Utgard Service Connection Tests
# Validates connectivity to all lab services
# Usage: ./scripts/test-connections.sh [timeout_seconds]

set -u

TIMEOUT=${1:-30}
FAILED=0
PASSED=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

GREEN="$UTGARD_GREEN"
RED="$UTGARD_RED"
YELLOW="$UTGARD_YELLOW"
BLUE="$UTGARD_BLUE"
NC="$UTGARD_NC" # No Color

LAB_NETWORK="$(utgard_config_get 'lab.network' '10.20.0.0/24')"
FW_IP="$(utgard_config_get 'lab.gateway_ip' '10.20.0.1')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"
OPENRELIK_UI_PORT="$(utgard_config_get 'ports_internal.openrelik_ui' '8711')"
OPENRELIK_API_PORT="$(utgard_config_get 'ports_internal.openrelik_api' '8710')"
NEKO_TOR_PORT="$(utgard_config_get 'ports_internal.neko_tor' '8080')"
NEKO_CHROMIUM_PORT="$(utgard_config_get 'ports_internal.neko_chromium' '8090')"

LAB_ROUTE_READY=0
if ip route 2>/dev/null | grep -q "${LAB_NETWORK}"; then
    LAB_ROUTE_READY=1
fi

utgard_banner "Utgard Lab Service Connection Tests"
echo "Testing with ${TIMEOUT}s timeout per service"
echo ""

# Function to test HTTP endpoint
test_http() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "Testing ${name}... "
    
    if timeout $TIMEOUT curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}[OK] PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

# Function to test port connectivity
test_port() {
    local name=$1
    local host=$2
    local port=$3
    
    echo -n "Testing ${name}... "
    
    if timeout $TIMEOUT bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}[OK] PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

echo -e "${BLUE}=== Direct Lab Network Access ===${NC}"
if [ "$LAB_ROUTE_READY" -eq 1 ]; then
    test_http "OpenRelik UI (${OPENRELIK_IP}:${OPENRELIK_UI_PORT})" "http://${OPENRELIK_IP}:${OPENRELIK_UI_PORT}/"
    test_http "OpenRelik API (${OPENRELIK_IP}:${OPENRELIK_API_PORT})" "http://${OPENRELIK_IP}:${OPENRELIK_API_PORT}/api/v1/docs/"
    echo ""
    test_http "Neko Tor UI (${NEKO_IP}:${NEKO_TOR_PORT})" "http://${NEKO_IP}:${NEKO_TOR_PORT}/"
    test_http "Neko Chromium UI (${NEKO_IP}:${NEKO_CHROMIUM_PORT})" "http://${NEKO_IP}:${NEKO_CHROMIUM_PORT}/"
else
    echo -e "${YELLOW}[WARN]${NC} No route to ${LAB_NETWORK} found; skipping direct access checks."
fi

echo ""
echo -e "${BLUE}=== Lab Network Services ===${NC}"
echo -n "Testing firewall connectivity... "
if vagrant ssh firewall -c "ip addr show eth0" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing OpenRelik connectivity... "
if vagrant ssh openrelik -c "docker ps" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing REMnux connectivity... "
if vagrant ssh remnux -c "systemctl status xrdp" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing Neko Tor Browser connectivity... "
if vagrant ssh neko -c "sudo docker ps --format '{{.Names}}' | grep -q 'neko-'" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

if [ "$LAB_ROUTE_READY" -eq 1 ]; then
    echo -n "Testing Neko Web UI (${NEKO_IP}:${NEKO_TOR_PORT})... "
    if timeout $TIMEOUT curl -s -f "http://${NEKO_IP}:${NEKO_TOR_PORT}/" > /dev/null 2>&1; then
        echo -e "${GREEN}[OK] PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi

    echo -n "Testing Neko Chromium UI (${NEKO_IP}:${NEKO_CHROMIUM_PORT})... "
    if timeout $TIMEOUT curl -s -f "http://${NEKO_IP}:${NEKO_CHROMIUM_PORT}/" > /dev/null 2>&1; then
        echo -e "${GREEN}[OK] PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi
fi

echo ""
echo -e "${BLUE}=== Network Isolation Tests ===${NC}"
echo -n "Testing lab network isolation (no direct external access)... "
if ! vagrant ssh openrelik -c "ping -c 1 8.8.8.8" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC} (Good: lab has no direct internet)"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARNING] WARNING${NC} (Lab has direct external access - may bypass Mullvad)"
fi

echo -n "Testing firewall route configuration... "
if vagrant ssh firewall -c "ip route | grep -q 10.20.0" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Mullvad VPN Tunnel ===${NC}"
echo -n "Testing WireGuard tunnel status... "
if vagrant ssh firewall -c "sudo wg show wg0" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
    
    # Extra check: verify tunnel has peer
    echo -n "Testing WireGuard peer configuration... "
    if vagrant ssh firewall -c "sudo wg show wg0 | grep -q peer" > /dev/null 2>&1; then
        echo -e "${GREEN}[OK] PASS${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}[WARNING] WARNING${NC} (No WireGuard peer - Mullvad not configured)"
    fi
else
    echo -e "${YELLOW}[WARNING] WARNING${NC} (WireGuard interface not configured - expected if MULLVAD_WG_CONF not set)"
fi

echo -n "Testing lab traffic routing to firewall... "
if vagrant ssh openrelik -c "ip route | grep -q 'default via 10.20.0.1'" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      TEST SUMMARY                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Passed: ${GREEN}${PASSED}${NC} | Failed: ${RED}${FAILED}${NC} | Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}[OK] All tests passed! Lab is operational.${NC}"
    echo ""
    echo "Internal service endpoints (lab network only):"
    echo "  - OpenRelik UI: http://${OPENRELIK_IP}:${OPENRELIK_UI_PORT}/"
    echo "  - OpenRelik API: http://${OPENRELIK_IP}:${OPENRELIK_API_PORT}/api/v1/docs/"
    echo "  - Neko Tor Browser: http://${NEKO_IP}:${NEKO_TOR_PORT}/"
    echo ""
    echo "External access: use Pangolin routes configured in docs/PANGOLIN-ACCESS.md."
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Check output above.${NC}"
    echo ""
    echo "Common issues:"
    echo "  - VMs not running: Run './scripts/start-lab.sh' first"
    echo "  - Services not ready: First boot takes 30-45 minutes"
    echo "  - Mullvad not configured: Set MULLVAD_WG_CONF environment variable"
    exit 1
fi
