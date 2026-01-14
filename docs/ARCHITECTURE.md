# Utgard Architecture

## Summary

Utgard runs isolated lab VMs behind a dedicated firewall. External access (if needed) is handled by Pangolin, and lab egress can be forced through Mullvad VPN.

## Network Flow

Operator -> Pangolin (optional) -> Firewall (10.20.0.1) -> Lab VMs (10.20.0.0/24) -> Mullvad (optional)

## Zones

- Host network (192.168.121.0/24): libvirt network, firewall eth0
- Lab network (10.20.0.0/24): OpenRelik, REMnux, Neko, firewall eth1
- VPN egress (wg0): optional Mullvad tunnel on firewall

## Security Model

- Default-deny nftables on the firewall
- No direct host -> lab exposure
- Packet capture and Suricata on lab traffic
- Pangolin is the only internet-facing entry point (if enabled)
