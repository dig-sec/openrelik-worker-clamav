#!/bin/bash
# Utgard Lab Status Checker
# Shows current state of network, VMs, and services
# No VMs? Shows what needs to be done to start them

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

RED="$UTGARD_RED"
GREEN="$UTGARD_GREEN"
YELLOW="$UTGARD_YELLOW"
BLUE="$UTGARD_BLUE"
NC="$UTGARD_NC" # No Color

# Lab network IPs (internal access)
FIREWALL_IP="$(utgard_config_get 'lab.firewall_ip' '10.20.0.2')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
REMNUX_IP="$(utgard_config_get 'lab.remnux_ip' '10.20.0.20')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"

utgard_banner "Utgard Lab Infrastructure Status"

# Check libvirt daemon
echo -n "Checking libvirt daemon... "
if systemctl is-active --quiet libvirtd; then
    echo -e "${GREEN}[OK] Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo "  Fix: sudo systemctl start libvirtd"
fi

# Check network status
echo -n "Checking utgard-lab network... "
if virsh net-list | grep -q "utgard-lab"; then
    if virsh net-list | grep "utgard-lab" | grep -q "active"; then
        echo -e "${GREEN}[OK] Active${NC}"
    else
        echo -e "${YELLOW}[WARNING] Defined but not active${NC}"
        echo "  Fix: sudo virsh net-start utgard-lab"
    fi
else
    echo -e "${RED}✗ Network not defined${NC}"
    echo "  This shouldn't happen - check Vagrantfile"
fi

# Check VM status
echo ""
echo -e "${BLUE}Virtual Machines:${NC}"
vm_count=$(virsh list --all 2>/dev/null | grep -c "utgard" || true)
vm_count=${vm_count:-0}

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
            echo -e "  ${GREEN}[OK]${NC} ${name} (${GREEN}running${NC})"
        else
            echo -e "  ${RED}✗${NC} ${name} (${RED}${state}${NC})"
        fi
    done
fi

# Check services via internal IP access
echo ""
echo -e "${BLUE}Services (lab network only):${NC}"

# Check OpenRelik UI
echo -n "  OpenRelik UI (${OPENRELIK_IP}:8711)... "
if curl -fsS --connect-timeout 2 "http://${OPENRELIK_IP}:8711/" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] Not reachable${NC}"
fi

# Check OpenRelik API
echo -n "  OpenRelik API (${OPENRELIK_IP}:8710)... "
if curl -fsS --connect-timeout 2 "http://${OPENRELIK_IP}:8710/api/v1/" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] Not reachable${NC}"
fi

# Check Neko Tor
echo -n "  Neko Tor (${NEKO_IP}:8080)... "
if curl -fsS --connect-timeout 2 "http://${NEKO_IP}:8080/" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] Not reachable${NC}"
fi

# Check Neko Chromium
echo -n "  Neko Chromium (${NEKO_IP}:8090)... "
if curl -fsS --connect-timeout 2 "http://${NEKO_IP}:8090/" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Reachable${NC}"
else
    echo -e "${YELLOW}[WARNING] Not reachable${NC}"
fi

# Try to check firewall services
echo -n "  Firewall nftables... "
if vagrant ssh firewall -c "sudo nft list ruleset > /dev/null 2>&1" 2>/dev/null; then
    echo -e "${GREEN}[OK] Configured${NC}"
else
    echo -e "${YELLOW}[WARNING] Not running or unreachable${NC}"
fi

echo ""
echo -e "${BLUE}Network Configuration:${NC}"
echo "  Lab network: 10.20.0.0/24 (virbr-utgard)"
echo "    - Firewall: ${FIREWALL_IP} (lab) / ${FIREWALL_VAGRANT_IP} (host)"
echo "    - OpenRelik: ${OPENRELIK_IP}"
echo "    - REMnux: ${REMNUX_IP}"
echo "    - Neko: ${NEKO_IP}"

echo ""
echo -e "${BLUE}Service URLs (lab network only):${NC}"
echo "  - OpenRelik UI: http://${OPENRELIK_IP}:8711/"
echo "  - OpenRelik API: http://${OPENRELIK_IP}:8710/api/v1/docs/"
echo "  - Neko Tor: http://${NEKO_IP}:8080/"
echo "  - Neko Chromium: http://${NEKO_IP}:8090/"
echo ""
echo "External access is provided via Pangolin (see docs/PANGOLIN-ACCESS.md)."
echo ""

# Check if user is in libvirt group
if groups | grep -q libvirt; then
    echo -e "${GREEN}[OK] User in libvirt group${NC}"
else
    echo -e "${YELLOW}[WARNING] User not in libvirt group${NC}"
    echo "  Fix: sudo usermod -aG libvirt \$USER (then log out/in)"
fi

# Check if vagrant is available
if command -v vagrant &> /dev/null; then
    vagrant_ver=$(vagrant version | head -1)
    echo -e "${GREEN}[OK] ${vagrant_ver}${NC}"
else
    echo -e "${RED}✗ Vagrant not installed${NC}"
fi

# Check if vagrant-libvirt is available
if vagrant plugin list 2>/dev/null | grep -q libvirt; then
    echo -e "${GREEN}[OK] vagrant-libvirt plugin installed${NC}"
else
    echo -e "${YELLOW}[WARNING] vagrant-libvirt plugin may not be installed${NC}"
fi

echo ""
