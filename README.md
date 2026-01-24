# Utgard OSINT Platform

Utgard is a turnkey OSINT and DFIR lab that provisions a small virtual network and a suite of containerized services behind a unified HTTPS portal. It uses Vagrant (libvirt), Ansible, Docker, and Nginx to deploy:

- Firewall/Gateway VM with nftables + dnsmasq + optional Mullvad WireGuard egress
- REMnux VM for malware analysis (with RDP)
- Host services: OpenRelik (forensic pipeline), Kasm Workspaces (isolated browsers incl. Tor), Guacamole (remote desktop gateway), Maigret (username OSINT)

The edge role generates a TLS cert and exposes all services via a single hostname, with optional subdomain routing and HTTP Basic Auth.

## Highlights
- Unified HTTPS portal with path or subdomain routing
- Self-signed TLS certificate generation (or use your own)
- Optional Basic Auth at the edge (per-service exemptions)
- Clean Docker network isolation, incl. Tor-only workspace
- Minimal, reproducible VM provisioning with Ansible Local

## Repository Layout
- `Vagrantfile`: Defines two VMs: `firewall` and `remnux`, passes lab vars to Ansible
- `config.yml`: Central config for network, external access, auth, features, VM resources
- `ansible/`: Ansible cfg, inventory, playbooks, and roles
  - `playbooks/firewall.yml`: Provisions the firewall VM
  - `playbooks/remnux.yml`: Provisions the REMnux VM
  - `playbooks/host.yml`: Provisions host services and edge portal
  - `roles/`: Roles for `base`, `firewall`, `remnux`, `edge`, `openrelik`, `guacamole`, `maigret`, `kasm`, `network`
- `docs/`: Additional guides (getting started, configuration, roles, access)

## Prerequisites
- Linux host with libvirt (or adapt Vagrant provider)
- Vagrant with libvirt provider
- Ansible (on host) and `community.docker` collection
- Docker Engine + Docker Compose plugin

Install Ansible collection:
```bash
ansible-galaxy collection install community.docker
```

## Configure
Edit `config.yml` to fit your environment:
- `lab.*`: Lab subnet, netmask, static IPs for firewall and REMnux
- `external_access.*`: Public hostname or IP; set `use_subdomains: true` to route services on subdomains (e.g., `guacamole.<host>`)
- `auth.*`: Enable edge HTTP Basic Auth; set username/password; choose whether to protect the landing page
- `features.*`: Enable REMnux snapshot management; optionally enable WireGuard (see Notes)
- `resources.*`: VM memory/CPU sizing

Example uses sslip.io:
```yaml
external_access:
  hostname: "20.240.216.254.sslip.io"
  use_subdomains: true
```

## Quick Start
1) Bring up VMs (firewall + remnux):
```bash
vagrant up
```

2) Provision host services and portal:
```bash
cd ansible
ansible-playbook playbooks/host.yml
```

3) Access the portal and services:
- Portal: `https://<hostname>/` (or just the root domain if subdomains are enabled)
- Guacamole: `https://guacamole.<hostname>/`
- OpenRelik: `https://openrelik.<hostname>/`
- Maigret: `https://maigret.<hostname>/`
- Kasm (OSINT): `https://browsers.<hostname>/`

On first run, the edge role prints access URLs and any generated Basic Auth credentials.

## Playbooks
- `playbooks/firewall.yml`: Applies `base` + `firewall` to the firewall VM
- `playbooks/remnux.yml`: Applies `base` + `remnux` to the REMnux VM
- `playbooks/host.yml`: Applies `base`, `network`, `edge`, `openrelik`, `guacamole`, `maigret`, `kasm` on the host

## Roles Overview
- `base`: Common packages, Docker install, network setup, health checks
- `firewall`: nftables NAT + filter, dnsmasq, optional WireGuard integration, simple monitoring hooks
- `remnux`: Tools (Wireshark, YARA Python, Volatility3 if available, etc.), xrdp + XFCE desktop
- `edge`: Nginx reverse proxy, self-signed TLS, Basic Auth, path/subdomain routing
- `openrelik`: Installs via official script, configures ports and extra workers, composes stack
- `guacamole`: Docker-based Guacamole (guacd + guacamole + PostgreSQL) with generated schema
- `maigret`: Runs Maigret web UI on localhost bound through edge
- `kasm`: Kasm VNC workspaces for Tor-only and clearweb OSINT, proxied via Nginx with TLS
- `network`: Creates dedicated Docker networks + iptables isolation for Kasm Tor

See `docs/Roles.md` for details and key variables.

## Authentication & Secrets
- Edge Basic Auth: username and password come from `config.yml`; if password is empty, one is generated and stored at `/opt/guacamole/auth/.htpasswd_secret`
- Guacamole DB: password stored at `/opt/guacamole/secrets/db_password` (generated if not provided)
- Kasm: passwords for Tor and OSINT workspaces stored under `/opt/kasm/secrets/`

## WireGuard (Optional Mullvad Egress)
To route all lab traffic through Mullvad VPN:
1. Obtain a Mullvad WireGuard config file
2. Place it in `ansible/roles/firewall/files/private/<endpoint>.conf`
3. Set `features.enable_wireguard: true` in `config.yml`
4. Re-provision the firewall VM
5. Verify with `curl https://am.i.mullvad.net/connected` from REMnux

See [docs/WireGuard-Setup.md](docs/WireGuard-Setup.md) for details.

## Notes & Tips
- TLS: edge role generates a cert for the configured hostname and wildcard; swap in real certs by updating edge defaults or templates
- Subdomains: Set `external_access.use_subdomains: true` to enable per-service subdomains; path routing remains available
- Snapshots: REMnux snapshot handling is controlled via `features.remnux_snapshot*` in `config.yml`

## Maintenance
Check VM status:
```bash
vagrant status
```
Re-provision after config changes:
```bash
cd ansible
ansible-playbook playbooks/host.yml
```

## License
This repository’s playbooks and templates are provided as-is for lab use. Verify local laws and provider policies before routing traffic via VPNs.
