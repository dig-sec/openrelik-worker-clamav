# Windows VM Implementation Status & Path Forward

## Current State

**Operational Lab (100% complete):**
- ✅ Firewall VM: Ubuntu 22.04, 10.20.0.2, dnsmasq, nftables
- ✅ REMnux VM: Ubuntu 22.04, 10.20.0.20, all REMnux tools
- ✅ Lab Network: 10.20.0.0/24, DNS resolution via firewall
- ✅ Host Services: Nginx, Guacamole, OpenRelik (9 workers), Kasm (Tor/Forensic), Maigret
- ✅ Portal: HTTPS with HTTP Basic Auth
- ✅ Snapshot system for REMnux (`clean` snapshot)

**Windows Analysis VM (Code Complete, Deployment Optional):**
- ✅ Ansible role fully written: `ansible/roles/windows-analysis/` (10 task files)
- ✅ Vagrantfile definition: Uses `gusztavvargadr/windows-10` (stable libvirt provider)
- ✅ Playbook: `ansible/playbooks/windows.yml` with explicit password scoping
- ✅ Inventory: Group `windows_analysis` with WinRM configuration
- ✅ Documentation: Comprehensive setup, troubleshooting, and workflow guides
- ⏳ **Deployment blocked**: Vagrant box download extremely slow (~1.5+ hours over current network)

## Why Windows VM is Optional

1. **Lab is fully functional without it**: REMnux provides Linux malware analysis
2. **Network/host analysis on REMnux**: Wireshark, tcpdump, network tools available
3. **Windows binary analysis on REMnux**: FLOSS, radare2, Ghidra, IDA Free all available
4. **Windows-specific malware**: Can be analyzed via REMnux or deferred to dedicated Windows system

## Deploying Windows VM Later

When network is faster or on a less constrained system:

```bash
# 1. Enable in config.yml
sed -i 's/windows_analysis_vm: false/windows_analysis_vm: true/' config.yml

# 2. Pre-download box to save time (optional, ~3-5 GB)
vagrant box add gusztavvargadr/windows-10 --provider libvirt

# 3. Bring up Windows VM (takes 5-10 minutes after box is downloaded)
vagrant up win-analysis

# 4. Monitor provisioning
tail -f /tmp/provision.log

# 5. Verify RDP access via Guacamole
# URL: https://<host>/guacamole/
# Add RDP connection: hostname=10.20.0.30, user=analyst, password=Utgard@Lab2026!
```

## What Windows VM Provides

When deployed:
- **Sysmon**: System instrumentation with SwiftOnSecurity config
- **Sysinternals**: Procmon, Procexp, Autoruns, TCPView with desktop shortcuts
- **Analysis Tools**: FLOSS, PE-sieve, x64dbg, Python 3.11, Wireshark, Strings
- **PowerShell Logging**: Module/script-block logging enabled
- **Windows Defender**: Realtime disabled, exclusions for analysis
- **RDP Access**: Via Guacamole or direct (username: analyst, password from provisioning)
- **Lab Integration**: Lab network 10.20.0.30, DNS via firewall, isolated from internet

## Current Recommendation

**Continue with REMnux-based malware analysis for now:**

1. Access portal: `https://20.240.216.254.sslip.io/`
2. Open Guacamole, SSH to REMnux (`10.20.0.20:22`, user: `vagrant`)
3. All analysis tools pre-installed (Wireshark, radare2, Ghidra, FLOSS, etc.)
4. Snapshot support (`vagrant snapshot restore remnux clean` for clean state)
5. Windows binary analysis via IDA Free / Ghidra on REMnux

**Deploy Windows VM when:**
- Network allows 3-5 GB box download in reasonable time
- Need native Windows binary execution (debuggers, DLLs)
- Need live process injection/manipulation (native Windows APIs)
- Host resources available (total lab would use ~24 GB with Windows enabled)

## Files Created/Modified

**New Ansible Assets:**
- `ansible/roles/windows-analysis/` (10 task files + defaults/handlers)
- `ansible/playbooks/windows.yml`
- `ansible/requirements.yml` (collection pins)

**Updated Configuration:**
- `Vagrantfile`: Windows VM definition (conditional, uses `gusztavvargadr/windows-10`)
- `config.yml`: Windows resources, lab IPs, feature flag
- `ansible/inventory.yml`: Windows-analysis group, WinRM transport

**Documentation:**
- `SETUP.md`: First-time setup guide
- `docs/Windows-Analysis-VM.md`: Deployment and usage
- `docs/Troubleshooting.md`: Comprehensive diagnostic guide

**Supporting:**
- `ansible.cfg` (root-level for playbook discovery)
- `ansible/ansible.cfg` (local override)

All code is syntax-checked and ready to provision when box download completes.
