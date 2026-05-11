#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib

PROFILE_ID = "weapon_followup_v0_1"
REBUILT_PACK_ID = "weapon_followup_real_rebuild_001"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / PROFILE_ID


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_rebuild_from_real_telemetry_probe.py", file=sys.stderr)
        return 1
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_real_telemetry_snapshot.py"), PROFILE_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_pack_factory.py"), "build-from-real-telemetry", "--profile", PROFILE_ID, "--pack-id", REBUILT_PACK_ID, "--force"])

    snapshot = read_json(GENERATED_DIR / "real_telemetry_snapshot.json")
    rebuilt_dir = switch_lib.resolve_generated_dir(PROFILE_ID, REBUILT_PACK_ID)
    validation = read_json(rebuilt_dir / "validation_report.json")
    runtime_manifest = read_json(rebuilt_dir / "runtime_manifest.json")
    review_ready = review_lib.pack_review_json_path(PROFILE_ID, REBUILT_PACK_ID).exists()

    report = {
        "real_telemetry_snapshot_ready": (GENERATED_DIR / "real_telemetry_snapshot.json").exists(),
        "balance_snapshot_has_real_metrics": bool(snapshot.get("real_metrics_ready", False)),
        "rebuild_recommendations_actionable": len(snapshot.get("rebuild_recommendations", [])) > 0,
        "build_from_real_telemetry_ready": rebuilt_dir.exists(),
        "rebuilt_pack_validated": bool(validation.get("ready_for_runtime_export", False)),
        "rebuilt_pack_exported": (rebuilt_dir / "runtime_manifest.json").exists() and bool(runtime_manifest.get("runtime_primitives")),
        "rebuilt_pack_review_ready": review_ready,
        "safe_switch_dry_run_ready": False,
        "probe_pass": False,
        "rebuilt_pack_id": REBUILT_PACK_ID,
    }
    try:
        switch_lib.validate_profile_ready(PROFILE_ID, REBUILT_PACK_ID)
        report["safe_switch_dry_run_ready"] = True
    except SystemExit:
        report["safe_switch_dry_run_ready"] = False
    report["probe_pass"] = all(
        bool(report[key])
        for key in [
            "real_telemetry_snapshot_ready",
            "balance_snapshot_has_real_metrics",
            "rebuild_recommendations_actionable",
            "build_from_real_telemetry_ready",
            "rebuilt_pack_validated",
            "rebuilt_pack_exported",
            "rebuilt_pack_review_ready",
            "safe_switch_dry_run_ready",
        ]
    )
    json_path = GENERATED_DIR / "rebuild_from_real_telemetry_probe_report.json"
    md_path = GENERATED_DIR / "rebuild_from_real_telemetry_probe_report.md"
    write_json(json_path, report)
    md_path.write_text("\n".join([f"- {k}: {str(v).lower() if isinstance(v, bool) else v}" for k, v in report.items()]) + "\n", encoding="utf-8")
    print(f"wrote {json_path.relative_to(ROOT)}")
    return 0 if report["probe_pass"] else 1


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or "command failed").strip())


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
