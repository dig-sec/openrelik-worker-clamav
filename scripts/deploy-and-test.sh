#!/bin/bash
# Deploy and test Utgard Lab
# Fully automates network creation, VM provisioning, and service testing

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PORT_OPENRELIK_UI="$(utgard_config_get 'ports.openrelik_ui' '8221')"
PORT_OPENRELIK_API="$(utgard_config_get 'ports.openrelik_api' '8222')"
PORT_GUACAMOLE="$(utgard_config_get 'ports.guacamole' '8223')"

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
echo "Running 18+ automated connectivity tests..."
echo ""
./scripts/test-connections.sh
TEST_RESULT=$?

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}[DONE] ALL TESTS PASSED${NC}"
    echo ""
    echo -e "${GREEN}Services are ready:${NC}"
    echo "  • Web UI:    http://localhost:${PORT_OPENRELIK_UI}/"
    echo "  • API:       http://localhost:${PORT_OPENRELIK_API}/api/v1/docs/"
    echo "  • Guacamole: http://localhost:${PORT_GUACAMOLE}/guacamole/"
else
    echo -e "${RED}[ERROR] SOME TESTS FAILED${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check lab status: ./scripts/check-status.sh"
    echo "  2. See troubleshooting guide: docs/TROUBLESHOOTING-QUICK-FIX.md"
    echo "  3. View detailed test output above"
fi
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

exit $TEST_RESULT
