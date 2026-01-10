# OpenRelik ClamAV Worker Setup

## Overview

The **OpenRelik ClamAV Worker** is a Celery-based task processor that runs **ClamAV** antivirus scanning over evidence supplied to OpenRelik. It safely unpacks Velociraptor collection archives (zip/tar.*), scans all contained files, and writes JSON reports back into the workflow. When detections are present, a second JSON file lists only the infected items for quick triage.

## Key Functionality

- Accepts Velociraptor collection exports (zip/tar.* archives)
- Safely extracts archives with path traversal protection
- Recursively scans all contained files with ClamAV
- Generates full JSON scan reports with all results
- Creates infected-only reports for quick triage
- Provides real-time progress updates during scanning
- Optional: Include clean files in detailed reports
- Automatic ClamAV signature updates during container build

## What is ClamAV?

ClamAV is an open-source antivirus engine designed for detecting trojans, viruses, malware and other malicious threats. Key characteristics:

- **GPL License**: Free, open-source antivirus
- **Multi-Platform**: Runs on Linux, macOS, Windows, BSD
- **Real-time Protection**: File scanning with minimal overhead
- **Database-Driven**: Uses virus definitions database (updated regularly)
- **Daemon-Based**: Can run as background service or CLI tool
- **Active Development**: Regular signature updates via `freshclam`

## Deployment

The ClamAV worker is automatically deployed and configured as part of the OpenRelik Vagrant environment. No additional setup is required beyond the standard `vagrant up openrelik` process.

### Docker Configuration

```yaml
openrelik-worker-clamav:
    container_name: openrelik-worker-clamav
    image: ghcr.io/julianghill/openrelik-worker-clamav:latest
    restart: always
    environment:
      - REDIS_URL=redis://openrelik-redis:6379
      - OPENRELIK_PYDEBUG=0
    volumes:
      - ./data:/usr/share/openrelik/data
    command: "celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-clamav"
```

### Signature Updates

The Docker image includes ClamAV signatures built during image creation. To maintain up-to-date signature definitions:

1. **Rebuild the image regularly**:
   ```bash
   docker pull ghcr.io/julianghill/openrelik-worker-clamav:latest
   docker-compose up -d openrelik-worker-clamav
   ```

2. **Or use freshclam sidecar** (optional):
   ```bash
   docker exec openrelik-worker-clamav freshclam
   ```

## Usage

### Supported Input Formats

The ClamAV worker accepts:

- **Velociraptor Collection Exports**: `.zip` or `.tar.*` (tar.gz, tar.bz2, tar.xz)
- **Archive Extraction**: Safely unpacks with path traversal protection
- **Recursive Scanning**: Scans all files in all subdirectories

### Available Tasks

#### ClamAV Velociraptor Scan
**Task ID**: `scan_velociraptor_collection`

Scan a Velociraptor collection export for malware:

1. Point the task at a Velociraptor collection export (zip/tar.*)
2. The worker extracts the archive
3. Recursively runs clamscan on all files
4. Generates reports and emits progress updates

### Output Files

The worker generates two JSON reports:

#### Full Scan Report (`*_clamav.json`)
Contains complete scan results:
- ClamAV command executed
- Return code (0=clean, 1=infected found)
- Per-file results (scanned path, status, detections)
- ClamAV scan summary (files scanned, infected count, time)
- stderr output (if any errors occurred)

**Example structure**:
```json
{
  "command": "clamscan -r /path/to/extracted",
  "return_code": 1,
  "files_scanned": 1245,
  "infected_count": 3,
  "time_elapsed": "45.2 seconds",
  "files": [
    {
      "path": "document.exe",
      "status": "FOUND",
      "detection": "Win.Trojan.Agent"
    },
    {
      "path": "image.jpg",
      "status": "OK"
    }
  ],
  "summary": "----------- SCAN SUMMARY -----------\nInfected files: 3\nTime: 45.2 sec (0 m 45 s)",
  "stderr": null
}
```

#### Infected-Only Report (`*_clamav_infected.json`)
Contains only detected malware:
- Only files flagged as `FOUND`
- Summary of infected count
- Quick triage reference

