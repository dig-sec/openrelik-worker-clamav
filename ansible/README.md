# Ansible Provisioning

Simplified, maintainable Ansible structure for Utgard lab.

## Structure

```
ansible/
├── ansible.cfg           # Ansible configuration
├── inventory.yml         # Host definitions
├── playbooks/            # VM deployment playbooks
│   ├── firewall.yml      # Firewall/gateway VM
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
    ├── guacamole/        # Remote access portal (web RDP/SSH)
    │   ├── tasks/main.yml
    │   ├── defaults/main.yml
    │   └── templates/
    ├── openrelik/        # OpenRelik forensics specific
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   └── install.yml
    │   ├── defaults/main.yml
    │   └── templates/
    └── remnux/           # REMnux malware analysis specific
        ├── tasks/
        │   ├── main.yml
        │   ├── tools.yml
        │   └── rdp.yml
        └── defaults/main.yml
```

## Playbook Architecture

Each VM playbook includes **two roles**:

```yaml
roles:
  - common      # Installs docker, sets up networking, base packages
  - <specific>  # Role-specific tools (firewall, openrelik, remnux)
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
ansible-playbook -i inventory.yml playbooks/firewall.yml -l firewall

# REMnux VM
ansible-playbook -i inventory.yml playbooks/remnux.yml -l remnux

# Specific role only
ansible-playbook -i inventory.yml playbooks/firewall.yml -l firewall --tags firewall,dns

# Local Host (no VM) - OpenRelik + Guacamole
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
- `openrelik_ui_port`: UI port mapping (default: 8711)
- `openrelik_api_port`: API port mapping (default: 8710)
- `openrelik_workers_enabled`: Enable worker containers (default: true)
- `openrelik_extra_workers`: Desired worker services list; the overlay compose only adds workers missing from the base OpenRelik compose (includes yara, hayabusa, capa, strings, entropy, eztools, exif, regripper, ssdeep, eml, clamav, grep, plaso, extraction, analyzer-config, elasticsearch).  New workers are maintained upstream by dig-sec:
  * https://github.com/dig-sec/openrelik-worker-clamav.git
  * https://github.com/dig-sec/openrelik-worker-elasticsearch.git
- `openrelik_registry_url`: Container registry for worker images (default: `ghcr.io`)
- `openrelik_worker_registry`: Worker image namespace/repo prefix (default: `ghcr.io/openrelik`)
- `openrelik_worker_tag`: Worker image tag (default: `latest`)
- `openrelik_local_build_workers`: Optional list of worker services to build locally from `roles/openrelik/files/<service>` instead of pulling from registry (default: `[]`)
- `openrelik_registry_username`: Registry username for private images (optional)
- `openrelik_registry_password`: Registry password/token (optional)
- `openrelik_skip_missing_workers`: Skip workers whose images cannot be pulled (default: false)

#### Publish ClamAV + Elasticsearch worker images to GHCR
- Workflow: `.github/workflows/openrelik-workers-ghcr.yml`
- Trigger:
  - Push to `main` when files under `roles/openrelik/files/openrelik-worker-clamav/` or `roles/openrelik/files/openrelik-worker-elasticsearch/` change.
  - Manual `workflow_dispatch` with optional `image_namespace` and `image_tag`.
- Default publish target/tag:
  - `ghcr.io/dig-sec/openrelik-worker-clamav:latest`
  - `ghcr.io/openrelik/openrelik-worker-elasticsearch:latest`

For deployment-by-pull, keep:
- `openrelik_worker_registry: ghcr.io/openrelik`
- `openrelik_worker_tag: latest`

For local build fallback, set:
```yaml
openrelik_local_build_workers:
  - openrelik-worker-clamav
  - openrelik-worker-elasticsearch
```

### Guacamole
- `guacamole_port`: HTTP port on host when TLS is disabled (default: 8081)
- `guacamole_tls_enabled`: Enable HTTPS reverse proxy (default: false)
- `guacamole_tls_port`: HTTPS port for Guacamole (default: 443)
- `guacamole_tls_cert_path`: TLS cert file path on host (default: `/opt/guacamole/tls/fullchain.pem`)
- `guacamole_tls_key_path`: TLS key file path on host (default: `/opt/guacamole/tls/privkey.pem`)
- `guacamole_tls_server_name`: Optional TLS server_name (default: empty)
- `guacamole_tls_self_signed`: Create a self-signed cert if missing (default: false)
- `guacamole_db_user`: PostgreSQL user (default: `guacamole`)
- `guacamole_db_password`: PostgreSQL password (auto-generated if empty)
- `guacamole_state_dir`: Data/config path (default: `/opt/guacamole`)

### Firewall - WireGuard/Mullvad Integration
- `enable_wireguard`: Enable/disable VPN setup (default: `true`)
- `wg_endpoint`: Mullvad exit point selection (default: `se-mma-wg-002`)
  - Available: `se-mma-wg-001`, `se-mma-wg-002`, `se-mma-wg-003`
  - Set at deployment: `WG_ENDPOINT=se-mma-wg-001 vagrant up firewall`
- `remnux_ip`: REMnux VM IP for DNS host records (optional)
- `dnsmasq_domain`: DNS suffix for lab hosts (default: `utgard.local`)
- `dnsmasq_upstream_servers`: Upstream resolvers list (default: Mullvad + public)
- WireGuard configs live in `ansible/roles/firewall/files/private/` (copy from `.conf.example` and keep secrets out of git)

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
