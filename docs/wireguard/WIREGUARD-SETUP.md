# WireGuard Integration Guide

## Quick Start

### 1. Choose an Endpoint

```bash
./scripts/wg-config.sh list
```

### 2. Activate Configuration

```bash
./scripts/wg-config.sh select se-mma-wg-001
```

### 3. Provision Lab with VPN

```bash
./scripts/provision.sh
```

All firewall traffic will route through the selected Mullvad endpoint.

## How It Works

The WireGuard configs are integrated into the provisioning workflow:

```
1. User selects endpoint: ./scripts/wg-config.sh select <name>
           ↓
2. Config copied to: wireguard/active-wg0.conf
           ↓
3. Provision script runs: ./scripts/provision.sh
           ↓
4. Firewall playbook reads: active-wg0.conf
           ↓
5. WireGuard interface (wg0) configured on firewall VM
           ↓
6. Lab network (10.20.0.0/24) routes through Mullvad VPN
           ↓
7. All traffic egresses through Swedish endpoint
```

## Available Endpoints

**Primary Endpoints (193.138.218.x):**
- se-mma-wg-001 → 193.138.218.220:51820
- se-mma-wg-002 → 193.138.218.80:51820
- se-mma-wg-003 → 193.138.218.83:51820
- se-mma-wg-004 → 193.138.218.130:51820
- se-mma-wg-005 → 193.138.218.82:51820

**Alternate Endpoints (141.98.255.x):**
- se-mma-wg-011 → 141.98.255.94:51820
- se-mma-wg-012 → 141.98.255.97:51820

**Cloud Endpoints (45.83.220.x):**
- se-mma-wg-101 → 45.83.220.68:51820
- se-mma-wg-102 → 45.83.220.69:51820
- se-mma-wg-103 → 45.83.220.70:51820

**Data Center Endpoints (45.129.59.x):**
- se-mma-wg-111 → 45.129.59.19:51820
- se-mma-wg-112 → 45.129.59.129:51820

## Usage

### View Current Configuration

```bash
./scripts/wg-config.sh current
```

Output:
```
Currently Active WireGuard Config: se-mma-wg-001
Endpoint: 193.138.218.220:51820
```

### Show Configuration Details

```bash
./scripts/wg-config.sh info se-mma-wg-001
```

### Test Connectivity

```bash
./scripts/wg-config.sh test
```

Verifies:
- Mullvad gateway is reachable
- WireGuard interface is active
- Tunnel is properly configured

### Rotate to Random Endpoint

For load balancing or evasion:

```bash
./scripts/wg-config.sh rotate
```

Randomly selects from all 12 endpoints.

## Integration with Utgard Lab

### Architecture

```
┌─────────────────────────────────────────┐
│ Neko Tor Browser / OpenRelik / REMnux  │
├─────────────────────────────────────────┤
│        Lab Network (10.20.0.0/24)       │
├─────────────────────────────────────────┤
│   Firewall VM (10.20.0.1)              │
│   • WireGuard Interface (wg0)          │
│   • Routes all traffic via Mullvad     │
├─────────────────────────────────────────┤
│   Mullvad VPN Tunnel                   │
│   • Endpoint: 193.138.218.220:51820   │
├─────────────────────────────────────────┤
│       Internet                          │
│       (Swedish exit IP)                │
└─────────────────────────────────────────┘
```

### Security Layers

1. **Lab Network Isolation** - Internal network (10.20.0.0/24)
2. **WireGuard Encryption** - All lab traffic encrypted
3. **VPN Anonymity** - Swedish Mullvad exit IP
4. **Tor Browser** - Optional additional anonymity (Neko)
5. **IDS Monitoring** - Suricata monitors firewall traffic

## Advanced Usage

### Backup Current Configuration

```bash
./scripts/wg-config.sh backup
```

Saves to `wireguard/.backup/wg0_YYYYMMDD_HHMMSS.conf`

### Restore from Backup

```bash
./scripts/wg-config.sh restore
```

Restores the most recent backup.

### Manual Configuration

If you want to use a custom WireGuard config not in the directory:

```bash
export MULLVAD_WG_CONF="$(cat your-wg-config.conf)"
./scripts/provision.sh firewall
```

### Check VPN Exit IP

```bash
vagrant ssh firewall
curl https://api.mullvad.net/ip
```

