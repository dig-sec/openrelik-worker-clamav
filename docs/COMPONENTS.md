# Utgard Components

## Network Architecture

All lab VMs route internet traffic through the firewall via **Mullvad VPN** (required).

```
Lab VMs (10.20.0.0/24) -> Firewall (10.20.0.2) -> Mullvad (wg0) -> Internet
```

## Components

| Component | Location | Access |
| --- | --- | --- |
| Firewall/Gateway | VM: firewall (10.20.0.2) | `vagrant ssh firewall` |
| OpenRelik | VM: openrelik (10.20.0.30) | Pangolin tunnel or SSH |
| REMnux | VM: remnux (10.20.0.20) | RDP or SSH |
| Neko Browsers | VM: neko (10.20.0.40) | Pangolin tunnel |
| Pangolin | `pangolin/` | https://your-domain.com |
| WireGuard | `wireguard/` | `./scripts/wg-config.sh` |

## Access Methods

- **SSH**: `vagrant ssh <vm-name>` from host
- **Pangolin**: External access via tunnels (requires setup)
- **RDP**: Direct RDP to REMnux (10.20.0.20:3389) from host network
