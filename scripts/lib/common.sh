#!/bin/bash

UTGARD_RED='\033[0;31m'
UTGARD_GREEN='\033[0;32m'
UTGARD_YELLOW='\033[1;33m'
UTGARD_BLUE='\033[0;34m'
UTGARD_NC='\033[0m'

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
