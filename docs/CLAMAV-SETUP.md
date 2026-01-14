# OpenRelik ClamAV Worker

## Purpose

Scans Velociraptor collection archives (zip/tar.*) with ClamAV and writes JSON reports.

## Deployment

Included in standard OpenRelik provisioning. No extra steps required.

Manual start (if needed):

```bash
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose up -d openrelik-worker-clamav"
```

## Usage

- Task: `scan_velociraptor_collection`
- Input: Velociraptor collection archive
- Output:
  - `*_clamav.json` (full report)
  - `*_clamav_infected.json` (detections only)

## Notes

- Use the infected-only report for quick triage.
- Rebuild the worker image to refresh signatures.
