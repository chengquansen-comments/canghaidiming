#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
PROFILE_ID = "posture_opening_pressure_v0_1"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_rebuild_from_snapshot_probe.py", file=sys.stderr)
        return 1
    run_serial([sys.executable, "tools/aigc_battle/switch_active_profile.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/aigc_sequence_telemetry_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/build_sequence_balance_snapshot.py", PROFILE_ID])
    snapshot_path = GENERATED_DIR / PROFILE_ID / "sequence_balance_snapshot.json"
    run_serial([sys.executable, "tools/aigc_battle/build_content_for_profile.py", PROFILE_ID, "--use-snapshot", str(snapshot_path)])
    run_serial([sys.executable, "tools/aigc_battle/validate_content_pack.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/switch_active_profile.py", PROFILE_ID])
    run_serial([sys.executable, "tools/aigc_battle/aigc_formal_sequence_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_full_sequence_reward_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_sequence_balance_probe.py"])

    generated_dir = GENERATED_DIR / PROFILE_ID
    validation_report = read_json(generated_dir / "validation_report.json")
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")
    formal_report = read_json(generated_dir / "formal_sequence_probe_report.json")
    reward_report = read_json(generated_dir / "full_sequence_reward_probe_report.json")
    balance_report = read_json(generated_dir / "sequence_balance_probe_report.json")

    run_serial([sys.executable, "tools/aigc_battle/aigc_runtime_primitive_probe.py"])

    telemetry_report = read_json(generated_dir / "telemetry_probe_report.json")
    snapshot = read_json(snapshot_path)
    primitive_report = read_json(generated_dir / "runtime_primitive_probe_report.json")

    weak_or_overpowered = bool(snapshot.get("weak_decks", [])) or bool(snapshot.get("overpowered_decks", [])) or bool(snapshot.get("sequence_rebuild_recommendations", []))
    abnormal_flagged = bool(snapshot.get("abnormal_decks", [])) or weak_or_overpowered
    report = {
        "telemetry_recorded": bool(telemetry_report.get("telemetry_probe_pass", False)),
        "balance_snapshot_ready": bool(snapshot.get("snapshot_ready", False)),
        "rebuild_uses_snapshot": bool(validation_report.get("rebuild_uses_snapshot", False)),
        "weak_or_overpowered_deck_flagged": weak_or_overpowered,
        "abnormal_decks_flagged": abnormal_flagged,
        "rebuilt_sequence_coverage_complete": bool(formal_report.get("all_formal_battles_use_generated_loadout", False)),
        "rebuilt_sequence_balance_pass": bool(balance_report.get("sequence_balance_pass", False)) and bool(balance_summary.get("snapshot_rebuild_pass", False)),
        "rebuilt_reward_closure_ready": bool(reward_report.get("full_sequence_loop_closed", False)),
        "rebuilt_runtime_primitive_ready": bool(primitive_report.get("probe_pass", False)),
        "fallback_loadout_count": int(primitive_report.get("fallback_loadout_count", formal_report.get("fallback_loadout_count", 0))),
        "rebuild_loop_pass": False,
    }
    report["rebuild_loop_pass"] = (
        report["telemetry_recorded"]
        and report["balance_snapshot_ready"]
        and report["rebuild_uses_snapshot"]
        and report["rebuilt_sequence_coverage_complete"]
        and report["rebuilt_sequence_balance_pass"]
        and report["rebuilt_reward_closure_ready"]
        and report["rebuilt_runtime_primitive_ready"]
        and report["fallback_loadout_count"] == 0
    )
    write_json(generated_dir / "rebuild_from_snapshot_probe_report.json", report)
    write_markdown(generated_dir / "rebuild_from_snapshot_probe_report.md", report)
    print("rebuild from snapshot probe complete")
    return 0 if report["rebuild_loop_pass"] else 1


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v8 Rebuild From Snapshot Probe",
        "",
        f"- telemetry_recorded: {str(report['telemetry_recorded']).lower()}",
        f"- balance_snapshot_ready: {str(report['balance_snapshot_ready']).lower()}",
        f"- rebuild_uses_snapshot: {str(report['rebuild_uses_snapshot']).lower()}",
        f"- weak_or_overpowered_deck_flagged: {str(report['weak_or_overpowered_deck_flagged']).lower()}",
        f"- abnormal_decks_flagged: {str(report['abnormal_decks_flagged']).lower()}",
        f"- rebuilt_sequence_coverage_complete: {str(report['rebuilt_sequence_coverage_complete']).lower()}",
        f"- rebuilt_sequence_balance_pass: {str(report['rebuilt_sequence_balance_pass']).lower()}",
        f"- rebuilt_reward_closure_ready: {str(report['rebuilt_reward_closure_ready']).lower()}",
        f"- rebuilt_runtime_primitive_ready: {str(report['rebuilt_runtime_primitive_ready']).lower()}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- rebuild_loop_pass: {str(report['rebuild_loop_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
