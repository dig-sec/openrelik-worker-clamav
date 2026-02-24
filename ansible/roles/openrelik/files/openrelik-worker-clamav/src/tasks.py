import json
import os
import shlex
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from openrelik_worker_common.file_utils import create_output_file
from openrelik_worker_common.task_utils import create_task_result, get_input_files

from .app import celery

TASK_NAME = "openrelik-worker-clamav.tasks.clamav-scan"

TASK_METADATA = {
    "display_name": "ClamAV scan",
    "description": "Scan files and folders for malware with ClamAV.",
    "task_config": [
        {
            "name": "recursive",
            "label": "Scan directories recursively",
            "description": "If checked, recursively scans input directories.",
            "type": "checkbox",
            "required": True,
            "default_value": True,
        },
        {
            "name": "update_signatures",
            "label": "Update signatures before scanning",
            "description": "Runs freshclam at task start to fetch latest official signatures.",
            "type": "checkbox",
            "required": True,
            "default_value": True,
        },
        {
            "name": "database_paths",
            "label": "/var/lib/clamav",
            "description": "Optional newline-separated list of ClamAV database files/directories.",
            "type": "textarea",
            "required": False,
        },
        {
            "name": "freshclam_mirror",
            "label": "database.clamav.net",
            "description": "Optional custom mirror for freshclam updates.",
            "type": "text",
            "required": False,
        },
        {
            "name": "allmatch",
            "label": "Report all signature matches",
            "description": "Enable clamscan --allmatch to return all detections instead of first match.",
            "type": "checkbox",
            "required": True,
            "default_value": True,
        },
        {
            "name": "detect_pua",
            "label": "Detect PUA",
            "description": "Enable potentially unwanted application (PUA) detection.",
            "type": "checkbox",
            "required": True,
            "default_value": True,
        },
    ],
}


def _parse_clamscan_output(output: str) -> list[dict[str, Any]]:
    findings = []
    for line in output.splitlines():
        if not line.endswith(" FOUND"):
            continue
        file_path, signature = line.rsplit(": ", 1)
        findings.append(
            {
                "file_path": file_path,
                "signature": signature.removesuffix(" FOUND"),
                "status": "infected",
            }
        )
    return findings


def _parse_database_paths(task_config: dict[str, Any]) -> list[str]:
    configured = task_config.get("database_paths") or ""
    if not isinstance(configured, str):
        configured = str(configured)
    entries = [entry.strip() for entry in configured.replace(",", "\n").splitlines() if entry.strip()]
    defaults = ["/var/lib/clamav", "/usr/local/share/clamav"]

    existing_paths: list[str] = []
    seen = set()
    for candidate in [*entries, *defaults]:
        if candidate in seen:
            continue
        seen.add(candidate)
        if os.path.exists(candidate):
            existing_paths.append(candidate)
    return existing_paths


def _build_freshclam_config(database_paths: list[str], mirror: str | None) -> str | None:
    config_lines = []
    mirror = (mirror or "").strip()
    if mirror:
        config_lines.append(f"DatabaseMirror {mirror}")

    first_dir = next((path for path in database_paths if os.path.isdir(path)), None)
    if first_dir:
        config_lines.append(f"DatabaseDirectory {first_dir}")

    if not config_lines:
        return None

    with tempfile.NamedTemporaryFile(mode="w", suffix=".conf", delete=False, encoding="utf-8") as fh:
        fh.write("\n".join(config_lines) + "\n")
        return fh.name


def _update_signatures(database_paths: list[str], freshclam_mirror: str | None) -> str:
    config_file = _build_freshclam_config(database_paths, freshclam_mirror)
    command = ["freshclam", "--stdout", "--foreground"]
    if config_file:
        command.extend(["--config-file", config_file])

    try:
        process = subprocess.run(command, capture_output=True, text=True, check=False)
        if process.returncode != 0:
            raise RuntimeError(
                f"freshclam failed with code {process.returncode}: {process.stderr.strip() or process.stdout.strip()}"
            )
        return " ".join(shlex.quote(part) for part in command)
    finally:
        if config_file:
            Path(config_file).unlink(missing_ok=True)


@celery.task(bind=True, name=TASK_NAME, metadata=TASK_METADATA)
def command(
    self,
    pipe_result: str | None = None,
    input_files: list | None = None,
    output_path: str | None = None,
    workflow_id: str | None = None,
    task_config: dict[str, Any] | None = None,
) -> str:
    del self

    task_config = task_config or {}
    input_files = get_input_files(pipe_result, input_files or [])
    if not input_files:
        raise ValueError("No input files provided")

    database_paths = _parse_database_paths(task_config)
    base_command = ["clamscan", "--infected", "--no-summary"]

    if task_config.get("recursive", True):
        base_command.append("--recursive")
    if task_config.get("allmatch", True):
        base_command.append("--allmatch")
    if task_config.get("detect_pua", True):
        base_command.append("--detect-pua")

    for db_path in database_paths:
        base_command.extend(["--database", db_path])

    command_strings = []
    if task_config.get("update_signatures", True):
        command_strings.append(
            _update_signatures(database_paths, task_config.get("freshclam_mirror"))
        )

    combined_findings = []
    raw_lines = []
    scanned_paths = []

    for input_file in input_files:
        scan_path = input_file.get("path")
        if not scan_path or not os.path.exists(scan_path):
            continue

        scanned_paths.append(scan_path)
        scan_command = [*base_command, scan_path]
        command_strings.append(" ".join(shlex.quote(part) for part in scan_command))

        process = subprocess.run(scan_command, capture_output=True, text=True, check=False)
        if process.returncode > 1:
            raise RuntimeError(
                f"clamscan failed for {scan_path} with code {process.returncode}: {process.stderr.strip() or process.stdout.strip()}"
            )

        raw_lines.extend(line for line in process.stdout.splitlines() if line)
        combined_findings.extend(_parse_clamscan_output(process.stdout))

    if not scanned_paths:
        raise ValueError("No valid input paths were found to scan")

    raw_output = create_output_file(output_path, display_name="clamav_stdout.txt", data_type="text/plain")
    with open(raw_output.path, "w", encoding="utf-8") as fh:
        if raw_lines:
            fh.write("\n".join(raw_lines) + "\n")

    findings_output = create_output_file(
        output_path,
        display_name="clamav_results.json",
        data_type="openrelik:clamav:findings",
    )
    with open(findings_output.path, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "findings": combined_findings,
                "database_paths": database_paths,
                "signatures_updated": task_config.get("update_signatures", True),
                "scanned_paths": scanned_paths,
            },
            fh,
            indent=2,
        )

    return create_task_result(
        output_files=[raw_output.to_dict(), findings_output.to_dict()],
        workflow_id=workflow_id,
        command=" && ".join(command_strings),
        meta={
            "infected_count": len(combined_findings),
            "database_paths": database_paths,
            "scanned_count": len(scanned_paths),
        },
    )
