#!/bin/bash
# Utgard Lab Startup Script
# Ensures libvirt network is active before starting VMs

set -e

# Always run from repo root so relative paths (Vagrantfile, provision/) resolve correctly
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "🔧 Starting utgard-lab network..."
sudo virsh net-start utgard-lab 2>/dev/null || echo "Network already active"

echo "🚀 Bringing up VMs..."
vagrant up "$@"

echo ""
echo "✅ Lab startup complete!"
echo ""
echo "Access services:"
echo "  - OpenRelik UI: http://localhost:8711/"
echo "  - OpenRelik API: http://localhost:8710/api/v1/docs/"
echo "  - Guacamole Web: http://localhost:18080/guacamole/"
