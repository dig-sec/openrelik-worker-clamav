#!/bin/bash
# Utgard Lab Startup Helper
# Provisions the 3-VM malware analysis lab with proper network setup
# 
# IMPORTANT: This script requires sudo for network bridge creation
# The first time you run this, you'll need to provide your password

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

# Lab network IPs (internal access)
FIREWALL_IP="$(utgard_config_get 'lab.firewall_ip' '10.20.0.2')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"

# Load Mullvad config (if present) so vagrant can pass it to the firewall
utgard_load_mullvad_conf

RED="$UTGARD_RED"
GREEN="$UTGARD_GREEN"
YELLOW="$UTGARD_YELLOW"
BLUE="$UTGARD_BLUE"
NC="$UTGARD_NC"

utgard_banner "Utgard Lab Provisioning Assistant"

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
echo "  2. Provision firewall VM (2GB RAM, 2 CPU) - network gateway & Mullvad WireGuard"
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
        echo -e "${GREEN}[OK] Network is active${NC}"
    else
        echo -e "${YELLOW}Network defined but not active - activating...${NC}"
        sudo virsh net-start utgard-lab
        echo -e "${GREEN}[OK] Network activated${NC}"
    fi
else
    echo -e "${YELLOW}not found - creating...${NC}"
    
    # Define and start the network from repo config
    sudo virsh net-define "$ROOT_DIR/network.xml"
    sudo virsh net-start utgard-lab
    echo -e "${GREEN}[OK] Network created and started${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Provisioning virtual machines...${NC}"
echo "(This takes 30-45 minutes the first time)"
echo ""

cd "$ROOT_DIR"

# Run vagrant up (firewall first for routing)
if utgard_vagrant_up_ordered; then
    echo ""
    echo -e "${GREEN}[OK] All VMs provisioned successfully${NC}"
    echo ""
    echo -e "${BLUE}Access your lab (lab network only 10.20.0.0/24):${NC}"
    echo "  - OpenRelik UI:  http://${OPENRELIK_IP}:8711/"
    echo "  - OpenRelik API: http://${OPENRELIK_IP}:8710/api/v1/docs/"
    echo "  - Neko Tor: http://${NEKO_IP}:8080/"
    echo "  - Neko Chromium: http://${NEKO_IP}:8090/"
    echo ""
    echo -e "${BLUE}External access:${NC}"
    echo "  - Use Pangolin routes configured in docs/PANGOLIN-ACCESS.md"
    echo ""
    echo -e "${BLUE}Neko Credentials:${NC}"
    echo "  - User: neko | Admin: admin"
    echo ""
    echo -e "${BLUE}Mullvad VPN routing:${NC}"
    echo "  - Place your config at provision/mullvad-wg0.conf (or set MULLVAD_WG_CONF) before provisioning"
    echo "  - Current status: $( [ -n "${MULLVAD_WG_CONF:-}" ] && echo 'loaded' || echo 'not loaded' )"
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
