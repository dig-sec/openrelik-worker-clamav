#!/usr/bin/env python3
"""
Permanent fix for openrelik-worker-common JSONDecodeError.
This script applies the task_utils.py patch to guard against empty/invalid pipe_result.
Designed to run at container startup to ensure fix survives redeploy.
"""

import sys
import os

file_path = '/openrelik/.venv/lib/python3.12/site-packages/openrelik_worker_common/task_utils.py'

# Verify file exists
if not os.path.exists(file_path):
    print(f"ERROR: {file_path} not found", file=sys.stderr)
    sys.exit(1)

# Read the file
with open(file_path, 'r') as f:
    content = f.read()

# Check if already patched
if 'except (json.JSONDecodeError' in content and 'and pipe_result.strip()' in content:
    print("✓ Patch already applied")
    sys.exit(0)

# Apply patch for newer version (with pipe_results list loop)
old_code_new = '''    pipe_results = []

    if isinstance(pipe_result, list):
        pipe_results.extend(pipe_result)

    if isinstance(pipe_result, str):
        pipe_results.append(pipe_result)

    for pipe_result in pipe_results:
        result_string = base64.b64decode(pipe_result.encode("utf-8")).decode("utf-8")
        result_dict = json.loads(result_string)
        input_files = result_dict.get("output_files", [])'''

new_code_new = '''    pipe_results = []

    if isinstance(pipe_result, list):
        pipe_results.extend(pipe_result)

    if isinstance(pipe_result, str) and pipe_result.strip():
        pipe_results.append(pipe_result)

    for pipe_result in pipe_results:
        try:
            result_string = base64.b64decode(pipe_result.encode("utf-8")).decode("utf-8")
            if not result_string.strip():
                continue
            result_dict = json.loads(result_string)
            input_files = result_dict.get("output_files", [])
        except (json.JSONDecodeError, ValueError, UnicodeDecodeError):
            continue'''

# Apply patch for older version (with simple if pipe_result:)
old_code_old = '''    if pipe_result:
        result_string = base64.b64decode(pipe_result.encode("utf-8")).decode("utf-8")
        result_dict = json.loads(result_string)
        input_files = result_dict.get("output_files", [])'''

new_code_old = '''    if pipe_result and pipe_result.strip():
        try:
            result_string = base64.b64decode(pipe_result.encode("utf-8")).decode("utf-8")
            if not result_string.strip():
                pass
            else:
                result_dict = json.loads(result_string)
                input_files = result_dict.get("output_files", [])
        except (json.JSONDecodeError, ValueError, UnicodeDecodeError):
            pass'''

patched = False

# Try new version first
if old_code_new in content:
    content = content.replace(old_code_new, new_code_new)
    patched = True
    print("✓ Applied patch for newer version (pipe_results list)")
# Try old version
elif old_code_old in content:
    content = content.replace(old_code_old, new_code_old)
    patched = True
    print("✓ Applied patch for older version (if pipe_result:)")
else:
    print("✗ Could not find matching code patterns; patch may already be applied or version mismatch", file=sys.stderr)
    sys.exit(1)

# Write back
try:
    with open(file_path, 'w') as f:
        f.write(content)
    print(f"✓ Successfully patched {file_path}")
except Exception as e:
    print(f"ERROR: Failed to write patch: {e}", file=sys.stderr)
    sys.exit(1)
