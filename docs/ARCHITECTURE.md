# Utgard Lab Architecture

## Overview

Utgard is a secure forensics lab environment with isolated VMs that route traffic through Mullvad VPN. External access is provided via Pangolin with TLS and service routing.

## Network Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ OPERATOR                                                                      │
│                                                                               │
│   Browser ──────► Pangolin (https://your-domain.com)                          │
└────────────────────────│──────────────────────────────────────────────────────┘
                         │ HTTPS
┌────────────────────────│──────────────────────────────────────────────────────┐
│ PANGOLIN HOST                                                                 │
│   Traefik + Pangolin + Gerbil                                                  │
└────────────────────────│──────────────────────────────────────────────────────┘
                         │
┌────────────────────────│──────────────────────────────────────────────────────┐
│ FIREWALL VM            │                                                      │
│                        │                                                      │
│   eth0 ◄───────────────┘  (192.168.121.x - vagrant-libvirt)                  │
│   eth1 ─────────────────────────► 10.20.0.1 (Lab Gateway)                    │
│   wg0 ──────────────────────────► Mullvad VPN (outbound traffic)             │
│   nftables, packet capture                                                   │
└───────────────────────────────────────────────────────────────────────────────┘
                         │
                         │ Lab Network (10.20.0.0/24)
                         │
        ┌────────────────┼────────────────┬─────────────────┐
        │                │                │                 │
        ▼                ▼                ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  OpenRelik    │ │   REMnux      │ │    Neko       │ │   (Future)    │
│  10.20.0.30   │ │  10.20.0.20   │ │  10.20.0.40   │ │  10.20.0.x    │
│               │ │               │ │               │ │               │
│  :8710 API    │ │  Analysis     │ │  :8080 Tor    │ │               │
│  :8711 UI     │ │  Tools        │ │  :8090 Chrome │ │               │
└───────────────┘ └───────────────┘ └───────────────┘ └───────────────┘
        │                │                │
        └────────────────┴────────────────┘
                         │
                         ▼
                  Firewall wg0 ──► Mullvad VPN ──► Internet
```

## Service Access (via Pangolin)

Once Pangolin is configured, access services via your domain:

| Service           | URL                          | Notes                    |
|-------------------|------------------------------|--------------------------|
| OpenRelik UI      | https://your-domain.com/<route> | Forensics platform    |
| OpenRelik API     | https://your-domain.com/<route> | REST API              |
| Neko Tor Browser  | https://your-domain.com/<route> | Isolated Tor browser  |
| Neko Chromium     | https://your-domain.com/<route> | Isolated Chromium     |
| Guacamole         | https://your-domain.com/<route> | Remote desktop gateway |
| REMnux            | Via Guacamole RDP               | Malware analysis       |

## Network Zones

### Zone 1: Host Network (192.168.121.0/24)
- vagrant-libvirt managed
- Firewall eth0 interface
- Pangolin host must reach this network

### Zone 2: Lab Network (10.20.0.0/24)
- Isolated internal network
- All lab VMs connected here
- Routed through Mullvad VPN for internet access
- External access routed via Pangolin

### Zone 3: Mullvad VPN
- Outbound traffic from lab network
- Swedish exit nodes for privacy
- Configured via `wg0` interface on firewall

## Traffic Flow

### Operator → Lab Service
```
Browser → Pangolin → Firewall → Lab VM (10.20.0.x)
```

### Lab VM → Internet
```
Lab VM → Firewall (10.20.0.1) → Mullvad wg0 → Internet
```

### Host → Internet (unchanged)
```
Host → Normal internet (not through lab)
```

## Quick Start

1. **Start the lab:**
   ```bash
   ./scripts/start-lab.sh
   ```

2. **Deploy Pangolin:**
   Follow `docs/PANGOLIN-ACCESS.md` and start the Pangolin stack.

3. **Access services:**
   Use the Pangolin routes you configured for OpenRelik, Neko, and Guacamole.

## Security Model

- **Isolation**: Lab VMs cannot reach host network directly
- **VPN Egress**: All lab internet traffic exits through Mullvad
- **Controlled Access**: Only Pangolin-authenticated users can access lab
- **No Port Forwarding**: No services exposed on host localhost
