# WireGuard VPN Configuration for Utgard Lab

## Overview

This directory contains Mullvad WireGuard configurations for Swedish endpoints. These are used to encrypt and route all lab traffic through the Mullvad VPN before reaching the internet, adding a layer of anonymity and protection when running malware detonation and threat analysis.

**Location:** Sweden (Malmo - MMA region)  
**Provider:** Mullvad VPN  
**Account:** Famous Wasp (shared experimental account)  
**Endpoints:** 12 Swedish servers across multiple datacenters

## Available Endpoints

| Config | Endpoint | Datacenter | Type |
|--------|----------|-----------|------|
| se-mma-wg-001 | 193.138.218.220:51820 | Malmo 1 | Primary |
| se-mma-wg-002 | 193.138.218.80:51820 | Malmo 2 | Primary |
| se-mma-wg-003 | 193.138.218.83:51820 | Malmo 3 | Primary |
| se-mma-wg-004 | 193.138.218.130:51820 | Malmo 4 | Primary |
| se-mma-wg-005 | 193.138.218.82:51820 | Malmo 5 | Primary |
| se-mma-wg-011 | 141.98.255.94:51820 | Malmo Alt 1 | Alternate |
| se-mma-wg-012 | 141.98.255.97:51820 | Malmo Alt 2 | Alternate |
| se-mma-wg-101 | 45.83.220.68:51820 | Malmo Cloud 1 | Cloud |
| se-mma-wg-102 | 45.83.220.69:51820 | Malmo Cloud 2 | Cloud |
| se-mma-wg-103 | 45.83.220.70:51820 | Malmo Cloud 3 | Cloud |
| se-mma-wg-111 | 45.129.59.19:51820 | Malmo Data 1 | Data Center |
| se-mma-wg-112 | 45.129.59.129:51820 | Malmo Data 2 | Data Center |

## Quick Start

### 1. List Available Configurations

```bash
./scripts/wg-config.sh list
```

Shows all 12 available WireGuard endpoints.

### 2. Select a Configuration

```bash
./scripts/wg-config.sh select se-mma-wg-001
```

This selects a specific endpoint to use during lab provisioning.

### 3. Provision with WireGuard

```bash
./scripts/provision.sh
```

The selected config will be applied during firewall VM provisioning.

### 4. Verify Connectivity

```bash
./scripts/wg-config.sh test
```

Tests if the WireGuard tunnel is active and routing correctly.

## Configuration Structure

Each config file contains:

```ini
[Interface]
PrivateKey = <shared_key>           # Mullvad account private key
Address = 10.66.31.54/32            # IPv4 address on Mullvad network
Address = fc00:bbbb:bbbb:bb01...    # IPv6 address on Mullvad network
DNS = 10.64.0.1                     # Mullvad DNS server

[Peer]
PublicKey = <endpoint_key>          # WireGuard endpoint public key
AllowedIPs = 0.0.0.0/0,::0/0        # Route all traffic through VPN
Endpoint = <ip>:51820              # VPN server endpoint
```

## Usage Scenarios

### Rotate Between Endpoints

If one endpoint becomes unstable, rotate to another:

```bash
./scripts/wg-config.sh rotate
```

Randomly selects a different endpoint from the 12 available.

### View Current Configuration

```bash
./scripts/wg-config.sh current
```

Shows which endpoint is currently selected.

### Check Configuration Details

```bash
./scripts/wg-config.sh info se-mma-wg-001
```

Displays the full WireGuard configuration for an endpoint.

## Integration with Lab

### How It Works

```
Neko Browser / OpenRelik / REMnux
           ↓
Lab Network (10.20.0.0/24)
           ↓
Firewall VM (10.20.0.1)
           ↓
WireGuard Tunnel (wg0)
           ↓
Mullvad VPN Endpoint (Sweden)
           ↓
Internet
```

### Configuration Flow

1. **Select endpoint:** `./scripts/wg-config.sh select se-mma-wg-XXX`
2. **Activate in firewall:** Stored in `wireguard/active-wg0.conf`
3. **Provision firewall:** `./scripts/provision.sh` or `vagrant provision firewall`
4. **Configure wg0 interface:** Ansible playbook sets up the WireGuard tunnel
5. **Route lab traffic:** All traffic from 10.20.0.0/24 routes through VPN

### Environment Variable (Alternative)

Instead of using the script, you can set the full WireGuard config directly:

```bash
export MULLVAD_WG_CONF="[Interface]
PrivateKey = UCBE7Gw5ljpNg5nApRkoJIT8o32YXpTHJR7DN983QkY=
..."

./scripts/provision.sh
```

## Advanced Usage

### Backup and Restore Configurations

Backup the currently active config:

```bash
./scripts/wg-config.sh backup
```

Restore from the latest backup:

```bash
./scripts/wg-config.sh restore
```

Backups are stored in `wireguard/.backup/`.

