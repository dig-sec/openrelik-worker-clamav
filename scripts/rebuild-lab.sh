#!/usr/bin/env bash
set -euo pipefail

# Utgard Lab Rebuild Script
# Cleans stale libvirt domains, resets Vagrant state, ensures network, and reprovisions VMs

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"

VAGRANT_PARALLEL_FLAG=""
if [ "${UTGARD_PARALLEL:-1}" -ne 0 ]; then
  VAGRANT_PARALLEL_FLAG="--parallel"
fi

PORT_LANDING="$(utgard_config_get 'ports.landing' '8220')"
PORT_OPENRELIK_UI="$(utgard_config_get 'ports.openrelik_ui' '8221')"
PORT_OPENRELIK_API="$(utgard_config_get 'ports.openrelik_api' '8222')"
PORT_GUACAMOLE="$(utgard_config_get 'ports.guacamole' '8223')"
PORT_NEKO_TOR="$(utgard_config_get 'ports.neko_tor' '8224')"
PORT_NEKO_CHROMIUM="$(utgard_config_get 'ports.neko_chromium' '8225')"
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
  echo "[OK] Domains cleared"
else
  echo "[OK] No utgard domains found"
fi

echo "Step 1b: Remove any stale disk images and volumes"
sudo rm -f /var/lib/libvirt/images/utgard_*.img 2>/dev/null || true
sudo virsh vol-list default 2>/dev/null | grep utgard | awk '{print $1}' | xargs -I {} sudo virsh vol-delete {} --pool default 2>/dev/null || true
echo "[OK] Disk images and volumes cleared"
echo

echo "Step 2: Reset Vagrant local state"
rm -rf .vagrant/machines || true
echo "[OK] .vagrant state reset"
echo

echo "Step 3: Ensure libvirt network 'utgard-lab' is active (sudo)"
if sudo virsh net-list | grep -q "utgard-lab"; then
  if sudo virsh net-list | grep "utgard-lab" | grep -q "active"; then
    echo "[OK] Network already active"
  else
    sudo virsh net-start utgard-lab || true
    echo "[OK] Network started"
  fi
else
  echo "- Defining network from $ROOT_DIR/network.xml"
  sudo virsh net-define "$ROOT_DIR/network.xml"
  sudo virsh net-start utgard-lab
  echo "[OK] Network defined and started"
fi
echo

echo "Step 4: Provision VMs with vagrant (under user 'loki')"
if id -u loki >/dev/null 2>&1; then
  sudo -u loki -H bash -lc "VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up firewall && VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up ${VAGRANT_PARALLEL_FLAG} openrelik remnux neko"
else
  echo "[WARNING] User 'loki' not found; running vagrant up as current user"
  VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up firewall && VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up ${VAGRANT_PARALLEL_FLAG} openrelik remnux neko
fi
echo "[OK] VMs are provisioning (first run can take 30-45 min)"
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
echo "[DONE] Rebuild finished!"
echo ""
echo "Access services:"
echo "  - Landing Page: http://localhost:${PORT_LANDING}/"
echo "  - Neko Tor Browser: http://localhost:${PORT_NEKO_TOR}/"
echo "  - Neko Chromium Browser: http://localhost:${PORT_NEKO_CHROMIUM}/"
echo "  - OpenRelik UI: http://localhost:${PORT_OPENRELIK_UI}/"
echo "  - OpenRelik API: http://localhost:${PORT_OPENRELIK_API}/api/v1/docs/"
echo "  - Guacamole Web: http://localhost:${PORT_GUACAMOLE}/guacamole/"
echo ""
echo "For more info: ./scripts/check-status.sh"
