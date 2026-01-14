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
┌─────────────────────────────────────────────────────────────────┐
│ OPERATOR                                                         │
│                                                                  │
│   Browser ──────► Pangolin (https://your-domain.com)             │
└────────────────────────│─────────────────────────────────────────┘
                         │ HTTPS
┌────────────────────────│─────────────────────────────────────────┐
│ PANGOLIN HOST          │                                         │
│   Traefik + Pangolin + Gerbil                                   │
│   Routes to lab services via DNS + Pangolin rules                │
└────────────────────────│─────────────────────────────────────────┘
                         │
┌────────────────────────│─────────────────────────────────────────┐
│ FIREWALL VM            │                                         │
│   eth0 ◄───────────────┘  (192.168.121.x)                       │
│   eth1 ─────────────────► 10.20.0.1 (Lab Gateway)               │
│   wg0 ──────────────────► Mullvad VPN (outbound)                │
│   nftables, packet capture                                      │
└──────────────────────────────────────────────────────────────────┘
                         │ Lab Network (10.20.0.0/24)
         ┌───────────────┼───────────────┬─────────────────┐
         ▼               ▼               ▼                 ▼
   ┌───────────┐  ┌───────────┐  ┌───────────┐     ┌───────────┐
   │ OpenRelik │  │  REMnux   │  │   Neko    │     │  (Future) │
   │ 10.20.0.30│  │ 10.20.0.20│  │ 10.20.0.40│     │ 10.20.0.x │
   │ :8710 API │  │  Analysis │  │ :8080 Tor │     │           │
   │ :8711 UI  │  │   Tools   │  │ :8090 Chr │     │           │
   └───────────┘  └───────────┘  └───────────┘     └───────────┘
         │               │               │
         └───────────────┴───────────────┘
                         │
                  Firewall wg0 ──► Mullvad VPN ──► Internet
```

### Security Principles
- **Complete isolation**: Lab VMs have NO direct internet access from the host
- **Pangolin access**: External access is routed through Pangolin with TLS
- **Controlled egress**: All lab traffic routes through firewall → Mullvad VPN
- **Network monitoring**: Full packet capture + IDS on all lab traffic
- **Default deny**: nftables blocks everything except explicit allows
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

### 5. Configure Pangolin

Use Pangolin for external access. See [docs/PANGOLIN-ACCESS.md](docs/PANGOLIN-ACCESS.md) for deployment and routing setup.

### 6. Access Services

Once Pangolin is configured, access services via your domain:

| Service           | URL                          | Credentials              |
|-------------------|------------------------------|--------------------------|
| OpenRelik UI      | https://your-domain.com/<openrelik-route> | admin / admin      |
| OpenRelik API     | https://your-domain.com/<openrelik-api-route> | -        |
| Neko Tor Browser  | https://your-domain.com/<neko-tor-route> | neko / admin        |
| Neko Chromium     | https://your-domain.com/<neko-chromium-route> | neko / admin |
| Guacamole         | https://your-domain.com/<guacamole-route> | guacadmin / guacadmin |

For Pangolin setup, see [docs/PANGOLIN-ACCESS.md](docs/PANGOLIN-ACCESS.md).

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

Check Pangolin routing and service reachability:
```bash
cd pangolin
sudo docker compose ps
sudo docker compose logs -f --tail=200
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose ps"
```

### Guacamole not reachable

Verify Pangolin routes and firewall containers:
```bash
cd pangolin
sudo docker compose ps
vagrant ssh firewall -c "docker ps | grep guacamole"
```

### Provisioning is slow

REMnux full installation takes 20-30 minutes. Monitor progress:
```bash
vagrant ssh remnux
tail -f /var/log/syslog
```

## Security Features

* **Network Isolation**: Lab VMs on isolated network with no direct internet  
* **VPN Egress**: All lab traffic routed through Mullvad WireGuard tunnel  
* **Packet Capture**: Continuous pcap recording of all lab network traffic  
* **IDS Monitoring**: Suricata IDS analyzing all lab traffic  
* **DNS Logging**: All DNS queries logged with nftables for C2 analysis  
* **Firewall Protection**: nftables default-deny with explicit allow rules  
* **Pangolin Access**: No direct lab VM access, services published via Pangolin  
* **SSH Restrictions**: SSH access limited to vagrant-libvirt network only  

## Malware Analysis Workflow

1. **Prepare**: Start lab with `./scripts/start-lab.sh`
2. **Transfer Sample**: Upload malware to OpenRelik via Pangolin route
3. **Analyze**: Use REMnux via Guacamole through Pangolin route
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
├── pangolin/                # Pangolin Docker Compose templates
├── docs/PANGOLIN-ACCESS.md  # Pangolin external access setup
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
