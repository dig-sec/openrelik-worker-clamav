# Quick Reference: WireGuard/Mullvad Deployment

## One-Minute Setup

```bash
# Deploy with default Mullvad endpoint (Sweden #2)
cd /home/azureuser/git/utgard
vagrant up firewall

# Deploy with specific endpoint
WG_ENDPOINT=se-mma-wg-001 vagrant up firewall   # Sweden #1
WG_ENDPOINT=se-mma-wg-003 vagrant up firewall   # Sweden #3

# Deploy all VMs
vagrant up
```

## Verify It's Working

```bash
# Check firewall WireGuard
vagrant ssh firewall
wg show

# Check lab VM can reach internet
vagrant ssh remnux
curl https://am.i.mullvad.net/json | jq '.ip'  # Should show Mullvad IP
```

## Available Endpoints

| Command | Endpoint | IP |
|---------|----------|-----|
| `vagrant up firewall` | se-mma-wg-002 | 193.138.218.80 |
| `WG_ENDPOINT=se-mma-wg-001 vagrant up firewall` | se-mma-wg-001 | 193.138.218.220 |
| `WG_ENDPOINT=se-mma-wg-003 vagrant up firewall` | se-mma-wg-003 | 193.138.218.83 |

## Common Tasks

### Guacamole
```bash
# Web UI for RDP/SSH access
https://20.240.216.254.sslip.io/guacamole
```

### Check WireGuard Status
```bash
vagrant ssh firewall
ip addr show wg0          # IP address
wg show                   # Interface details
ip route show             # Routing table
```

### Switch Endpoint Without Full Redeployment
```bash
vagrant ssh firewall
sudo wg-quick down wg0
sudo cp /tmp/ansible/roles/firewall/files/private/se-mma-wg-003.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0
```

### Verify No DNS Leaks
```bash
vagrant ssh remnux
nslookup google.com       # Should use Mullvad DNS (10.64.0.1)
```

### Deploy Host Machine VPN (Optional)
```bash
sudo cp /home/azureuser/git/utgard/ansible/roles/firewall/files/host-client.conf.example /etc/wireguard/utgard.conf
sudo nano /etc/wireguard/utgard.conf
sudo wg-quick up utgard
curl https://am.i.mullvad.net/json | jq '.'
sudo wg-quick down utgard
```

### Destroy and Redeploy Firewall
```bash
vagrant destroy firewall -f
vagrant up firewall
```

### REMnux Snapshot Recovery
```bash
# Save a clean snapshot
vagrant snapshot save remnux clean

# Restore after analysis
vagrant snapshot restore remnux clean
```

## Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| WireGuard won't connect | See [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md#wireguard-wont-connect) |
| DNS not resolving | See [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md#dns-not-resolving) |
| Slow throughput | See [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md#slow-throughput) |
| Can't reach lab VMs | See [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md#cant-reach-lab-vms-from-host) |

## Documentation

- **Quick Start**: [README.md](../README.md)
- **WireGuard Guide**: [WIREGUARD-MULLVAD-GUIDE.md](../WIREGUARD-MULLVAD-GUIDE.md)
- **Architecture**: [DEPLOYMENT-FLOW.md](DEPLOYMENT-FLOW.md)

## Lab Network

```
Firewall: 10.20.0.2 (gateway with WireGuard)
REMnux: 10.20.0.20 (routes through firewall)
WireGuard Lab IP: 10.66.31.54
Mullvad DNS: 10.64.0.1
```

## Key Files

- `ansible/roles/firewall/tasks/wireguard.yml` - WireGuard setup
- `ansible/roles/firewall/files/private/se-mma-wg-*.conf` - Mullvad endpoint configs (not committed)
- `Vagrantfile` - VM definitions (includes WG_ENDPOINT support)
- `ansible/README.md` - Provisioning documentation

## Environment Variables

| Variable | Default | Example |
|----------|---------|---------|
| `WG_ENDPOINT` | se-mma-wg-002 | `WG_ENDPOINT=se-mma-wg-001` |

---

**Status**: ✅ Integration Complete - Ready for Deployment

For complete documentation, see [WIREGUARD-MULLVAD-GUIDE.md](../WIREGUARD-MULLVAD-GUIDE.md)
