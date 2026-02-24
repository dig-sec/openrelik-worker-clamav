# openrelik-worker-clamav

openrelik-worker-clamav is an OpenRelik worker that scans input files/directories with ClamAV (`clamscan`) and returns normalized findings for workflow processing.

## Features

- Scans each upstream input file path with `clamscan`.
- Refreshes signatures with `freshclam` before scanning (enabled by default).
- Uses multiple signature locations (`database_paths` plus built-in defaults like `/var/lib/clamav`).
- Uses `--allmatch` and `--detect-pua` by default for broader detection coverage.
- Emits machine-readable JSON findings (`clamav_results.json`).
- Emits full scanner output (`clamav_stdout.txt`).

## Task configuration

- `recursive` (bool, default `true`): recursively scan directories.
- `update_signatures` (bool, default `true`): run `freshclam` before scan.
- `database_paths` (textarea): newline/comma-separated list of additional `.cvd/.cld` files or directories.
- `freshclam_mirror` (text): optional mirror override for freshclam.
- `allmatch` (bool, default `true`): pass `--allmatch` to report all matching signatures.
- `detect_pua` (bool, default `true`): pass `--detect-pua` to include PUA hits.

## Local development

```bash
uv sync --no-dev
uv run pytest
```

## Docker usage example

```yaml
openrelik-worker-clamav:
  image: ghcr.io/dig-sec/openrelik-worker-clamav:latest
  environment:
    - REDIS_URL=redis://openrelik-redis:6379
  command: "celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-clamav"
```

## Development dependencies

To install code style and linting tools (flake8, isort, black):

```bash
uv pip install -r pyproject.toml --dev
# or, if not using uv:
pip install flake8 isort black
```

To check code style:

```bash
flake8 src tests
isort --check src tests
black --check src tests
```
