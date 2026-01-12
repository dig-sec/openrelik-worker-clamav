# Neko Tor Browser Integration

## Overview

Neko Tor Browser is now integrated into the Utgard lab environment. This provides:

* **Secure Tor browsing** - Access .onion sites within an isolated container  
* **Lab network isolation** - All traffic visible on lab network for analysis  
* **Multi-user support** - Multiple analysts can control the browser simultaneously  
* **WebRTC streaming** - Low-latency video via modern web protocols  
* **Guacamole gateway** - Access through existing Guacamole web gateway  

## Quick Access

**After provisioning:**
```
http://localhost:8080          # Direct access
http://localhost:18080/guacamole/  # Via Guacamole gateway
```

**Default credentials:** `neko` / `admin`

## Components Added

| Component | Location | Purpose |
|-----------|----------|---------|
| **Neko VM** | 10.20.0.40 | Dedicated VM for Tor Browser |
| **Ansible Playbook** | `provision/neko.yml` | Installation and configuration |
| **Docker Compose** | `services/neko/docker-compose.neko.yml` | Standalone deployment option |
| **Vagrantfile Entry** | Vagrant config | VM definition and provisioning |
| **Documentation** | `docs/neko/NEKO-SETUP.md` | Full integration guide |
| **Test Script** | `test-connections.sh` | Updated with neko checks |
| **Config Script** | `scripts/configure-neko-guacamole.sh` | Guacamole integration |
| **Quick Reference** | `scripts/NEKO-QUICKREF.sh` | Command cheatsheet |

## Provisioning

Neko is automatically included when you run:

```bash
./scripts/provision.sh
```

Or provision just neko:

```bash
vagrant up neko
```

## Network Architecture

```
┌─────────────────────────────────────────┐
│ Host System (8080, 8081 forwarded)     │
├─────────────────────────────────────────┤
│                                         │
│  Firewall VM (10.20.0.1)              │
│  ├─ Mullvad VPN (if configured)       │
│  ├─ nftables firewall                 │
│  └─ Suricata IDS                      │
│           ↓                             │
│  Neko VM (10.20.0.40)                 │
│  └─ Docker Container                   │
│     └─ Tor Browser                     │
│        └─ .onion sites                │
│                                         │
└─────────────────────────────────────────┘
```

## Usage Scenarios

### 1. Analyze Malicious Tor Sites

```bash
# Access neko
# Open .onion site URL in Tor Browser
# All traffic captured on firewall:
vagrant ssh firewall
sudo tcpdump -i eth1 'host 10.20.0.40' -w /tmp/site.pcap

# Analyze in OpenRelik or REMnux
```

### 2. Collaborative Threat Analysis

- Admin opens Neko connection
- Multiple analysts log in simultaneously
- Collaborative investigation of suspicious content
- All actions logged and visible

### 3. Safe Browsing Research

- Test website behavior in isolated environment
- No risk to production systems
- Traffic isolated to lab network
- Container destroyed after investigation

### 4. Tor Network Traffic Analysis

- Capture all Tor traffic for analysis
- Study Tor handshake patterns
- Identify Tor vs regular traffic
- Research anonymity effectiveness

## Troubleshooting

**Neko not accessible:**
```bash
# Check if VM is running
vagrant status neko

# Start it if needed
vagrant up neko

# Check service status
vagrant ssh neko
sudo systemctl status neko
```

**Port conflicts:**
- Modify ports in `Vagrantfile` and `provision/neko.yml`
- Change host port from 8080 to alternative (e.g., 8090)

**Memory issues:**
- Increase VM memory in Vagrantfile: `lv.memory = 4096`

See [NEKO-SETUP.md](./NEKO-SETUP.md) for comprehensive troubleshooting.

## Security Notes

* **What's protected:**
- Container isolation from host
- Lab network isolation
- Persistent privacy (no data on host)
- VPN + Tor stacking (if Mullvad configured)

WARNING:️ **What's not protected:**
- Lab admins can see all traffic
- Browser vulnerabilities still apply
- No OS-level exploit isolation

## Further Reading

- **Full Guide:** [NEKO-SETUP.md](./NEKO-SETUP.md)
- **Quick Reference:** [scripts/NEKO-QUICKREF.sh](../../scripts/NEKO-QUICKREF.sh)
- **Neko Project:** https://github.com/m1k1o/neko
- **Tor Project:** https://www.torproject.org/

---

**Neko Version:** Latest (automatically pulled)  
**Added:** January 2026