**Example structure**:
```json
{
  "infected_count": 3,
  "files": [
    {
      "path": "document.exe",
      "detection": "Win.Trojan.Agent"
    },
    {
      "path": "script.vbs",
      "detection": "VBS.Worm.Generic"
    },
    {
      "path": "archive.zip",
      "detection": "Heuristics.Structured.Email.SuspiciousZip"
    }
  ]
}
```

### Optional Parameters

#### Include Clean Files
- **Default**: `false` (only infected files in report)
- **Option**: Check "Include clean files" to list all scanned files
- **Use Case**: Full inventory of evidence scanned

### Progress Events

During scanning, the worker emits progress events showing:
- Files processed so far
- Total files to scan
- Current file being scanned
- Percentage completion

The OpenRelik UI displays these updates in real-time while the scan runs.

## Analysis Workflows

### Incident Response Triage

1. **Collect evidence** via Velociraptor
2. **Export collection** as zip/tar
3. **Run ClamAV scan** via OpenRelik
4. **Review infected-only report** for quick triage
5. **Feed to downstream workers** for detailed analysis:
   - Yara (additional pattern matching)
   - Capa (capability analysis of detected executables)
   - Strings (extract IOCs from detected files)

### Forensic Investigation

1. **Process forensic image** with Velociraptor
2. **Export suspicious directories** as collection
3. **Scan with ClamAV** for known malware
4. **Chain to SSDeep** for variant detection
5. **Use Entropy Worker** to identify obfuscated files
6. **Analyze with Yara** for custom signatures

### Malware Analysis Lab

1. **Collect samples** from multiple sources
2. **Batch scan with ClamAV** for initial classification
3. **Separate infected/clean** using infected-only report
4. **Feed infected samples** to:
   - Capa (identify capabilities)
   - Yara (rule generation/testing)
   - Strings (IOC extraction)
5. **Use SSDeep** to find variants

### Enterprise Threat Hunt

1. **Velociraptor hunts** across endpoints
2. **Collect matching files** as collection export
3. **ClamAV scan** entire collection
4. **Grep worker** on infected files for patterns
5. **Yara worker** with custom detection rules
6. **Alert on detections** for containment

## Output Integration

Both report files are attached to the workflow:

- **Download directly** from OpenRelik UI
- **Feed to downstream tasks** without leaving workflow
- **Export for external SIEM** or analysis tools
- **Store in evidence archive** for compliance/audit

### Downstream Worker Integration

#### Feed to Yara Worker
```
ClamAV Worker (scan)
    ↓ (infected files extracted)
Extraction Worker (extract matched files)
    ↓
Yara Worker (rule-based detection)
```

#### Feed to Strings Worker
```
ClamAV Worker (identify infected)
    ↓
Strings Worker (extract IOCs from detected files)
    ↓
Grep Worker (pattern matching)
```

#### Feed to Capa Worker
```
ClamAV Worker (identify executables)
    ↓
Capa Worker (capability analysis)
```

## Performance Notes

- **Concurrency**: Worker runs with 4 concurrent tasks (configurable)
- **Scan Speed**: Depends on:
  - Number of files in collection
  - File sizes
  - System I/O performance
  - ClamAV signature database size
- **Memory Usage**: Moderate; scales with archive size
- **Temporary Storage**: Extracts to temp directory, cleaned up after scan

**Typical Performance**:
- Small collection (100 files, <1GB): 5-10 seconds
- Medium collection (500 files, <5GB): 20-45 seconds
- Large collection (5000+ files, >10GB): 2-5 minutes

To adjust concurrency:
```bash
--concurrency=2   # Reduce for resource constraints
--concurrency=8   # Increase for high throughput
```

## Troubleshooting

### No Detections Found

**Symptom**: ClamAV returns 0 infected files

**Possible Causes**:
1. Files are genuinely clean (no malware detected)
2. Signatures are outdated
3. Collection contains legitimate software

**Solutions**:
1. Update signatures: `docker pull ghcr.io/julianghill/openrelik-worker-clamav:latest`
2. Verify with Yara worker using custom signatures
3. Check ClamAV version: `docker exec openrelik-worker-clamav clamscan --version`

