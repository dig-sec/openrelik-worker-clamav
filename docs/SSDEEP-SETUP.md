# OpenRelik SSDeep Worker

## Purpose

Generates SSDeep fuzzy hashes for files to find near-duplicates.

## Deployment

Included in standard OpenRelik provisioning.

Manual start (if needed):

```bash
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose up -d openrelik-worker-ssdeep"
```

## Usage

- Input: any file (>= ~4KB recommended)
- Output: `<filename>.ssdeep`

To compare two hashes:

```bash
ssdeep -s <hash1> <hash2>
```

## Troubleshooting

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-ssdeep"
```
