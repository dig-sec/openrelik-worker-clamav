# Neko Tor Browser Integration Guide

## Overview

This document describes the integration of **n.eko** - a self-hosted virtual browser that uses WebRTC - into the Utgard lab environment. Neko provides a containerized Tor Browser for secure, anonymous internet browsing and accessing Tor sites within an isolated lab environment.

## Architecture

### Components

- **Neko Tor Browser VM** (`10.20.0.40`)
  - Runs Tor Browser in a containerized environment
  - Accessible via WebRTC web UI on port 8080
  - Can be accessed directly or through Guacamole gateway
  - Isolated on the lab network (10.20.0.0/24)

### Network Isolation

```
Internet (Mullvad VPN)
    ↓
Firewall VM (10.20.0.1)
    ↓
Neko VM (10.20.0.40) ← Isolated lab network
    ↓
Tor Browser in Docker
    ↓
Tor Network Sites
```

## Quick Start

### 1. Provision the Neko VM

The neko VM is included in the standard Utgard provisioning:

```bash
./scripts/provision.sh
```

This will:
- Create the `neko` VM with 3GB RAM and 2 CPUs
- Install Docker and Docker Compose
- Deploy the neko Tor Browser container
- Expose ports 8080 (Web UI) and 8081 (WebRTC broadcast)

### 2. Access Neko

**Direct Access:**
```
http://localhost:8080
```

**Via Guacamole (after configuration):**
```
http://localhost:18080/guacamole/ → Neko Tor Browser connection
```

**Default Credentials:**
- User password: `neko`
- Admin password: `admin`

(Change these via `NEKO_PASSWORD` and `NEKO_ADMIN_PASSWORD` environment variables)

## Configuration

### Environment Variables

Set before running `./scripts/provision.sh`:

```bash
# Custom neko credentials
export NEKO_PASSWORD="your-password"
export NEKO_ADMIN_PASSWORD="your-admin-password"

# Then provision
./scripts/provision.sh
```

### VM Resources

Modify in `Vagrantfile` (lines for neko VM):

```ruby
lv.memory = 3072  # MB
lv.cpus = 2       # CPU cores
```

### Display Resolution

Change in `provision/neko.yml`:

```yaml
- NEKO_SCREEN=1920x1080  # Modify resolution
```

## Usage

### Accessing Tor Sites Anonymously

1. **Direct Web Access:**
   - Navigate to `http://localhost:8080`
   - Log in with configured credentials
   - Use the Tor Browser as normal for .onion sites

2. **Multi-User Collaborative Browsing:**
   - Multiple users can control the same browser simultaneously
   - Useful for collaborative threat analysis of suspicious sites
   - Admin can supervise user actions

3. **Security Testing:**
   - Test malicious website behavior in isolated container
   - Analyze Tor network traffic on the lab network
   - Firewall captures all traffic for pcap analysis

### Advanced Features

#### Screen Sharing
- WebRTC provides smooth, low-latency video streaming
- Better performance than traditional remote desktop protocols
- Broadcast to multiple participants simultaneously

#### Persistent Sessions
- Browser data persists in `/home/neko` volume
- Tor Browser cookies and cache maintained across sessions
- Optional: Wipe on container restart for privacy

#### VPN + Tor Stacking
- Lab network traffic routes through Mullvad VPN (if configured)
- Neko adds another layer of anonymity via Tor Browser
- ISP sees: Lab → VPN
- VPN sees: Tor Browser traffic

## Troubleshooting

### Neko Service Not Starting

```bash
# Check service status
vagrant ssh neko
sudo systemctl status neko

# View logs
sudo journalctl -u neko -f

# Manual restart
sudo systemctl restart neko
```

### Port Conflicts

If ports 8080/8081 are already in use:

Edit `Vagrantfile` and `provision/neko.yml`:
```ruby
nk.vm.network "forwarded_port", guest: 8080, host: 8090  # Change host port
```

### Docker Issues

```bash
vagrant ssh neko
sudo systemctl status docker
sudo docker ps  # List containers
sudo docker logs neko-tor-browser  # View container logs
```

### Memory Issues

If Neko uses excessive memory, increase VM allocation:

```ruby
lv.memory = 4096  # Increase from 3072
```

### Network Access Issues

```bash
# From host
curl http://localhost:8080/

# From lab network
vagrant ssh openrelik
curl http://10.20.0.40:8080/
```

