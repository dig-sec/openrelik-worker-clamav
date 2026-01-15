# WireGuard/Mullvad Integration Summary

**Status**: ✅ COMPLETE

This document summarizes the integration of Mullvad VPN exit configurations into the Utgard lab infrastructure.

## What Was Integrated

### 1. WireGuard Configuration Files
**Location**: `ansible/roles/firewall/files/`

```
ansible/roles/firewall/files/
├── host-client.conf             # Optional: host machine VPN connection
├── se-mma-wg-001.conf          # Mullvad Sweden endpoint #1
├── se-mma-wg-002.conf          # Mullvad Sweden endpoint #2
└── se-mma-wg-003.conf          # Mullvad Sweden endpoint #3
```

**Purpose**: These files define Mullvad VPN exit points for encrypted, anonymized internet access.

### 2. Ansible Task for WireGuard Setup
**Location**: `ansible/roles/firewall/tasks/wireguard.yml`

**Capabilities**:
- Installs WireGuard kernel module and userspace tools
- Configures WireGuard interface (wg0) on firewall VM
- Supports **two deployment methods**:
  - **Method 1** (Legacy): Direct config content via `wg0_conf` variable
  - **Method 2** (Active): Select Mullvad endpoint from `ansible/roles/firewall/files/`
- Enables WireGuard persistence across reboots
- Tests Mullvad connectivity
- Verifies DNS resolution through Mullvad

### 3. Vagrantfile Integration
**Location**: `Vagrantfile` (firewall VM section)

**Feature**: Environment variable support for endpoint selection
```ruby
wg_endpoint: ENV['WG_ENDPOINT'] || 'se-mma-wg-002'
```

**Usage**:
```bash
# Default endpoint (se-mma-wg-002)
vagrant up firewall

# Specific endpoint
WG_ENDPOINT=se-mma-wg-001 vagrant up firewall
WG_ENDPOINT=se-mma-wg-003 vagrant up firewall
```

### 4. Documentation
Created comprehensive guides:

- **[WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md)**
  - Architecture diagram and how it works
  - Deployment options and verification steps
  - Troubleshooting guide
  - Security considerations
  - Network architecture details

- **[ansible/README.md](ansible/README.md)** (updated)
  - Firewall role WireGuard variables documented
  - References to WireGuard guide


## Architecture

### Before Integration
```
Lab VMs → Direct Internet Access (No Encryption)
```

### After Integration
```
Lab VMs → Firewall VM → WireGuard (wg0) → Mullvad Exit → Internet (Encrypted)
         └─────────────────┬──────────────────────────┘
              All traffic routed through single encrypted tunnel
              with Mullvad's IP address as origin
```

## How It Works

1. **Firewall VM** runs WireGuard interface connected to Mullvad endpoint
2. **Ansible** automatically deploys WireGuard during `vagrant up firewall`
3. **Lab VMs** (OpenRelik, REMnux) have firewall as default gateway
4. **All outbound traffic** from lab VMs is encrypted via WireGuard
5. **Mullvad DNS** (10.64.0.1) prevents DNS leaks
6. **Operators** can select different Mullvad endpoints at deployment time

## Deployment Options

### Option 1: Standard Deployment (Default Endpoint)
```bash
cd /home/azureuser/git/utgard
vagrant up firewall

# Result: Firewall VM uses se-mma-wg-002 (Mullvad Sweden #2)
```

### Option 2: Select Specific Endpoint
```bash
# Use Mullvad Sweden #1
WG_ENDPOINT=se-mma-wg-001 vagrant up firewall

# Use Mullvad Sweden #3
WG_ENDPOINT=se-mma-wg-003 vagrant up firewall
```

### Option 3: Offline/No VPN Mode
```bash
# Disable WireGuard in config.yml (features.enable_wireguard: false)
# Firewall still functions as gateway without VPN tunnel
```

## Available Mullvad Endpoints

| Identifier | Server | IP | Port |
|------------|--------|-----|------|
| se-mma-wg-001 | Sweden #1 | 193.138.218.220 | 51820 |
| se-mma-wg-002 | Sweden #2 | 193.138.218.80 | 51820 |
| se-mma-wg-003 | Sweden #3 | 193.138.218.83 | 51820 |

All use Mullvad's public keys and are pre-configured in `ansible/roles/firewall/files/`.

## Verification Steps

### Check Firewall VM
```bash
vagrant ssh firewall
ip addr show wg0          # Verify interface (10.66.31.54)
wg show                   # View WireGuard status
curl https://am.i.mullvad.net/json | jq '.'  # Check exit IP
```

### Check Lab VMs
```bash
vagrant ssh openrelik
ping 8.8.8.8             # Routes through firewall → Mullvad
nslookup google.com      # Uses Mullvad DNS (10.64.0.1)
curl https://am.i.mullvad.net/json | jq '.'  # Should show Mullvad exit
```

### From Host (Optional)
```bash
# If host has WireGuard installed
sudo wg-quick up /home/azureuser/git/utgard/ansible/roles/firewall/files/host-client.conf
curl https://am.i.mullvad.net/json | jq '.'
sudo wg-quick down utgard
```

## Configuration Details

### WireGuard Task Flow

1. **Pre-check**: Verify WireGuard kernel support
2. **Install**: Install WireGuard from Ubuntu repositories
3. **Deploy Config**: Copy selected endpoint config to `/etc/wireguard/wg0.conf`
4. **Enable Interface**: Bring up wg0 with `wg-quick`
5. **Boot Persistence**: Enable `wg-quick@wg0` systemd service
6. **Verification**: Test Mullvad DNS and connectivity
7. **Logging**: Report status to Ansible output

