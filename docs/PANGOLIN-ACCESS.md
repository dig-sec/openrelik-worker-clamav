# Pangolin External Access Setup

## Goal

Publish Utgard services over HTTPS without a client VPN.

## Requirements

- Linux host with Docker + Docker Compose
- DNS record pointing to the Pangolin host
- Network route from Pangolin host to 10.20.0.0/24

## Setup

```bash
mkdir -p pangolin/config/traefik pangolin/config/db \
  pangolin/config/letsencrypt pangolin/config/logs pangolin/config/traefik/logs
```

Update:
- `pangolin/config/traefik/traefik_config.yml` (email)
- `pangolin/config/traefik/dynamic_config.yml` (domain)
- `pangolin/config/config.yml` (Pangolin settings)

Start:

```bash
cd pangolin
sudo docker compose up -d
```

Initial setup:

```
https://your-domain.com/auth/initial-setup
```

## Add Services (Pangolin UI)

- OpenRelik UI: `http://10.20.0.30:8711`
- OpenRelik API: `http://10.20.0.30:8710`
- Neko Tor: `http://10.20.0.40:8080`
- Neko Chromium: `http://10.20.0.40:8090`
