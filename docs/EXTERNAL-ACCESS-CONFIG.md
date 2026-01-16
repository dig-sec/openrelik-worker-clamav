# External Access Configuration Guide

## Overview

The Utgard OSINT platform now supports flexible external access configuration through a centralized `config.yml` file. This allows the same deployment to work with:

1. **Public IP address**: Direct IP access without DNS
2. **sslip.io domains**: Free SSL/TLS via sslip.io subdomain service
3. **Custom domains**: Your own registered domain name
4. **Subdomain routing**: Each service on its own subdomain (optional)
5. **Path-based routing**: All services at different URL paths (default)

## Current Configuration

```yaml
external_access:
  hostname: "20.240.216.254.sslip.io"
  use_subdomains: false
  service_subdomains:
    guacamole: "remote"
    openrelik: "forensics"
    maigret: "osint"
    kasm: "browsers"
```

### Deployed Settings
- **External Hostname**: `20.240.216.254.sslip.io`
- **Routing Mode**: Path-based (default)
- **TLS**: Self-signed certificate automatically generated
- **Redirect**: HTTP automatically redirects to HTTPS

## Access Patterns

### Current (Path-Based) Mode

All services accessible from the same domain with different URL paths:

```
https://20.240.216.254.sslip.io/              → Portal landing page
https://20.240.216.254.sslip.io/guacamole/    → Guacamole remote desktop
https://20.240.216.254.sslip.io/openrelik/    → OpenRelik forensic analysis
https://20.240.216.254.sslip.io/maigret/      → Maigret username OSINT
https://20.240.216.254.sslip.io/kasm/         → Kasm browser workspaces
```

**Advantages**:
- Single SSL certificate required
- No wildcard DNS needed
- Simple configuration
- Works with IP addresses

### Optional (Subdomain) Mode

Each service on its own subdomain. To enable:

```yaml
external_access:
  hostname: "20.240.216.254.sslip.io"
  use_subdomains: true
```

Access would then be:

```
https://20.240.216.254.sslip.io/              → Portal landing page
https://remote.20.240.216.254.sslip.io/       → Guacamole
https://forensics.20.240.216.254.sslip.io/    → OpenRelik
https://osint.20.240.216.254.sslip.io/        → Maigret
https://browsers.20.240.216.254.sslip.io/     → Kasm
```

To customize subdomain names, modify `service_subdomains`.

## Configuration Options

### Hostname Options

#### 1. IP Address (No DNS)
```yaml
external_access:
  hostname: "20.240.216.254"
  use_subdomains: false
```
- Direct IP access: `https://20.240.216.254/guacamole/`
- No DNS required
- Self-signed cert warnings in browser

#### 2. sslip.io (Free DNS + SSL)
```yaml
external_access:
  hostname: "20.240.216.254.sslip.io"
  use_subdomains: false
```
- sslip.io provides free DNS pointing IP to subdomains
- SSL certificates from Let's Encrypt via sslip.io
- Access: `https://20.240.216.254.sslip.io/guacamole/`
- No registration required

#### 3. Custom Domain (Your Own DNS)
```yaml
external_access:
  hostname: "utgard.example.com"
  use_subdomains: false
```
- Use your registered domain
- Point DNS A record to `20.240.216.254`
- Requires valid DNS setup
- Self-signed certificate (or provide your own)

### Service Subdomain Customization

Customize subdomain prefixes for each service:

```yaml
external_access:
  hostname: "20.240.216.254.sslip.io"
  use_subdomains: true
  service_subdomains:
    guacamole: "rdp"              # https://rdp.20.240.216.254.sslip.io/
    openrelik: "forensics"        # https://forensics.20.240.216.254.sslip.io/
    maigret: "username-search"    # https://username-search.20.240.216.254.sslip.io/
    kasm: "browsers"              # https://browsers.20.240.216.254.sslip.io/
```

## How It Works

### Configuration Flow

