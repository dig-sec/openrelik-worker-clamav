# Pangolin External Access Setup

## Overview

Pangolin replaces the WireGuard host tunnel for external access to Utgard services. Run Pangolin on a host that can reach the lab network (10.20.0.0/24) and publish OpenRelik, Neko, and Guacamole through Pangolin-managed routes.

## Prerequisites

- Linux host with Docker and Docker Compose
- DNS record pointing your domain at the Pangolin host
- Root access on the Pangolin host

## Directory Structure

The repo includes a Pangolin template under `pangolin/`. Create the runtime directories before starting:

```bash
mkdir -p pangolin/config/traefik pangolin/config/db pangolin/config/letsencrypt pangolin/config/logs pangolin/config/traefik/logs
```

## Configure Pangolin

1. Update your domain and email:
   - `pangolin/config/traefik/traefik_config.yml` (replace `admin@example.com`)
   - `pangolin/config/traefik/dynamic_config.yml` (replace `pangolin.example.com`)
2. Fill in Pangolin settings:
   - `pangolin/config/config.yml`

## Start the Stack

```bash
cd pangolin
sudo docker compose up -d
sudo docker compose ps
```

## Initial Setup

Open:

```
https://your-domain.com/auth/initial-setup
```

## Publish Utgard Services

In the Pangolin UI, add services that point at the lab IPs:

- OpenRelik UI: `http://10.20.0.30:8711`
- OpenRelik API: `http://10.20.0.30:8710`
- Neko Tor Browser: `http://10.20.0.40:8080`
- Neko Chromium: `http://10.20.0.40:8090`
- Guacamole: `http://10.20.0.1:8080/guacamole`

Make sure the Pangolin host can route to the lab network. If Pangolin runs on the firewall VM, it already sits on both the host network and the lab network.
