#!/usr/bin/env bash
set -euo pipefail

# Clean logs across Utgard lab VMs to reduce noise
# Usage: ./scripts/clean-logs.sh
# Optional: set CLEAN_PCAPS=true to also remove firewall pcaps

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "Cleaning logs on firewall..."
vagrant ssh firewall -c "sudo bash -c '
  if [ -d /var/log/nginx ]; then find /var/log/nginx -type f -name "*.log" -exec truncate -s 0 {} \;; fi
  if [ -d /var/log/suricata ]; then find /var/log/suricata -type f -name "*.log" -exec truncate -s 0 {} \;; fi
  if [ "${CLEAN_PCAPS:-}" = "true" ] && [ -d /var/log/pcaps ]; then rm -f /var/log/pcaps/*.pcap*; fi
  echo firewall-done
'"

echo "Cleaning logs on openrelik..."
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose ps >/dev/null 2>&1 || true; sudo bash -c '
  if [ -d /var/lib/docker/containers ]; then
    find /var/lib/docker/containers -name "*-json.log" -exec truncate -s 0 {} \;;
  fi
  rm -f /tmp/*.log /tmp/*ansible*.log 2>/dev/null || true
  echo openrelik-done
'"

echo "Cleaning logs on remnux..."
vagrant ssh remnux -c "sudo bash -c '
  rm -f /tmp/*.log /tmp/*ansible*.log 2>/dev/null || true
  systemctl is-active xrdp >/dev/null 2>&1 || true
  echo remnux-done
'"

echo "Log cleanup completed."
