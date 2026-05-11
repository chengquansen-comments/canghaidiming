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

from tools.aigc_battle import switch_active_profile as switch_lib

PROFILE_ID = "weapon_followup_v0_1"
PACK_ID = "weapon_followup_v0_1_formal_sequence_pack_001"
REPORT_DIR = ROOT / "data" / "aigc_battle" / "generated" / PROFILE_ID
OLD_PROFILES = [
    "posture_basic_v0_1",
    "posture_tuned_v0_1b",
    "posture_llm_candidate_v0_1",
    "posture_opening_pressure_v0_1",
]


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_playable_mechanic_loop_probe.py", file=sys.stderr)
        return 1
    original_active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_content_for_profile.py"), PROFILE_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "validate_content_pack.py"), PROFILE_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "export_runtime_manifest.py"), PROFILE_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "switch_active_profile.py"), PROFILE_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_weapon_followup_probe.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_real_telemetry_probe.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_real_telemetry_snapshot.py"), PROFILE_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_rebuild_from_real_telemetry_probe.py")])
    old_profiles_regression_pass = run_old_profile_regression()
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_review_workspace.py")])
    restore_original_active(original_active)
    active_after = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")

    followup_report = read_json(REPORT_DIR / "weapon_followup_probe_report.json")
    telemetry_report = read_json(REPORT_DIR / "real_telemetry_probe_report.json")
    rebuild_report = read_json(REPORT_DIR / "rebuild_from_real_telemetry_probe_report.json")
    snapshot = read_json(REPORT_DIR / "real_telemetry_snapshot.json")
    report = {
        "weapon_followup_runtime_supported": bool(followup_report.get("manifest_exports_followup", False)) and bool(followup_report.get("godot_loader_reads_followup", False)),
        "generated_sequence_uses_weapon_followup": bool(followup_report.get("generated_sequence_uses_weapon_followup", False)),
        "followup_cards_generated": bool(followup_report.get("followup_cards_generated", False)),
        "followup_decks_generated": bool(followup_report.get("followup_decks_generated", False)),
        "followup_chain_valid": bool(followup_report.get("followup_chain_valid", False)),
        "battle_shows_followup_effect": bool(followup_report.get("battle_shows_followup_effect", False)),
        "real_telemetry_recorded": bool(telemetry_report.get("real_telemetry_recorded", False)),
        "turn_count_recorded": bool(telemetry_report.get("turn_count_recorded", False)),
        "hp_delta_recorded": bool(telemetry_report.get("hp_delta_recorded", False)),
        "card_usage_recorded": bool(telemetry_report.get("card_usage_recorded", False)),
        "weapon_followup_triggered_recorded": bool(telemetry_report.get("weapon_followup_triggered_recorded", False)),
        "balance_snapshot_has_real_metrics": bool(snapshot.get("real_metrics_ready", False)),
        "build_from_real_telemetry_ready": bool(rebuild_report.get("probe_pass", False)),
        "full_sequence_playable": bool(followup_report.get("probe_pass", False)),
        "old_profiles_regression_pass": old_profiles_regression_pass,
        "active_profile_not_corrupted": active_after == original_active,
        "probe_pass": False,
    }
    report["probe_pass"] = all(bool(report[key]) for key in report if key != "probe_pass")
    json_path = REPORT_DIR / "playable_mechanic_loop_probe_report.json"
    md_path = REPORT_DIR / "playable_mechanic_loop_probe_report.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text("\n".join([f"- {k}: {str(v).lower()}" for k, v in report.items()]) + "\n", encoding="utf-8")
    print(f"wrote {json_path.relative_to(ROOT)}")
    return 0 if report["probe_pass"] else 1


def run_old_profile_regression() -> bool:
    commands = [
        "validate_content_pack.py",
        "export_runtime_manifest.py",
        "aigc_formal_sequence_probe.py",
        "aigc_full_sequence_reward_probe.py",
        "aigc_sequence_balance_probe.py",
    ]
    for profile_id in OLD_PROFILES:
        for script_name in commands:
            run([sys.executable, str(ROOT / "tools" / "aigc_battle" / script_name), profile_id])
    return True


def restore_original_active(active: dict[str, Any]) -> None:
    profile_id = str(active.get("active_mechanic_profile_id", "")).strip()
    pack_id = str(active.get("active_content_pack_id", "")).strip() or None
    if not profile_id:
        return
    switch_lib.switch_active_profile(profile_id, pack_id, switch_source="playable_mechanic_loop_restore")


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or "command failed").strip())


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
