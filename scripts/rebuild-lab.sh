#!/usr/bin/env bash
set -euo pipefail

# Utgard Lab Rebuild Script
# Cleans stale libvirt domains, resets Vagrant state, ensures network, and reprovisions VMs

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

VAGRANT_PARALLEL_FLAG=""
if [ "${UTGARD_PARALLEL:-1}" -ne 0 ]; then
  VAGRANT_PARALLEL_FLAG="--parallel"
fi

# Lab network IPs (direct access)
FIREWALL_IP="$(utgard_config_get 'lab.firewall_ip' '10.20.0.2')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"

# Load Mullvad config if available
utgard_load_mullvad_conf
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
  sudo -u loki -H env MULLVAD_WG_CONF="${MULLVAD_WG_CONF:-}" VAGRANT_DEFAULT_PROVIDER=libvirt \
    bash -lc "vagrant up firewall && vagrant up ${VAGRANT_PARALLEL_FLAG} openrelik remnux neko"
else
  echo "[WARNING] User 'loki' not found; running vagrant up as current user"
  MULLVAD_WG_CONF="${MULLVAD_WG_CONF:-}" VAGRANT_DEFAULT_PROVIDER=libvirt \
    vagrant up firewall && vagrant up ${VAGRANT_PARALLEL_FLAG} openrelik remnux neko
fi
echo "[OK] VMs are provisioning (first run can take 30-45 min)"
echo ""
echo "VMs being provisioned:"
echo "  - firewall (2GB RAM, 2 CPU) - network gateway & Mullvad WireGuard"
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
echo "Access services (lab network only 10.20.0.0/24):"
echo "  - OpenRelik UI: http://${OPENRELIK_IP}:8711/"
echo "  - OpenRelik API: http://${OPENRELIK_IP}:8710/api/v1/docs/"
echo "  - Guacamole: http://${FIREWALL_IP}:8080/guacamole/"
echo "  - Neko Tor: http://${NEKO_IP}:8080/"
echo "  - Neko Chromium: http://${NEKO_IP}:8090/"
echo ""
echo "External access: use Pangolin routes configured in docs/PANGOLIN-ACCESS.md."
echo ""
echo "For more info: ./scripts/check-status.sh"
