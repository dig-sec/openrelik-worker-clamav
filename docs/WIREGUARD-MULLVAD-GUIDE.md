# WireGuard/Mullvad Integration Guide

Utgard lab supports Mullvad VPN for secure, anonymized internet access through the firewall gateway.

## Overview

```
┌─────────────────┐
│   Host Machine  │
│  (optional WG)  │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Firewall│──── WireGuard ──────┐
    │   VM    │  (Mullvad Exit)     │
    └────┬────┘                     │
         │                          │
    ┌────┴────┐               ┌─────▼──────┐
    │ REMnux  │               │   Internet  │
    │         │◄──── All traffic routed ──►│(Mullvad)
    └─────────┘    through secure tunnel   └─────────┘
```

## How It Works

1. **Firewall VM** has WireGuard interface (wg0) connected to Mullvad exit
2. **Lab VM** (REMnux) routes all traffic through firewall
3. **All outbound traffic** is encrypted and anonymized via Mullvad
4. **Host machine** can optionally connect to same exit point
5. **No direct internet** access to lab VMs - everything through tunnel

## Available Mullvad Endpoints

Three Swedish Mullvad exit points:

| File | Endpoint | IP |
|------|----------|-----|
| se-mma-wg-001.conf | #1 | 193.138.218.220 |
| se-mma-wg-002.conf | #2 | 193.138.218.80 |
| se-mma-wg-003.conf | #3 | 193.138.218.83 |

Copy the matching `.conf.example` into `ansible/roles/firewall/files/private/` and replace placeholders.

## Deployment

### Option 1: Use Default Endpoint (SE-MMA-002)

```bash
cd /home/azureuser/git/utgard
vagrant up firewall
```

### Option 2: Select Specific Endpoint

```bash
# Use SE-MMA-001
WG_ENDPOINT=se-mma-wg-001 vagrant up firewall

# Use SE-MMA-003
WG_ENDPOINT=se-mma-wg-003 vagrant up firewall
```

### Option 3: Deploy Without VPN (No WireGuard)

```bash
# Disable WireGuard in config.yml (features.enable_wireguard: false)
vagrant up firewall
```

The firewall will still work for routing; it just won't route through Mullvad.

## Verification

### Check WireGuard on Firewall VM

```bash
# SSH into firewall
vagrant ssh firewall

# View interface
ip addr show wg0

# Check routes
ip route show

# View WireGuard details
wg show

# Test Mullvad DNS
nslookup google.com 10.64.0.1
```

### Check From REMnux VM

```bash
vagrant ssh remnux

# All traffic goes through firewall
ping 8.8.8.8

# DNS works (using Mullvad's 10.64.0.1)
nslookup google.com
```

### Verify Exit IP

From any VM or host (with Mullvad connected):
```bash
# Should show Mullvad Swedish IP
curl https://am.i.mullvad.net/json | jq .
```

## Host Machine Connection (Optional)

To route your host machine through the same Mullvad exit:

```bash
# Copy host config
sudo cp ansible/roles/firewall/files/host-client.conf.example /etc/wireguard/utgard.conf
sudo nano /etc/wireguard/utgard.conf

# Connect
sudo wg-quick up utgard

# Verify Mullvad IP
curl https://am.i.mullvad.net/json

# Disconnect
sudo wg-quick down utgard
```

## Dynamic Endpoint Switching

Change Mullvad exit without redeploying:

```bash
# SSH to firewall
vagrant ssh firewall

# Get current endpoint
wg show

# Bring down WireGuard
sudo wg-quick down wg0

# Copy new endpoint config
sudo cp /tmp/ansible/roles/firewall/files/private/se-mma-wg-003.conf /etc/wireguard/wg0.conf

# Bring up with new endpoint
sudo wg-quick up wg0

# Verify
wg show
```

## Network Architecture

### Lab Network (10.20.0.0/24)

- **Firewall**: 10.20.0.2 (gateway, WireGuard tunnel)
- **REMnux**: 10.20.0.20 (routes through firewall)

### WireGuard

- **Interface**: wg0
- **Lab IP**: 10.66.31.54/32 (as per Mullvad config)
- **DNS**: 10.64.0.1 (Mullvad)
- **Default gateway**: Through Mullvad exit

### Firewall Rules

- **Forward traffic** from lab VMs (10.20.0.0/24) → WireGuard interface
- **Masquerade** outbound traffic (NAT)
- **Allow DNS** through Mullvad (10.64.0.1)

## Troubleshooting

### WireGuard Won't Connect

```bash
# Check if interface exists
sudo ip addr show wg0

# Check logs
sudo dmesg | tail -20

# Try manual connect
sudo wg-quick up wg0
```

### DNS Not Resolving

```bash
# Test Mullvad DNS directly
nslookup google.com 10.64.0.1

# Check /etc/resolv.conf
cat /etc/resolv.conf

# Flush cache and retry
sudo systemctl restart systemd-resolved
```

### Slow Throughput

- Try different endpoint: `WG_ENDPOINT=se-mma-wg-001 vagrant up firewall`
- Check latency to endpoint: `mtr 193.138.218.220`
- Check network load: `iftop -i wg0`

### Can't Reach Lab VMs From Host

- Verify firewall routing: `ip route show` on firewall
- Check NAT rules: `sudo iptables -t nat -L`
- Ensure firewall VM is running: `vagrant status`
- Test connectivity: `ping 10.20.0.20` (from host, won't work if isolated)

## Security Considerations

### ✅ Implemented

- Single encrypted tunnel for all lab traffic
- No DNS leaks (using Mullvad's 10.64.0.1)
- Multiple exit points for flexibility
- Traffic isolation via network namespace

### ⚠️ Lab-Only

- Keys included in repository (test lab only)
- No perfect forward secrecy (static keys)
- Single point of failure (firewall VM)

### 🔒 For Production

- Rotate/regenerate WireGuard keys
- Use separate Mullvad account for production
- Implement failover (multiple firewall VMs)
- Monitor bandwidth/connections
- Audit DNS queries

## Configuration Files Reference

### /etc/wireguard/wg0.conf (Firewall)

```ini
[Interface]
PrivateKey = [Mullvad private key]
Address = 10.66.31.54/32,fc00:bbbb:bbbb:bb01::3:1f35/128
DNS = 10.64.0.1

[Peer]
PublicKey = [Mullvad public key]
AllowedIPs = 0.0.0.0/0,::0/0
Endpoint = [Mullvad IP:51820]
```

### Firewall Routes

- Lab VMs → Firewall (10.20.0.0/24 via 10.20.0.2)
- Firewall → Internet (0.0.0.0/0 via WireGuard wg0)
- DNS → Mullvad (10.64.0.1 via WireGuard)

## Additional Resources

- Lab README: [README.md](../README.md)
- WireGuard configs: [ansible/roles/firewall/files/](../ansible/roles/firewall/files/) (examples) and [ansible/roles/firewall/files/private/](../ansible/roles/firewall/files/private/) (real configs)
- Ansible provisioning: [ansible/README.md](../ansible/README.md)
