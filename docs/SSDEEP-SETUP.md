# OpenRelik SSDeep Worker Setup

## Overview

The **OpenRelik SSDeep Worker** is a Celery-based task processor designed to calculate **SSDeep** (Context-Triggered Piecewise Hashes) for files. SSDeep is a fuzzy hashing algorithm used to identify similar files, even if they have minor modifications.

## Key Functionality

- Accepts one or more input files
- For each input file, executes the ssdeep command-line tool
- Generates an output file (e.g., `original_filename.ssdeep`) for each input
- Output contains the calculated SSDeep hash
- If a file is too small for SSDeep or an error occurs, the output contains a relevant notice or error message

## What is SSDeep?

SSDeep is a program designed to compute Context-Triggered Piecewise Hashes (CTPH). Unlike traditional cryptographic hashes (MD5, SHA-1), which change completely if even one byte in the file is modified, SSDeep is designed to identify similar files.

### Use Cases

1. **Malware Analysis**: Identify variants of known malware samples
2. **File Integrity**: Detect small modifications to documents or executables
3. **Duplicate Detection**: Find similar files across large datasets
4. **Forensic Analysis**: Identify related evidence in forensic investigations

## Deployment

The SSDeep worker is automatically deployed and configured as part of the OpenRelik Vagrant environment. No additional setup is required beyond the standard `vagrant up openrelik` process.

### Docker Configuration

```yaml
openrelik-worker-ssdeep:
    container_name: openrelik-worker-ssdeep
    image: ghcr.io/openrelik/openrelik-worker-ssdeep:latest
    restart: always
    environment:
      - REDIS_URL=redis://openrelik-redis:6379
      - OPENRELIK_PYDEBUG=0
    volumes:
      - ./data:/usr/share/openrelik/data
    command: "celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-ssdeep"
```

## Usage

### Input Files

The SSDeep worker accepts any file types. Common use cases include:

- **Executable files** (.exe, .dll, .so, etc.)
- **Documents** (.pdf, .doc, .docx, .xls, etc.)
- **Archives** (.zip, .rar, .7z, etc.)
- **Images** (.jpg, .png, .gif, etc.)
- **Any binary or text file**

### Output Format

For each input file, SSDeep generates a `.ssdeep` output file with the following format:

```
3072:xR7zVfQzJQ7/p...etc...:aR7YkfQzKQ4/p...etc...
```

The hash format is: `block_size:hash1:hash2`

- **block_size**: The block size used in hashing (typically 4096 bytes)
- **hash1**: The fuzzy hash of the first half of the file
- **hash2**: The fuzzy hash of the second half of the file

### Example Workflow

1. **Add files** to OpenRelik
2. **Create a task** using the SSDeep worker
3. **Select input files** for analysis
4. **Execute the task**
5. **Review results** in the output files (`.ssdeep` extension)

## Comparing SSDeep Hashes

To compare SSDeep hashes, use the `ssdeep` command-line tool:

```bash
ssdeep -s <hash1> <hash2>
```

Output shows a similarity percentage (0-100):
- **0**: Files are completely different
- **100**: Files are identical

### Example

```bash
ssdeep -s "3072:xR7zVfQzJQ7/p:aR7YkfQzKQ4/p" "3072:xR7zVfQzJQ7/q:aR7YkfQzKQ4/q"
Match: 99 percent
```

## Advanced Options

The SSDeep worker supports advanced features:

### Recursive Processing

The worker can process multiple files in a batch:
1. Select multiple input files
2. The worker generates a `.ssdeep` file for each

### Minimum File Size

SSDeep requires a minimum file size to generate meaningful hashes:
- Files smaller than ~4KB may not generate valid fuzzy hashes
- The worker will output a notice for files below this threshold

### Output Customization

Output files are named based on the input file:
- Input: `sample.exe`
- Output: `sample.exe.ssdeep`

## Troubleshooting

### No Output Generated

**Symptom**: SSDeep task completes but no `.ssdeep` files appear

**Solutions**:
1. Verify input files are at least 4KB in size
2. Check file permissions in `/usr/share/openrelik/data`
3. Review worker logs: `docker logs openrelik-worker-ssdeep`

### Hash Generation Fails

**Symptom**: Output file contains error message

**Solutions**:
1. Verify the input file is not corrupted
2. Check disk space: `docker exec openrelik-worker-ssdeep df -h`
3. Verify file permissions: `docker exec openrelik-worker-ssdeep ls -l /usr/share/openrelik/data`

### Worker Not Running

**Symptom**: SSDeep worker doesn't appear in task list

**Solutions**:
1. Check worker status: `docker ps | grep ssdeep`
2. View logs: `docker logs openrelik-worker-ssdeep`
3. Restart worker: `docker restart openrelik-worker-ssdeep`
4. Verify Redis connectivity: `docker logs openrelik-redis`

## Resources

- **SSDeep Homepage**: https://tlsh.org/
- **SSDeep GitHub**: https://github.com/ssdeep-project/ssdeep
- **OpenRelik SSDeep Worker**: https://github.com/jaegeral/openrelik-worker-ssdeep2
- **CTPH Research**: https://www.digitalcorpora.org/

## Integration with Other Workers

The SSDeep worker can be chained with other OpenRelik workers:

### Example: Entropy → SSDeep

1. Use **Entropy Worker** to identify high-entropy files
2. Pass results to **SSDeep Worker** for fuzzy hashing
3. Use output to identify similar suspicious files

### Example: Yara → SSDeep

1. Use **Yara Worker** to detect malicious patterns
2. Pass matched files to **SSDeep Worker**
3. Generate fuzzy hashes of detected malware for variant tracking

## Performance Notes

- **Concurrency**: Worker runs with 4 concurrent tasks (configurable in docker-compose)
- **Processing Time**: Depends on file size; typically 1-5 seconds per file
- **Resource Usage**: Minimal CPU and memory overhead

To adjust concurrency, modify the docker-compose command:
```bash
--concurrency=8  # Increase to 8 concurrent tasks
```

## Related Workers

- **Entropy Worker**: Identify suspicious files by entropy analysis
- **Strings Worker**: Extract readable text from binary files
- **Capa Worker**: Identify malware capabilities
- **Yara Worker**: Pattern matching and malware detection