### Lab Network Routing

- **Lab Network**: 10.20.0.0/24
- **Firewall IP**: 10.20.0.2 (gateway)
- **Lab VMs Default Route**: 10.20.0.2
- **Firewall Default Route**: Via WireGuard wg0 to Mullvad
- **Forwarding**: nftables rules forward lab traffic through wg0

### WireGuard Interface

- **Interface**: wg0
- **Lab Side IP**: 10.66.31.54/32 (from Mullvad config)
- **IPv6**: fc00:bbbb:bbbb:bb01::3:1f35/128
- **DNS**: 10.64.0.1 (Mullvad's resolver)
- **Peer**: Mullvad gateway public key + endpoint IP

## Files Modified/Created

### Created Files
- ✅ `WIREGUARD-MULLVAD-GUIDE.md` - Complete WireGuard/Mullvad documentation
- ✅ `INTEGRATION-SUMMARY.md` - This file

### Modified Files
- ✅ `ansible/roles/firewall/tasks/wireguard.yml` - Enhanced with Mullvad endpoint selection
- ✅ `Vagrantfile` - Added WG_ENDPOINT environment variable support
- ✅ `ansible/README.md` - Documented WireGuard/Mullvad variables
- ✅ `README.md` - Added reference to WireGuard guide

### Existing Files (Unchanged)
- `ansible/roles/firewall/files/host-client.conf` - Host machine VPN connection (optional)
- `ansible/roles/firewall/files/se-mma-wg-001.conf` - Mullvad Sweden #1 config
- `ansible/roles/firewall/files/se-mma-wg-002.conf` - Mullvad Sweden #2 config
- `ansible/roles/firewall/files/se-mma-wg-003.conf` - Mullvad Sweden #3 config
- `ansible/roles/firewall/tasks/main.yml` - References wireguard.yml
- `ansible/roles/firewall/handlers/main.yml` - Handlers for WireGuard

## Integration Points

### Vagrant → Ansible
```
Vagrantfile firewall.vm.provision
  ↓
  env['wg_endpoint'] = ENV['WG_ENDPOINT'] || 'se-mma-wg-002'
  ↓
  passes wg_endpoint as extra_vars
  ↓
  Ansible firewall.yml playbook
```

### Ansible → WireGuard Task
```
roles/firewall/tasks/main.yml
  ↓
  - include_tasks: wireguard.yml
  ↓
  Template task reads wg_endpoint variable
  ↓
  src: "roles/firewall/files/{{ wg_endpoint }}.conf"
  ↓
  Copies selected endpoint config to /etc/wireguard/wg0.conf
```

### WireGuard → Lab VMs
```
wg0 interface on firewall
  ↓
  nftables rules forward lab traffic (10.20.0.0/24)
  ↓
  nftables masquerade to WireGuard IP (10.66.31.54)
  ↓
  Traffic exits through Mullvad with encrypted tunnel
```

## Security Model

### ✅ Implemented
- Single encrypted tunnel for all lab traffic
- No DNS leaks (using Mullvad's resolver)
- Multiple exit points available
- Firewall acts as trusted gateway
- Lab VMs isolated from direct internet

### ⚠️ Test Lab Limitations
- Keys included in repository (regenerate for production)
- Static WireGuard keys (no perfect forward secrecy)
- Single firewall VM (no failover)
- Shared Mullvad tunnel (not exclusive)

### 🔒 Production Recommendations
- Generate new WireGuard keys
- Use dedicated Mullvad account
- Implement firewall VM redundancy
- Monitor bandwidth and connections
- Audit DNS query logs
- Rotate keys periodically

## Testing Checklist

- [ ] Deploy with default endpoint: `vagrant up firewall`
- [ ] Verify WireGuard interface: `ip addr show wg0`
- [ ] Test Mullvad connectivity: `wg show`
- [ ] Deploy with specific endpoint: `WG_ENDPOINT=se-mma-wg-001 vagrant up firewall`
- [ ] Verify lab VM traffic: `ping 8.8.8.8` from openrelik VM
- [ ] Check exit IP: `curl https://am.i.mullvad.net/json` from any VM
- [ ] Test DNS resolution: `nslookup google.com` from lab VM
- [ ] Switch endpoints without redeployment (manual test)
- [ ] Verify firewall rules: `sudo nft list ruleset` on firewall

## Next Steps

1. **Test Deployment**
   ```bash
   vagrant up firewall
   vagrant ssh firewall
   wg show
   ```

2. **Deploy All VMs**
   ```bash
   vagrant up  # Deploys firewall + openrelik + remnux
   ```

3. **Verify Connectivity**
   ```bash
   vagrant ssh openrelik
   curl https://am.i.mullvad.net/json | jq '.'
   ```

4. **Optional: Test Endpoint Switching**
   ```bash
   # Deploy with different endpoint
   WG_ENDPOINT=se-mma-wg-003 vagrant destroy firewall -f
   WG_ENDPOINT=se-mma-wg-003 vagrant up firewall
   ```

## Documentation References

- **User Guide**: [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md)
- **Endpoint Details**: [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md#available-mullvad-endpoints)
- **Ansible Integration**: [ansible/README.md](ansible/README.md)
- **Lab Overview**: [README.md](README.md)

## Questions?

See the comprehensive troubleshooting section in [WIREGUARD-MULLVAD-GUIDE.md](WIREGUARD-MULLVAD-GUIDE.md) for:
- WireGuard connection issues
- DNS resolution problems
- Performance optimization
- Endpoint switching procedures
