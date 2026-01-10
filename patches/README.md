# JSONDecodeError Fix for openrelik-worker-common

## Problem
`openrelik-worker-capa` (and other workers) crash with `JSONDecodeError('Expecting value: line 1 column 1 (char 0)')` when `get_input_files()` receives an empty or invalid `pipe_result` from upstream tasks.

**File:** `openrelik_worker_common/task_utils.py`  
**Function:** `get_input_files()`

## Solution
Guard against empty/invalid `pipe_result` and wrap decode+parse in try/except with logging.

## How to Apply (Permanent Fix on Redeploy)

### Option 1: Apply Patch to openrelik-worker-common (Recommended)
Apply the patch to your local `openrelik-worker-common` clone before building workers:

```bash
cd /path/to/openrelik-worker-common
git apply patches/openrelik-worker-common-task-utils-json-fix.patch
```

Then rebuild worker images:
```bash
docker build -t ghcr.io/openrelik/openrelik-worker-capa:latest .
```

### Option 2: Auto-Apply at Container Startup
Add to Docker Compose or worker Dockerfile to run the fix script at startup:

**In docker-compose.yml:**
```yaml
openrelik-worker-capa:
  image: ghcr.io/openrelik/openrelik-worker-capa:latest
  environment:
    - REDIS_URL=redis://openrelik-redis:6379
  volumes:
    - ./patches:/patches:ro
  entrypoint: >
    sh -c "python3 /patches/apply-task-utils-fix.py && 
    exec celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-capa"
```

**In Dockerfile:**
```dockerfile
COPY patches/apply-task-utils-fix.py /usr/local/bin/
RUN chmod +x /usr/local/bin/apply-task-utils-fix.py
ENTRYPOINT ["/bin/sh", "-c", "python3 /usr/local/bin/apply-task-utils-fix.py && exec celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-capa"]
```

### Option 3: Permanent Local Override (Development)
Copy the fix script into running containers:

```bash
for container in openrelik-worker-capa openrelik-worker-yara openrelik-worker-entropy; do
  docker cp patches/apply-task-utils-fix.py $container:/tmp/
  docker exec $container python3 /tmp/apply-task-utils-fix.py
  docker restart $container
done
```

## Verification

### Check if patch is applied:
```bash
docker exec openrelik-worker-capa grep "import logging" \
  /openrelik/.venv/lib/python3.12/site-packages/openrelik_worker_common/task_utils.py
```

Should output:
```
import logging
```

### Check for error handling:
```bash
docker exec openrelik-worker-capa grep -A 2 "except (json.JSONDecodeError" \
  /openrelik/.venv/lib/python3.12/site-packages/openrelik_worker_common/task_utils.py
```

Should show the try/except block.

## What the Fix Does

1. **Empty string guard:** Only process non-empty `pipe_result` values
2. **Logging import:** Adds logging to track issues
3. **Try/except:** Catches `json.JSONDecodeError`, `ValueError`, `UnicodeDecodeError`
4. **Error logging:** Logs failed parses with the problematic `pipe_result` (first 100 chars)
5. **Graceful continuation:** Skips bad results; proceeds with available `input_files`

## Files

- `openrelik-worker-common-task-utils-json-fix.patch` — Ready-to-apply patch for worker-common
- `apply-task-utils-fix.py` — Idempotent Python script that auto-applies at container startup

## Testing

After applying the fix, trigger a workflow where an upstream task returns an empty/invalid result. The worker should:
- Log a warning or error
- Continue processing with available input files
- **NOT** crash with `JSONDecodeError`

## Upstream PR
This fix has been submitted upstream to `openrelik/openrelik-worker-common` as:
- **Title:** task_utils: guard empty pipe_result and add JSON decode error handling
- **Status:** [Pending review]

Once merged, rebuild worker images with the updated common library.
