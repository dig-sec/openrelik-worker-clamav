#!/bin/bash
# Deploy openrelik-worker-eztools to running OpenRelik instance
# Usage: ./deploy-eztools.sh

set -e

OPENRELIK_DIR="${OPENRELIK_DIR:-/opt/openrelik/openrelik}"
PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches" && pwd)"

echo "📦 Deploying openrelik-worker-eztools..."

# Verify OpenRelik is running
if ! docker ps | grep -q "openrelik-server"; then
    echo "❌ OpenRelik is not running. Start it with: openrelik-start"
    exit 1
fi

# Check if worker already running
if docker ps | grep -q "openrelik-worker-eztools"; then
    echo "⚠️  Worker already running, stopping first..."
    docker stop openrelik-worker-eztools
    docker rm openrelik-worker-eztools
fi

# Add service to docker-compose.yml if not present
cd "$OPENRELIK_DIR"

if ! grep -q "openrelik-worker-eztools" docker-compose.yml; then
    echo "📝 Adding worker to docker-compose.yml..."
    python3 << 'EOF'
import yaml

with open('docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)

if 'openrelik-worker-eztools' not in compose.get('services', {}):
    compose['services']['openrelik-worker-eztools'] = {
        'container_name': 'openrelik-worker-eztools',
        'image': 'ghcr.io/openrelik/openrelik-worker-eztools:latest',
        'restart': 'always',
        'environment': [
            'REDIS_URL=redis://openrelik-redis:6379',
            'OPENRELIK_PYDEBUG=0'
        ],
        'volumes': [
            './data:/usr/share/openrelik/data'
        ],
        'depends_on': ['openrelik-redis'],
        'command': 'celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-eztools'
    }
    print("✓ Worker service added to compose")

with open('docker-compose.yml', 'w') as f:
    yaml.dump(compose, f, default_flow_style=False, sort_keys=False)

print("✓ Configuration saved")
EOF
fi

# Start the worker
echo "🚀 Starting openrelik-worker-eztools..."
docker compose up -d openrelik-worker-eztools

# Wait for container to be healthy
echo "⏳ Waiting for worker to start..."
sleep 3

# Apply the JSONDecodeError patch
echo "🔧 Applying JSONDecodeError patch..."
docker cp "$PATCHES_DIR/apply-task-utils-fix.py" openrelik-worker-eztools:/tmp/
docker exec openrelik-worker-eztools python3 /tmp/apply-task-utils-fix.py

# Verify it's running
if docker ps | grep -q "openrelik-worker-eztools"; then
    echo "✅ openrelik-worker-eztools deployed successfully!"
    echo ""
    echo "📊 Verify with:"
    echo "   docker logs openrelik-worker-eztools"
    echo ""
    echo "🔍 Access OpenRelik UI at: http://localhost:8711"
    echo "   Tasks → New Task → Select 'EZTools' worker"
else
    echo "❌ Worker failed to start. Check logs:"
    docker logs openrelik-worker-eztools
    exit 1
fi
