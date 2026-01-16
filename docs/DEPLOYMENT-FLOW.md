# Deployment Flow Documentation

## Environment Variable Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ User Command                                                    │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────────┐
        │ WG_ENDPOINT=se-mma-wg-001 vagrant up     │
        │         (or use default)                 │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │ Vagrantfile processes environment var    │
        │ ENV['WG_ENDPOINT'] || 'se-mma-wg-002'   │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │ Sets wg_endpoint Ansible variable        │
        │ passes to provisioner extra_vars         │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │ Ansible firewall.yml playbook            │
        │ receives wg_endpoint                     │
        └──────────────┬───────────────────────────┘
                       │
    ┌──────────────────┴──────────────────┐
    │                                     │
    ▼                                     ▼
┌─────────────────┐           ┌──────────────────┐
│ base role       │           │ firewall role    │
├─────────────────┤           ├──────────────────┤
│ - Docker        │           │ - DNS (dnsmasq)  │
│ - Networking    │           │ - Firewall       │
│ - Health checks │           │ - Monitoring     │
└─────────────────┘           │ - WireGuard ◄────┼──── wg_endpoint
                              └──────────────────┘
                                      │
                                      ▼
                        ┌──────────────────────────┐
                        │ wireguard.yml task       │
                        │                          │
                        │ if wg_endpoint:           │
                        │   copy from firewall/files│
                        │   {{ wg_endpoint }}.conf  │
                        └──────────────┬───────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
        ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
        │ se-mma-wg-001    │  │ se-mma-wg-002    │  │ se-mma-wg-003    │
        │ .conf            │  │ .conf (default)  │  │ .conf            │
        ├──────────────────┤  ├──────────────────┤  ├──────────────────┤
        │ IP: 193.138.     │  │ IP: 193.138.     │  │ IP: 193.138.     │
        │ 218.220          │  │ 218.80           │  │ 218.83           │
        └──────────┬───────┘  └────────┬─────────┘  └──────────┬───────┘
                   │                   │                       │
                   └───────────────────┼───────────────────────┘
                                      │
                                      ▼
                        ┌──────────────────────────┐
                        │ /etc/wireguard/wg0.conf  │
                        │                          │
                        │ [Interface]              │
                        │ Address = 10.66.31.54    │
                        │ PrivateKey = ...         │
                        │ DNS = 10.64.0.1          │
                        │                          │
                        │ [Peer]                   │
                        │ PublicKey = ...          │
                        │ Endpoint = 193.138.X.X   │
                        └──────────┬───────────────┘
                                   │
                                   ▼
                        ┌──────────────────────────┐
                        │ wg-quick up wg0          │
                        │                          │
                        │ Interface comes online   │
                        │ Routes configured        │
                        │ Service enabled          │
                        └──────────┬───────────────┘
                                   │
                                   ▼
                        ┌──────────────────────────┐
                        │ Firewall VM running      │
                        │ WireGuard connected to   │
                        │ selected Mullvad exit    │
                        └──────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │ Lab VM deploy                │
                    │ (remnux)                     │
                    │                              │
                    │ Default gateway: 10.20.0.2   │
                    │ (firewall VM)                │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │ All lab VM traffic routed    │
                    │ through firewall             │
                    │ through WireGuard tunnel     │
                    │ to Mullvad exit IP          │
                    └──────────────────────────────┘
```

## Traffic Flow

```
┌──────────────────────────────────────────────────────────────────┐
│ Lab VM (REMnux)                                                 │
│ IP: 10.20.0.20 (remnux)                                         │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       │ Default route: 10.20.0.2
                       │ All traffic to internet → firewall
                       │
                       ▼
        ┌──────────────────────────────────────────┐
        │ Firewall VM                              │
        │ IP: 10.20.0.2 (lab side)                 │
        ├──────────────────────────────────────────┤
        │ WireGuard Interface (wg0)                │
        │ IP: 10.66.31.54                          │
        │ Connected to: Mullvad endpoint           │
        │ (193.138.218.220/80/83)                  │
        │                                          │
        │ nftables rules:                          │
        │ - Forward 10.20.0.0/24 → wg0            │
        │ - SNAT to 10.66.31.54 (WG IP)           │
        │ - Allow traffic to Mullvad endpoint      │
        └──────────────────┬───────────────────────┘
                           │
                           │ All traffic encrypted
                           │ through WireGuard tunnel
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │ Mullvad VPN Exit Point                   │
        │                                          │
        │ Sweden #1: 193.138.218.220  (se-mma-001)│
        │ Sweden #2: 193.138.218.80   (se-mma-002)│
        │ Sweden #3: 193.138.218.83   (se-mma-003)│
        │                                          │
        │ Outbound IP: Mullvad Sweden IP           │
        │ DNS: 10.64.0.1 (Mullvad resolver)        │
        └──────────────────┬───────────────────────┘
                           │
                           │ Encrypted tunnel
                           │ Your IP hidden behind Mullvad
                           │ No DNS leaks (Mullvad DNS only)
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │ Internet                                 │
        │                                          │
        │ See: Mullvad Sweden IP (anonymized)      │
        │ Can't see: Your lab IP                   │
        │                                          │
        │ Example: curl https://am.i.mullvad.net   │
        │ Returns: Sweden exit IP, Mullvad network │
        └──────────────────────────────────────────┘
