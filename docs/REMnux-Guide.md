# REMnux VM Guide

## Overview
REMnux is a Linux-based malware analysis workstation. Utgard deploys it as a Vagrant VM with analysis tools and RDP access via Guacamole.

## Access
- **RDP**: Via Guacamole at `https://<hostname>/guacamole/`
- **SSH**: Direct SSH to `10.20.0.20` (if firewall allows)

## Tools Installed
Core analysis tools:
- `binwalk`: Firmware analysis
- `exiftool`: Metadata extraction
- `strace`, `ltrace`: System call tracing
- `gdb`: Debugger
- `nmap`: Network scanning
- `wireshark`, `tcpdump`: Network capture
- `radare2` (if available): Reverse engineering
- `volatility3` (if available): Memory forensics
- Python tools: `pycryptodome`, `capstone`, `angr`, `keystone`, `yara-python`

Optional tools may fail silently if not in distro repos.

## Configuration
Key variables in `roles/remnux/defaults/main.yml`:
- REMnux tools installed via apt + pip
- xrdp service for RDP access
- XFCE desktop environment

## RDP Configuration
- **Service**: xrdp (RDP server)
- **Desktop**: XFCE
- **Port**: `3389`
- **Default credentials**: `vagrant/vagrant` (Vagrant box defaults)

To add to Guacamole:
1. Login to Guacamole
2. Settings → Connections → New Connection
3. **Protocol**: RDP
4. **Hostname**: `10.20.0.20` (or `utgard-remnux.utgard.local`)
5. **Port**: `3389`
6. **Username**: `vagrant`
7. **Password**: `vagrant`

## Usage

### Connect via Guacamole RDP
1. Open `https://<hostname>/guacamole/`
2. Click the `remnux-rdp` connection
3. XFCE desktop appears in browser

### Direct SSH (if firewall allows)
```bash
ssh -i ~/.vagrant.d/insecure_private_key vagrant@10.20.0.20
```

### Run Analysis
```bash
# Wireshark: open in XFCE desktop or run headless capture
sudo tcpdump -i eth0 -w /tmp/capture.pcap

# Strings extraction
strings malware_sample.exe

# YARA scanning (if installed)
yara rules.yar sample.exe
```

## File Transfer
1. Via XFCE file manager (mounted shares if configured)
2. Via SCP through SSH
3. Via OpenRelik (upload evidence, download artifacts)

## Snapshots
If `features.remnux_snapshot: true` in `config.yml`:
```bash
# Save snapshot
vagrant snapshot save remnux clean

# Restore snapshot
vagrant snapshot restore remnux clean

# List snapshots
vagrant snapshot list remnux
```

## Container Management (if applicable)
REMnux is a bare VM, not containerized. Manage via Vagrant:
```bash
# SSH
vagrant ssh remnux

# Halt
vagrant halt remnux

# Resume
vagrant up remnux

# Destroy
vagrant destroy remnux
```

## Troubleshooting
- **RDP connection fails**: Check xrdp service (`systemctl status xrdp` on VM)
- **Desktop not showing**: May be loading; wait 10–30 seconds
- **Slow RDP**: Network latency; check bandwidth and reduce resolution
- **Tools missing**: Some tools require additional repos; install manually if needed

