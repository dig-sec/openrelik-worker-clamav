#!/bin/bash
# Utgard Service Connection Tests
# Validates connectivity to all lab services
# Usage: ./scripts/test-connections.sh [timeout_seconds]

set -e

TIMEOUT=${1:-30}
FAILED=0
PASSED=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Utgard Lab Service Connection Tests                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Testing with ${TIMEOUT}s timeout per service"
echo ""

# Function to test HTTP endpoint
test_http() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "Testing ${name}... "
    
    if timeout $TIMEOUT curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
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
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

echo -e "${BLUE}=== OpenRelik Services ===${NC}"
test_http "OpenRelik UI (8711)" "http://localhost:8711/"
test_http "OpenRelik API (8710)" "http://localhost:8710/api/v1/docs/"

echo ""
echo -e "${BLUE}=== Guacamole Web Gateway ===${NC}"
test_http "Guacamole Web (18080)" "http://localhost:18080/guacamole/"

echo ""
echo -e "${BLUE}=== Firewall Proxy Services ===${NC}"
test_port "nginx (8710)" "localhost" "8710"
test_port "nginx (8711)" "localhost" "8711"
echo -n "Skipping legacy RDP proxy (3389)... " && echo -e "${YELLOW}disabled${NC}"

echo ""
echo -e "${BLUE}=== Host Network Connectivity ===${NC}"
test_port "vagrant-libvirt eth0" "localhost" "22" || true

echo ""
echo -e "${BLUE}=== Lab Network Services ===${NC}"
echo -n "Testing firewall connectivity... "
if vagrant ssh firewall -c "ip addr show eth0" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing OpenRelik connectivity... "
if vagrant ssh openrelik -c "docker ps" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing REMnux connectivity... "
if vagrant ssh remnux -c "systemctl status xrdp" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing Neko Tor Browser connectivity... "
if vagrant ssh neko -c "systemctl status neko" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing Neko Web UI (8080)... "
if timeout $TIMEOUT curl -s "http://localhost:8080/" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Network Isolation Tests ===${NC}"
echo -n "Testing lab network isolation (no direct external access)... "
if ! vagrant ssh openrelik -c "ping -c 1 8.8.8.8" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} (Good: lab has no direct internet)"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Lab has direct external access - may bypass Mullvad)"
fi

echo -n "Testing firewall route configuration... "
if vagrant ssh firewall -c "ip route | grep -q 10.20.0" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Security Services ===${NC}"
echo -n "Testing nftables firewall... "
if vagrant ssh firewall -c "sudo nft list ruleset | grep -q filter" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing packet capture service... "
if vagrant ssh firewall -c "sudo systemctl status lab-pcap" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (Service may not be running)"
    ((FAILED++))
fi

echo -n "Testing Suricata IDS... "
if vagrant ssh firewall -c "sudo systemctl status suricata" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (IDS may not be running)"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Mullvad VPN Tunnel ===${NC}"
echo -n "Testing WireGuard tunnel status... "
if vagrant ssh firewall -c "sudo wg show wg0" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
    
    # Extra check: verify tunnel has peer
    echo -n "Testing WireGuard peer configuration... "
    if vagrant ssh firewall -c "sudo wg show wg0 | grep -q peer" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (No WireGuard peer - Mullvad not configured)"
    fi
else
    echo -e "${YELLOW}⚠ WARNING${NC} (WireGuard interface not configured - expected if MULLVAD_WG_CONF not set)"
fi

echo -n "Testing lab traffic routing to firewall... "
if vagrant ssh openrelik -c "ip route | grep -q 'default via 10.20.0.1'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Analysis Tools ===${NC}"
echo -n "Testing REMnux YARA installation... "
if vagrant ssh remnux -c "which yara" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

echo -n "Testing REMnux Volatility installation... "
if vagrant ssh remnux -c "which volatility3" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Volatility 3 not yet installed - may still be provisioning)"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      TEST SUMMARY                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Passed: ${GREEN}${PASSED}${NC} | Failed: ${RED}${FAILED}${NC} | Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Lab is operational.${NC}"
    echo ""
    echo "Access services:"
    echo "  - OpenRelik UI: http://localhost:8711/"
    echo "  - OpenRelik API: http://localhost:8710/api/v1/docs/"
    echo "  - Guacamole Web: http://localhost:18080/guacamole/"
    echo "  - Neko Tor Browser: http://localhost:8080/"
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
