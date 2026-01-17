# Windows Analysis VM Guide

## Overview
The Windows Analysis VM is an optional malware-analysis workstation connected to the lab network behind the firewall. It runs Sysmon for system instrumentation, Sysinternals tools, and other analysis utilities.

## Prerequisites
- At least 8 GB RAM available on host (16+ GB total recommended)
- Windows 10 Vagrant box: `gusztavvargadr/windows-10` (~3-5 GB, faster boot)
- WinRM enabled on the Windows box (default with Vagrant provisioner)
- Ansible collections: `community.windows`, `ansible.windows`
- First boot: 5-10 minutes for Windows setup + provisioning

## Enable in Configuration
Edit `config.yml`:
```yaml
features:
  windows_analysis_vm: true

resources:
  windows_analysis:
    memory: 8192  # 8 GB
    cpus: 4       # 4 vCPUs
```

## Bring Up VM
```bash
vagrant up win-analysis
```

This will:
1. Create Windows 10 VM on `10.20.0.30` in the `utgard-lab` network
2. Configure static IP, DNS, and hostname (`utgard-win`)
3. Run Ansible provisioning to install tools and hardening
4. Create a clean snapshot automatically

## Provisioning
The `windows-analysis` role installs:
- **Sysmon**: System monitor with SwiftOnSecurity config
- **Sysinternals Suite**: Procmon, Procexp, Autoruns, TCPView, etc.
- **Analysis Tools**: 
  - FLOSS (Firefly Language Obfuscation Solver Script)
  - PE-sieve (PE malware detection)
  - x64dbg (debugger)
  - Python 3.11
  - Wireshark (portable)
  - .NET SDK (optional)
- **PowerShell Logging**: Module logging, script-block logging, transcription
- **Windows Defender**: Configured for lab (realtime off, exclusions added)

## User Account
An `analyst` user account is created with RDP access. Default password is auto-generated. To set a custom password, update config or role defaults before provisioning.

## RDP Access via Guacamole
1. Login to Guacamole at `https://<hostname>/guacamole/`
2. Settings → Connections → New Connection
   - **Name**: `windows-analysis`
   - **Protocol**: RDP
   - **Hostname**: `10.20.0.30` (or `utgard-win.utgard.local`)
   - **Port**: `3389`
   - **Username**: `analyst`
   - **Password**: (from provisioning output or `/opt/guacamole/secrets/` if stored)
3. Connect and accept certificate warning

## Snapshots
Clean snapshot is created automatically on first `vagrant up`:
```bash
# Revert to clean state after detonation
vagrant snapshot restore win-analysis clean

# Save a new snapshot
vagrant snapshot save win-analysis <name>

# List snapshots
vagrant snapshot list win-analysis
```

## Typical Workflow

### Prepare Analysis Environment
1. Connect via RDP
2. Open Procmon and set desired filters
3. Set up Wireshark or tcpdump (on firewall) for network capture
4. Stage sample in `C:\tmp\samples` or via SMB

### Execute Malware
1. Start captures (Procmon, network)
2. Execute sample
3. Observe behavior for 5–10 minutes
4. Stop captures

### Collect Artifacts
1. Export Procmon CSV: File → Save
2. Export Windows Event Logs: Event Viewer → Export
3. Copy to SMB share (if configured) or via OpenRelik upload
4. Revert snapshot when done

## Artifacts Storage

### Local Capture
- Procmon logs: `C:\Users\analyst\Desktop\procmon-*.csv`
- PowerShell logs: `C:\ProgramData\PowerShell\logs\*`
- Event logs: Export via Event Viewer

### Centralized (Optional)
- Share via SMB from REMnux to Windows for file exchange
- Push logs to OpenRelik for centralized analysis
- Ship Windows Event Logs to Elastic (via Winlogbeat, if deployed)

## Tools Quick Reference

| Tool | Location | Usage |
|------|----------|-------|
| **Procmon** | Desktop shortcut | Monitor process/file/registry activity |
| **Procexp** | Desktop shortcut | Process explorer tree and details |
| **Autoruns** | Desktop shortcut | Persistence mechanisms, startup items |
| **TCPView** | Desktop shortcut | Active network connections |
| **Sysinternals Suite** | `C:\tools\sysinternals` | Full suite available on PATH |
| **FLOSS** | `C:\tools\analysis\floss.exe` | Automated YARA-IDA script obfuscation |
| **PE-sieve** | `C:\tools\analysis\pe-sieve64.exe` | Detect injected code in running processes |
| **x64dbg** | `C:\tools\analysis\x64dbg\x64dbg.exe` | User-mode debugger |
| **Wireshark** | `C:\tools\analysis\` | Network packet analysis |
| **Strings** | `C:\tools\analysis\strings64.exe` | Extract strings from binaries |
| **Python 3** | `C:\Program Files\Python311\python.exe` | Script execution and data processing |

## Sysmon Configuration
Uses SwiftOnSecurity's community configuration for comprehensive logging:
- Process creation, image loads, registry operations
- Network connections, file operations, DNS queries
- Event forwarding rules for common malware behaviors

Logs written to Event Viewer: `Applications and Services Logs → Microsoft → Windows → Sysmon → Operational`

## Defender Configuration
- **Realtime Protection**: Disabled (to avoid interference during detonation)
- **Cloud Protection**: Disabled
- **Sample Submission**: Disabled (NeverSend)
- **Exclusions**: Analysis directories added
- Can be re-enabled or per-sample as needed

## Network Isolation (Optional)
If `enable_wireguard: true` on the firewall, all lab traffic (including Windows VM) egresses through Mullvad. Otherwise, direct internet access through firewall NAT.

## Troubleshooting

### RDP Connection Fails
- Ensure WinRM is running: `winrm quickconfig`
- Check firewall: `Get-NetFirewallProfile`
- Verify analyst user exists: `Get-LocalUser analyst`

### Sysmon Not Logging
- Check service: `Get-Service Sysmon64`
- Verify config: `sysmon64 -c` (shows current config)
- Review Event Viewer: Applications and Services Logs → Sysmon

### PowerShell Logs Not Appearing
- Enable Module Logging: `Set-PSLoggingPolicy.ps1` (included in provisioning)
- Check registry: `HKLM\Software\Policies\Microsoft\Windows\PowerShell`
- Verify transcription output: `C:\ProgramData\PowerShell\logs\`

### Snapshot Restore Fails
- Ensure VM is shut down: `vagrant halt win-analysis`
- Try snapshot list: `vagrant snapshot list win-analysis`
- Recreate clean snapshot: `vagrant snapshot save win-analysis clean`

