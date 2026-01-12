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

PORT_OPENRELIK_UI="$(utgard_config_get 'ports.openrelik_ui' '8221')"
PORT_OPENRELIK_API="$(utgard_config_get 'ports.openrelik_api' '8222')"
PORT_GUACAMOLE="$(utgard_config_get 'ports.guacamole' '8223')"
PORT_NEKO_TOR="$(utgard_config_get 'ports.neko_tor' '8224')"
PORT_NEKO_CHROMIUM="$(utgard_config_get 'ports.neko_chromium' '8225')"

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

echo -e "${BLUE}=== OpenRelik Services ===${NC}"
test_http "OpenRelik UI (${PORT_OPENRELIK_UI})" "http://localhost:${PORT_OPENRELIK_UI}/"
test_http "OpenRelik API (${PORT_OPENRELIK_API})" "http://localhost:${PORT_OPENRELIK_API}/api/v1/docs/"

echo ""
echo -e "${BLUE}=== Guacamole Web Gateway ===${NC}"
test_http "Guacamole Web (${PORT_GUACAMOLE})" "http://localhost:${PORT_GUACAMOLE}/guacamole/"

echo ""
echo -e "${BLUE}=== Firewall Proxy Services ===${NC}"
test_port "nginx (${PORT_OPENRELIK_UI})" "localhost" "${PORT_OPENRELIK_UI}"
test_port "nginx (${PORT_OPENRELIK_API})" "localhost" "${PORT_OPENRELIK_API}"
echo -n "Skipping legacy RDP proxy (3389)... " && echo -e "${YELLOW}disabled${NC}"

echo ""
echo -e "${BLUE}=== Host Network Connectivity ===${NC}"
test_port "vagrant-libvirt eth0" "localhost" "22" || true

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

echo -n "Testing Neko Web UI (${PORT_NEKO_TOR})... "
if timeout $TIMEOUT curl -s -f "http://localhost:${PORT_NEKO_TOR}/" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing Neko Chromium UI (${PORT_NEKO_CHROMIUM})... "
if timeout $TIMEOUT curl -s -f "http://localhost:${PORT_NEKO_CHROMIUM}/" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
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
echo -e "${BLUE}=== Security Services ===${NC}"
echo -n "Testing nftables firewall... "
if vagrant ssh firewall -c "sudo nft list ruleset | grep -q filter" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing packet capture service... "
if vagrant ssh firewall -c "sudo systemctl status utgard-tcpdump" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (Service may not be running)"
    ((FAILED++))
fi

echo -n "Testing Suricata IDS... "
if vagrant ssh firewall -c "sudo systemctl status suricata" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (IDS may not be running)"
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
echo -e "${BLUE}=== Analysis Tools ===${NC}"
echo -n "Testing REMnux YARA installation... "
if vagrant ssh remnux -c "which yara" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing REMnux Volatility installation... "
if vagrant ssh remnux -c "which volatility3" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PASS${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARNING] WARNING${NC} (Volatility 3 not yet installed - may still be provisioning)"
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
    echo "Access services:"
    echo "  - OpenRelik UI: http://localhost:${PORT_OPENRELIK_UI}/"
    echo "  - OpenRelik API: http://localhost:${PORT_OPENRELIK_API}/api/v1/docs/"
    echo "  - Guacamole Web: http://localhost:${PORT_GUACAMOLE}/guacamole/"
    echo "  - Neko Tor Browser: http://localhost:${PORT_NEKO_TOR}/"
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
