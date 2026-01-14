# Utgard - Malware Analysis Lab

Utgard is an isolated malware analysis lab built from Vagrant VMs and Docker services. It provides a controlled network, centralized forensics (OpenRelik), an analyst workstation (REMnux), and optional external access via Pangolin.

## What You Get

- OpenRelik UI/API for artifact indexing and analysis
- REMnux workstation VM with core analysis tools
- Firewall/gateway VM with strict isolation and optional Mullvad VPN egress
- Network capture and Suricata IDS on lab traffic
- Optional Neko Tor Browser VM and Pangolin access layer

## Architecture (Short Form)

Operator -> Pangolin (optional) -> Firewall -> Lab VMs -> Mullvad (optional)

## Prerequisites

- Vagrant >= 2.3.4
- libvirt/KVM + vagrant-libvirt
- 12GB RAM, 50GB disk (minimum)
- Mullvad WireGuard config (optional)

## Quick Start

```bash
git clone <your-repo> utgard
cd utgard

# Optional: Mullvad VPN
export MULLVAD_WG_CONF="$(cat ~/Downloads/mullvad-wg0.conf)"

./scripts/deploy-all.sh
```

## Access

- Pangolin UI: https://your-domain.com
- OpenRelik UI: https://your-domain.com/<route>
- OpenRelik API: https://your-domain.com/<route>
- Neko Tor Browser: https://your-domain.com/<route>

Default creds (first run):
- OpenRelik: admin / admin
- Neko: neko / admin

## Common Ops

```bash
./scripts/start-lab.sh
./scripts/check-status.sh
vagrant halt
vagrant destroy -f
```

## Documentation

- Architecture: docs/ARCHITECTURE.md
- Components map: docs/COMPONENTS.md
- Pangolin access: docs/PANGOLIN-ACCESS.md
- WireGuard VPN: docs/wireguard/WIREGUARD-SETUP.md
- Neko Tor Browser: docs/neko/NEKO-SETUP.md
