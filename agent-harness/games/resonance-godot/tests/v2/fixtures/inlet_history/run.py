"""Isolate the frozen historical legality profile; never edits the product project."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

fixture = Path(__file__).resolve().parent
project = fixture.parents[3]
xdg = Path(os.environ["XDG_DATA_HOME"])
if not xdg.is_absolute():
    raise SystemExit("Historical fixture requires absolute isolated XDG_DATA_HOME")
xdg.mkdir(parents=True, exist_ok=True)
work = Path(tempfile.mkdtemp(prefix="inlet-history-", dir=xdg))
for name in ["scripts", "scenes", "tests"]:
    shutil.copytree(project / name, work / name)
shutil.copyfile(project / "project.godot", work / "project.godot")
(work / "assets").symlink_to(project / "assets", target_is_directory=True)
(work / ".godot").mkdir()
if (project / ".godot/imported").exists():
    (work / ".godot/imported").symlink_to(project / ".godot/imported", target_is_directory=True)
if (project / ".godot/global_script_class_cache.cfg").exists():
    shutil.copyfile(project / ".godot/global_script_class_cache.cfg", work / ".godot/global_script_class_cache.cfg")
witness = json.loads((fixture / "witness.json").read_text())
for name, expected in witness["provenance"]["frozen_source_sha256"].items():
    if hashlib.sha256((fixture / name).read_bytes()).hexdigest() != expected:
        raise SystemExit("Frozen historical source hash mismatch: " + name)
shutil.copyfile(fixture / "board.gd", work / "scripts/v2/board.gd")
shutil.copyfile(fixture / "geometry_adapter.gd", work / "scripts/v2/geometry.gd")
shutil.copyfile(fixture / "full_expedition.gd", work / "tests/v2/full_expedition_test.gd")
command = ["godot", "--headless", "--fixed-fps", "120", "--path", str(work), "--script", "tests/v2/fixtures/inlet_history/target.gd", "--", "--no-save", "--product-board=" + str(project / "scripts/v2/board.gd"), "--history-output=" + str(work / "historical-result.json")]
print(json.dumps({"cwd": str(work), "command": command, "xdg": {k: v for k, v in os.environ.items() if k.startswith("XDG_")}, "product_board_sha256": hashlib.sha256((project / "scripts/v2/board.gd").read_bytes()).hexdigest(), "result": str(work / "historical-result.json")}), flush=True)
result = subprocess.run(command, cwd=work, timeout=180)
if result.returncode:
    raise SystemExit(result.returncode)
# A second isolated engine freezes the pre-tie Board through the derived
# historical prefix and applies current product only at its all42 target.
pre_tie_hash = hashlib.sha256((fixture / "pre_tie_board.gd").read_bytes()).hexdigest()
derived = json.loads((fixture / "derived42_witness.json").read_text())
if pre_tie_hash != derived["provenance"]["pre_tie_board_sha256"]:
    raise SystemExit("Frozen pre-tie Board hash mismatch")
shutil.copyfile(fixture / "pre_tie_board.gd", work / "scripts/v2/board.gd")
audit = (fixture / "product_audit_template.gd").read_text().replace('extends "res://scripts/v2/board.gd"', 'extends ' + json.dumps(str(project / "scripts/v2/board.gd")))
(work / "product_audit.gd").write_text(audit)
command = ["godot", "--headless", "--fixed-fps", "120", "--path", str(work), "--script", "tests/v2/fixtures/inlet_history/physical_cases.gd", "--", "--no-save", "--product-audit=" + str(work / "product_audit.gd")]
print(json.dumps({"cwd": str(work), "command": command, "profile": "HISTORICAL1.0/pre-tie prefix; current product only at derived42 target"}), flush=True)
result = subprocess.run(command, cwd=work, timeout=180)
if result.returncode:
    raise SystemExit(result.returncode)
# Current Board throughout; historical1.0 selection only. Separate fresh engines
# preserve the original ordinary-tail and standalone-large construction schedules.
shutil.copyfile(project / "scripts/v2/board.gd", work / "scripts/v2/board.gd")
for mode in ["--density-only", "--standalone"]:
    command = ["godot", "--headless", "--fixed-fps", "120", "--path", str(work), "--script", "tests/v2/fixtures/inlet_history/physical_cases.gd", "--", "--no-save", "--current-only", mode]
    print(json.dumps({"cwd": str(work), "command": command, "profile": "CURRENT product Board throughout / HISTORICAL1.0 matching", "board_sha256": hashlib.sha256((work / "scripts/v2/board.gd").read_bytes()).hexdigest()}), flush=True)
    result = subprocess.run(command, cwd=work, timeout=180)
    if result.returncode:
        raise SystemExit(result.returncode)
raise SystemExit(0)
