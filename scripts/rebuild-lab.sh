#!/usr/bin/env bash
set -euo pipefail

# Utgard Lab Rebuild Script
# Cleans stale libvirt domains, resets Vagrant state, ensures network, and reprovisions VMs

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "╔════════════════════════════════════════════════════╗"
echo "║           Utgard Lab – Rebuild Environment         ║"
echo "╚════════════════════════════════════════════════════╝"
echo

echo "Step 1: Stop and remove any existing utgard libvirt domains (sudo)"
mapfile -t DOMAINS < <(sudo virsh list --all 2>/dev/null | awk '/utgard_/ {print $2}')
if [[ ${#DOMAINS[@]} -gt 0 ]]; then
  for d in "${DOMAINS[@]}"; do
    echo "- Handling domain: $d"
    sudo virsh destroy "$d" 2>/dev/null || true
    sudo virsh undefine "$d" --remove-all-storage 2>/dev/null || true
  done
  echo "✓ Domains cleared"
else
  echo "✓ No utgard domains found"
fi

echo "Step 1b: Remove any stale disk images and volumes"
sudo rm -f /var/lib/libvirt/images/utgard_*.img 2>/dev/null || true
sudo virsh vol-list default 2>/dev/null | grep utgard | awk '{print $1}' | xargs -I {} sudo virsh vol-delete {} --pool default 2>/dev/null || true
echo "✓ Disk images and volumes cleared"
echo

echo "Step 2: Reset Vagrant local state"
rm -rf .vagrant/machines || true
echo "✓ .vagrant state reset"
echo

echo "Step 3: Ensure libvirt network 'utgard-lab' is active (sudo)"
if sudo virsh net-list | grep -q "utgard-lab"; then
  if sudo virsh net-list | grep "utgard-lab" | grep -q "active"; then
    echo "✓ Network already active"
  else
    sudo virsh net-start utgard-lab || true
    echo "✓ Network started"
  fi
else
  echo "- Defining network from $ROOT_DIR/network.xml"
  sudo virsh net-define "$ROOT_DIR/network.xml"
  sudo virsh net-start utgard-lab
  echo "✓ Network defined and started"
fi
echo

echo "Step 4: Provision VMs with vagrant (under user 'loki')"
if id -u loki >/dev/null 2>&1; then
  sudo -u loki -H bash -lc 'VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up'
else
  echo "⚠ User 'loki' not found; running vagrant up as current user"
  VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up
fi
echo "✓ VMs are provisioning (first run can take 30-45 min)"
echo ""
echo "VMs being provisioned:"
echo "  - firewall (2GB RAM, 2 CPU) - reverse proxy & network gateway"
echo "  - openrelik (4GB RAM, 2 CPU) - artifact analysis"
echo "  - remnux (4GB RAM, 2 CPU) - malware analysis tools"
echo "  - neko (3GB RAM, 2 CPU) - Tor & Chromium browsers"
echo

echo "Step 5: Quick connectivity tests"
if id -u loki >/dev/null 2>&1; then
  sudo -u loki -H bash -lc './scripts/test-connections.sh 15' || true
else
  ./scripts/test-connections.sh 15 || true
fi
echo
echo "✅ Rebuild finished!"
echo ""
echo "Access services:"
echo "  - Neko Tor Browser: http://localhost:8080/"
echo "  - Neko Chromium Browser: http://localhost:8090/"
echo "  - OpenRelik UI: http://localhost:8711/"
echo "  - OpenRelik API: http://localhost:8710/api/v1/docs/"
echo "  - Guacamole Web: http://localhost:18080/guacamole/"
echo ""
echo "For more info: ./scripts/check-status.sh"
