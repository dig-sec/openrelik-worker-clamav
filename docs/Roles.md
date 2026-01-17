# Roles Overview

## base
Common OS setup:
- Packages (curl, git, openssh, etc.)
- Docker CE installation + service enablement
- DNS resolver setup and IP forwarding for firewall
- Health checks (uptime, disk, memory, Docker, DNS)

## firewall
Gateway configuration:
- nftables filter + NAT (masquerade lab subnet)
- dnsmasq resolver bound to `lab_gateway` and localhost
- Optional WireGuard integration (Mullvad). Provide `wg0.conf` or endpoint config in `roles/firewall/files/private/`
- Key vars: `lab_network`, `lab_gateway`, `enable_wireguard`, `firewall_external_interface`, `firewall_wireguard_interface`, `dnsmasq_domain`, `dnsmasq_upstream_servers`

## remnux
Malware analysis VM:
- Installs analysis tooling (Wireshark, yara-python, etc.)
- RDP via xrdp + XFCE

## edge
HTTPS entry and routing:
- Generates TLS cert for `external_access.hostname` (+ wildcard)
- Nginx site at `/etc/nginx/sites-available/utgard.conf`
- Path-based routing by default; subdomain routing if `external_access.use_subdomains: true`
- Basic Auth with per-service exemptions
- Key vars: `edge_external_hostname`, `edge_use_subdomains`, `edge_auth_*`, `portal_service_endpoints.*`

## openrelik
Forensic pipeline:
- Installs via official script
- Configures UI/API ports, removes stray bindings, sets `OPENRELIK_SERVER_URL`
- Adds extra workers via `docker-compose.extra-workers.yml`
- Key vars: `openrelik_install_dir`, `openrelik_ui_port`, `openrelik_api_port`, `openrelik_extra_workers`, `openrelik_worker_registry`

## guacamole
Remote desktop gateway:
- Dockerized `guacd`, `guacamole`, and PostgreSQL
- Auto-generates DB schema and password
- Key vars: `guacamole_state_dir`, `guacamole_db_*`, images, `guacamole_initdb_path`

## maigret
Username OSINT web UI:
- Runs Maigret on localhost, proxied by edge
- Key vars: `maigret_state_dir`, `maigret_port`, `maigret_image`

## kasm
Isolated browsers:
- Tor-only workspace (isolated Docker network)
- Forensic OSINT workspace (clearweb network)
- Nginx TLS proxy for KasmVNC WebSockets
- Key vars: `kasm_state_dir`, `kasm_proxy_port`, `kasm_*_image`, `kasm_*_password[_file]`, network names/subnets

## network
Docker network + iptables isolation:
- Creates dedicated networks for each service
- Enforces Tor-only egress for the Tor workspace
- Key vars: `docker_networks`, `kasm_tor_*`, `kasm_clearweb_*`

