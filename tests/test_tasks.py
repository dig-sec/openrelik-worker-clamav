from pathlib import Path

from src.tasks import (
    TASK_METADATA,
    TASK_NAME,
    _build_freshclam_config,
    _parse_clamscan_output,
    _parse_database_paths,
    command,
)


class DummyResultFile:
    def __init__(self, path: Path, display_name: str):
        self.path = str(path)
        self.display_name = display_name

    def to_dict(self):
        return {"path": self.path, "display_name": self.display_name}


def test_parse_clamscan_output():
    parsed = _parse_clamscan_output("/tmp/a.bin: Win.Test.EICAR_HDB-1 FOUND\n/tmp/clean.bin: OK")
    assert parsed == [
        {
            "file_path": "/tmp/a.bin",
            "signature": "Win.Test.EICAR_HDB-1",
            "status": "infected",
        }
    ]


def test_parse_database_paths(tmp_path):
    custom = tmp_path / "custom-db"
    custom.mkdir()
    parsed = _parse_database_paths({"database_paths": f"{custom}\n/missing/path"})
    assert str(custom) in parsed


def test_build_freshclam_config(tmp_path):
    db_dir = tmp_path / "db"
    db_dir.mkdir()
    config_file = _build_freshclam_config([str(db_dir)], "database.clamav.net")
    assert config_file
    content = Path(config_file).read_text(encoding="utf-8")
    assert "DatabaseMirror database.clamav.net" in content
    assert f"DatabaseDirectory {db_dir}" in content


def test_command(monkeypatch, tmp_path):
    input_file = tmp_path / "sample.bin"
    input_file.write_text("dummy", encoding="utf-8")

    output_dir = tmp_path / "out"
    output_dir.mkdir()

    db_dir = tmp_path / "db"
    db_dir.mkdir()

    def fake_create_output_file(output_path, display_name, data_type=None):
        del data_type
        return DummyResultFile(Path(output_path) / display_name, display_name)

    class FakeProcess:
        def __init__(self, returncode=0, stdout="", stderr=""):
            self.returncode = returncode
            self.stdout = stdout
            self.stderr = stderr

    calls = []

    def fake_run(args, capture_output, text, check):
        del capture_output, text, check
        calls.append(args)
        if args[0] == "freshclam":
            return FakeProcess(returncode=0, stdout="updated")
        return FakeProcess(
            returncode=1,
            stdout=f"{input_file}: Win.Test.EICAR_HDB-1 FOUND\n",
            stderr="",
        )

    monkeypatch.setattr("src.tasks.create_output_file", fake_create_output_file)
    monkeypatch.setattr("src.tasks.subprocess.run", fake_run)

    result = command.run(
        pipe_result=None,
        input_files=[{"path": str(input_file), "display_name": "sample.bin"}],
        output_path=str(output_dir),
        workflow_id="wf-1",
        task_config={
            "recursive": False,
            "database_paths": str(db_dir),
            "update_signatures": True,
            "allmatch": True,
            "detect_pua": True,
        },
    )

    assert isinstance(result, str)
    assert calls[0][0] == "freshclam"
    assert calls[1][0] == "clamscan"
    assert "--database" in calls[1]
    assert "--allmatch" in calls[1]
    assert "--detect-pua" in calls[1]
    assert (output_dir / "clamav_results.json").exists()
    assert (output_dir / "clamav_stdout.txt").exists()


def test_task_metadata_contract():
    assert TASK_NAME == "openrelik-worker-clamav.tasks.clamav-scan"
    assert TASK_METADATA["display_name"] == "ClamAV scan"
    assert "task_config" in TASK_METADATA
    task_config_names = {item["name"] for item in TASK_METADATA["task_config"]}
    assert {
        "recursive",
        "update_signatures",
        "database_paths",
    }.issubset(task_config_names)
