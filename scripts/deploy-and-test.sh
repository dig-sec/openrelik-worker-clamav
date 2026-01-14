#!/bin/bash
# Deploy and test Utgard Lab
# Fully automates network creation, VM provisioning, and service testing

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

# Lab network IPs (internal access)
FIREWALL_IP="$(utgard_config_get 'lab.firewall_ip' '10.20.0.2')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"

RED="$UTGARD_RED"
GREEN="$UTGARD_GREEN"
YELLOW="$UTGARD_YELLOW"
BLUE="$UTGARD_BLUE"
NC="$UTGARD_NC"

utgard_banner "Utgard Lab - Full Deploy & Test Suite"

# Step 1: Create network
echo -e "${BLUE}Step 1: Network Setup${NC}"
if virsh net-list 2>/dev/null | grep -q "utgard-lab"; then
    echo -e "${GREEN}[OK] Network already defined${NC}"
    if virsh net-list 2>/dev/null | grep "utgard-lab" | grep -q "active"; then
        echo -e "${GREEN}[OK] Network is active${NC}"
    else
        echo "Starting network..."
        sudo virsh net-start utgard-lab
        echo -e "${GREEN}[OK] Network started${NC}"
    fi
else
    echo "Creating network..."
    sudo virsh net-define network.xml
    sudo virsh net-start utgard-lab
    echo -e "${GREEN}[OK] Network created and started${NC}"
fi
echo ""

# Step 2: Clean old VMs
echo -e "${BLUE}Step 2: Cleanup${NC}"
if [ -d ".vagrant" ]; then
    echo "Removing old .vagrant directory..."
    rm -rf .vagrant
    echo -e "${GREEN}[OK] Cleaned${NC}"
else
    echo -e "${GREEN}[OK] No old artifacts${NC}"
fi
echo ""

# Step 3: Provision VMs
echo -e "${BLUE}Step 3: VM Provisioning${NC}"
echo -e "${YELLOW}This takes 30-45 minutes on first run...${NC}"
echo ""
utgard_vagrant_up_ordered
echo ""
echo -e "${GREEN}[OK] VMs provisioned${NC}"
echo ""

# Step 4: Wait for services to stabilize
echo -e "${BLUE}Step 4: Service Stabilization${NC}"
echo "Waiting 10 seconds for services to initialize..."
sleep 10
echo -e "${GREEN}[OK] Ready to test${NC}"
echo ""

# Step 5: Run tests
echo -e "${BLUE}Step 5: Service Testing${NC}"
echo "Running connectivity tests..."
echo ""
./scripts/test-connections.sh
TEST_RESULT=$?

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}[DONE] ALL TESTS PASSED${NC}"
    echo ""
    echo -e "${GREEN}Services are ready (lab network only):${NC}"
    echo "  • OpenRelik UI: http://${OPENRELIK_IP}:8711/"
    echo "  • OpenRelik API: http://${OPENRELIK_IP}:8710/api/v1/docs/"
    echo "  • Guacamole: http://${FIREWALL_IP}:8080/guacamole/"
    echo "  • Neko Tor: http://${NEKO_IP}:8080/"
    echo "  • Neko Chromium: http://${NEKO_IP}:8090/"
    echo ""
    echo "External access: use Pangolin routes configured in docs/PANGOLIN-ACCESS.md."
else
    echo -e "${RED}[ERROR] SOME TESTS FAILED${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check lab status: ./scripts/check-status.sh"
    echo "  2. View detailed test output above"
fi
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

exit $TEST_RESULT
