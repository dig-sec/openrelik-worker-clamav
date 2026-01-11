# Utgard - Malware Analysis Lab

Automated malware analysis lab with isolated network, OpenRelik forensics platform, REMnux analyst workstation, and Mullvad VPN egress.

## Malware Analysis Network Architecture

This lab provides a secure, isolated environment for analyzing malicious software:

- **OpenRelik**: Artifact indexing and forensic analysis platform with UI/API
- **REMnux VM**: Analyst workstation with base tools (YARA, binwalk, tshark); full REMnux CLI install optional
- **Firewall/Gateway**: Multi-homed VM enforcing strict isolation with Mullvad VPN egress
- **Network Monitoring**: Continuous packet capture + Suricata IDS

### Network Architecture
```
┌─────────────────────────────────────────────────┐
│ Host Machine                                     │
│   Access: localhost:8710/8711 (OpenRelik)      │
│           localhost:18080/guacamole (Guacamole) │
│           localhost:8080 (Neko Tor Browser)     │
├─────────────────────────────────────────────────┤
│ Firewall VM (10.20.0.1)                        │
│   - nginx reverse proxy                         │
│   - nftables firewall (default deny)            │
│   - WireGuard → Mullvad VPN                     │
│   - Packet capture + Suricata IDS               │
├─────────────────────────────────────────────────┤
│ Isolated Lab Network (10.20.0.0/24)            │
│                                                  │
│  OpenRelik (10.20.0.30)        REMnux (10.20.0.20) │
│  - Docker containers           - Full REMnux dist │
│  - Forensics analysis          - RDP enabled     │
│  - Internet via firewall       - Analysis tools  │
│                                                  │
│  Neko Tor Browser (10.20.0.40)                  │
│  - WebRTC Tor Browser session                    │
│  - Internet via firewall                         │
└─────────────────────────────────────────────────┘
```

