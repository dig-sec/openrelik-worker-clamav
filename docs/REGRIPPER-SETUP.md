# OpenRelik RegRipper Worker

## Purpose

Analyzes Windows registry hives and produces text reports.

## Use

- Input: SYSTEM, SAM, SOFTWARE, SECURITY, NTUSER.DAT
- Output: `<hive>_regripper.txt`

## Logs

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-regripper"
```
