# Utgard Components Overview

Use this as a quick map of each service, where it lives in the repo, and how to access or operate it. Detailed setup and troubleshooting for specific services live in their dedicated docs.

## Firewall / Gateway
- Purpose: Isolation, routing, NAT, nftables default-deny, optional Mullvad WireGuard egress, reverse proxy for OpenRelik and Guacamole, packet capture + Suricata IDS.
- VM: firewall (10.20.0.1)
- Playbook: provision/firewall.yml
- Access: `vagrant ssh firewall`
- Key services: nginx (ports 80/443/8710/8711/18080), wg0 tunnel (optional), nftables, suricata, tcpdump.
- Notes: set `MULLVAD_WG_CONF` before provisioning to enforce VPN egress; otherwise traffic goes out eth0.

## OpenRelik
- Purpose: Artifact indexing and forensics platform (UI + API).
- VM: openrelik (10.20.0.30)
- Playbook: provision/openrelik.yml
- Install path: /opt/openrelik/openrelik
- Access: UI http://localhost:8711/ ; API http://localhost:8710/api/v1/docs/ (through firewall reverse proxy)
- Auth: local admin/admin by default, or Google OAuth via env vars `OPENRELIK_CLIENT_ID`, `OPENRELIK_CLIENT_SECRET`, `OPENRELIK_ALLOWLIST`.
- Helper scripts inside VM: `openrelik-start`, `openrelik-stop`, `openrelik-logs`.

## REMnux Analyst VM
- Purpose: Analyst workstation with base tools (YARA, binwalk, tshark); optional full REMnux CLI distro.
- VM: remnux (10.20.0.20)
- Playbook: provision/remnux.yml
- Access: RDP (via Guacamole) or SSH `vagrant@10.20.0.20`.
- Desktop: xrdp + xfce installed; set `remnux_install_cli=true` in the playbook if your environment supports the full REMnux CLI.

## Guacamole
- Purpose: Browser-based RDP/SSH gateway to lab VMs.
- Location: Runs on firewall VM via Docker (optional, enabled by default in firewall playbook).
- Access: http://localhost:18080/guacamole/ (reverse proxied)
- Default credentials: guacadmin/guacadmin (change on first login).
- Setup guide: docs/GUACAMOLE-SETUP.md

## Neko Tor Browser
- Purpose: Remote multi-user Tor Browser session for .onion research.
- Compose: services/neko/docker-compose.neko.yml
- Docs: docs/neko/NEKO-README.md (overview), docs/neko/NEKO-SETUP.md (full guide), docs/neko/NEKO-INTEGRATION.md (change summary), docs/neko/NEKO-ARCHITECTURE.txt (topology), docs/neko/NEKO-SUMMARY.txt (file manifest)
- Access: http://localhost:8080 (credentials in setup doc). Guacamole integration script: scripts/configure-neko-guacamole.sh. Quickref: scripts/NEKO-QUICKREF.sh.

## Mullvad WireGuard
- Purpose: VPN egress for the lab; enforced at firewall when configured.
- Config: export `MULLVAD_WG_CONF` before provisioning firewall. Endpoint switcher script: scripts/wg-config.sh.
- Docs: docs/wireguard/WIREGUARD-SETUP.md, docs/wireguard/WIREGUARD-SUMMARY.txt.

## Scripts & Automation
- Start/stop/provision: scripts/start-lab.sh, scripts/provision.sh, vagrant commands.
- Health checks: scripts/check-status.sh, scripts/test-connections.sh.
- Cleanup: scripts/clean-logs.sh.
- Deployment helper: scripts/deploy-and-test.sh.
- WireGuard endpoint switcher: scripts/wg-config.sh.
- Neko helpers: scripts/configure-neko-guacamole.sh, scripts/NEKO-QUICKREF.sh.

## Files and Definitions
- VM definitions: Vagrantfile
- Libvirt network: network.xml
- Firewall reverse proxy template: provision/firewall.yml (nginx section)
- Example settings: provision/settings.toml.example

## Access Map (Host → Lab)
- OpenRelik UI/API: localhost:8711 / localhost:8710
- Guacamole: localhost:18080/guacamole
- Neko: localhost:8080 (Tor Browser)
- SSH (via Guacamole or direct host network): firewall 10.20.0.1, remnux 10.20.0.20, openrelik 10.20.0.30

## Operational Notes
- All lab traffic routes through the firewall; keep Mullvad configured for real malware detonation.
- nftables default-deny is enforced; only explicit services are exposed via reverse proxy.
- Suricata and packet capture run on the firewall; check logs in /var/log/suricata and /var/log/pcaps on the firewall VM.
- Re-run provisioning for a single VM with `vagrant provision <vm>` if you change its playbook.
