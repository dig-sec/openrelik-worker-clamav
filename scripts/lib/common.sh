#!/bin/bash

UTGARD_RED='\033[0;31m'
UTGARD_GREEN='\033[0;32m'
UTGARD_YELLOW='\033[1;33m'
UTGARD_BLUE='\033[0;34m'
UTGARD_NC='\033[0m'

# Best-effort helper to populate Mullvad WireGuard config from disk when
# MULLVAD_WG_CONF is not already set in the environment. Looks for a file at
# ${UTGARD_MULLVAD_CONF_PATH} or falls back to provision/mullvad-wg0.conf.
utgard_load_mullvad_conf() {
  # Require ROOT_DIR from caller context
  local default_path="${ROOT_DIR:-}/provision/mullvad-wg0.conf"
  local conf_path="${UTGARD_MULLVAD_CONF_PATH:-$default_path}"

  # Preserve any user-supplied env
  if [ -n "${MULLVAD_WG_CONF:-}" ]; then
    return 0
  fi

  # Load from file if present
  if [ -f "$conf_path" ]; then
    MULLVAD_WG_CONF="$(cat "$conf_path")"
    export MULLVAD_WG_CONF
    echo "[INFO] Loaded Mullvad config from $conf_path"
    return 0
  fi

  echo "[WARN] MULLVAD_WG_CONF is unset and no Mullvad config found at $conf_path"
  return 0
}

utgard_banner() {
  local title="$1"
  echo -e "${UTGARD_BLUE}╔════════════════════════════════════════════════════════════╗${UTGARD_NC}"
  printf "${UTGARD_BLUE}║ %-58s ║${UTGARD_NC}\n" "$title"
  echo -e "${UTGARD_BLUE}╚════════════════════════════════════════════════════════════╝${UTGARD_NC}"
  echo ""
}

utgard_use_parallel() {
  [ "${UTGARD_PARALLEL:-1}" -ne 0 ]
}

utgard_vagrant_up() {
  if utgard_use_parallel; then
    vagrant up --parallel "$@"
  else
    vagrant up "$@"
  fi
}

utgard_vagrant_up_ordered() {
  local firewall_target="firewall"
  vagrant up "$firewall_target"

  if [ "$#" -gt 0 ]; then
    utgard_vagrant_up "$@"
  else
    utgard_vagrant_up openrelik remnux neko
  fi
}
