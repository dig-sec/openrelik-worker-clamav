# Landing Page & Portal Integration Guide

## Overview

The Utgard Lab now features a centralized landing page serving as the main entry point for users. This page provides:

- **Visual hub** with navigation to all lab services
- **Worker directory** with descriptions of all 15 analysis workers
- **Quick-access buttons** to main platforms
- **Getting started guide** with provisioning steps
- **Credentials and security notes**
- **Professional appearance** with responsive design

## Accessing the Landing Page

### Primary Access
```
http://localhost/
```

This is the main entry point when accessing the Utgard Lab from the host machine. The firewall VM's nginx reverse proxy serves this page on port 80 (HTTP).

### Backup Access Points
The landing page also automatically redirects 404 errors to the main page, making it resilient to incorrect paths.

## Architecture

### Nginx Configuration

The firewall VM runs nginx as a reverse proxy with the following servers configured:

| Port | Service | Target |
|------|---------|--------|
| 80 | Landing Page | Static HTML from `/vagrant/services/index.html` |
| 8710 | OpenRelik API | Proxy to openrelik-redis:8710 |
| 8711 | OpenRelik UI | Proxy to openrelik-redis:8711 |
| 18080 | Guacamole Gateway | Proxy to 127.0.0.1:8080/guacamole/ |

**Configuration Location**: [provision/firewall.yml](../provision/firewall.yml) (lines 194-240)

### File Structure

```
/vagrant/services/
├── index.html              Main landing page (hosted on port 80)
└── neko/
    └── docker-compose.neko.yml
```

The landing page is served directly from the shared Vagrant folder, accessible to the firewall VM at `/vagrant/services/index.html`.

## Landing Page Sections

### 1. Header & Introduction
- Lab name and branding
- Brief description of Utgard's capabilities
- Quick-access buttons to main services

### 2. Quick-Access Panel
Three primary buttons for immediate access:
- 🚀 **Launch OpenRelik UI** - Main forensic analysis platform
- 📚 **API Documentation** - Developer reference
- 🖥️ **Remote Desktop** - Analyst workstation access

### 3. Core Services
- **OpenRelik UI**: Web interface for evidence management
- **OpenRelik API**: REST API with Swagger documentation
- **Guacamole Gateway**: Remote desktop protocol gateway

### 4. Forensic Workers (Categorized)
Workers organized by function:

#### Forensic Analysis
- RegRipper: Windows registry analysis
- EZTools: Windows artifacts (LECmd, RBCmd, AppCompatCache)
- Hayabusa: Event log analysis
- Plaso: Super timeline construction

#### Malware Analysis
- ClamAV: Antivirus scanning
- Yara: Pattern-based detection
- Capa: Capability analysis
- SSDeep: Fuzzy hashing

#### Document Analysis
- EML: Email forensics (EML/MSG)
- Exif: Image metadata
- Analyzer-Config: Config file parsing
- Extraction: File carving

#### Utilities
- Strings: String extraction
- Grep: Pattern matching
- Entropy: Entropy analysis

### 5. Documentation Links
- Quick Start Guide
- Full Documentation
- Project Overview
- Architecture Components
- Individual Worker Guides

### 6. Getting Started Section
Step-by-step provisioning instructions and useful commands

### 7. Credentials Box
Default login credentials with security warnings

### 8. Status Indicator
Real-time status showing lab operational state

### 9. Footer
Project information and external links (GitHub, OpenRelik)

## Styling & Design

