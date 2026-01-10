# OpenRelik EZTools Worker Integration

## Overview
The `openrelik-worker-eztools` is a Celery-based task processor that executes command-line forensic tools from Eric Zimmerman's EZTools suite.

**Supported Tools:**
- **LECmd**: LNK shortcut file parser
- **RBCmd**: Windows Recycle Bin parser ($I and $R files)
- **AppCompatCacheParser**: AppCompatCache (ShimCache) parser from SYSTEM registry hives

## Prerequisites
- Docker and Docker Compose running on the OpenRelik VM
- The `openrelik-worker-common` JSONDecodeError patch applied (see `../patches/README.md`)

## Installation

### Option 1: Add to Ansible Playbook (Recommended for Redeploy)
Add the eztools worker configuration to `provision/openrelik.yml` in the Python YAML section where other workers are defined.

### Option 2: Manual docker-compose Update
```bash
cd /opt/openrelik/openrelik
# Edit docker-compose.yml and add:
```

**Docker Compose Configuration:**
```yaml
openrelik-worker-eztools:
  container_name: openrelik-worker-eztools
  image: ghcr.io/openrelik/openrelik-worker-eztools:latest
  restart: always
  environment:
    - REDIS_URL=redis://openrelik-redis:6379
    - OPENRELIK_PYDEBUG=0
  volumes:
    - ./data:/usr/share/openrelik/data
    - ../patches:/patches:ro
  entrypoint: >
    sh -c "python3 /patches/apply-task-utils-fix.py && 
    exec celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-eztools"
  depends_on:
    - openrelik-redis
```

### Option 3: Vagrant SSH + Docker CLI
```bash
# SSH into OpenRelik VM
vagrant ssh openrelik

# Add worker using docker-compose
cd /opt/openrelik/openrelik
docker compose up -d openrelik-worker-eztools
```

## Usage

### Via OpenRelik UI
1. Navigate to **Workflow** → **New Task**
2. Select **EZTools** worker
3. Choose a tool (LECmd, RBCmd, or AppCompatCacheParser)
4. Upload or select input file
5. (Optional) Configure tool-specific arguments and output format
6. Execute

### Configuration Options
- **Tool Selection**: Choose which EZTool to run
- **Tool Arguments**: Additional CLI flags (tool-specific)
- **Output Extension**: File extension for captured STDOUT (txt, csv, json)
- **Output Data Type**: Metadata tag for OpenRelik (e.g., `lnk_file_analysis`, `recycle_bin_parsed`)

### Examples

**LECmd on LNK file:**
```
Tool: LECmd
Input: shortcut.lnk
Output Extension: txt
Data Type: lnk_file_analysis
```

**RBCmd on Recycle Bin file:**
```
Tool: RBCmd
Input: $I123456
Output Extension: csv
Data Type: recycle_bin_parsed
```

## Verification

### Check if worker is running:
```bash
vagrant ssh openrelik -c "docker ps | grep eztools"
```

### View worker logs:
```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-eztools"
```

### Test a simple task:
1. Go to OpenRelik UI (http://localhost:8711)
2. Create a new workflow
3. Add a file to analyze
4. Select EZTools worker and configure
5. Run and check output files

## Troubleshooting

### Worker not starting
```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-eztools"
```

### JSONDecodeError in logs
Ensure the patch is applied:
```bash
vagrant ssh openrelik -c "docker exec openrelik-worker-eztools python3 /patches/apply-task-utils-fix.py"
```

### No output files generated
- Verify input file is valid for the selected tool
- Check tool-specific arguments are correct
- Review worker logs for errors

## Integration with Patch System
The configuration above includes the JSONDecodeError fix via the patches entrypoint. This ensures the fix survives container restarts and redeploys.

If you manually add the worker without patches, apply the fix manually:
```bash
docker cp patches/apply-task-utils-fix.py openrelik-worker-eztools:/tmp/
docker exec openrelik-worker-eztools python3 /tmp/apply-task-utils-fix.py
```

## Known Limitations
- Output format detection is still in development (TODO)
- Tool-specific argument validation is minimal; ensure arguments are STDOUT-compatible
- Windows-only tools may have different behavior on Linux containers
