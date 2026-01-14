# OpenRelik Exif Worker

## Purpose

Extracts EXIF metadata from image files using exiftool.

## Deployment

Included in standard OpenRelik provisioning.

Manual start (if needed):

```bash
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose up -d openrelik-worker-exif"
```

## Usage

- Input: image file
- Output: text (default) or JSON if enabled in the UI

## Troubleshooting

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-exif"
```
