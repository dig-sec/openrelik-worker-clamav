# OpenRelik RegRipper Worker Integration

## Overview
The `openrelik-worker-regripper` is a Celery-based forensic analysis tool designed to extract and analyze Windows registry hive files using RegRipper. It automatically detects registry hive types and applies appropriate analysis profiles to generate forensic reports.

**Features:**
- Automatic registry hive type detection
- Profile-based analysis (SAM, SYSTEM, NTUSER.DAT, etc.)
- Artifact extraction and forensic reporting
- Structured output for further analysis
- Optimized concurrency for registry analysis

## Installation

The RegRipper worker is automatically deployed during `vagrant up openrelik` as part of the standard build process. No additional setup required.

### Manual Deployment (if needed)
```bash
vagrant ssh openrelik
cd /opt/openrelik/openrelik
docker compose up -d openrelik-worker-regripper
```

## Usage

### Via OpenRelik UI
1. Navigate to **Workflow** → **New Task**
2. Select **RegRipper** worker
3. Upload or select registry hive file
4. Execute analysis

### Supported Registry Hives

The RegRipper worker automatically detects and analyzes:
- **SYSTEM** — System hive (boot time, device info, services)
- **SAM** — Security Accounts Manager (user accounts, hashes)
- **NTUSER.DAT** — User registry (user settings, MRU lists, Run keys)
- **SOFTWARE** — Software installations and configurations
- **SECURITY** — Security policies and audit logs
- **DEFAULT** — Default user profile template

### Output

RegRipper analysis generates detailed forensic reports including:
- Registry artifact timeline
- Recently accessed files (MRU)
- Installed software and updates
- Startup locations and services
- User activity and login history
- Deleted/remnant data analysis
- ShimCache and AppCompat data (if SYSTEM hive)

## Examples

**Analyze SYSTEM registry hive:**
```
Input: SYSTEM
Output File: SYSTEM_regripper.txt
Data Type: windows_registry_system_analysis
```

**Analyze SAM hive (user accounts):**
```
Input: SAM
Output File: SAM_regripper.txt
Data Type: windows_registry_sam_analysis
```

**Analyze user NTUSER.DAT:**
```
Input: NTUSER.DAT
Output File: NTUSER_regripper.txt
Data Type: windows_registry_user_analysis
```

## Verification

### Check if worker is running:
```bash
vagrant ssh openrelik -c "docker ps | grep regripper"
```

### View worker logs:
```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-regripper"
```

### Test analysis:
1. Go to OpenRelik UI (http://localhost:8711)
2. Create workflow with a Windows registry hive file
3. Select RegRipper worker
4. Review extracted forensic artifacts in output

## Output Example

```
Hive: SYSTEM
LastWrite Time: 2024-01-10 15:30:45 UTC

Services:
  - CryptSvc (Cryptographic Services) - Started
  - RpcSs (Remote Procedure Call) - Started
  - w32time (Windows Time) - Started

Device Information:
  - Computer Name: WORKSTATION-01
  - Timezone: Eastern Time

Boot Entry:
  - Last Boot: 2024-01-10 14:15:22 UTC
  - Boot Device: \Device\HarddiskVolume1

Network Configuration:
  - DHCP Enabled: Yes
  - DNS Servers: 8.8.8.8, 1.1.1.1
```

## Performance

The RegRipper worker is configured with:
- **Concurrency:** 2 (optimized for registry I/O)
- **Restart Policy:** Always (auto-recovery on failure)
- **Memory:** Unlimited (handles large registry hives)

## Troubleshooting

### Worker not starting
```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-regripper"
```

### Analysis produces no output
- Verify the input file is a valid Windows registry hive
- Check file permissions and accessibility
- Review worker logs for hive type detection errors

### JSONDecodeError in logs
The patch is automatically applied during provisioning. If you manually deployed after the initial build, reapply:
```bash
docker cp patches/apply-task-utils-fix.py openrelik-worker-regripper:/tmp/
docker exec openrelik-worker-regripper python3 /tmp/apply-task-utils-fix.py
```

## Integration with Patch System
The JSONDecodeError fix is automatically applied to the RegRipper worker during the build process as part of the worker suite patching task.

## Advanced Usage

### Analyzing Registry Hives from Disk Images
1. Use the Extraction worker to mount/extract registry files
2. Pass extracted hives to RegRipper worker
3. Chain outputs for complete forensic analysis

### Forensic Workflow Example
```
Input: Disk Image
  ↓
Extraction Worker (Mount + Extract SYSTEM/SAM/NTUSER.DAT)
  ↓
RegRipper Worker (Analyze extracted hives)
  ↓
Output: Forensic Registry Reports
```

## Additional Resources
- [RegRipper Documentation](https://github.com/keydet89/RegRipper3.0)
- [Windows Registry Forensics](https://en.wikipedia.org/wiki/Windows_registry)
- [SANS Windows Registry Analysis](https://www.sans.org/cyber-aces/resources/guides/windows-registry-forensics)
