#!/bin/bash
# Utgard Lab Startup Script
# Ensures libvirt network is active before starting VMs

set -e

# Always run from repo root so relative paths (Vagrantfile, provision/) resolve correctly
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

LAB_NETWORK="$(utgard_config_get 'lab.network' '10.20.0.0/24')"
FW_IP="$(utgard_config_get 'lab.gateway_ip' '10.20.0.1')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"
OPENRELIK_UI_PORT="$(utgard_config_get 'ports_internal.openrelik_ui' '8711')"
OPENRELIK_API_PORT="$(utgard_config_get 'ports_internal.openrelik_api' '8710')"
NEKO_TOR_PORT="$(utgard_config_get 'ports_internal.neko_tor' '8080')"
NEKO_CHROMIUM_PORT="$(utgard_config_get 'ports_internal.neko_chromium' '8090')"

echo " Starting utgard-lab network..."
sudo virsh net-start utgard-lab 2>/dev/null || echo "Network already active"

echo " Bringing up VMs..."
if [ "$#" -gt 0 ]; then
  utgard_vagrant_up_ordered "$@"
else
  utgard_vagrant_up_ordered
fi

echo ""
echo "[DONE] Lab startup complete!"
echo ""
echo "External access is provided via Pangolin."
echo "  See docs/PANGOLIN-ACCESS.md for deployment and routing setup."
echo ""
echo "Internal service endpoints (lab network only):"
echo "  - OpenRelik UI: http://${OPENRELIK_IP}:${OPENRELIK_UI_PORT}/"
echo "  - OpenRelik API: http://${OPENRELIK_IP}:${OPENRELIK_API_PORT}/api/v1/docs/"
echo "  - Neko Tor Browser: http://${NEKO_IP}:${NEKO_TOR_PORT}/"
echo "  - Neko Chromium Browser: http://${NEKO_IP}:${NEKO_CHROMIUM_PORT}/"
echo ""
echo "Default Credentials:"
echo "  - OpenRelik: admin / admin"
echo "  - Neko: neko / admin"
echo ""
echo "For WireGuard/Mullvad VPN routing:"
echo "  export MULLVAD_WG_CONF=\"\$(cat /path/to/mullvad.wg)\""
echo "  vagrant provision firewall"
