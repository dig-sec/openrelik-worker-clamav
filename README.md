# Utgard Lab Environment

A simplified OSINT and forensics lab built with Vagrant, Ansible, and Docker.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Host (20.240.216.254)                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Headscale  │  │  OpenRelik  │  │   Vagrant VMs           │  │
│  │  (control)  │  │  (forensics)│  │  ┌─────────┐ ┌────────┐ │  │
│  │  :8080      │  │  :8711      │  │  │Firewall │→│REMnux  │ │  │
│  └──────┬──────┘  └─────────────┘  │  │ (WG+TS) │ │(TS)    │ │  │
│         │                          │  └─────────┘ └────────┘ │  │
│         │  Tailscale Mesh          └─────────────────────────┘  │
│         └──────────────────────────────────────────────────────►│
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Install Ansible on Host
```bash
sudo apt update && sudo apt install -y ansible-core
```

### 2. Provision Host Services (Headscale + OpenRelik)
```bash
cd /home/azureuser/git/utgard
ansible-playbook -i ansible/inventory.yml ansible/playbooks/host.yml -l localhost
```

### 3. Create Headscale Auth Key
```bash
docker exec headscale headscale preauthkeys create --user default --reusable --expiration 24h
```

### 4. Deploy VMs with Tailscale
```bash
# Set the auth key from step 3
export TAILSCALE_AUTHKEY="your-key-here"

# Deploy firewall (with WireGuard + Tailscale)
vagrant up firewall

# Deploy REMnux (behind firewall, with Tailscale)
vagrant up remnux
```

## Configuration

Edit `config.yml` to adjust IPs, ports, VM resources, and feature flags. Environment variables like `WG_ENDPOINT`, `OPENRELIK_CLIENT_ID`, and `OPENRELIK_CLIENT_SECRET` override the config during provisioning.

## Access

- **OpenRelik UI** (default): http://20.240.216.254:8711
- **OpenRelik API** (default): http://20.240.216.254:8710
- **Headscale**: http://20.240.216.254:8080
- **VMs**: `vagrant ssh firewall` or `vagrant ssh remnux`

## Lab Network

- Host: `20.240.216.254` (Azure public IP)
- Firewall VM: `10.20.0.2` (lab gateway with WireGuard/Mullvad)
- REMnux VM: `10.20.0.20` (behind firewall)
- Tailscale: `100.64.x.x/10` (mesh overlay via Headscale)

## OpenRelik Workers

All 17 workers are enabled by default (set `features.enable_extra_workers: false` in `config.yml` to disable):
- **plaso** - Timeline generation
- **yara** - YARA rule scanning
- **strings/floss** - String extraction
- **hayabusa** - Windows EVTX triage
- **capa** - Executable capability analysis
- **os-creds** - OS credential extraction
- **extraction** - File extraction from disk images
- **bulkextractor** - Bulk forensics
- **containers** - Container operations
- **grep/entropy** - Pattern matching and entropy analysis
- **dfindexeddb/chromecreds** - Browser forensics
- **cloud-logs/analyzer-logs/analyzer-config** - Log analysis

## Documentation

- `QUICK-REFERENCE.md` - Common commands
- `WIREGUARD-MULLVAD-GUIDE.md` - VPN setup
- `ansible/README.md` - Ansible roles and provisioning
