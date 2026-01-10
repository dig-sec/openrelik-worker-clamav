#!/bin/bash
# Utgard Lab Status Checker
# Shows current state of network, VMs, and services
# No VMs? Shows what needs to be done to start them

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Utgard Lab Infrastructure Status                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check libvirt daemon
echo -n "Checking libvirt daemon... "
if systemctl is-active --quiet libvirtd; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo "  Fix: sudo systemctl start libvirtd"
fi

# Check network status
echo -n "Checking utgard-lab network... "
if virsh net-list | grep -q "utgard-lab"; then
    if virsh net-list | grep "utgard-lab" | grep -q "active"; then
        echo -e "${GREEN}✓ Active${NC}"
    else
        echo -e "${YELLOW}⚠ Defined but not active${NC}"
        echo "  Fix: sudo virsh net-start utgard-lab"
    fi
else
    echo -e "${RED}✗ Network not defined${NC}"
    echo "  This shouldn't happen - check Vagrantfile"
fi

# Check VM status
echo ""
echo -e "${BLUE}Virtual Machines:${NC}"
vm_count=$(virsh list --all 2>/dev/null | grep -c utgard || echo 0)

if [ "$vm_count" -eq 0 ]; then
    echo -e "  ${YELLOW}No Utgard VMs found${NC}"
    echo ""
    echo -e "${YELLOW}To provision VMs:${NC}"
    echo "  1. Start the network (requires sudo):"
    echo "     ${BLUE}sudo virsh net-start utgard-lab${NC}"
    echo ""
    echo "  2. Provision the VMs (takes ~45 minutes first time):"
    echo "     ${BLUE}vagrant up${NC}"
    echo ""
    echo "  Or use the automated helper:"
    echo "     ${BLUE}./scripts/start-lab.sh${NC}"
else
    virsh list --all 2>/dev/null | grep utgard | while read -r line; do
        name=$(echo $line | awk '{print $2}')
        state=$(echo $line | awk '{print $3}')
        
        if [ "$state" == "running" ]; then
            echo -e "  ${GREEN}✓${NC} ${name} (${GREEN}running${NC})"
        else
            echo -e "  ${RED}✗${NC} ${name} (${RED}${state}${NC})"
        fi
    done
fi

# Check Docker on OpenRelik
echo ""
echo -e "${BLUE}Services:${NC}"

# Try to check OpenRelik
echo -n "  OpenRelik container... "
if vagrant ssh openrelik -c "docker ps 2>/dev/null | grep -q openrelik" 2>/dev/null; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${YELLOW}⚠ Not running or unreachable${NC}"
fi

# Check Guacamole Web Gateway
echo -n "  Guacamole Web (firewall:18080)... "
if vagrant ssh firewall -c "curl -fsS http://localhost:18080/guacamole/ >/dev/null" 2>/dev/null; then
    echo -e "${GREEN}✓ Reachable${NC}"
else
    echo -e "${YELLOW}⚠ Not reachable${NC}"
fi

# Try to check firewall services
echo -n "  Firewall nftables... "
if vagrant ssh firewall -c "sudo nft list ruleset > /dev/null 2>&1" 2>/dev/null; then
    echo -e "${GREEN}✓ Configured${NC}"
else
    echo -e "${YELLOW}⚠ Not running or unreachable${NC}"
fi

echo ""
echo -e "${BLUE}Networking:${NC}"

# Get host IP for lab network
lab_net=$(virsh net-dumpxml utgard-lab 2>/dev/null | grep -oP '<ip address="\K[^"]+' || echo "not found")
echo "  Lab network (utgard-lab): 10.20.0.0/24"
echo "    - Gateway IP: 10.20.0.1 (firewall)"
echo "    - OpenRelik: 10.20.0.30"
echo "    - REMnux: 10.20.0.20"

echo ""
echo -e "${BLUE}When Services Are Up:${NC}"
echo "  - OpenRelik UI: http://localhost:8711/"
echo "  - OpenRelik API: http://localhost:8710/api/v1/docs/"
echo "  - Guacamole Web: http://localhost:18080/guacamole/"
echo ""
echo "  Test connectivity: ./scripts/test-connections.sh"
echo ""

# Check if user is in libvirt group
if groups | grep -q libvirt; then
    echo -e "${GREEN}✓ User in libvirt group${NC}"
else
    echo -e "${YELLOW}⚠ User not in libvirt group${NC}"
    echo "  Fix: sudo usermod -aG libvirt \$USER (then log out/in)"
fi

# Check if vagrant is available
if command -v vagrant &> /dev/null; then
    vagrant_ver=$(vagrant version | head -1)
    echo -e "${GREEN}✓ ${vagrant_ver}${NC}"
else
    echo -e "${RED}✗ Vagrant not installed${NC}"
fi

# Check if vagrant-libvirt is available
if vagrant plugin list 2>/dev/null | grep -q libvirt; then
    echo -e "${GREEN}✓ vagrant-libvirt plugin installed${NC}"
else
    echo -e "${YELLOW}⚠ vagrant-libvirt plugin may not be installed${NC}"
fi

echo ""
