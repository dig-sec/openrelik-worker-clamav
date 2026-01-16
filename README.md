# Utgard Lab Environment

A simplified OSINT and forensics lab built with Vagrant, Ansible, and Docker.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Host (20.240.216.254)                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Guacamole   │  │  OpenRelik  │  │   Vagrant VMs           │  │
│  │ (remote UI) │  │  (forensics)│  │  ┌─────────┐ ┌────────┐ │  │
│  │ :443        │  │  :8711      │  │  │Firewall │→│REMnux  │ │  │
│  └──────┬──────┘  └─────────────┘  │  │ (WG)    │ │(RDP)   │ │  │
│         │                          │  └─────────┘ └────────┘ │  │
│         │  Browser access          └─────────────────────────┘  │
│         └──────────────────────────────────────────────────────►│
└─────────────────────────────────────────────────────────────────┘
```

## Prereqs (Host)

- Ubuntu 22.04+ (or compatible Debian-based) with hardware virtualization enabled.
- Vagrant with the `vagrant-libvirt` plugin.
- libvirt/KVM tooling available on the host.

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils vagrant
vagrant plugin install vagrant-libvirt
sudo usermod -aG libvirt $USER
```

Log out/in after the group change so Vagrant can access libvirt.

## Quick Start

### 1. Install Ansible on Host
```bash
sudo apt update && sudo apt install -y ansible-core
```

### 2. Provision Host Services (OpenRelik + Guacamole)
```bash
cd /home/azureuser/git/utgard/ansible
sudo ansible-playbook -i inventory.yml playbooks/host.yml -l localhost
```

### 3. Access Services
The **Edge** role (unified HTTPS portal) handles all service routing:

- **Portal Landing Page**: https://20.240.216.254/ (main entry point)
- **Guacamole**: https://20.240.216.254/guacamole (remote access, RDP/SSH broker)
- **OpenRelik**: https://20.240.216.254/openrelik (forensic artifacts analysis)
- **Maigret**: https://20.240.216.254/maigret (username OSINT search across 3000+ sites)
- **Kasm Workspaces**: https://20.240.216.254:8443 (isolated browsers with Tor & OSINT)

Guacamole login: `guacadmin` / `guacadmin` (change password on first login). Self-signed certificate used by default.

### 4. Deploy VMs
```bash
vagrant up firewall
vagrant up remnux
```

## Configuration

Edit `config.yml` to adjust IPs, ports, VM resources, and feature flags. Environment variables like `WG_ENDPOINT` override the config during provisioning.

WireGuard configs are not committed. Copy the matching `.conf.example` from `ansible/roles/firewall/files/` into `ansible/roles/firewall/files/private/` and replace placeholders, or set `wg0_conf` when provisioning.

## Service Architecture

### Base Role
Sets up Docker, system dependencies, and networking foundation.

### Network Role
Manages Docker networks for service isolation:
- `openrelik_default` (172.25.0.0/24) – OpenRelik workers
- `maigret_default` (172.26.0.0/24) – Maigret container
- `guacamole_default` (172.32.0.0/24) – Guacamole + PostgreSQL
- `kasm-isolated` (172.30.0.0/24) – Tor browser (restricted outbound)
- `kasm-clearweb` (172.31.0.0/24) – OSINT browser (full internet)

Applies iptables rules to isolate Tor container (Tor-only traffic, no DNS leaks).

### Edge Role (Unified HTTPS Portal)
Host-level Nginx reverse proxy that:
- Listens on 443 (HTTPS) and 80 (redirect to HTTPS)
- Serves unified landing page at `/`
- Routes `/guacamole/` → Guacamole port 8080
- Routes `/openrelik/` → OpenRelik UI port 8711 (with asset rewrite)
- Routes `/openrelik/api/` → OpenRelik API port 8710
- Routes `/maigret/` → Maigret port 5000
- Redirects `:8443` → Kasm WebSocket proxy on separate port

### Service Roles
- **Guacamole** – Remote access gateway (RDP/SSH broker to VMs)
- **OpenRelik** – Forensic artifact analysis platform
- **Maigret** – Username search across 3000+ sites
- **Kasm** – Isolated browser workspaces (Tor + OSINT)

## Access Points

- **Main Portal**: https://20.240.216.254/
- **Guacamole**: https://20.240.216.254/guacamole
- **OpenRelik**: https://20.240.216.254/openrelik
- **Maigret**: https://20.240.216.254/maigret
- **Kasm Workspaces**: https://20.240.216.254:8443
- **VMs**: `vagrant ssh firewall` or `vagrant ssh remnux`

## Guacamole VM Connections

Guacamole brokers RDP/SSH access to lab VMs without exposing ports publicly. Create connections in the UI:
- **REMnux** (RDP: `10.20.0.20:3389`)
- **Firewall** (SSH: `10.20.0.2:22`)

## Lab Network

- Host: `20.240.216.254` (Azure public IP)
- Firewall VM: `10.20.0.2` (lab gateway with WireGuard/Mullvad)
- REMnux VM: `10.20.0.20` (behind firewall)

## REMnux Recovery

REMnux is a high-risk analysis VM. Use snapshots to roll back after malware testing.

```bash
# Create a clean snapshot after provisioning
vagrant snapshot save remnux clean

# Revert when needed
vagrant snapshot restore remnux clean
```

Snapshots are auto-created when `features.remnux_snapshot: true` in `config.yml`.

## OpenRelik Workers

OpenRelik runs the core workers from the official compose file plus any extras defined in `ansible/roles/openrelik/defaults/main.yml` (override `openrelik_extra_workers` if needed).
