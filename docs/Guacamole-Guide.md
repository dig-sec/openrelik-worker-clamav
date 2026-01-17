# Guacamole Guide

## Overview
Guacamole is a clientless remote desktop gateway. Utgard uses it to provide RDP, VNC, and SSH access to analysis workstations.

## Architecture
Three Docker containers:
- `guacd`: Remote desktop proxy daemon (protocol translation)
- `guacamole`: Web UI and server (Java-based)
- `guacamole-db`: PostgreSQL database (connections, users, settings)

## Configuration
Key variables:
- `guacamole_state_dir`: `/opt/guacamole`
- `guacamole_port`: `8080` (internal, proxied by nginx)
- `guacamole_db_name`: `guacamole`
- `guacamole_db_user`: `guacamole`
- `guacamole_db_password`: Auto-generated if not provided, stored at `/opt/guacamole/secrets/db_password`

## Access
- URL: `https://<hostname>/guacamole/`
- Default admin: Guacamole defaults (check deployment docs for initial login)
- Add connections via web UI: settings → connections

## Adding Connections

### RDP (REMnux VM)
1. Login to Guacamole
2. Settings → Connections → New Connection
3. **Name**: `remnux-rdp`
4. **Protocol**: RDP
5. **Hostname**: `10.20.0.20` (or DNS name `utgard-remnux.utgard.local`)
6. **Port**: `3389`
7. **Username/Password**: (set in REMnux; default vagrant/vagrant)
8. Save

### VNC
1. **Protocol**: VNC
2. **Hostname**: (target VNC server)
3. **Port**: `5900` (default)
4. **Username/Password**: As configured on VNC server

### SSH
1. **Protocol**: SSH
2. **Hostname**: (target host)
3. **Port**: `22`
4. **Username/Password**: SSH credentials

## Data Persistence
- Database: `/opt/guacamole/postgres/` (PostgreSQL data directory)
- Connection settings: Stored in PostgreSQL
- User accounts: PostgreSQL

## Container Management
```bash
# Status
docker compose ps -f /opt/guacamole/docker-compose.yml

# Logs
docker compose logs -f /opt/guacamole/docker-compose.yml guacamole

# Restart
docker compose restart -f /opt/guacamole/docker-compose.yml
```

## Troubleshooting
- **Can't connect to RDP**: Check firewall rules on REMnux; ensure xrdp service is running
- **Database errors**: Check PostgreSQL logs in docker compose output
- **Slow connections**: May be latency; check network paths and enable bandwidth limits if needed

