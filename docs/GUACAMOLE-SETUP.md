# Guacamole Setup

Guacamole provides browser-based access to the lab VMs (RDP/SSH) through the firewall.

## Access

- URL: http://localhost:18080/guacamole/
- Default login: `guacadmin` / `guacadmin`
- Change the admin password on first login.

## Create Connections

From the Guacamole admin UI:

1. Go to Settings → Connections → New Connection.
2. Create the following connections (examples below).

### REMnux (RDP)

- Name: `remnux-rdp`
- Protocol: RDP
- Hostname: `10.20.0.20`
- Port: `3389`
- Username: `vagrant`
- Password: `vagrant`

### OpenRelik (SSH)

- Name: `openrelik-ssh`
- Protocol: SSH
- Hostname: `10.20.0.30`
- Port: `22`
- Username: `vagrant`
- Password: `vagrant`

### Firewall (SSH)

- Name: `firewall-ssh`
- Protocol: SSH
- Hostname: `10.20.0.1`
- Port: `22`
- Username: `vagrant`
- Password: `vagrant`

## Notes

- Guacamole connects from the firewall VM, so use the lab IPs above.
- If connections fail, confirm the lab is up with `vagrant status` and `./scripts/check-status.sh`.
