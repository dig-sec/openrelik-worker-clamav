#!/bin/bash
# Set Neko WebRTC IP for proper connectivity
# This configures the public IP that clients use to connect to Neko's WebRTC stream

set -e

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)

if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not determine public IP"
    exit 1
fi

echo "Detected public IP: $PUBLIC_IP"
echo ""
echo "Updating Neko containers with NEKO_WEBRTC_IP=$PUBLIC_IP..."

# Update neko VM
vagrant ssh neko -c "
    sudo sed -i 's/NEKO_WEBRTC_IP=.*/NEKO_WEBRTC_IP=$PUBLIC_IP/' /opt/neko/docker-compose.yml
    cd /opt/neko && sudo docker-compose restart
"

echo ""
echo "Done! Neko containers restarted with WebRTC IP: $PUBLIC_IP"
echo ""
echo "You can also set this before provisioning:"
echo "  export NEKO_WEBRTC_IP=$PUBLIC_IP"
echo "  vagrant provision neko"
