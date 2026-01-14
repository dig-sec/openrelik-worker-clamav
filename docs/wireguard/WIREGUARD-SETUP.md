# WireGuard Setup

## Quick Start

```bash
./scripts/wg-config.sh list
./scripts/wg-config.sh select <name>
./scripts/provision.sh
```

## Verify

```bash
./scripts/wg-config.sh current
./scripts/wg-config.sh test
```

## Alternative: Direct Config

```bash
export MULLVAD_WG_CONF="$(cat /path/to/wg0.conf)"
./scripts/provision.sh
```

## Troubleshooting

```bash
vagrant ssh firewall
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0 -f
```
