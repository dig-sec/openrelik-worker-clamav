# Pangolin Checklist

- DNS points to Pangolin host
- Pangolin UI reachable at `https://your-domain.com`
- TLS cert issued
- Routes added for OpenRelik and Neko
- Browser access works
- Pangolin host can reach 10.20.0.0/24

Quick checks:

```bash
cd pangolin
sudo docker compose ps
sudo docker compose logs -f --tail=200
```
