# Architecture & Topology

## Network Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                         Host (Linux)                            │
│  Docker services + Nginx edge portal on 20.240.216.254         │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  HTTPS Reverse Proxy                   │    │
│  │  (Nginx on :443, TLS cert, path/subdomain routing)    │    │
│  └────────────────────────────────────────────────────────┘    │
│         │              │              │              │          │
│         ▼              ▼              ▼              ▼          │
│   ┌─────────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐   │
│   │ OpenRelik   │ │Guacamole │ │ Maigret  │ │ Kasm Proxy │   │
│   │ :8710/8711  │ │  :8080   │ │  :5000   │ │   :8443    │   │
│   └─────────────┘ └──────────┘ └──────────┘ └────────────┘   │
│         │              │              │              │          │
│    [Workers]      [PostgreSQL]    [Reports]   [TOR & OSINT]    │
│   [Plaso,YARA]     [DB auth]      [OSINT]    [Isolated nets]  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
          │                          │
          │                          │
    [Virtual NAT                [Virtual Private
     Network]                    Network]
          │                          │
          ▼                          ▼
    ┌──────────────────────────────────────┐
    │        Firewall VM (10.20.0.2)       │
    │  nftables NAT, dnsmasq, IP forward   │
    └──────────────────────────────────────┘
          │                          │
          ▼                          ▼
    ┌──────────────────────────────────────┐
    │         REMnux VM (10.20.0.20)       │
    │   Malware analysis, RDP, Tools      │
    │   Access via Guacamole Remote       │
    └──────────────────────────────────────┘
```

## Services Overview

### OpenRelik (Forensic Pipeline)
- UI: `8711`, API: `8710`
- Workers: Plaso, YARA, Hayabusa, CAPa, Strings, etc.
- Data stored at `/opt/openrelik/openrelik/data`
- Access: `https://<host>/openrelik/`

### Guacamole (Remote Desktop Gateway)
- Port `8080` (internal)
- PostgreSQL backend at `/opt/guacamole/postgres`
- Provides RDP/VNC/SSH access
- Access: `https://<host>/guacamole/`

### Maigret (OSINT Username Search)
- Port `5000`
- Searches 3000+ sites for usernames
- Reports stored at `/opt/maigret/reports`
- Access: `https://<host>/maigret/`

### Kasm Workspaces (Isolated Browsers)
- **Tor**: Network-isolated, Tor-only egress
  - Port `6901` (internal)
  - Network: `kasm-isolated` (`172.30.0.0/24`)
  - iptables blocks outbound except to Tor gateway
  
- **OSINT**: Forensic tools + clearweb access
  - Port `6902` (internal)
  - Network: `kasm-clearweb` (`172.31.0.0/24`)

- **Proxy**: Nginx + TLS on `8443` (internal)
  - Paths: `/tor/` and `/osint/`

### Firewall VM
- Gateway for lab VMs
- nftables: filter (drop by default), forward (lab traffic), NAT
- dnsmasq: DNS resolver on `10.20.0.2:53` for lab VMs
- Optional: WireGuard egress via Mullvad

### REMnux VM
- Malware analysis tools (Wireshark, YARA, Volatility3, etc.)
- xrdp + XFCE desktop on `3389`
- Accessed via Guacamole

## Data Flow: User → Portal → Service

```
1. User browses https://<host>/openrelik/
2. TLS termination at Nginx (edge role)
3. Optional: Basic Auth check
4. Nginx proxies to localhost:8711 (OpenRelik UI)
5. UI makes API calls to localhost:8710
6. Workers process tasks in background
7. Response proxied back through Nginx with X-Forwarded-* headers
```

## Network Isolation
- Each Docker service runs on its own bridge network
- Kasm Tor container uses `kasm-isolated` network with iptables egress restrictions
- iptables rules drop all outbound from Tor subnet except to gateway (10.64.0.1)

