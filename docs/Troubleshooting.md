# Troubleshooting

## Quick Checks
- Vagrant status: `vagrant status`
- Ansible collections installed: `ansible-galaxy collection list | grep community`
- Docker running (host services): `systemctl status docker`
- Libvirt running: `systemctl status libvirtd`

## Vagrant / libvirt
### Provider missing
```bash
vagrant plugin install vagrant-libvirt
vagrant plugin list
```

### libvirtd not running
```bash
systemctl status libvirtd
systemctl start libvirtd
systemctl enable libvirtd
virsh net-list
```

### Box not found
```bash
vagrant box add generic/ubuntu2204
vagrant box add generic/windows10
vagrant box list
```

### VMs won't start
```bash
vagrant up --debug 2>&1 | tee vagrant-debug.log
df -h /var/lib/libvirt/images
virsh net-list
```

### Clean broken state
```bash
vagrant destroy -f
rm -rf .vagrant/
virsh vol-list default
```

## Ansible Collections Missing
**Error:** module not found (e.g., `win_user`, `win_service`)
```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list | grep windows
```

## Network & DNS (Lab)
### Lab VMs cannot reach firewall
```bash
vagrant ssh remnux -- ping -c 3 10.20.0.2
vagrant ssh firewall -- ping -c 3 10.20.0.20
```

### DNS resolution fails
```bash
# From REMnux
nslookup utgard-win.utgard.local 10.20.0.2
cat /etc/resolv.conf

# On firewall
vagrant ssh firewall
systemctl status dnsmasq
dig @localhost utgard-win.utgard.local
```

## WireGuard / Mullvad (firewall)
### WireGuard not active
```bash
vagrant ssh firewall
ip link show wg0
systemctl status wg-quick@wg0
```
Ensure config exists: `ansible/roles/firewall/files/private/se-mma-wg-002.conf` and `features.enable_wireguard: true` in config.yml, then:
```bash
vagrant reload firewall --provision
```

### Mullvad connectivity fails
```bash
vagrant ssh firewall -- curl -s https://am.i.mullvad.net/connected
journalctl -u wg-quick@wg0 -n 50
```
If config is invalid, re-download from Mullvad and re-provision.

## Services (host)
### Portal or services not reachable
```bash
systemctl status docker
docker ps
docker logs nginx 2>&1 | tail -50
docker logs guacamole 2>&1 | tail -50
docker logs openrelik-ui 2>&1 | tail -50
```
Run host provisioning if needed:
```bash
cd ansible
ansible-playbook playbooks/host.yml
```

### Authentication issues
```bash
cat /opt/guacamole/auth/.htpasswd_secret
grep -A5 auth_basic /etc/nginx/sites-enabled/utgard.conf
```

### Guacamole cannot reach RDP/SSH targets
```bash
# Test RDP from another host
nc -zv 10.20.0.30 3389

# Test SSH to REMnux
nc -zv 10.20.0.20 22
```
Verify Guacamole connection settings match lab IPs and credentials printed during provisioning.

## Logs to Check
- Vagrant: `vagrant up --debug` output or `vagrant-debug.log`
- Ansible: provisioning output or `ansible.log` if configured
- Systemd: `journalctl -u libvirtd`, `journalctl -u docker`, `journalctl -u wg-quick@wg0`
- Docker services: `docker logs <container> | tail`
- Nginx: `/var/log/nginx/error.log`

## Recovery
### Reset everything
```bash
vagrant destroy -f
rm -rf /opt/guacamole /opt/openrelik /opt/kasm /opt/maigret
rm -rf .vagrant/
vagrant up
cd ansible
ansible-playbook playbooks/host.yml
```

### Rebuild a single service
```bash
cd ansible
ansible-playbook playbooks/host.yml -t maigret --extra-vars="maigret_state_dir=/opt/maigret"
```
# Troubleshooting

## Common Issues

### VMs won't start
```bash
# Check libvirt status
systemctl status libvirtd

# Check Vagrant logs
vagrant up --debug

# Verify libvirt networks
virsh net-list

# Check disk space
df -h /var/lib/libvirt/images
```

### Provisioning fails
```bash
# Re-run specific playbook
cd ansible
ansible-playbook playbooks/host.yml -vvv

# Check Ansible syntax
ansible-playbook playbooks/host.yml --syntax-check

# Run only a specific role
ansible-playbook playbooks/host.yml -t openrelik
```

### Services not accessible
1. Check TLS cert:
   ```bash
   openssl x509 -in /opt/guacamole/tls/fullchain.pem -text -noout
   ```

2. Verify Nginx is running:
   ```bash
   systemctl status nginx
   sudo nginx -t
   ```

3. Check service container status:
   ```bash
   docker ps | grep openrelik
   docker logs openrelik-ui
   ```

4. Test localhost port:
   ```bash
   curl -k https://localhost:8711  # OpenRelik UI
   curl -k https://localhost:8080  # Guacamole
   ```

### Docker network issues
```bash
# List networks
docker network ls

# Inspect network
docker network inspect kasm-isolated

# Check routing
ip route show
```

### Authentication failing
1. Check Basic Auth file:
   ```bash
   cat /opt/guacamole/auth/.htpasswd
   ```

2. Verify password:
   ```bash
   cat /opt/guacamole/auth/.htpasswd_secret
   ```

3. Check Nginx auth config:
   ```bash
   grep -A 10 "auth_basic" /etc/nginx/sites-enabled/utgard.conf
   ```

### OpenRelik workers not starting
```bash
# Check logs
docker logs openrelik-worker-plaso

# Verify image availability
docker inspect ghcr.io/openrelik/openrelik-worker-plaso:latest

# Check compose extra workers file
cat /opt/openrelik/openrelik/docker-compose.extra-workers.yml
```

### Guacamole can't connect to RDP
1. Verify xrdp is running on REMnux:
   ```bash
   vagrant ssh remnux
   sudo systemctl status xrdp
   ```

2. Check firewall rules:
   ```bash
   vagrant ssh remnux
   sudo nft list ruleset
   ```

3. Test RDP port directly:
   ```bash
   nc -zv 10.20.0.20 3389
   ```

### Kasm Tor isolation not working
```bash
# Check iptables rules
sudo iptables -L FORWARD -n

# Verify network subnet
docker network inspect kasm-isolated

# Check container interface
docker exec kasm-tor-browser ip addr show
```

## Logs to Check
- **Vagrant provisioning**: `./ansible.log`
- **Nginx**: `sudo tail -f /var/log/nginx/error.log`
- **Docker**: `docker compose logs <service>`
- **Systemd**: `sudo journalctl -u nginx` or `docker`

## Recovery
### Reset everything
```bash
# Destroy VMs
vagrant destroy -f

# Remove old state
rm -rf /opt/guacamole /opt/openrelik /opt/kasm /opt/maigret

# Re-provision
vagrant up
cd ansible
ansible-playbook playbooks/host.yml
```

### Rebuild a single service
```bash
cd ansible
ansible-playbook playbooks/host.yml -t maigret --extra-vars="maigret_state_dir=/opt/maigret"
```