### Color Scheme
- **Primary**: Purple gradient (#667eea to #764ba2)
- **Secondary**: White backgrounds with subtle shadows
- **Accents**: Yellow (#ffc107) for warnings

### Responsive Design
The page is fully responsive and works on:
- Desktop browsers (1920px and above)
- Tablets (768px - 1024px)
- Mobile devices (320px - 767px)

### Accessibility Features
- Semantic HTML structure
- Clear contrast ratios
- Descriptive link text
- Logical tab order

## Integration with Nginx

### How It Works

1. **Request arrives** at `http://localhost/`
2. **Nginx listens** on port 80 (default HTTP)
3. **Server block** processes request:
   ```nginx
   server {
     listen 80 default_server;
     root /vagrant/services;
     index index.html;
     location / {
       try_files $uri $uri/ =404;
     }
     error_page 404 /index.html;
   }
   ```
4. **File served** from `/vagrant/services/index.html`
5. **Requests to missing pages** redirect to landing page (404 → /index.html)

### Why This Approach

1. **Single entry point**: Users always land on the main hub
2. **Professional appearance**: Custom branded landing page vs. directory listings
3. **Navigation centralization**: All services accessible from one place
4. **Resilient routing**: 404 errors gracefully redirect to homepage
5. **Performance**: Static HTML served directly by nginx (no processing)

## Provisioning Automation

The landing page is automatically configured during `vagrant up openrelik` via the firewall playbook:

1. **Ansible copies** firewall.yml to each vagrant VM
2. **Nginx configuration** installed on firewall VM
3. **Landing page** already present in `/vagrant/services/index.html`
4. **Nginx service** started and enabled

No additional steps needed—the page is live after provisioning.

## Customization

### Modifying the Landing Page

Edit `services/index.html` directly:

```bash
cd /home/loki/git/utgard
nano services/index.html
```

Changes will be reflected immediately after refreshing the browser (nginx serves static files).

### Adding New Sections

The page uses semantic HTML sections. To add a new worker section:

```html
<div class="section">
    <div class="section-header">🔍 New Category</div>
    <div class="section-content">
        <p>Description of new worker category</p>
        <div class="workers-grid">
            <div class="worker-card">
                <strong>Worker Name</strong>
                <p>Brief description of capabilities</p>
            </div>
        </div>
    </div>
</div>
```

### Changing Colors

Modify the CSS gradient in the `<style>` section:

```css
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
```

Or change the primary color:

```css
color: #667eea;  /* Change to your color */
```

## User Workflow

### First-Time User
1. Provision lab: `./scripts/provision.sh`
2. Access `http://localhost/`
3. Click "🚀 Launch OpenRelik UI"
4. Create analysis tasks using the web interface
5. Reference worker guides for specific analysis needs

### Returning User
1. Check status: `./scripts/check-status.sh`
2. Start if needed: `./scripts/start-lab.sh`
3. Access `http://localhost/`
4. Navigate to required service/worker guide

### Developer
1. Access `http://localhost:8710/api/v1/docs/` from landing page
2. Use OpenRelik REST API for programmatic access
3. Integrate with CI/CD pipelines for automated analysis

## Troubleshooting

### Landing Page Not Loading

**Check nginx status**:
```bash
vagrant ssh firewall
sudo systemctl status nginx
```

**Check nginx logs**:
```bash
sudo tail -f /var/log/nginx/error.log
```

**Verify file exists**:
```bash
ls -la /vagrant/services/index.html
```

### Slow Page Load

- **Clear browser cache**: Ctrl+Shift+Delete
- **Check network**: `./scripts/test-connections.sh`
- **Check firewall VM**: `vagrant status`

### Links Not Working

- **Check OpenRelik running**: `docker ps | grep openrelik`
- **Check Guacamole running**: `docker ps | grep guacamole`
- **Verify ports**: `netstat -tulpn | grep LISTEN`

## Security Considerations

### Access Control
- Landing page is publicly accessible (no authentication required)
- Credentials are default/weak (for demo purposes)
- **Production note**: Implement authentication for real deployments

### HTTPS
- Currently HTTP only (port 80)
- **Recommendation**: Add SSL/TLS certificate for production
- Nginx config can be extended with HTTPS:
  ```nginx
  listen 443 ssl;
  ssl_certificate /etc/nginx/certs/cert.pem;
  ssl_certificate_key /etc/nginx/certs/key.pem;
  ```

### Network Isolation
- Landing page served only within lab network
- Host cannot directly access firewall VM services
- Port forwarding handled by Vagrant/libvirt

## Related Documentation

- [provision/firewall.yml](../provision/firewall.yml) - Nginx configuration
- [START-HERE.txt](../START-HERE.txt) - Quick start guide
- [README.md](../README.md) - Full project documentation
- [PROJECT-REVIEW.md](../PROJECT-REVIEW.md) - Project overview

## Summary

The landing page transforms Utgard Lab into a user-friendly, professionally presented forensic analysis platform. It serves as:

1. **Primary entry point** for all users
2. **Visual hub** for service discovery
3. **Quick reference** for worker capabilities
4. **Getting started guide** for new users
5. **Professional face** of the lab infrastructure

The integration with nginx is seamless, automatic, and requires no manual configuration after provisioning.
