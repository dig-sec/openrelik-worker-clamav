# Guacamole Setup

Guacamole provides browser-based access to the lab VMs (RDP/SSH) through the firewall.

## Access

- URL: http://localhost:18080/guacamole/
- Default login: `guacadmin` / `guacadmin`
- **Important**: Change the admin password on first login

## Pre-Configured Connections

The following connections are automatically created during provisioning:

### REMnux Analyst VM (RDP)
- **Protocol**: RDP
- **Hostname**: `10.20.0.20:3389`
- **Username**: `vagrant`
- **Password**: `vagrant`
- **Features**: Desktop environment with analysis tools

### OpenRelik Server (SSH)
- **Protocol**: SSH
- **Hostname**: `10.20.0.30:22`
- **Username**: `vagrant`
- **Password**: `vagrant`
- **Use case**: Server management, Docker operations

### Firewall Gateway (SSH)
- **Protocol**: SSH
- **Hostname**: `10.20.0.1:22`
- **Username**: `vagrant`
- **Password**: `vagrant`
- **Use case**: Network monitoring, firewall management

### Neko Browser VM (SSH)
- **Protocol**: SSH
- **Hostname**: `10.20.0.40:22`
- **Username**: `vagrant`
- **Password**: `vagrant`
- **Use case**: Container management

## Manual Connection Setup

To add additional connections manually:

1. Go to Settings → Connections → New Connection
2. Configure with lab network IPs (10.20.0.x)
3. Use `vagrant` / `vagrant` for credentials

## Notes

- Guacamole connects from the firewall VM, so use the lab IPs above.
- If connections fail, confirm the lab is up with `vagrant status` and `./scripts/check-status.sh`.
