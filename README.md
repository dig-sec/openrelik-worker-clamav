# openrelik-worker-clamav

OpenRelik worker for scanning files and directories with ClamAV.

---

## Features

- Scan files and directories with `clamscan`
- Refresh signatures with `freshclam` (default)
- Multiple signature locations (`database_paths` + built-in defaults)
- `--allmatch` and `--detect-pua` enabled by default
- Machine-readable JSON findings (`clamav_results.json`)
- Full scanner output (`clamav_stdout.txt`)

---

## Task Configuration

| Name              | Type     | Default | Description                                                        |
|-------------------|----------|---------|--------------------------------------------------------------------|
| `recursive`       | bool     | true    | Recursively scan directories                                       |
| `update_signatures` | bool   | true    | Run `freshclam` before scan                                        |
| `database_paths`  | textarea |         | Newline/comma-separated list of additional `.cvd`/`.cld` files/dirs|
| `freshclam_mirror`| text     |         | Optional mirror override for freshclam                             |
| `allmatch`        | bool     | true    | Pass `--allmatch` to report all matching signatures                |
| `detect_pua`      | bool     | true    | Pass `--detect-pua` to include PUA hits                            |

---

## Local Development

```bash
uv sync --no-dev
uv run pytest
```

---

## Docker Usage Example

```yaml
openrelik-worker-clamav:
  image: ghcr.io/dig-sec/openrelik-worker-clamav:latest
  environment:
    - REDIS_URL=redis://openrelik-redis:6379
  command: >
    celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-clamav
```