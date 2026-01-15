#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

echo "Vagrant status:"
vagrant status || true

echo ""
echo "Libvirt network (utgard-lab):"
if command -v virsh >/dev/null 2>&1; then
  sudo virsh net-list | grep -E "utgard-lab|Name" || true
else
  echo "virsh not available"
fi

echo ""
echo "Firewall services:"
if vagrant ssh firewall -c "systemctl is-active wg-quick@wg0 dnsmasq nftables" >/dev/null 2>&1; then
  vagrant ssh firewall -c "systemctl is-active wg-quick@wg0 dnsmasq nftables" || true
else
  echo "firewall VM not reachable"
fi
