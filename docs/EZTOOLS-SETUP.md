# OpenRelik EZTools Worker

## Purpose

Runs Eric Zimmerman's tools (LECmd, RBCmd, AppCompatCacheParser) on Windows artifacts.

## Deployment

Included in standard OpenRelik provisioning.

Manual start (if needed):

```bash
vagrant ssh openrelik -c "cd /opt/openrelik/openrelik && docker compose up -d openrelik-worker-eztools"
```

## Usage

- Select the EZTools worker in OpenRelik
- Choose tool and arguments
- Output is captured as text/csv/json depending on options

## Troubleshooting

```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-eztools"
```
