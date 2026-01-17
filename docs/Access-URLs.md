# Access URLs

Utgard exposes services via the edge (nginx) with TLS.

## Path-Based Routing (default)
- Portal: `https://<hostname>/`
- Guacamole: `https://<hostname>/guacamole/`
- OpenRelik: `https://<hostname>/openrelik/` (API at `/openrelik/api/`)
- Maigret: `https://<hostname>/maigret/`
- Kasm: `https://<hostname>/kasm/` (Tor at `/kasm/tor/`)

## Subdomain Routing (`external_access.use_subdomains: true`)
- Portal: `https://<hostname>/`
- Guacamole: `https://guacamole.<hostname>/`
- OpenRelik: `https://openrelik.<hostname>/`
- Maigret: `https://maigret.<hostname>/`
- Kasm (OSINT): `https://browsers.<hostname>/`
- Kasm (Tor): `https://tor.<hostname>/`

## Authentication
If `auth.enabled: true` in `config.yml`:
- Landing page can be protected (`auth.protect_landing: true`)
- Some services may be exempt (e.g., Guacamole/OpenRelik/Kasm have their own auth)
- Credentials printed during playbook run; password stored at `/opt/guacamole/auth/.htpasswd_secret` if auto-generated

