#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

FIREWALL_IP="$(utgard_config_get 'lab.firewall_ip' '10.20.0.2')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"

utgard_banner "Utgard Lab Startup"

cd "$ROOT_DIR"

utgard_vagrant_up_ordered

echo ""
echo "Access (lab network only 10.20.0.0/24):"
echo "  - OpenRelik UI:  http://${OPENRELIK_IP}:8711/"
echo "  - OpenRelik API: http://${OPENRELIK_IP}:8710/api/v1/docs/"
echo "  - Neko Tor:      http://${NEKO_IP}:8080/"
echo "  - Neko Chromium: http://${NEKO_IP}:8090/"
echo ""
echo "External access: configure Pangolin routes."
echo ""
