# OpenRelik EML Worker Setup

## Overview

The **OpenRelik EML Worker** is a Celery-based task processor designed to parse **EML** (.eml) and **Outlook Item** (.msg) files. It extracts metadata, body content, and attachments, making them available for further processing within the OpenRelik ecosystem.

## Key Functionality

- Parses EML (MIME) formatted email messages
- Parses MSG (Outlook) formatted email messages
- Extracts email metadata (From, To, Subject, Date, etc.)
- Extracts email body content (text and HTML)
- Extracts and lists attachments
- Generates structured output for further analysis
- Handles nested/embedded messages and multipart content

## Email File Formats Supported

### EML Files
- Standard MIME format email messages
- Commonly exported from email clients (Outlook, Thunderbird, Apple Mail)
- Human-readable text-based format
- Extensions: `.eml`, `.mht` (MIME HTML)

### MSG Files
- Microsoft Outlook proprietary format
- Binary format containing complete email with attachments
- Preserves all Outlook-specific properties
- Extensions: `.msg`, `.oft` (Outlook template)

## Deployment

The EML worker is automatically deployed and configured as part of the OpenRelik Vagrant environment. No additional setup is required beyond the standard `vagrant up openrelik` process.

### Docker Configuration

```yaml
openrelik-worker-eml:
    container_name: openrelik-worker-eml
    image: ghcr.io/openrelik/openrelik-worker-eml:latest
    restart: always
    environment:
      - REDIS_URL=redis://openrelik-redis:6379
      - OPENRELIK_PYDEBUG=0
    volumes:
      - ./data:/usr/share/openrelik/data
    command: "celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-eml"
```

## Usage

### Input Files

The EML worker accepts email message files:

- **EML Files**: Single email messages in MIME format
- **MSG Files**: Outlook message items (single messages or attachments containing messages)
- **Multiple Files**: Can process batch operations on multiple files

### Output Format

For each input email file, the EML worker generates output containing:

#### Metadata Extraction
```
From: sender@example.com
To: recipient@example.com
Subject: Email Subject Line
Date: 2024-01-10T14:30:00+00:00
Message-ID: <unique-id@example.com>
```

#### Body Content
- Plain text version (if available)
- HTML version (if available)
- Converted to readable text format

#### Attachments
```
Attachment 1:
  Name: document.pdf
  Size: 245632 bytes
  MIME Type: application/pdf
  
Attachment 2:
  Name: image.jpg
  Size: 1024576 bytes
  MIME Type: image/jpeg
```

#### CC/BCC Recipients
```
CC: cc@example.com
BCC: bcc@example.com
```

#### Additional Headers
```
Reply-To: reply@example.com
X-Priority: 1 (High)
X-Mailer: Microsoft Outlook 16.0
```

### Example Workflow

1. **Import email files** into OpenRelik
2. **Create a task** using the EML worker
3. **Select input files** (EML or MSG files for analysis)
4. **Execute the task**
5. **Review extracted metadata** in the output
6. **Chain to other workers** for further analysis:
   - Pass extracted attachments to Yara for malware scanning
   - Send extracted URLs to grep worker for pattern matching
   - Analyze extracted images with Exif worker

## Email Analysis Workflows

### Phishing Email Investigation

1. **Use EML Worker** to extract metadata and attachments
2. **Use Strings Worker** to extract URLs and suspicious strings
3. **Use Grep Worker** to pattern match known phishing indicators
4. **Use Capa Worker** to analyze attached executables

### Malware Detection

1. **Use EML Worker** to extract attachments
2. **Use Yara Worker** to scan extracted files against malware signatures
3. **Use Capa Worker** to identify malicious capabilities in executables
4. **Use Entropy Worker** to identify obfuscated/packed files

### Email Thread Analysis

1. **Use EML Worker** to extract metadata from multiple related emails
2. **Use Grep Worker** to identify correlations (same IP, domain, sender patterns)
3. **Use Strings Worker** to extract key terms and indicators

### Attachment Forensics

1. **Use EML Worker** to list and extract attachments
2. **Use SSDeep Worker** to identify similar attachments across emails
3. **Use Exif Worker** to analyze image attachments
4. **Use RegRipper Worker** to analyze registry hive attachments

## Handling MSG Files

MSG files are Microsoft Outlook-specific and may contain:

