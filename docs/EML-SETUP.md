# OpenRelik EML Worker

## Purpose

Parses `.eml` and `.msg` email files and extracts headers, body content, and attachments.

## Deployment

Included in standard OpenRelik provisioning.

Manual start (if needed):

```bash
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose up -d openrelik-worker-eml"
```

## Usage

- Input: `.eml` or `.msg`
- Output: structured text with metadata, body, and attachment list
- Common next steps: run Yara or Strings on extracted attachments

## Troubleshooting

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-eml"
```
