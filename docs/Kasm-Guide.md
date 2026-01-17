# Kasm Workspaces Guide

## Overview
Kasm Workspaces provides isolated, containerized browser environments. Utgard deploys two:
1. **Tor Browser**: Network-isolated (Tor-only egress via iptables)
2. **Forensic OSINT**: Clearweb-enabled with OSINT tools

## Architecture
- **kasm-tor-browser**: Isolated network, Tor-only
- **kasm-forensic-osint**: Clearweb network, full internet access
- **kasm-proxy**: Nginx TLS reverse proxy for WebSocket connections

Each workspace uses KasmVNC (WebSocket-based VNC, not Guacamole-compatible).

## Configuration
Key variables:
- `kasm_state_dir`: `/opt/kasm`
- `kasm_proxy_port`: `8443`
- `kasm_tor_image`: `kasmweb/tor-browser:1.18.0`
- `kasm_osint_image`: `kasmweb/forensic-osint:1.18.0`
- `kasm_tor_password`: Auto-generated if empty, stored at `/opt/kasm/secrets/tor_password`
- `kasm_osint_password`: Auto-generated if empty, stored at `/opt/kasm/secrets/osint_password`

## Access URLs

### Path-Based Routing
- **Tor**: `https://<hostname>/kasm/tor/`
- **OSINT**: `https://<hostname>/kasm/osint/`

### Subdomain Routing (`use_subdomains: true`)
- **Tor**: `https://tor.<hostname>/`
- **OSINT**: `https://browsers.<hostname>/`

## Login Credentials
- **Username**: `kasm_user` (default)
- **Tor password**: Auto-generated; check `/opt/kasm/secrets/tor_password`
- **OSINT password**: Auto-generated; check `/opt/kasm/secrets/osint_password`

Passwords also printed by Ansible during provisioning.

## Network Isolation
### Tor Workspace
- Docker network: `kasm-isolated` (`172.30.0.0/24`)
- iptables rules block all outbound except to Tor gateway (`172.30.0.1`)
- Only Tor traffic egresses; DNS blocked to force Tor resolution

### OSINT Workspace
- Docker network: `kasm-clearweb` (`172.31.0.0/24`)
- Full internet access; standard clearweb traffic

## Container Management
```bash
# Status
docker compose ps -f /opt/kasm/docker-compose.yml

# Logs
docker compose logs -f /opt/kasm/docker-compose.yml

# Restart
docker compose restart -f /opt/kasm/docker-compose.yml

# View network isolation (iptables)
sudo iptables -L FORWARD
```

## Customization
### Change Passwords
```bash
# Update Tor password
echo "new_password_here" > /opt/kasm/secrets/tor_password
docker compose restart -f /opt/kasm/docker-compose.yml kasm-tor-browser
```

### Add More Workspaces
Edit `/opt/kasm/docker-compose.yml` to add new services and routes in `/opt/kasm/nginx-kasm.conf`. Restart the proxy.

## Troubleshooting
- **WebSocket connection fails**: Check TLS cert and proxy logs
- **No internet in OSINT**: Verify `kasm-clearweb` network and Docker routing
- **Tor not connecting**: Check iptables rules and network isolation
- **Slow performance**: Increase `kasm_shm_size` (default `512m`) for shared memory

