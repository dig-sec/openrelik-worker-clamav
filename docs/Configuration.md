# Configuration

All core settings live in `config.yml`.

## Network
- `lab.network`: CIDR for the lab subnet (default `10.20.0.0/24`)
- `lab.netmask`: Netmask (default `255.255.255.0`)
- `lab.firewall_ip`: Firewall/Gateway VM IP (default `10.20.0.2`)
- `lab.remnux_ip`: REMnux VM IP (default `10.20.0.20`)

## Host
- `host.network_cidr`: Host network CIDR
- `host.public_ip`: Public IP (used in TLS SAN and informational output)
- `host.private_ip`: Private IP (optional)

## External Access
- `external_access.hostname`: Public hostname or IP (supports `sslip.io`)
- `external_access.use_subdomains`: Boolean; if true, services use subdomains
- `external_access.service_subdomains.*`: Subdomain labels for services (e.g., `guacamole`, `openrelik`, `maigret`, `browsers`, `tor`)

## Authentication
- `auth.enabled`: Enable HTTP Basic Auth at edge
- `auth.username`: Username (default `utgard`)
- `auth.password`: Password; if empty, generated and stored at `/opt/guacamole/auth/.htpasswd_secret`
- `auth.protect_landing`: If true, protects the landing page with Basic Auth

## Features
- `features.enable_wireguard`: If true, gateway rules assume WireGuard egress; wireguard tasks are present but disabled by default in the role include
- `features.remnux_snapshot`: Manage a REMnux snapshot on `vagrant up`
- `features.remnux_snapshot_name`: Snapshot name (default `clean`)

## WireGuard
- `wireguard.endpoint`: Mullvad endpoint selection (e.g., `se-mma-wg-002`)
- Provide `wg0.conf` via variable or `roles/firewall/files/private/<endpoint>.conf`

## VM Resources
- `resources.firewall.{memory,cpus}`: Sizing for firewall VM
- `resources.remnux.{memory,cpus}`: Sizing for REMnux VM

