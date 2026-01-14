# Pangolin External Access Plan (OSINT-Friendly)

**Goal:** Simple, reliable external access to all Utgard services from a browser.  
**Audience:** OSINT analysts who need quick access without VPN clients.  
**Status:** Ready to deploy with the Pangolin templates in `pangolin/`.

---

## High-Level Flow

```
Operator Browser ──HTTPS──► Pangolin (Traefik + Pangolin + Gerbil)
                                   │
                                   └──► Utgard Lab Services (10.20.0.0/24)
```

---

## Quick Start (Minimal Steps)

1. **Prepare folders**
   ```bash
   mkdir -p pangolin/config/traefik pangolin/config/db pangolin/config/letsencrypt \
     pangolin/config/logs pangolin/config/traefik/logs
   ```

2. **Update domain + email**
   - `pangolin/config/traefik/traefik_config.yml` → replace `admin@example.com`
   - `pangolin/config/traefik/dynamic_config.yml` → replace `pangolin.example.com`

3. **Configure Pangolin**
   - `pangolin/config/config.yml` → fill required settings (see Pangolin docs)

4. **Start the stack**
   ```bash
   cd pangolin
   sudo docker compose up -d
   ```

5. **Initial setup**
   - Open `https://your-domain.com/auth/initial-setup`

6. **Add Utgard services in Pangolin**
   - OpenRelik UI → `http://10.20.0.30:8711`
   - OpenRelik API → `http://10.20.0.30:8710`
   - Neko Tor → `http://10.20.0.40:8080`
   - Neko Chromium → `http://10.20.0.40:8090`
   - Guacamole → `http://10.20.0.1:8080/guacamole`

---

## OSINT-Friendly Routes (Recommended)

Use short, memorable routes for fast access:

- `/openrelik`
- `/openrelik-api`
- `/neko-tor`
- `/neko-chromium`
- `/guacamole`

These are configured in the Pangolin UI when adding services.

---

## Checklist Before You Call It Done

- DNS A/AAAA record points to Pangolin host
- HTTPS cert issued (Traefik + Let's Encrypt)
- Pangolin UI reachable at `https://your-domain.com`
- All five services load in browser
- Guacamole and Neko WebRTC work without mixed-content errors

---

## Troubleshooting (Fast)

```bash
cd pangolin
sudo docker compose ps
sudo docker compose logs -f --tail=200
```

Common issues:
- **TLS not issuing:** check DNS + email in `traefik_config.yml`
- **Services unreachable:** confirm Pangolin host can reach `10.20.0.0/24`
- **Guacamole pathing:** ensure service target includes `/guacamole`
- **Neko WebRTC:** if clients can’t connect, verify `NEKO_WEBRTC_IP` points to the public hostname/IP

---

## Security Notes

- Pangolin becomes the single internet-facing access point.
- Keep Pangolin admin credentials secure and rotate after first login.
- Do not expose lab services directly; only via Pangolin routes.
