# Pangolin External Access

All external access to the Utgard lab is through Pangolin tunnels. There are no open ports on the lab network.

Pangolin repo: https://github.com/fosrl/pangolin

## Network Architecture

```
Internet → Pangolin Server (your-domain.com)
              ↓ (secure tunnel)
           Firewall (10.20.0.2)
              ↓ (lab network)
           Lab VMs
```

## Static IP Assignments

| VM        | IP Address    | Services                     |
|-----------|---------------|------------------------------|
| Firewall  | 10.20.0.2     | Gateway, DNS, Mullvad VPN    |
| REMnux    | 10.20.0.20    | RDP (3389), Analysis tools   |
| OpenRelik | 10.20.0.30    | API (8710), UI (8711)        |
| Neko      | 10.20.0.40    | Tor (8080), Chromium (8090)  |

## Setup

```bash
mkdir -p pangolin/config/traefik pangolin/config/db \
  pangolin/config/letsencrypt pangolin/config/logs pangolin/config/traefik/logs
```

Update:
- `pangolin/config/traefik/traefik_config.yml` (email)
- `pangolin/config/traefik/dynamic_config.yml` (domain)
- `pangolin/config/config.yml` (settings)

Start:

```bash
cd pangolin
sudo docker compose up -d
```

Initial setup:

```
https://your-domain.com/auth/initial-setup
```

## Service Endpoints (Pangolin UI)

Configure these targets in Pangolin:

| Service           | Target URL                    | Notes                    |
|-------------------|-------------------------------|--------------------------|
| OpenRelik UI      | `http://10.20.0.30:8711`      | Web interface            |
| OpenRelik API     | `http://10.20.0.30:8710`      | REST API                 |
| Neko Tor Browser  | `http://10.20.0.40:8080`      | WebRTC browser session   |
| Neko Chromium     | `http://10.20.0.40:8090`      | WebRTC browser session   |
| REMnux RDP        | `tcp://10.20.0.20:3389`       | RDP tunnel (Newt client) |

## Access Methods

1. **Web Services** (OpenRelik, Neko): Direct HTTPS via Pangolin subdomain
2. **RDP** (REMnux): Use Pangolin Newt client for TCP tunnel

No SSH port forwarding, VPN clients, or Guacamole needed.
