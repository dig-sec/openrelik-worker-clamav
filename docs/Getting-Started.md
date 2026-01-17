# Getting Started

This guide helps you stand up the Utgard OSINT platform quickly.

## Prerequisites
- Linux host with libvirt and Vagrant (or adapt provider)
- Ansible installed on the host
- Docker Engine and the Docker Compose plugin
- Ansible collection: `community.docker`

Install the collection:
```bash
ansible-galaxy collection install community.docker
```

## Configure
Edit `config.yml`:
- `lab.*`: Lab subnet and static IPs for the firewall (`10.20.0.2`) and REMnux (`10.20.0.20`)
- `external_access.*`: Public `hostname` (ip.sslip.io or your domain), and `use_subdomains: true` for subdomain routing
- `auth.*`: Enable or disable edge HTTP Basic Auth; set username/password
- `features.*`: Toggle `remnux_snapshot` and `enable_wireguard` (see notes)

## Provision
Bring up virtual machines:
```bash
vagrant up
```

Provision host services and portal:
```bash
cd ansible
ansible-playbook playbooks/host.yml
```

## Access URLs
If `use_subdomains: true` in `config.yml`:
- Portal: `https://<hostname>/`
- Guacamole: `https://guacamole.<hostname>/`
- OpenRelik: `https://openrelik.<hostname>/`
- Maigret: `https://maigret.<hostname>/`
- Kasm (OSINT): `https://browsers.<hostname>/`
- Kasm (Tor): `https://tor.<hostname>/`

If using path-based routing:
- Guacamole: `https://<hostname>/guacamole/`
- OpenRelik: `https://<hostname>/openrelik/`
- Maigret: `https://<hostname>/maigret/`
- Kasm: `https://<hostname>/kasm/` (Tor at `/kasm/tor/`)

## Credentials
- Edge Basic Auth: if enabled and no password provided, one is generated and stored at `/opt/guacamole/auth/.htpasswd_secret`
- Kasm: generated passwords stored under `/opt/kasm/secrets/`
- Guacamole DB: `/opt/guacamole/secrets/db_password`

## Maintenance
Check status:
```bash
vagrant status
```
Re-provision host services:
```bash
cd ansible
ansible-playbook playbooks/host.yml
```

