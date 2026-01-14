# Utgard Architecture

Utgard runs lab VMs behind a firewall. Pangolin provides optional external access. All lab VMs access the internet via the firewall through Mullvad VPN egress.

Flow:

Operator -> Pangolin (optional) -> Firewall (10.20.0.2) -> Lab VMs (10.20.0.0/24)
Lab VMs -> Firewall -> Mullvad VPN -> Internet

Zones:
- Host: 192.168.121.0/24 (firewall eth0)
- Lab: 10.20.0.0/24 (firewall eth1)
- VPN: wg0 (Mullvad egress for all lab traffic)

Security:
- Default-deny nftables on firewall
- No direct host -> lab access
- Packet capture + Suricata on lab traffic