Output:
```json
{
  "ip": "185.223.214.123",
  "country": "Sweden",
  "city": "Malmo",
  "latitude": 59.3,
  "longitude": 18.0,
  "mullvad_exit_ip": true
}
```

### Monitor VPN Traffic

```bash
vagrant ssh firewall
sudo tcpdump -i wg0 -v  # Inside tunnel
sudo tcpdump -i eth0 -v  # To VPN endpoint
```

## Troubleshooting

### WireGuard Interface Not Coming Up

```bash
vagrant ssh firewall
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0 -f
```

### Check Endpoint Connectivity

```bash
vagrant ssh firewall
nc -zu -w 2 193.138.218.220 51820  # UDP check
```

### View Active WireGuard Status

```bash
vagrant ssh firewall
sudo wg show wg0
```

### Switch Endpoint Without Reprovisioning

```bash
# Select new endpoint
./scripts/wg-config.sh select se-mma-wg-002

# SSH into firewall
vagrant ssh firewall

# Restart WireGuard
sudo wg-quick down wg0
sudo cp /tmp/active-wg0.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0
```

## Configuration Files

### Directory Structure

```
wireguard/
├── README.md                    # This file
├── se-mma-wg-001.conf          # 12 endpoint configs
├── se-mma-wg-002.conf
├── ... (10 more configs)
├── active-wg0.conf             # Currently selected config
└── .backup/                     # Backup directory
    ├── wg0_20260109_125000.conf
    └── wg0_20260109_130000.conf
```

### Configuration Format

Each WireGuard config contains:

```ini
[Interface]
PrivateKey = <key>              # Mullvad account key
Address = 10.66.31.54/32        # IPv4 on Mullvad network
Address = fc00:bbbb:bbbb...     # IPv6 on Mullvad network
DNS = 10.64.0.1                 # Mullvad DNS

[Peer]
PublicKey = <key>               # Endpoint public key
AllowedIPs = 0.0.0.0/0,::0/0    # Route all traffic
Endpoint = X.X.X.X:51820        # VPN server address
```

## Script Commands Reference

| Command | Purpose | Example |
|---------|---------|---------|
| `list` | Show all endpoints | `./scripts/wg-config.sh list` |
| `select <name>` | Choose endpoint | `./scripts/wg-config.sh select se-mma-wg-001` |
| `current` | Show active endpoint | `./scripts/wg-config.sh current` |
| `info <name>` | Show config details | `./scripts/wg-config.sh info se-mma-wg-001` |
| `activate <name>` | Activate for provision | `./scripts/wg-config.sh activate se-mma-wg-001` |
| `test` | Test connectivity | `./scripts/wg-config.sh test` |
| `rotate` | Random endpoint | `./scripts/wg-config.sh rotate` |
| `backup` | Backup current | `./scripts/wg-config.sh backup` |
| `restore` | Restore from backup | `./scripts/wg-config.sh restore` |

## Account Information

**Mullvad Device:** Famous Wasp  
**Private Key:** UCBE7Gw5ljpNg5nApRkoJIT8o32YXpTHJR7DN983QkY=  
**VPN Network IP:** 10.66.31.54  
**Region:** Sweden (Malmo)  
**Endpoints:** 12 available

This is a shared experimental Mullvad account for Utgard lab use.

## References

- **WireGuard:** https://www.wireguard.com/
- **Mullvad VPN:** https://mullvad.net/
- **Mullvad API:** https://api.mullvad.net/
- **WireGuard Installation:** https://www.wireguard.com/install/

## Integration with Other Components

### With Neko Tor Browser

Neko traffic path:
```
Neko Browser → Lab Network → Firewall WireGuard → Mullvad (Sweden) → Tor → .onion sites
```

### With Suricata IDS

- Monitors traffic entering WireGuard tunnel
- Detects malicious patterns before encryption
- Logs all suspicious activity

### With OpenRelik

- Can ingest network artifacts
- Analyze VPN handshake patterns
- Study encrypted tunnel behavior

### With REMnux

- Deep packet inspection of WireGuard
- Traffic analysis and forensics
- Protocol implementation testing

---

**Last Updated:** January 9, 2026  
**WireGuard Endpoints:** 12  
**Region:** Sweden  
**Status:** Production Ready