## Monitoring

### Check Neko VM Health

```bash
./scripts/test-connections.sh
```

This tests:
- VM connectivity
- Service status
- Port accessibility
- WebRTC stream availability

### Monitor Docker Container

```bash
vagrant ssh neko
sudo docker stats neko-tor-browser  # Real-time resource usage
sudo docker inspect neko-tor-browser  # Configuration details
```

## Integration Points

### Firewall pcap Analysis

All Tor Browser traffic through the Neko VM is captured:

```bash
vagrant ssh firewall
sudo tcpdump -i eth1 -w /tmp/neko-traffic.pcap 'host 10.20.0.40'
```

### OpenRelik Integration

1. Create artifact in OpenRelik from pcap
2. Analyze Tor traffic patterns
3. Correlate with timeline events

### REMnux Analysis

Copy pcaps to REMnux for deeper analysis:

```bash
vagrant scp firewall:/tmp/neko-traffic.pcap /tmp/
# Then transfer to REMnux for analysis
```

## Security Considerations

### * What Neko Protects

- **Container isolation** - Tor Browser runs in isolated Docker container
- **Persistent privacy** - No data left on host system
- **Lightweight footprint** - No full OS for Tor Browser
- **Lab isolation** - Tor traffic visible only on internal network
- **Multi-user transparency** - All actions logged/visible to admin

### WARNING:️ What Neko Does NOT Provide

- **Direct anonymity from lab admins** - Lab infrastructure sees all traffic
- **OS fingerprinting protection** - Simple containment, not hardened
- **Exploit isolation** - A browser 0-day could compromise container
- **Malware analysis** - Not intended for running untrusted code

### Best Practices

1. **Monitor traffic** - Use Suricata IDS on firewall
2. **Regular updates** - Redeploy container regularly: `vagrant provision neko`
3. **Access control** - Restrict Neko access via Guacamole ACLs
4. **Logging** - Enable audit logging for sensitive sites
5. **Containment** - Don't mix with production analysis on same lab

## Scaling

### Multiple Instances

To run multiple Neko instances for different teams:

1. Create new VM in Vagrantfile
2. Adjust IP (e.g., 10.20.0.41, 10.20.0.42)
3. Modify ports (e.g., 8090, 8100)
4. Run provision for specific VM: `vagrant up neko2`

### Load Balancing

Use nginx on firewall to load-balance multiple Neko instances:

```nginx
upstream neko_backend {
    server 10.20.0.40:8080;
    server 10.20.0.41:8080;
    server 10.20.0.42:8080;
}

server {
    listen 8085;
    location / {
        proxy_pass http://neko_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Advanced Configuration

### Custom Neko Settings

Edit `provision/neko.yml` environment variables:

```yaml
environment:
  # Logging
  - NEKO_LOGS=false           # Disable neko logs
  # Performance
  - NEKO_SCREEN=2560x1440    # High resolution
  - NEKO_SCREEN_FPS=60       # Frame rate
  # Security
  - NEKO_NAT=1               # WebRTC NAT traversal
  - NEKO_EPR=50000-50100    # UDP port range
```

### Health Checks

Neko includes built-in health monitoring:

```bash
vagrant ssh neko
curl http://localhost:8080/health
```

### Persistent Storage

Browser data stored in Docker volume:

```bash
vagrant ssh neko
sudo docker volume inspect neko_neko_data
sudo ls -la /var/lib/docker/volumes/neko_neko_data/_data/
```

## Reference

- **Project:** https://github.com/m1k1o/neko
- **Documentation:** https://neko.m1k1o.net/
- **Docker Images:** https://github.com/orgs/m1k1o/packages?repo_name=neko
- **Tor Browser:** https://www.torproject.org/download/

## Support

For neko-specific issues:

1. Check [neko GitHub Issues](https://github.com/m1k1o/neko/issues)
2. Review [neko documentation](https://neko.m1k1o.net/)
3. Check container logs: `vagrant ssh neko && sudo journalctl -u neko -f`

## Updates

To update to latest Neko version:

```bash
# SSH into neko VM
vagrant ssh neko

# Pull latest image
sudo docker pull ghcr.io/m1k1o/neko/tor-browser:latest

# Restart service
sudo systemctl restart neko
```

---

**Last Updated:** January 2026
**Neko Version:** Latest (auto-pulled on provision)
**Tor Browser Version:** Latest (included in neko image)
