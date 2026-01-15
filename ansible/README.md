# Ansible Provisioning

Simplified, maintainable Ansible structure for Utgard lab.

## Structure

```
ansible/
├── ansible.cfg           # Ansible configuration
├── inventory.yml         # Host definitions
├── playbooks/            # VM deployment playbooks
│   ├── firewall.yml      # Firewall/gateway VM
│   ├── openrelik.yml     # OpenRelik forensics VM
│   └── remnux.yml        # REMnux analysis VM
└── roles/
    ├── common/           # ⭐ SHARED: Used by all VMs
    │   ├── tasks/
    │   │   ├── main.yml         # Base setup
    │   │   ├── docker.yml       # Docker installation
    │   │   ├── network.yml      # Network config
    │   │   └── health.yml       # Health checks
    │   ├── defaults/main.yml    # Default variables
    │   └── templates/
    ├── firewall/         # Firewall/gateway specific
    │   ├── tasks/
    │   │   ├── main.yml         # DNS, firewall, VPN
    │   │   ├── dns.yml
    │   │   ├── nftables.yml
    │   │   ├── wireguard.yml
    │   │   └── monitoring.yml
    │   ├── handlers/main.yml
    │   └── templates/
    ├── openrelik/        # OpenRelik forensics specific
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── install.yml
    │   │   ├── workers.yml
    │   │   └── migrations.yml
    │   ├── defaults/main.yml
    │   └── templates/
    └── remnux/           # REMnux malware analysis specific
        ├── tasks/
        │   ├── main.yml
        │   ├── tools.yml
        │   └── rdp.yml
        └── defaults/main.yml
```

## Key Improvements

✅ **No Duplication** - Common tasks in single `common/` role
✅ **Clear Roles** - Each role has obvious purpose
✅ **Maintainable** - Changes in one place
✅ **Scalable** - Add new VMs by creating new roles
✅ **DRY Principle** - Don't Repeat Yourself

## Playbook Architecture

Each VM playbook includes **two roles**:

```yaml
roles:
  - common      # Installs docker, sets up networking, base packages
  - <specific>  # VM-specific tools (firewall, openrelik, remnux)
```

## Usage

### Automatic (via Vagrant)
```bash
cd /home/azureuser/git/utgard
vagrant up    # Automatically runs provisioning with correct playbooks
```

### Manual
```bash
cd ansible

# Firewall VM
ansible-playbook -i inventory.yml playbooks/firewall.yml

# OpenRelik VM
ansible-playbook -i inventory.yml playbooks/openrelik.yml

# REMnux VM
ansible-playbook -i inventory.yml playbooks/remnux.yml

# Specific role only
ansible-playbook -i inventory.yml playbooks/firewall.yml --tags firewall,dns

# Local Host (no VM) - Headscale + OpenRelik
# Requires Ansible installed on this host:
#   sudo apt update && sudo apt install -y ansible-core
ansible-playbook -i inventory.yml playbooks/host.yml -l localhost
```

## Variables

### Common (passed to all VMs)
- `lab_network`: Lab network CIDR (default: 10.20.0.0/24)
- `lab_gateway`: Gateway IP (default: 10.20.0.2)
- `lab_ip`: VM's lab network IP
- `common_configure_network`: Manage lab DNS/resolv.conf (default: true)

### OpenRelik
- `openrelik_client_id`: Google OAuth client ID
- `openrelik_client_secret`: Google OAuth secret
- `openrelik_run_migrations`: Run DB migrations (default: true)
- `openrelik_ui_port`: UI port mapping (default: 8711)
- `openrelik_api_port`: API port mapping (default: 8710)
- `openrelik_workers_enabled`: Enable worker containers (default: true)

### Firewall - WireGuard/Mullvad Integration
- `enable_wireguard`: Enable/disable VPN setup (default: `true`)
- `wg_endpoint`: Mullvad exit point selection (default: `se-mma-wg-002`)
  - Available: `se-mma-wg-001`, `se-mma-wg-002`, `se-mma-wg-003`
  - Set at deployment: `WG_ENDPOINT=se-mma-wg-001 vagrant up firewall`
- `openrelik_ip`: OpenRelik VM IP for DNS host records (optional)
- `remnux_ip`: REMnux VM IP for DNS host records (optional)
- `dnsmasq_domain`: DNS suffix for lab hosts (default: `utgard.local`)
- `dnsmasq_upstream_servers`: Upstream resolvers list (default: Mullvad + public)
- WireGuard configs live in the role files: `ansible/roles/firewall/files/se-mma-wg-*.conf`

See [WIREGUARD-MULLVAD-GUIDE.md](../WIREGUARD-MULLVAD-GUIDE.md) for complete documentation.

## Adding a New VM

1. Create new role directory:
   ```bash
   mkdir -p ansible/roles/mynewvm/{tasks,templates,defaults}
   ```

2. Create `tasks/main.yml`:
   ```yaml
   ---
   - include_tasks: mytask.yml
   ```

3. Create playbook `playbooks/mynewvm.yml`:
   ```yaml
   ---
   - name: Deploy MyNewVM
     hosts: all
     become: yes
     roles:
       - common      # Always include common!
       - mynewvm
   ```

4. Add Vagrant definition in `Vagrantfile`

5. Run provisioning:
   ```bash
   vagrant up mynewvm
   ```

## Troubleshooting

### View logs
```bash
# Ansible logs (in VM)
cat /tmp/ansible.log

# Specific playbook run
ansible-playbook -i inventory.yml playbooks/firewall.yml -vvv
```

### Rerun specific role
```bash
ansible-playbook -i inventory.yml playbooks/firewall.yml \
  --tags firewall,dns -vvv
```

### SSH into VM and test role
```bash
vagrant ssh firewall
cd /tmp/ansible
ansible-playbook -i inventory.yml playbooks/firewall.yml
```
