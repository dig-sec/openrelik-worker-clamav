# OpenRelik ClamAV Worker

## Purpose

Scans Velociraptor collection archives and writes JSON reports.

## Use

- Task: `scan_velociraptor_collection`
- Input: zip/tar.* collection
- Output: `*_clamav.json`, `*_clamav_infected.json`

## Logs

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-clamav"
```
