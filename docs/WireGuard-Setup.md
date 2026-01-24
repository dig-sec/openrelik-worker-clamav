# WireGuard / Mullvad VPN Setup

## Overview
The firewall VM can route all lab traffic through Mullvad VPN using WireGuard. This provides:
- Anonymized internet egress for REMnux VM
- Centralized VPN management at the firewall
- Fail-closed nftables rules if WireGuard interface is down

## Prerequisites
1. A Mullvad VPN account or valid Mullvad WireGuard configuration
2. WireGuard configuration file (`wg0.conf`) for a Mullvad exit point
3. `enable_wireguard: true` in `config.yml`

## Obtain Mullvad WireGuard Configuration

### Option 1: Download from Mullvad
1. Visit [https://mullvad.net/en/download/wireguard-config/](https://mullvad.net/en/download/wireguard-config/)
2. Select an exit country and download the config
3. Choose a filename matching the endpoint (e.g., `se-mma-wg-002.conf` for Sweden)

### Option 2: Use Mullvad CLI
```bash
# On a machine with Mullvad CLI installed
mullvad relay set location se  # Sweden
mullvad wireguard key regenerate
mullvad wireguard config get > se-mma-wg-002.conf
```

## Configure

### 1. Place WireGuard Config
Copy the Mullvad config file to the ansible role:
```bash
cp se-mma-wg-002.conf ansible/roles/firewall/files/private/se-mma-wg-002.conf
```

The filename must match the `wg_endpoint` setting or use the `WG_ENDPOINT` environment variable.

### 2. Update config.yml
```yaml
features:
  enable_wireguard: true

wireguard:
  endpoint: "se-mma-wg-002"  # Matches filename above
```

### 3. Re-provision Firewall
```bash
vagrant reload firewall --provision
```

Or re-run the playbook:
```bash
cd ansible
ansible-playbook playbooks/firewall.yml
```

## Verify WireGuard Status

### Check on Firewall VM
```bash
vagrant ssh firewall
sudo wg show            # Show WireGuard interface details
sudo ip addr show wg0   # Show wg0 IP
curl https://am.i.mullvad.net/connected  # Verify Mullvad exit
```

### Check from REMnux
```bash
# REMnux
curl https://am.i.mullvad.net/json
# Should show: "mullvad_exit_ip_hostname": "exit-xx.mullvad.net"
```

## Troubleshooting

### WireGuard Service Won't Start
```bash
vagrant ssh firewall
sudo systemctl status wg-quick@wg0
sudo systemctl restart wg-quick@wg0
sudo journalctl -xe  # Check logs
```

### No DNS Resolution in Lab VMs
```bash
# On firewall, verify dnsmasq is running
sudo systemctl status dnsmasq

# Check DNS resolution from REMnux
nslookup google.com 10.20.0.2
```

### Mullvad Connection Fails
1. Verify config file format:
   ```bash
   sudo wg showconf wg0
   ```
2. Check if Mullvad servers are reachable (endpoint IPs may change)
3. Download fresh config from Mullvad website
4. Ensure private key matches current Mullvad account

### Lab Connectivity Broken
- Check nftables rules:
  ```bash
  sudo nft list ruleset | grep postrouting
  ```
- Verify WireGuard interface is up:
  ```bash
  ip link show wg0
  ```
- Check if `wg0` is being used as egress (nftables should masquerade via `wg0`)

## DNS Leak Prevention
Dnsmasq upstreams default to Mullvad DNS (`10.64.0.1`) + Cloudflare/Google. For strict DNS-over-Tor or additional privacy, customize in firewall role defaults:

```yaml
dnsmasq_upstream_servers:
  - "10.64.0.1"          # Mullvad DNS
  # - "1.1.1.1"          # Cloudflare (remove if privacy-sensitive)
  # - "8.8.8.8"          # Google (remove if privacy-sensitive)
```

## Disabling WireGuard
To revert to direct internet access:
```yaml
# config.yml
features:
  enable_wireguard: false
```

Re-provision:
```bash
vagrant reload firewall --provision
```

Nftables will fall back to using the host's default interface for NAT egress.

## Advanced: Custom Mullvad Endpoint
If you have multiple Mullvad configs for different exit points:
```bash
cp se-mma-wg-002.conf ansible/roles/firewall/files/private/
cp se-mma-wg-003.conf ansible/roles/firewall/files/private/
cp nl-mma-wg-001.conf ansible/roles/firewall/files/private/
```

Switch between them via environment variable:
```bash
WG_ENDPOINT=nl-mma-wg-001 vagrant reload firewall --provision
```

Or update `config.yml`:
```yaml
wireguard:
  endpoint: "nl-mma-wg-001"
```

## Monitoring WireGuard
Check bandwidth usage on firewall:
```bash
while true; do clear; date; wg; sleep 2; done
```

Monitor in Prometheus (if deployed):
```promql
wireguard_traffic_bytes_received{interface="wg0"}
wireguard_traffic_bytes_sent{interface="wg0"}
```

