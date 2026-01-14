# Neko Tor Browser Setup

## Provision

```bash
./scripts/provision.sh
# or
vagrant up neko
```

## Access

- Direct: http://localhost:8080
- Guacamole (optional): http://localhost:18080/guacamole/

Default creds: `neko` / `admin`

## Configuration (Optional)

```bash
export NEKO_PASSWORD="your-password"
export NEKO_ADMIN_PASSWORD="your-admin-password"
```

Ports and VM resources are set in `Vagrantfile` and `provision/neko.yml`.

## Troubleshooting

```bash
vagrant ssh neko
sudo systemctl status neko
sudo journalctl -u neko -f
```
