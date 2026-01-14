# Utgard Components

This is a quick map of core services, where they live, and how you reach them.

| Component | Purpose | Location | Access |
| --- | --- | --- | --- |
| Firewall/Gateway | Isolation, routing, capture, IDS, optional VPN egress | VM: firewall (10.20.0.1) | `vagrant ssh firewall` |
| OpenRelik | Forensics UI/API + workers | VM: openrelik (10.20.0.30) | Pangolin route |
| REMnux | Analyst workstation | VM: remnux (10.20.0.20) | RDP via Guacamole or SSH |
| Neko Tor Browser | Remote Tor browser | VM: neko (10.20.0.40) | Pangolin route |
| Pangolin | External access + TLS routing | `pangolin/` | https://your-domain.com |
| WireGuard | VPN egress (optional) | `wireguard/` | `./scripts/wg-config.sh` |

## Key Files

- Vagrantfile: VM definitions
- network.xml: libvirt network
- provision/*.yml: Ansible playbooks
- services/*: Docker compose templates

## Docs

- Pangolin: docs/PANGOLIN-ACCESS.md
- Neko: docs/neko/NEKO-SETUP.md
- WireGuard: docs/wireguard/WIREGUARD-SETUP.md
