# Maigret Guide

## Overview
Maigret is a free and open-source OSINT tool for finding accounts across 3000+ websites by username.

## Installation
Runs as a Docker container at `/opt/maigret`:
- Image: `soxoj/maigret:latest`
- Port: `5000` (internal, proxied by nginx)
- Reports: `/opt/maigret/reports`

## Configuration
Key variables in `roles/maigret/defaults/main.yml`:
- `maigret_state_dir`: `/opt/maigret`
- `maigret_port`: `5000`
- `maigret_image`: `soxoj/maigret:latest`
- `maigret_reports_dir`: `<state_dir>/reports`

## Access
- URL: `https://<hostname>/maigret/` (path-based) or `https://maigret.<hostname>/` (subdomain)
- No authentication required (covered by edge if enabled)

## Usage

### Web UI
1. Browse to `https://<hostname>/maigret/`
2. Enter username(s) to search
3. Maigret queries 3000+ sites in parallel
4. Results displayed with links to profiles
5. Export reports to JSON/HTML

### CLI (if needed)
```bash
docker exec maigret maigret --help
docker exec maigret maigret username
```

## Reports
- Stored at `/opt/maigret/reports/`
- Accessible via web UI download or direct file access
- Formats: JSON, HTML

## Container Management
```bash
# Status
docker compose ps -f /opt/maigret/docker-compose.yml

# Logs
docker compose logs -f /opt/maigret/docker-compose.yml

# Restart
docker compose restart -f /opt/maigret/docker-compose.yml
```

## Troubleshooting
- **Slow searches**: Network latency or rate limiting; Maigret respects robots.txt and timeouts
- **Site timeouts**: Some sites may be slow or unavailable; re-run for better coverage
- **No results**: Username may not exist or sites may require registration
- **Port conflict**: Ensure `5000` is free on host

