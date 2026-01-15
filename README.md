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

### 3. Access Guacamole
Browse to `https://20.240.216.254.nip.io/guacamole` and log in with `guacadmin` / `guacadmin` (change the password on first login). If you see a certificate warning, the default setup uses a self-signed cert.

### 4. Deploy VMs
```bash
vagrant up firewall
vagrant up remnux
```

## Configuration

Edit `config.yml` to adjust IPs, ports, VM resources, and feature flags. Environment variables like `WG_ENDPOINT` override the config during provisioning.

## Guacamole Access

Guacamole runs on the host and brokers RDP/SSH sessions to lab VMs without exposing those ports publicly. Create connections in the Guacamole UI for:
- **REMnux** (RDP: `10.20.0.20:3389`)
- **Firewall** (SSH: `10.20.0.2:22`)

## Access

- **OpenRelik UI** (default): http://20.240.216.254:8711
- **OpenRelik API** (default): http://20.240.216.254:8710
- **Guacamole**: https://20.240.216.254.nip.io/guacamole
- **VMs**: `vagrant ssh firewall` or `vagrant ssh remnux`

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

## Documentation

- `QUICK-REFERENCE.md` - Common commands
- `TEAM-ACCESS.md` - Analyst onboarding and access
- `WIREGUARD-MULLVAD-GUIDE.md` - VPN setup
- `docs/DEPLOYMENT-FLOW.md` - Deployment flow details
- `ansible/README.md` - Ansible roles and provisioning
