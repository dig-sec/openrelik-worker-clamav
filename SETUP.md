# Setup Guide - First Time

Before bringing up any VMs, complete these prerequisites:

## 1. Install Ansible Collections

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

Or individually:
```bash
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.windows
ansible-galaxy collection install ansible.windows
```

## 2. Install Vagrant Plugins

```bash
vagrant plugin install vagrant-libvirt
```

## 3. Configure config.yml

Copy and customize:
```bash
cp config.yml.example config.yml
```

Or edit the existing `config.yml` to match your environment:
- Lab network and IPs
- External hostname (use sslip.io for testing)
- Authentication settings
- VM resource sizing

## 4. Enable Optional Features

**Windows Analysis VM:**
```yaml
features:
  windows_analysis_vm: true
```

**WireGuard/Mullvad VPN:**
```yaml
features:
  enable_wireguard: true
wireguard:
  endpoint: "se-mma-wg-002"
```

Then place Mullvad config at:
```bash
ansible/roles/firewall/files/private/se-mma-wg-002.conf
```

## 5. Bring Up Lab

```bash
# All VMs (firewall + remnux + optional win-analysis + host services)
vagrant up

# Or specific VMs
vagrant up firewall remnux
vagrant up win-analysis  # If enabled
```

## 6. Provision Host Services

```bash
cd ansible
ansible-playbook playbooks/host.yml
```

## 7. Access Portal

Find the URLs and credentials printed at the end of provisioning:
- Portal: `https://<hostname>/`
- Guacamole: `https://<hostname>/guacamole/`
- OpenRelik: `https://<hostname>/openrelik/`
- Kasm: `https://<hostname>/kasm/`
- Maigret: `https://<hostname>/maigret/`

## 8. Add Windows to Guacamole (if enabled)

```
Settings → Connections → New Connection
- Name: windows-analysis
- Protocol: RDP
- Hostname: 10.20.0.30
- Port: 3389
- Username: analyst
- Password: Utgard@Lab2026! (or from provisioning output)
```

## Troubleshooting First Boot

### Windows box download
```bash
# Box will download automatically on first 'vagrant up win-analysis'
# peru/windows-10-enterprise-x64-eval is ~6-8 GB
# Or pre-download:
vagrant box add peru/windows-10-enterprise-x64-eval --provider libvirt
```

### Windows VM won't provision
```bash
# Check WinRM status
vagrant ssh win-analysis -- powershell -c "Get-Service WinRM"

# Manually wait for WinRM to be ready, then retry
vagrant provision win-analysis
```

### Ansible collections not found
```bash
# Verify installation
ansible-galaxy collection list | grep community

# Re-install if missing
ansible-galaxy collection install -r ansible/requirements.yml --force
```

### Vagrant/libvirt issues
```bash
# Check libvirt daemon
systemctl status libvirtd

# List networks
virsh net-list

# Clean up broken VMs
vagrant destroy -f
virsh vol-list default  # List orphaned volumes
```

### Docker daemon not responding
```bash
# Check Docker on host
systemctl status docker

# Restart if needed
systemctl restart docker
```

For more help, see [docs/Troubleshooting.md](docs/Troubleshooting.md).
