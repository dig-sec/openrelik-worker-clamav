#!/bin/bash
# Deploy and test Utgard Lab
# Fully automates network creation, VM provisioning, and service testing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Utgard Lab - Full Deploy & Test Suite             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Create network
echo -e "${BLUE}Step 1: Network Setup${NC}"
if virsh net-list 2>/dev/null | grep -q "utgard-lab"; then
    echo -e "${GREEN}✓ Network already defined${NC}"
    if virsh net-list 2>/dev/null | grep "utgard-lab" | grep -q "active"; then
        echo -e "${GREEN}✓ Network is active${NC}"
    else
        echo "Starting network..."
        sudo virsh net-start utgard-lab
        echo -e "${GREEN}✓ Network started${NC}"
    fi
else
    echo "Creating network..."
    sudo virsh net-define network.xml
    sudo virsh net-start utgard-lab
    echo -e "${GREEN}✓ Network created and started${NC}"
fi
echo ""

# Step 2: Clean old VMs
echo -e "${BLUE}Step 2: Cleanup${NC}"
if [ -d ".vagrant" ]; then
    echo "Removing old .vagrant directory..."
    rm -rf .vagrant
    echo -e "${GREEN}✓ Cleaned${NC}"
else
    echo -e "${GREEN}✓ No old artifacts${NC}"
fi
echo ""

# Step 3: Provision VMs
echo -e "${BLUE}Step 3: VM Provisioning${NC}"
echo -e "${YELLOW}This takes 30-45 minutes on first run...${NC}"
echo ""
vagrant up
echo ""
echo -e "${GREEN}✓ VMs provisioned${NC}"
echo ""

# Step 4: Wait for services to stabilize
echo -e "${BLUE}Step 4: Service Stabilization${NC}"
echo "Waiting 10 seconds for services to initialize..."
sleep 10
echo -e "${GREEN}✓ Ready to test${NC}"
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
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    echo ""
    echo -e "${GREEN}Services are ready:${NC}"
    echo "  • Web UI:    http://localhost:8711/"
    echo "  • API:       http://localhost:8710/api/v1/docs/"
    echo "  • Guacamole: http://localhost:18080/guacamole/"
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check lab status: ./scripts/check-status.sh"
    echo "  2. See troubleshooting guide: docs/TROUBLESHOOTING-QUICK-FIX.md"
    echo "  3. View detailed test output above"
fi
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

exit $TEST_RESULT
