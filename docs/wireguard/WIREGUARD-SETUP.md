# WireGuard Setup

Mullvad VPN egress is **required**. Lab VMs (neko, openrelik, remnux) access the internet via the firewall through Mullvad.

## Setup

```bash
./scripts/wg-config.sh list
./scripts/wg-config.sh select <name>
./scripts/provision.sh
```

Verify:

```bash
./scripts/wg-config.sh current
./scripts/wg-config.sh test
```

Manual config:

```bash
export MULLVAD_WG_CONF="$(cat /path/to/wg0.conf)"
./scripts/provision.sh
```

Logs:

```bash
vagrant ssh firewall
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0 -f
```