### Manual WireGuard Control

SSH into the firewall VM and control WireGuard directly:

```bash
# Check WireGuard status
vagrant ssh firewall
sudo wg show

# Bring interface up/down
sudo wg-quick up wg0
sudo wg-quick down wg0

# View configuration
sudo cat /etc/wireguard/wg0.conf
```

### Switch Endpoints Without Reprovisioning

If already provisioned, you can switch endpoints on-the-fly:

```bash
# On firewall VM
sudo wg-quick down wg0
sudo cp /path/to/new-config.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0
```

## Security Notes

### What's Protected

* **Lab-to-Internet traffic** encrypted through Mullvad VPN  
* **Multiple endpoint options** for redundancy and diversity  
* **Network isolation** - VPN routes all lab traffic  
* **DNS privacy** - Mullvad DNS (10.64.0.1) used  
* **IPv6 support** - Both IPv4 and IPv6 routed

### What's Not Protected

* **Lab internal traffic** - OpenRelik, REMnux, Neko communicate unencrypted within lab network  
* **Lab to host traffic** - Guacamole (18080), OpenRelik (8710/8711) accessible from host  
* **WireGuard key exposure** - Private key is the "Famous Wasp" experimental account  
* **Endpoint IP visibility** - VPN exit IP visible to destination websites

## Troubleshooting

### Check WireGuard Status

```bash
vagrant ssh firewall
sudo systemctl status lab-firewall
sudo wg show wg0
sudo ip route show
```

### WireGuard Interface Not Coming Up

```bash
# Check if endpoint is reachable
vagrant ssh firewall
nc -zu -w 1 193.138.218.220 51820

# View detailed logs
sudo journalctl -u wg-quick@wg0 -f
```

### Firewall Rules Blocking VPN

```bash
# List current nftables rules
vagrant ssh firewall
sudo nft list ruleset | grep -A5 -B5 51820
```

### Switch to Different Endpoint

```bash
./scripts/wg-config.sh select se-mma-wg-002
vagrant provision firewall
```

## Monitoring

### Check IP Address

```bash
# From inside lab
vagrant ssh openrelik
curl https://api.mullvad.net/ip

# Should return Swedish exit IP
```

### Monitor Traffic

```bash
# From firewall
vagrant ssh firewall
sudo tcpdump -i wg0 -n  # WireGuard traffic
sudo tcpdump -i eth0 -n # External traffic (should show VPN endpoint IPs)
```

## Rotating Endpoints

To cycle through different endpoints for load balancing or evasion:

```bash
# Automatic random rotation
./scripts/wg-config.sh rotate

# Manual selection
./scripts/wg-config.sh list
./scripts/wg-config.sh select se-mma-wg-005
vagrant provision firewall
```

## Account Information

**Device Name:** Famous Wasp  
**Private Key:** `UCBE7Gw5ljpNg5nApRkoJIT8o32YXpTHJR7DN983QkY=`  
**VPN IP:** 10.66.31.54 (IPv4) / fc00:bbbb:bbbb:bb01::3:1f35 (IPv6)

This is a shared experimental Mullvad account for the Utgard lab environment.

## References

- **Mullvad VPN:** https://mullvad.net/
- **WireGuard:** https://www.wireguard.com/
- **WireGuard Protocol:** https://www.wireguard.com/protocol/
- **Mullvad API:** https://api.mullvad.net/

## Integration with Other Components

### With Neko Tor Browser

- Neko traffic → Lab network → Firewall → WireGuard → Mullvad → Tor → .onion sites
- Provides both VPN anonymity and Tor anonymity layers

### With OpenRelik

- Can analyze VPN traffic patterns
- See encrypted tunnel to Mullvad endpoint
- Useful for understanding VPN behavior

### With REMnux

- Deep packet inspection of WireGuard handshake
- Analyze VPN implementation details
- Test traffic leaks

## Commands Reference

```bash
# Management
./scripts/wg-config.sh list              # List all endpoints
./scripts/wg-config.sh current           # Show active endpoint
./scripts/wg-config.sh select <name>     # Choose endpoint
./scripts/wg-config.sh rotate            # Random endpoint
./scripts/wg-config.sh info <name>       # Show config details

# Provisioning
./scripts/wg-config.sh activate <name>   # Activate for next provision
./scripts/provision.sh                   # Apply selected config

# Testing
./scripts/wg-config.sh test              # Test connectivity
vagrant ssh firewall                      # SSH into firewall
sudo wg show wg0                          # Check interface status
curl https://api.mullvad.net/ip           # Check exit IP

# Maintenance
./scripts/wg-config.sh backup             # Backup current
./scripts/wg-config.sh restore            # Restore from backup
```

---

**Last Updated:** January 9, 2026  
**Total Endpoints:** 12  
**Region:** Sweden (Malmo)  
**Status:** Production Ready
