# Neko Tor Browser Setup

## Provision

```bash
./scripts/provision.sh
# or
vagrant up neko
```

## Access

- Direct (from host): http://10.20.0.40:8080
- Pangolin tunnel: Configure route in Pangolin dashboard

Defaults: `neko/admin`

## Optional Config

```bash
export NEKO_PASSWORD="your-password"
export NEKO_ADMIN_PASSWORD="your-admin-password"
```

Ports and VM resources are in `Vagrantfile` and `provision/neko.yml`.

## Logs

```bash
vagrant ssh neko
sudo systemctl status neko
sudo journalctl -u neko -f
```
