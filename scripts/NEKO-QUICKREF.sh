#!/bin/bash
# Quick reference: Neko Tor Browser in Utgard

# ============================================
# QUICK START
# ============================================

# 1. Provision everything (includes neko)
./scripts/provision.sh

# 2. Start services
./scripts/start-lab.sh

# 3. Test connectivity
./scripts/test-connections.sh

# 4. Access Neko
# Tor Browser:     http://localhost:8080
# Chromium Browser: http://localhost:8090
# Credentials: neko / admin


# ============================================
# NEKO VM MANAGEMENT
# ============================================

# Check VM status
vagrant status neko

# Start neko VM only
vagrant up neko

# SSH into neko VM
vagrant ssh neko

# Restart neko service
vagrant ssh neko
sudo systemctl restart neko

# View neko logs
vagrant ssh neko
sudo systemctl status neko
sudo journalctl -u neko -f

# Restart docker container
vagrant ssh neko
sudo docker restart neko-tor-browser
sudo docker restart neko-chromium-browser


# ============================================
# TROUBLESHOOTING
# ============================================

# Is neko running?
vagrant ssh neko -c "sudo systemctl status neko"

# Check docker container
vagrant ssh neko -c "sudo docker ps | grep neko"

# View container logs
vagrant ssh neko -c "sudo docker logs neko-tor-browser"
vagrant ssh neko -c "sudo docker logs neko-chromium-browser"

# Test port accessibility
curl -v http://localhost:8080/

# Check from lab network
vagrant ssh firewall -c "curl http://10.20.0.40:8080/"


# ============================================
# NETWORK CONFIGURATION
# ============================================

# Neko VM IP: 10.20.0.40
# Host port mapping:
#   8080 → Neko Tor Web UI
#   8081 → Tor WebRTC broadcast
#   8090 → Neko Chromium Web UI
#   8091 → Chromium WebRTC broadcast

# Firewall: routes lab traffic through Mullvad VPN (if configured)
# Neko: adds Tor Browser anonymity on top


# ============================================
# ADVANCED OPERATIONS
# ============================================

# Custom credentials during provisioning
export NEKO_PASSWORD="mypassword"
export NEKO_ADMIN_PASSWORD="myadminpass"
./scripts/provision.sh

# Re-provision just neko VM
vagrant provision neko

# Pull latest neko image
vagrant ssh neko
sudo docker pull ghcr.io/m1k1o/neko/tor-browser:latest
sudo systemctl restart neko

# Access neko container shell
vagrant ssh neko
sudo docker exec -it neko-tor-browser bash

# Monitor resource usage
vagrant ssh neko
sudo docker stats neko-tor-browser

# View persistent browser data
vagrant ssh neko
sudo ls -la /var/lib/docker/volumes/neko_neko_data/_data/


# ============================================
# SECURITY & MONITORING
# ============================================

# Capture neko traffic for analysis
vagrant ssh firewall
sudo tcpdump -i eth1 'host 10.20.0.40' -w /tmp/neko.pcap

# Monitor IDS alerts for neko traffic
vagrant ssh firewall
sudo tail -f /var/log/suricata/fast.log | grep 10.20.0.40

# View packet captures in OpenRelik
# Dashboard → Artifacts → Upload pcap


# ============================================
# CLEANUP
# ============================================

# Stop neko VM
vagrant halt neko

# Remove neko VM
vagrant destroy neko

# Delete all neko docker data
vagrant ssh neko
sudo docker volume rm neko_neko_data

# Clean neko logs
vagrant ssh firewall
./scripts/clean-logs.sh
