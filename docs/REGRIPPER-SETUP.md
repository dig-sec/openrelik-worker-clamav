# OpenRelik RegRipper Worker

## Purpose

Analyzes Windows registry hives and produces text reports.

## Deployment

Included in standard OpenRelik provisioning.

Manual start (if needed):

```bash
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose up -d openrelik-worker-regripper"
```

## Usage

- Input: registry hives (SYSTEM, SAM, SOFTWARE, SECURITY, NTUSER.DAT)
- Output: `<hive>_regripper.txt`

## Verification

```bash
vagrant ssh openrelik -c "docker ps | grep regripper"
```