1. **config.yml** contains `external_access` section
2. **Ansible playbook** loads `config.yml` when deploying edge role
3. **Edge role tasks** set Ansible variables from config
4. **nginx template** (Jinja2) renders configuration using these variables
5. **Generated nginx.conf** includes:
   - Server name/subdomain settings
   - Conditional blocks (subdomain vs. path-based)
   - Proxy rules for each service
   - SSL certificate paths
   - HTTP→HTTPS redirects

### Files Involved

- **Configuration**: [`config.yml`](../config.yml)
- **Edge role defaults**: [`ansible/roles/edge/defaults/main.yml`](../ansible/roles/edge/defaults/main.yml)
- **Edge role tasks**: [`ansible/roles/edge/tasks/main.yml`](../ansible/roles/edge/tasks/main.yml)
- **nginx template**: [`ansible/roles/edge/templates/nginx-portal.conf.j2`](../ansible/roles/edge/templates/nginx-portal.conf.j2)
- **Generated config**: `/etc/nginx/sites-available/utgard.conf`

## Deployment & Testing

### Initial Deployment
```bash
cd /home/azureuser/git/utgard/ansible
sudo ansible-playbook -i inventory.yml playbooks/host.yml -l localhost
```

### After Changing Configuration

1. Edit `config.yml`
2. Re-run the playbook (only edge role tasks will update)
3. Verify nginx syntax: `sudo nginx -t`
4. Check logs: `sudo journalctl -u nginx -f`

### Test Access

```bash
# Test portal landing page
curl -k https://20.240.216.254.sslip.io/

# Test guacamole proxy
curl -k https://20.240.216.254.sslip.io/guacamole/ | head -20

# Check nginx error log
tail -f /var/log/nginx/error.log
```

### Browser Access

1. Open browser
2. Navigate to: `https://20.240.216.254.sslip.io/`
3. Accept self-signed certificate warning
4. Click service links in landing page

## SSL/TLS Certificates

### Current Setup (Self-Signed)

Certificates are auto-generated at first deployment:
- Location: `/opt/guacamole/tls/`
- Files:
  - `fullchain.pem` (certificate chain)
  - `privkey.pem` (private key)
  - `cert.pem` (certificate)

Generated with 365-day validity from edge role.

### Bringing Your Own Certificate

1. Place certificate files at `/opt/guacamole/tls/`:
   - `fullchain.pem` (your certificate + CA chain)
   - `privkey.pem` (your private key)
2. Re-run playbook or manually reload nginx: `sudo systemctl reload nginx`

## Troubleshooting

### Certificate Warnings in Browser

**Expected with self-signed certificates**. sslip.io provides valid certs, but self-signed at the service level.

### Services Unreachable

Check nginx is running:
```bash
sudo systemctl status nginx
sudo nginx -t
```

Check proxy targets are listening:
```bash
netstat -tlnp | grep -E ':(8080|8710|8711|5000)'
```

### Hostname Not Resolving

If using `20.240.216.254.sslip.io`:
- sslip.io should auto-resolve IP to all subdomains
- Test: `nslookup forensics.20.240.216.254.sslip.io`

### nginx Not Reloading After Config Change

Edit `config.yml` → Re-run playbook → It triggers handler to reload

## Advanced: Custom Configuration Example

To deploy with a custom domain and subdomain routing:

```yaml
external_access:
  hostname: "osint.yourdomain.com"
  use_subdomains: true
  service_subdomains:
    guacamole: "desktop"
    openrelik: "forensics"
    maigret: "research"
    kasm: "browsers"
```

This would create:
- `osint.yourdomain.com` → Portal
- `desktop.osint.yourdomain.com` → Guacamole
- `forensics.osint.yourdomain.com` → OpenRelik
- `research.osint.yourdomain.com` → Maigret
- `browsers.osint.yourdomain.com` → Kasm

Requires:
- Registered domain
- Wildcard DNS: `*.osint.yourdomain.com A 20.240.216.254`
- Valid SSL cert for `osint.yourdomain.com` and `*.osint.yourdomain.com`

## See Also

- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Service access and credentials
- [DEPLOYMENT-FLOW.md](DEPLOYMENT-FLOW.md) - Architecture and deployment details
