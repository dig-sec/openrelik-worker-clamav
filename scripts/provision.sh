#!/bin/bash
# Utgard Lab Startup Helper
# Provisions the 3-VM malware analysis lab with proper network setup
# 
# IMPORTANT: This script requires sudo for network bridge creation
# The first time you run this, you'll need to provide your password

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Utgard Lab Provisioning Assistant                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if user is in libvirt group
if ! groups | grep -q libvirt; then
    echo -e "${RED}ERROR: User is not in libvirt group${NC}"
    echo ""
    echo "Fix with:"
    echo "  sudo usermod -aG libvirt \$USER"
    echo "  newgrp libvirt"
    echo ""
    exit 1
fi

# Check if vagrant is installed
if ! command -v vagrant &> /dev/null; then
    echo -e "${RED}ERROR: Vagrant not installed${NC}"
    exit 1
fi

# Check if vagrant-libvirt plugin is installed
if ! vagrant plugin list | grep -q libvirt; then
    echo -e "${YELLOW}Installing vagrant-libvirt plugin...${NC}"
    vagrant plugin install vagrant-libvirt
fi

echo "This script will:"
echo "  1. Create the utgard-lab network (requires sudo for bridge creation)"
echo "  2. Provision firewall VM (2GB RAM, 2 CPU) - reverse proxy & network gateway"
echo "  3. Provision openrelik VM (4GB RAM, 2 CPU) - artifact analysis"
echo "  4. Provision remnux VM (4GB RAM, 2 CPU) - malware analysis tools"
echo "  5. Provision neko VM (3GB RAM, 2 CPU) - Tor & Chromium browsers"
echo ""
echo -e "${YELLOW}First provisioning will take 30-45 minutes.${NC}"
echo ""

read -p "Ready to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"

# Verify libvirtd is running
if ! systemctl is-active --quiet libvirtd; then
    echo -n "Starting libvirtd... "
    sudo systemctl start libvirtd
    echo -e "${GREEN}done${NC}"
fi

# Create network if it doesn't exist
echo -n "Checking for utgard-lab network... "
if virsh net-list 2>/dev/null | grep -q "utgard-lab"; then
    echo -e "${GREEN}already defined${NC}"
    
    # Check if it's active
    if virsh net-list 2>/dev/null | grep "utgard-lab" | grep -q "active"; then
        echo -e "${GREEN}✓ Network is active${NC}"
    else
        echo -e "${YELLOW}Network defined but not active - activating...${NC}"
        sudo virsh net-start utgard-lab
        echo -e "${GREEN}✓ Network activated${NC}"
    fi
else
    echo -e "${YELLOW}not found - creating...${NC}"
    
    # Define and start the network from repo config
    sudo virsh net-define "$ROOT_DIR/network.xml"
    sudo virsh net-start utgard-lab
    echo -e "${GREEN}✓ Network created and started${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Provisioning virtual machines...${NC}"
echo "(This takes 30-45 minutes the first time)"
echo ""

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Run vagrant up
if vagrant up; then
    echo ""
    echo -e "${GREEN}✓ All VMs provisioned successfully${NC}"
    echo ""
    echo -e "${BLUE}Access your lab:${NC}"
    echo "  - Neko Tor Browser: http://localhost:8080/"
    echo "  - Neko Chromium Browser: http://localhost:8090/"
    echo "  - OpenRelik UI:  http://localhost:8711/"
    echo "  - OpenRelik API: http://localhost:8710/api/v1/docs/"
    echo "  - Guacamole Web: http://localhost:18080/guacamole/"
    echo ""
    echo -e "${BLUE}Neko Credentials:${NC}"
    echo "  - User: neko | Admin: admin"
    echo ""
    echo -e "${BLUE}Enable WireGuard/Mullvad VPN routing (optional):${NC}"
    echo "  export MULLVAD_WG_CONF=\"\$(cat /path/to/mullvad.wg)\""
    echo "  vagrant provision firewall"
    echo ""
    echo -e "${BLUE}Verify services are up:${NC}"
    echo "  ./scripts/test-connections.sh"
    echo ""
    echo -e "${BLUE}Check lab status:${NC}"
    echo "  ./scripts/check-status.sh"
    echo ""
    echo -e "${BLUE}Rebuild lab from scratch:${NC}"
    echo "  ./scripts/rebuild-lab.sh"
    echo ""
    echo -e "${BLUE}Stop the lab:${NC}"
    echo "  vagrant halt"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}✗ Provisioning failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. Network permission error"
    echo "     → Requires sudo for virsh commands"
    echo "     → You may need to provide password"
    echo ""
    echo "  2. Disk space"
    echo "     → 40GB free space recommended"
    echo ""
    echo "  3. Ansible not found"
    echo "     → Install: sudo apt install ansible"
    echo ""
    echo "Check for more details in the output above."
    exit 1
fi
