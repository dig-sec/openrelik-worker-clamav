#!/bin/bash
# Script to configure neko in Guacamole
# This adds neko as a connection through Guacamole's web interface
# Run this after Guacamole and neko are up and running

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"

GUAC_PORT="$(utgard_config_get 'ports.guacamole' '8223')"
NEKO_HOST="$(utgard_config_get 'lab.neko_ip' '10.20.0.40')"
NEKO_PORT="$(utgard_config_get 'ports_internal.neko_tor' '8080')"

GUAC_HOST="http://localhost:${GUAC_PORT}/guacamole/rest"
GUAC_USERNAME="guacadmin"
GUAC_PASSWORD="guacadmin"

# Get authentication token
TOKEN=$(curl -s -X POST \
  "${GUAC_HOST}/tokens" \
  -d "username=${GUAC_USERNAME}&password=${GUAC_PASSWORD}" \
  -H "Content-Type: application/x-www-form-urlencoded" | jq -r '.authToken')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo "Failed to authenticate with Guacamole"
  exit 1
fi

echo "Authenticated with Guacamole. Token: ${TOKEN:0:20}..."

# Create HTTP connection for neko
curl -s -X POST \
  "${GUAC_HOST}/connections?token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Neko Tor Browser",
    "protocol": "http",
    "parentIdentifier": "ROOT",
    "attributes": {
      "max-connections": "4",
      "max-connections-per-user": "2",
      "weight": "100",
      "failover-only": "false",
      "guacd-port": "4822",
      "guacd-encryption": "none"
    },
    "parameters": {
      "hostname": "'"${NEKO_HOST}"'",
      "port": "'"${NEKO_PORT}"'",
      "path": "/",
      "use-ssl": "false",
      "read-only": "false",
      "destination-host": "'"${NEKO_HOST}"'",
      "destination-port": "'"${NEKO_PORT}"'"
    }
  }' | jq .

echo ""
echo "Neko connection added to Guacamole"
echo "Access via: http://localhost:${GUAC_PORT}/guacamole/"
echo "Connection: Neko Tor Browser"
