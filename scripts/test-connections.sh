#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=./lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

WAIT_SECONDS="${1:-0}"
if [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] && [ "$WAIT_SECONDS" -gt 0 ]; then
  echo "Waiting ${WAIT_SECONDS}s before testing..."
  sleep "$WAIT_SECONDS"
fi

FIREWALL_IP="$(utgard_config_get 'lab.firewall_ip' '10.20.0.2')"
OPENRELIK_IP="$(utgard_config_get 'lab.openrelik_ip' '10.20.0.30')"
REMNUX_IP="$(utgard_config_get 'lab.remnux_ip' '10.20.0.20')"
NEKO_IP="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

cd "$ROOT_DIR"

echo "Testing connectivity from firewall VM..."

if vagrant ssh firewall -c "ping -c 1 -W 1 ${OPENRELIK_IP} >/dev/null" 2>/dev/null; then
  ok "OpenRelik reachable (${OPENRELIK_IP})"
else
  warn "OpenRelik not reachable (${OPENRELIK_IP})"
fi

if vagrant ssh firewall -c "ping -c 1 -W 1 ${REMNUX_IP} >/dev/null" 2>/dev/null; then
  ok "REMnux reachable (${REMNUX_IP})"
else
  warn "REMnux not reachable (${REMNUX_IP})"
fi

if vagrant ssh firewall -c "ping -c 1 -W 1 ${NEKO_IP} >/dev/null" 2>/dev/null; then
  ok "Neko reachable (${NEKO_IP})"
else
  warn "Neko not reachable (${NEKO_IP})"
fi

http_check() {
  local name="$1"
  local url="$2"
  local code
  code=$(vagrant ssh firewall -c "curl -s -o /dev/null -w '%{http_code}' ${url}" 2>/dev/null || true)
  if [ -n "$code" ] && [ "$code" != "000" ]; then
    ok "${name} responded (${url})"
  else
    warn "${name} no response (${url})"
  fi
}

http_check "OpenRelik UI" "http://${OPENRELIK_IP}:8711/"
http_check "OpenRelik API" "http://${OPENRELIK_IP}:8710/api/v1/docs/"
http_check "Neko Tor" "http://${NEKO_IP}:8080/"
http_check "Neko Chromium" "http://${NEKO_IP}:8090/"

echo "Done."