- **Embedded OLE objects** (Word documents, Excel spreadsheets)
- **Nested messages** (forwarded/replied emails)
- **Rich text formatting** (converted to readable format)
- **Calendar entries** (in some MSG variants)

The EML worker automatically extracts and presents this content in a structured format.

## Email Headers and Properties

Extracted headers include:

- `Date`: Message timestamp
- `From`: Sender email address and name
- `To`: Primary recipients
- `CC`: Carbon copy recipients
- `BCC`: Blind carbon copy recipients (if visible in export)
- `Subject`: Email subject line
- `Message-ID`: Unique message identifier
- `In-Reply-To`: ID of message being replied to
- `References`: IDs of related messages in thread
- `Reply-To`: Address for replies (if different from From)
- `Content-Type`: MIME type of content
- `X-* headers`: Non-standard extended headers (Outlook-specific, etc.)

## Output File Format

Output files are typically named based on the input file:

- Input: `phishing-email.eml`
- Output: `phishing-email.eml.extracted` or similar
- Structured text format containing all extracted data

## Troubleshooting

### Corrupted Email File

**Symptom**: Worker fails to parse MSG or EML file

**Solutions**:
1. Verify file is not corrupted: Try opening in email client
2. Ensure file has correct extension (.eml or .msg)
3. Check file size is reasonable (>100 bytes)
4. Review worker logs: `docker logs openrelik-worker-eml`

### Missing Attachments in Output

**Symptom**: Email has attachments but none are listed

**Solutions**:
1. Verify attachments actually exist in the file
2. Check file permissions in data directory
3. Ensure MSG file is not password-protected
4. Review worker logs for attachment extraction errors

### Encoding Issues

**Symptom**: Output contains garbled characters or encoding errors

**Solutions**:
1. Worker automatically detects character encoding
2. Some legacy emails may use non-standard encodings
3. Review raw email headers for `Content-Encoding` specification
4. Try converting MSG to EML format first

### Worker Not Running

**Symptom**: EML worker doesn't appear in task list

**Solutions**:
1. Check worker status: `docker ps | grep eml`
2. View logs: `docker logs openrelik-worker-eml`
3. Restart worker: `docker restart openrelik-worker-eml`
4. Verify Redis connectivity: `docker logs openrelik-redis`

## Performance Notes

- **Concurrency**: Worker runs with 4 concurrent tasks (configurable)
- **Processing Time**: Typically 0.5-2 seconds per email
- **Memory Usage**: Low overhead; scales with attachment sizes
- **Attachment Extraction**: All attachments extracted to output

To adjust concurrency:
```bash
--concurrency=8  # Increase to 8 concurrent tasks
```

## Integration with Other Workers

### Email Security Analysis Chain

```
EML Worker (Extract)
    ↓
Strings Worker (Extract IOCs)
    ↓
Grep Worker (Pattern matching)
    ↓
[Yara Worker if executables detected]
    ↓
[Capa Worker for capability analysis]
```

### Email Forensics Chain

```
EML Worker (Extract metadata + attachments)
    ↓
RegRipper Worker (if registry hives attached)
    ↓
Exif Worker (if images attached)
    ↓
Yara Worker (scan all extracted files)
```

## Advanced Features

### Nested Message Handling

If an email contains a forwarded or nested email:
1. Extracts outer message metadata
2. Identifies nested message
3. Extracts nested message as separate entity

### Multipart Content

For emails with multiple parts:
- Text version (preserved)
- HTML version (converted to text)
- Attachments (extracted)
- Embedded resources (extracted if accessible)

### Original Message Preservation

- Full email headers preserved in output
- Raw source available for detailed analysis
- Timestamps in UTC for consistency

## Related Workers

- **Strings Worker**: Extract text from attachments
- **Yara Worker**: Scan attachments for malware
- **Capa Worker**: Analyze executable attachments
- **Entropy Worker**: Identify suspicious attachments
- **Exif Worker**: Extract image attachment metadata
- **RegRipper Worker**: Analyze registry attachments
- **Grep Worker**: Search email content for patterns
- **SSDeep Worker**: Identify similar attachments

## Resources

- **EML Format Specification**: https://www.ietf.org/rfc/rfc5322.txt
- **MSG Format Documentation**: https://docs.microsoft.com/en-us/openspecs/exchange_server_protocols/ms-oxcdata/
- **OpenRelik EML Worker**: https://github.com/jaegeral/openrelik-worker-eml
- **Email Security Best Practices**: https://www.cisa.gov/
