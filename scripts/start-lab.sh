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

PORT_LANDING="$(utgard_config_get 'ports.landing' '8220')"
PORT_OPENRELIK_UI="$(utgard_config_get 'ports.openrelik_ui' '8221')"
PORT_OPENRELIK_API="$(utgard_config_get 'ports.openrelik_api' '8222')"
PORT_GUACAMOLE="$(utgard_config_get 'ports.guacamole' '8223')"
PORT_NEKO_TOR="$(utgard_config_get 'ports.neko_tor' '8224')"
PORT_NEKO_CHROMIUM="$(utgard_config_get 'ports.neko_chromium' '8225')"

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
echo "Access services:"
echo "  - Landing Page: http://localhost:${PORT_LANDING}/"
echo "  - OpenRelik UI: http://localhost:${PORT_OPENRELIK_UI}/"
echo "  - OpenRelik API: http://localhost:${PORT_OPENRELIK_API}/api/v1/docs/"
echo "  - Guacamole Web: http://localhost:${PORT_GUACAMOLE}/guacamole/"
echo "  - Neko Tor Browser: http://localhost:${PORT_NEKO_TOR}/"
echo "  - Neko Chromium Browser: http://localhost:${PORT_NEKO_CHROMIUM}/"
echo ""
echo "Default Credentials:"
echo "  - OpenRelik: admin / admin"
echo "  - Guacamole: guacadmin / guacadmin"
echo "  - Neko: neko / admin"
echo ""
echo "For WireGuard/Mullvad VPN routing:"
echo "  export MULLVAD_WG_CONF=\"\$(cat /path/to/mullvad.wg)\""
echo "  vagrant provision firewall"