### Archive Extraction Fails

**Symptom**: "Failed to extract archive" error

**Possible Causes**:
1. Archive file is corrupted
2. Archive format not supported
3. Insufficient permissions/disk space

**Solutions**:
1. Test archive extraction locally: `tar -tzf collection.tar.gz | head`
2. Check disk space: `docker exec openrelik-worker-clamav df -h`
3. Verify file permissions: `ls -lh collection.tar.gz`
4. Try different format (zip vs tar.gz)

### Memory/Resource Issues

**Symptom**: Worker crashes or becomes unresponsive during large scans

**Solutions**:
1. Reduce concurrency (fewer parallel scans)
2. Split large collections into smaller batches
3. Monitor system resources: `docker stats openrelik-worker-clamav`
4. Increase Docker memory allocation

### Worker Not Running

**Symptom**: ClamAV worker doesn't appear in task list

**Solutions**:
1. Check worker status: `docker ps | grep clamav`
2. View logs: `docker logs openrelik-worker-clamav`
3. Restart worker: `docker restart openrelik-worker-clamav`
4. Verify Redis connectivity: `docker logs openrelik-redis`

## Advanced Features

### Path Traversal Protection

Archives are extracted with safety checks to prevent directory traversal attacks:
- Validates all extracted paths
- Rejects paths with `..` components
- Creates isolated temp directory per task
- Automatic cleanup after completion

### Safe Staging

- Each scan gets isolated temp directory
- No persistent storage of extracted files
- Automatic cleanup prevents disk fill
- Concurrent scans don't interfere

### Return Codes

ClamAV return codes:
- **0**: No viruses/errors found
- **1**: Virus(es) found
- **2**: Error occurred during scan

Reports include return code for automation workflows.

## Future Enhancements

### Disk Image Support (Planned)
The worker currently expects archives/directories. Future versions may support:
- Raw disk image scanning
- Virtual machine image analysis
- Automated mounting and cleanup
- QEMU/GuestFS integration

## Related Workers

- **Yara Worker**: Pattern-based malware detection
- **Capa Worker**: Analyze capabilities in infected executables
- **Strings Worker**: Extract text from detected malware
- **Entropy Worker**: Identify suspicious/obfuscated files
- **Extraction Worker**: Extract files for further analysis
- **Grep Worker**: Search for patterns in detected items
- **SSDeep Worker**: Identify malware variants via fuzzy hashing

## Resources

- **ClamAV Homepage**: https://www.clamav.net/
- **ClamAV Documentation**: https://docs.clamav.net/
- **ClamAV GitHub**: https://github.com/Cisco-Talos/clamav
- **OpenRelik ClamAV Worker**: https://github.com/julianghill/openrelik-worker-clamav
- **Velociraptor**: https://docs.velociraptor.app/
- **OpenRelik**: https://openrelik.io/

## Virus Database Updates

### Automatic Updates (Docker Build)
- ClamAV signatures are refreshed during image build
- Pull latest image regularly for current definitions

### Manual Updates (Inside Container)
```bash
docker exec openrelik-worker-clamav freshclam
```

### Scheduled Updates (Cron - Advanced)
```bash
# In your Docker host
0 4 * * * docker exec openrelik-worker-clamav freshclam >> /var/log/freshclam.log 2>&1
```

### Signature Feed Configuration
By default, ClamAV uses:
- **Main DB**: Official Cisco Talos signatures
- **Update Frequency**: Daily recommended
- **Database Mirror**: Automatically selected by freshclam

## Limitations and Notes

1. **Velociraptor-Focused**: Optimized for Velociraptor collection exports
2. **Archive-Based**: Currently processes archives/directories (disk image support coming)
3. **Antivirus Complement**: Should be part of comprehensive security workflow
4. **Known Malware**: Detects known threats; unknowns may evade detection
5. **False Positives**: Like all antivirus, may flag legitimate files rarely

## Legal/Compliance Notes

- ClamAV is free, open-source, GPL-licensed
- Suitable for enterprise/government use
- No licensing restrictions
- Source code available for audit
- Community-maintained virus definitions
