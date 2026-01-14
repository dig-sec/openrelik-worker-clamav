# OpenRelik SSDeep Worker

## Purpose

Generates SSDeep fuzzy hashes to find near-duplicate files.

## Use

- Input: any file (>= ~4KB recommended)
- Output: `<filename>.ssdeep`

Compare:

```bash
ssdeep -s <hash1> <hash2>
```

## Logs

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-ssdeep"
```
