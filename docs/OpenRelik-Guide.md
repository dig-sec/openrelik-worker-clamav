# OpenRelik Guide

## Overview
OpenRelik is a forensic artifact analysis and processing platform. Utgard deploys it with multiple workers for parallel processing.

## Installation
Installed via official install script at `/opt/openrelik`. The role:
- Creates `/opt/openrelik` directory
- Downloads `install.sh` from `https://github.com/openrelik/openrelik-deploy`
- Runs the script to generate `docker-compose.yml`
- Configures ports and extra workers
- Starts the stack

## Configuration
Key variables in `roles/openrelik/defaults/main.yml`:
- `openrelik_install_dir`: `/opt/openrelik`
- `openrelik_ui_port`: `8711`
- `openrelik_api_port`: `8710`
- `openrelik_extra_workers`: List of worker services (Plaso, YARA, Hayabusa, CAPa, etc.)
- `openrelik_worker_registry`: `ghcr.io/openrelik`
- `openrelik_worker_tag`: `latest`

## Workers
Default workers (see upstream repos for new components):
- `openrelik-worker-plaso`: Timeline analysis (concurrency: 2)
- `openrelik-worker-yara`: Malware pattern matching (concurrency: 2)
- `openrelik-worker-hayabusa`: Event log analysis (concurrency: 4)
- `openrelik-worker-capa`: Malware capability analysis (concurrency: 1)
- `openrelik-worker-strings`: String extraction (concurrency: 4)
- `openrelik-worker-exif`: Metadata extraction (concurrency: 1)
- `openrelik-worker-ssdeep`: Fuzzy hashing (concurrency: 1)
- `openrelik-worker-clamav`: Malware scanning (concurrency: 2) — repo: https://github.com/dig-sec/openrelik-worker-clamav.git
- ... and more

Adjust concurrency based on host CPU and memory. Each worker runs as a separate container.

## Access
- UI: `https://<hostname>/openrelik/`
- API: `https://<hostname>/openrelik/api/`

## Data & Artifacts
- Stored at `/opt/openrelik/openrelik/data/`
- Share evidence files via upload UI or direct file placement on host

## Container Management
```bash
# Check status
docker compose ps -f /opt/openrelik/openrelik/docker-compose.yml

# View logs
docker compose logs -f -f /opt/openrelik/openrelik/docker-compose.yml openrelik-ui

# Restart workers
docker compose restart -f /opt/openrelik/openrelik/docker-compose.yml
```

## Troubleshooting
- **Workers not starting**: Check `openrelik_skip_missing_workers: true` in playbook or provide valid image credentials
- **Port conflicts**: Ensure `8710` and `8711` are free on host
- **Out of memory**: Lower worker concurrency or increase host RAM
