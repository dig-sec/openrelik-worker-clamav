# Pangolin External Access Checklist

Use this as a quick validation pass after setup. For full steps, see docs/PANGOLIN-ACCESS.md.

- DNS points to Pangolin host
- Pangolin UI reachable at `https://your-domain.com`
- TLS cert issued
- Routes added for OpenRelik and Neko
- Routes resolve from a browser
- Pangolin host can reach 10.20.0.0/24

Quick checks:

```bash
cd pangolin
sudo docker compose ps
sudo docker compose logs -f --tail=200
```
