# OpenRelik Exif Worker Integration

## Overview
The `openrelik-worker-exif` is a Celery-based task processor that extracts EXIF (Exchangeable Image File Format) metadata from image files using the industry-standard `exiftool` utility.

**Features:**
- Extracts comprehensive EXIF metadata from images
- Flexible output formats (plain text or JSON)
- Supports all major image formats
- Configurable output through OpenRelik UI

## Installation

The exif worker is automatically deployed during `vagrant up openrelik` as part of the standard build process. No additional setup required.

### Manual Deployment (if needed)
```bash
vagrant ssh openrelik
cd /opt/openrelik/openrelik
docker compose up -d openrelik-worker-exif
```

## Usage

### Via OpenRelik UI
1. Navigate to **Workflow** → **New Task**
2. Select **Exif** worker
3. Upload or select image file
4. Configure output format (see below)
5. Execute

### Configuration Options

#### Output in JSON format
- **UI Label:** "Output in JSON format"
- **Type:** Checkbox (boolean)
- **Default:** Unchecked (plain text output)
- **Effect:**
  - **Checked:** Output saved as `.json` with MIME type `application/json`
  - **Unchecked:** Output saved as `.txt` with MIME type `text/plain`

### Examples

**Extract EXIF as plain text:**
```
Input: photo.jpg
Output Format: Plain Text
Output File: photo_exif.txt
```

**Extract EXIF as JSON:**
```
Input: photo.jpg
Output Format: JSON
Output File: photo_exif.json
Data Type: image_metadata
```

## Supported Image Formats

The exif worker supports all formats that `exiftool` handles:
- JPEG (.jpg, .jpeg)
- PNG (.png)
- TIFF (.tif, .tiff)
- GIF (.gif)
- BMP (.bmp)
- RAW formats (.cr2, .nef, .raw, etc.)
- And many more...

## Verification

### Check if worker is running:
```bash
vagrant ssh openrelik -c "docker ps | grep exif"
```

### View worker logs:
```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-exif"
```

### Test extraction:
1. Go to OpenRelik UI (http://localhost:8711)
2. Create workflow with an image file
3. Select Exif worker
4. Configure output format
5. Review extracted metadata in output files

## Output Examples

### Plain Text Output
```
ExifTool Version Number         : 12.76
File Name                       : photo.jpg
Directory                       : /data
File Size                       : 2.5 MB
Image Width                     : 4000
Image Height                    : 3000
Make                            : Canon
Model                           : Canon EOS 5D Mark IV
...
```

### JSON Output
```json
{
  "SourceFile": "/data/photo.jpg",
  "ExifToolVersion": 12.76,
  "FileName": "photo.jpg",
  "FileSize": "2.5 MB",
  "ImageWidth": 4000,
  "ImageHeight": 3000,
  "Make": "Canon",
  "Model": "Canon EOS 5D Mark IV",
  ...
}
```

## Troubleshooting

### Worker not starting
```bash
vagrant ssh openrelik -c "docker logs openrelik-worker-exif"
```

### No output files generated
- Verify input file is a valid image
- Check that the file has readable EXIF data
- Review worker logs for errors

### JSONDecodeError in logs
The patch is automatically applied during provisioning. If you manually deployed after the initial build, reapply:
```bash
docker cp patches/apply-task-utils-fix.py openrelik-worker-exif:/tmp/
docker exec openrelik-worker-exif python3 /tmp/apply-task-utils-fix.py
```

## Integration with Patch System
The JSONDecodeError fix is automatically applied to the exif worker during the build process as part of the worker suite patching task.

## Additional Resources
- [ExifTool Documentation](https://exiftool.org/)
- [EXIF Standard](https://en.wikipedia.org/wiki/Exif)
