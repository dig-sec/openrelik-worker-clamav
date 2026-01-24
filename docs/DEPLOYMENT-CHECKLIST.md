# Lab Deployment Checklist

Use this checklist to verify the lab is properly configured before running `vagrant up`.

## Pre-Deployment Checks

### Prerequisites
- [ ] System has ≥16 GB RAM (8 GB minimum, 12+ recommended with all VMs)
- [ ] KVM/QEMU and libvirt installed and running
- [ ] Vagrant installed (≥2.3.0)
- [ ] Ansible installed (≥2.9, ≥2.0 compatibility mode used)
- [ ] Python 3.6+ on host (for Ansible)

### Vagrant Setup
- [ ] `generic/ubuntu2204` box added: `vagrant box list | grep ubuntu2204`
- [ ] `vagrant-libvirt` plugin installed: `vagrant plugin list | grep libvirt`
- [ ] libvirt daemon running: `systemctl status libvirtd`

### Ansible Setup
- [ ] Collections installed: `cd ansible && ansible-galaxy collection install -r requirements.yml`
- [ ] Verify collections: `ansible-galaxy collection list | grep -E 'community.docker'`

### Project Configuration
- [ ] `config.yml` exists and is properly formatted (copy from `config.yml` if needed)
- [ ] Network settings reasonable (default `10.20.0.0/24` is fine)
- [ ] External hostname set (use `<IP>.sslip.io` for testing)

## Deployment Phase

### Firewall VM
```bash
# First VM - establish lab network
vagrant up firewall

# Expected output:
# - VM boots and provisions via Ansible
# - Network interface gets 10.20.0.2
# - dnsmasq starts
# - Docker daemon starts
```

- [ ] Firewall VM boots without errors
- [ ] Network: `ping 10.20.0.2` works from host

```bash
# Verify firewall services
vagrant ssh firewall

# Inside firewall VM:
# [ ] systemctl status dnsmasq (running)
# [ ] systemctl status docker (running)  
# [ ] ip addr | grep 10.20.0
```

### REMnux VM
```bash
# Second VM - malware lab
vagrant up remnux

# Expected output:
# - VM boots with 10.20.0.20
# - Connects to firewall (10.20.0.2) as gateway/DNS
# - REMnux tools provisioned
# - Optional: snapshot 'clean' created
```

- [ ] REMnux VM boots without errors
- [ ] Network: `ping 10.20.0.20` works from host
- [ ] Can ping firewall: `vagrant ssh remnux -- ping 10.20.0.2`

```bash
# Verify REMnux network
vagrant ssh remnux

# Inside REMnux VM:
# [ ] cat /etc/resolv.conf shows 10.20.0.2
# [ ] nslookup utgard-remnux.utgard.local works
# [ ] REMnux tools present in /opt/remnux-tools
```

### Host Services
```bash
# Run from host (outside vagrant)
cd ansible
ansible-playbook playbooks/host.yml

# Expected output:
# - Docker containers created (nginx, guacamole, openrelik, etc.)
# - HTTPS certificates generated
# - Auth credentials stored
```

- [ ] All playbook tasks complete successfully
- [ ] Docker containers running: `docker ps`
- [ ] Nginx reverse proxy active
- [ ] Guacamole available

## Post-Deployment Verification

### Network Connectivity
```bash
# Test lab network from host
ping 10.20.0.2   # Firewall
ping 10.20.0.20  # REMnux

# All should respond
```

- [ ] Ping all lab VMs succeeds

### DNS Resolution (from lab VMs)
```bash
vagrant ssh remnux

# Inside REMnux:
nslookup utgard-remnux.utgard.local      # Self
nslookup utgard-firewall.utgard.local    # Firewall
```

- [ ] DNS resolves lab hostnames to correct IPs

### Portal Access
```bash
# Get hostname from config.yml
HOSTNAME=$(grep 'hostname:' config.yml | tail -1 | awk '{print $2}')

# Try to access
curl -k https://$HOSTNAME/
```

- [ ] HTTPS portal responds (may need basic auth)
- [ ] Self-signed certificate warning is OK
- [ ] Can authenticate with credentials from provisioning output

### Guacamole RDP/SSH
1. Navigate to `https://<hostname>/guacamole/`
2. Login with displayed credentials
3. Connect to REMnux (SSH)

- [ ] Guacamole portal loads
- [ ] REMnux SSH connection works

### WireGuard/Mullvad (Optional)
```bash
# If enable_wireguard: true in config.yml

# Test from REMnux
vagrant ssh remnux
curl https://am.i.mullvad.net/connected

# Should return: {"mullvad_exit_ip":"<IP>","mullvad_exit_ip_hostname":"<name>","opponent_en":"","country":"SE","city":"","latitude":62.0079,"longitude":15.1017,"country_en":"Sweden","city_en":"","mullvad_exit_ipv6":"","mullvad_hostname":"<hostname>"}
```

- [ ] Mullvad endpoint shows connected (if WireGuard enabled)
- [ ] Exit IP is from Mullvad infrastructure

## Common Gotchas

### Firewall VM Must Be First
**Why:** Firewall hosts the lab network that other VMs depend on
```bash
# ✓ Correct
vagrant up firewall
vagrant up remnux

# ✗ Wrong - will cause network timeouts
vagrant up remnux  # Firewall not running yet!
vagrant up firewall
```

## Snapshot Management

### Create Snapshots
```bash
# After everything works, save clean snapshots
vagrant snapshot save remnux clean
```

### Restore from Snapshot
```bash
# Quick reset to known-good state
vagrant snapshot restore remnux clean
```

### Delete Snapshots
```bash
vagrant snapshot delete remnux clean
```

## Cleanup / Full Reset

```bash
# Destroy all VMs (stops services but keeps config)
vagrant destroy -f

# Clean Docker state
docker system prune -f

# Full cleanup (delete all VM volumes)
virsh vol-list default
virsh vol-delete <volume-name> default  # For each orphaned volume

# Or completely reset vagrant
rm -rf .vagrant/
vagrant global-status --prune
```

## Health Check Commands

Run these periodically to verify lab health:

```bash
# Check VM status
vagrant status

# Check network connectivity
for ip in 10.20.0.{2,20}; do echo "Testing $ip:"; ping -c 1 "$ip" && echo "✓" || echo "✗"; done

# Check Docker services
docker ps --format "{{.Names}}\t{{.Status}}"

# Check lab firewall routing
vagrant ssh firewall -- ip route
vagrant ssh firewall -- nft list ruleset | head -20

# Check Ansible facts
ansible all -i ansible/inventory.yml -m setup | head -50
```

## Success Criteria

Lab is ready when:

1. ✓ All VMs boot without errors: `vagrant status` shows "running"
2. ✓ Lab network active: All IPs ping successfully
3. ✓ DNS working: `nslookup utgard-*.utgard.local` from lab VMs
4. ✓ Guacamole portal accessible: `https://<hostname>/guacamole/`
5. ✓ RDP/SSH connections work through Guacamole
6. ✓ REMnux can run: `vagrant ssh remnux -- remnux version` (if version available)

If all criteria met: **Lab is fully operational!**

## Next Steps

- Review [WireGuard-Setup.md](WireGuard-Setup.md) for VPN egress configuration  
- Review [docs/README.md](../docs/README.md) for service documentation
- Review [Troubleshooting.md](Troubleshooting.md) if issues arise
