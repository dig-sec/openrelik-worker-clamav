# Utgard - Malware Analysis Lab

Isolated malware analysis lab built from Vagrant VMs and Docker services. Lab VMs access the internet via Mullvad VPN egress. Optional external access via Pangolin.

## Quick Start

```bash
git clone <your-repo> utgard
cd utgard

# Required: Mullvad VPN config for internet egress
export MULLVAD_WG_CONF="$(cat ~/Downloads/mullvad-wg0.conf)"

./scripts/deploy-all.sh
```

## Access

- Pangolin: https://your-domain.com
- OpenRelik UI/API and Neko: add routes in Pangolin
- Defaults: OpenRelik `admin/admin`, Neko `neko/admin`

## Docs

- `docs/ARCHITECTURE.md`
- `docs/COMPONENTS.md`
- `docs/PANGOLIN-ACCESS.md`
- `docs/wireguard/WIREGUARD-SETUP.md`
- `docs/neko/NEKO-SETUP.md`