```

## Deployment Timeline

### Default Deployment
```
1. User: vagrant up
   ↓
2. Vagrant reads WG_ENDPOINT env var
   → Uses default: se-mma-wg-002
   ↓
3. Vagrant creates firewall VM
   ↓
4. Vagrant runs provisioning:
   - Ansible playbooks/firewall.yml
   - wg_endpoint = "se-mma-wg-002"
   ↓
5. Ansible runs roles:
   - common (docker, network, health)
   - firewall (dns, nftables, monitoring, wireguard)
   ↓
6. WireGuard task executes:
   - Install WireGuard
   - Copy ansible/roles/firewall/files/private/se-mma-wg-002.conf
   - Enable wg0 interface
   - Verify connectivity
   ↓
7. Lab VM deploy (remnux)
   ↓
8. All lab traffic routes through firewall → Mullvad
```

### Custom Endpoint Deployment
```
1. User: WG_ENDPOINT=se-mma-wg-001 vagrant up firewall
   ↓
2. Vagrant reads WG_ENDPOINT env var
   → Uses: se-mma-wg-001
   ↓
3. Same as above, but step 6 uses:
   - Copy ansible/roles/firewall/files/private/se-mma-wg-001.conf
   - Connects to 193.138.218.220 instead
```

## Architecture Decision Tree

```
                        ┌─ Start Deployment ─┐
                        │                      │
                        ▼                      ▼
            ┌────────────────────┐   ┌──────────────────┐
            │ WG_ENDPOINT set?   │   │ config.yml set?  │
            └────────┬───────────┘   └────────┬─────────┘
                     │                        │
            ┌────────▼─────────┐      ┌───────▼────────┐
            │ Use env var      │      │ Use config.yml │
            │ value            │      │ value          │
            └────────┬─────────┘      └───────┬────────┘
                     │                        │
                     └────────┬───────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │ wg_endpoint =   │
                    │ se-mma-wg-001/002/003│
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │ Ansible wireguard.yml│
                    │ reads variable       │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼──────────────┐
                    │ Copy roles/firewall/files/ │
                    │ private/                   │
                    │ {{ wg_endpoint }}.conf     │
                    │ to /etc/wireguard          │
                    └──────────┬─────────────┘
                               │
                    ┌──────────▼─────────────┐
                    │ wg-quick up wg0       │
                    │                       │
                    │ Interface active      │
                    │ Tunnel established    │
                    │ Routes configured     │
                    └───────────────────────┘
```

## State Transitions

```
                           ┌─────────┐
                      ┌────►│ OFFLINE │◄────┐
                      │     └─────────┘     │
                      │                     │
                      │ wg-quick down      │
                      │ vagrant destroy    │
                      │                    │
        ┌─────────────┴────┐      ┌────────┴──────────┐
        │                  │      │                   │
        ▼                  ▼      ▼                   ▼
    ┌────────┐        ┌──────────────────┐      ┌─────────┐
    │DEPLOYING│──────►│ WIREGUARD INIT  │─────►│ ONLINE  │
    │ VMs    │        │ (Installing,    │      │ & ACTIVE│
    └────────┘        │ Configuring)    │      └─────────┘
                      └──────────────────┘           ▲
                              │                      │
                              │ Error               │
                              │ (Missing config)    │
                              │                     │
                              └─────────┬───────────┘
                                   FALLBACK
                              (Firewall only,
                               no VPN tunnel)
```

## File Dependencies

```
Vagrantfile
    │
    ├──► ENV['WG_ENDPOINT']
    │
    └──► ansible/playbooks/firewall.yml
         │
         └──► ansible/roles/firewall/tasks/wireguard.yml
              │
              ├──► ansible/roles/firewall/files/private/se-mma-wg-001.conf
              │
              ├──► ansible/roles/firewall/files/private/se-mma-wg-002.conf
              │
              └──► ansible/roles/firewall/files/private/se-mma-wg-003.conf
```

## Endpoint Selection Matrix

```
Command                           Endpoint Used    Exit IP
─────────────────────────────────────────────────────────────
vagrant up firewall               se-mma-wg-002    193.138.218.80
WG_ENDPOINT=se-mma-wg-001         se-mma-wg-001    193.138.218.220
  vagrant up firewall
WG_ENDPOINT=se-mma-wg-002         se-mma-wg-002    193.138.218.80
  vagrant up firewall
WG_ENDPOINT=se-mma-wg-003         se-mma-wg-003    193.138.218.83
  vagrant up firewall
```

## Summary

This diagram shows how the Mullvad VPN exit configuration flows through the deployment process:

1. **Environment Variable** - User specifies endpoint at command time
2. **Vagrantfile** - Reads env var, sets Ansible variable
3. **Ansible Playbook** - Receives endpoint value (`wg_endpoint`)
4. **WireGuard Task** - Copies correct config file
5. **System** - WireGuard interface comes up with selected endpoint
6. **Traffic** - All lab VM traffic routed through selected Mullvad exit

The default behavior (se-mma-wg-002) ensures smooth deployment without user input, while the env var allows easy switching for failover, load testing, or geographical preferences.