### Security Principles
- **Complete isolation**: Lab VMs have NO direct internet access from the host
- **Controlled egress**: All traffic routes through firewall (optionally via Mullvad VPN)
- **Network monitoring**: Full packet capture + IDS on all lab traffic
- **Default deny**: nftables blocks everything except explicit allows
- **Reverse proxy only**: No direct lab VM access from host
- **DNS logging**: All DNS queries logged for C2 analysis
- **Ephemeral VMs**: Easy destroy/rebuild for clean state

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) >= 2.3.4
- [libvirt/KVM](https://libvirt.org/) (Linux hypervisor)
- [vagrant-libvirt plugin](https://github.com/vagrant-libvirt/vagrant-libvirt) >= 0.11.2
- Minimum 12GB RAM (4GB per lab VM + host overhead)
- Minimum 50GB disk space
- Mullvad VPN account (for WireGuard configuration)

**Install on Debian/Ubuntu:**
```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
vagrant plugin install vagrant-libvirt
```

## Quick Start

### 1. Clone and Configure

```bash
git clone <your-repo> utgard
cd utgard
```

### 2. (Optional) Configure Mullvad WireGuard

Get your WireGuard config from [Mullvad account](https://mullvad.net/en/account/wireguard-config):

```bash
export MULLVAD_WG_CONF="$(cat ~/Downloads/mullvad-wg0.conf)"
```

**Without Mullvad:** Lab traffic egresses via the firewall's public interface (not recommended for real malware runs).

### 3. (Optional) Configure OpenRelik OAuth

For Google OAuth instead of local auth:

```bash
export OPENRELIK_CLIENT_ID="your-client-id"
export OPENRELIK_CLIENT_SECRET="your-client-secret"
export OPENRELIK_ALLOWLIST="your-email@gmail.com"
```

**Without OAuth:** OpenRelik uses local authentication (admin/admin on first run).

### 4. Start the Lab

```bash
./scripts/start-lab.sh
```

This will:
- Start the utgard-lab libvirt network (requires sudo password)
- Provision four VMs: firewall, openrelik, remnux, neko
- Install all tools and configure networking
- Enable packet capture and IDS monitoring

**First run takes ~15-25 minutes** (base tools only; REMnux CLI install is disabled by default on Ubuntu 22.04).

### 5. Access Services

- **Guacamole Web Gateway**: http://localhost:18080/guacamole/ (login: `guacadmin/guacadmin`, routed via nginx)
- **OpenRelik UI**: http://localhost:8711/
- **OpenRelik API**: http://localhost:8710/api/v1/docs/
- **Neko Tor Browser**: http://localhost:8080/ (login: `neko/admin`)
  

Authentication:
- **Guacamole**: Default login `guacadmin/guacadmin` (change after first login). Use Guacamole to access RDP/SSH sessions via a web browser—no RDP client required.
- **OpenRelik (local)**: username `admin`, password `admin` (seeded automatically when OAuth is not configured)

**Guacamole** provides browser-based access to REMnux RDP and SSH to all VMs. Configure connections from the Guacamole admin interface after login.

See [docs/GUACAMOLE-SETUP.md](docs/GUACAMOLE-SETUP.md) for Guacamole setup and usage.

Component-by-component overview: see [docs/COMPONENTS.md](docs/COMPONENTS.md).

## Helper Commands

**Lab Management:**
```bash
./scripts/start-lab.sh      # Start all VMs with network
vagrant halt                 # Stop all VMs
vagrant destroy -f           # Delete all VMs (clean slate)
vagrant status               # Check VM status
```

**Individual VM Control:**
```bash
vagrant up firewall          # Start only firewall
vagrant provision openrelik  # Re-run ansible on openrelik
vagrant ssh remnux           # SSH into REMnux
vagrant up neko              # Start Neko Tor Browser VM
vagrant provision neko       # Rebuild Neko container and config
```

**Inside VMs:**
```bash
# On firewall:
sudo tail -f /var/log/syslog | grep LAB_DNS    # Watch DNS queries
sudo tcpdump -i eth1 -nn                       # Live packet capture
ls /var/log/pcaps/                             # Saved pcap files
sudo tail -f /var/log/suricata/fast.log       # IDS alerts

# On openrelik:
openrelik-start              # Start OpenRelik services
openrelik-stop               # Stop OpenRelik services
openrelik-logs               # View container logs

# On remnux:
which yara && yara --version                   # Verify YARA
which binwalk && binwalk --help               # Verify binwalk
which tshark && tshark --version              # Verify tshark
```

## Troubleshooting

### Network not found error

If you see "Network not found: no network with matching name":

```bash
sudo virsh net-start utgard-lab
```

Or use the `scripts/start-lab.sh` script which handles this automatically.

### VMs won't provision

Check libvirt network status:
```bash
virsh net-list --all
sudo virsh net-start utgard-lab
```

### No internet in lab VMs

Verify Mullvad tunnel:
```bash
vagrant ssh firewall -c "sudo wg show"
vagrant ssh firewall -c "curl -s https://am.i.mullvad.net/json | jq"
```

If wg0 is down, set `MULLVAD_WG_CONF` and reprovision:
```bash
export MULLVAD_WG_CONF="$(cat your-mullvad-config.conf)"
vagrant provision firewall
```

### Can't access OpenRelik UI

Check port forwarding and nginx:
```bash
vagrant port firewall
vagrant ssh firewall -c "sudo systemctl status nginx"
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose ps"
```

### Guacamole not reachable

Verify nginx and containers:
```bash
vagrant ssh firewall -c "sudo systemctl status nginx"
vagrant ssh firewall -c "docker ps | grep guacamole"
```

### Provisioning is slow

REMnux full installation takes 20-30 minutes. Monitor progress:
```bash
vagrant ssh remnux
tail -f /var/log/syslog
```

## Security Features

✅ **Network Isolation**: Lab VMs on isolated network with no direct internet  
✅ **VPN Egress**: All lab traffic routed through Mullvad WireGuard tunnel  
✅ **Packet Capture**: Continuous pcap recording of all lab network traffic  
✅ **IDS Monitoring**: Suricata IDS analyzing all lab traffic  
✅ **DNS Logging**: All DNS queries logged with nftables for C2 analysis  
✅ **Firewall Protection**: nftables default-deny with explicit allow rules  
✅ **Reverse Proxy**: No direct lab VM access, only via firewall proxies  
✅ **SSH Restrictions**: SSH access limited to vagrant-libvirt network only  

## Malware Analysis Workflow

1. **Prepare**: Start lab with `./scripts/start-lab.sh`
2. **Transfer Sample**: Upload malware to OpenRelik via UI (localhost:8711)
3. **Analyze**: Use REMnux via Guacamole (localhost:18080/guacamole)
4. **Monitor**: Watch network activity in firewall logs
5. **Extract IOCs**: Use OpenRelik to index and search artifacts
6. **Review**: Check packet captures in `/var/log/pcaps/` on firewall
7. **Clean**: `vagrant destroy -f && ./scripts/start-lab.sh` for fresh environment

## Project Structure

```
utgard/
├── Vagrantfile              # VM definitions and network topology
├── scripts/start-lab.sh     # Helper script to start lab
├── README.md                # This file
├── docs/GUACAMOLE-SETUP.md  # Guacamole setup and access guide
├── INCIDENT-RESPONSE.md     # Security incident procedures
└── provision/
    ├── firewall.yml         # Firewall + VPN + monitoring config
    ├── openrelik.yml        # OpenRelik Docker setup
    ├── remnux.yml           # REMnux full distribution install
    └── settings.toml.example # OAuth config example
```

## More Information

- [OpenRelik Documentation](https://openrelik.org/docs/)
- [OpenRelik GitHub](https://github.com/openrelik/)
- [REMnux](https://remnux.org/)
- [Mullvad WireGuard](https://mullvad.net/help/wireguard-config/)
