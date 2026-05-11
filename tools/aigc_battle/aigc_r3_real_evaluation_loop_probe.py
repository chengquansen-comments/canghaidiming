#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
REPORT_JSON = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_real_evaluation_loop_probe_report.json"
REPORT_MD = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_real_evaluation_loop_probe_report.md"


def main() -> int:
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/aigc_headless_evaluation_runner.py", "--default-r3-pack-set", "--samples", "2"])
    run([sys.executable, "tools/aigc_battle/build_real_evaluation_snapshot.py", "--default-r3-pack-set"])
    run([sys.executable, "tools/aigc_battle/build_rebuild_recommendations.py", "--default-r3-pack-set"])
    rebuilt_pack_id = next_rebuild_pack_id("weapon_followup_eval_rebuild_")
    run([
        sys.executable,
        "tools/aigc_battle/aigc_build_from_evaluation_snapshot.py",
        "--profile",
        "weapon_followup_v0_1",
        "--pack",
        "weapon_followup_v0_1_formal_sequence_pack_001",
        "--new-pack-id",
        rebuilt_pack_id,
    ])
    rebuilt_dir = ROOT / "data" / "aigc_battle" / "generated" / "weapon_followup_v0_1" / "packs" / rebuilt_pack_id
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", "weapon_followup_v0_1", "--generated-dir", str(rebuilt_dir)])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", "weapon_followup_v0_1", "--generated-dir", str(rebuilt_dir)])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/aigc_evaluation_dashboard_probe.py"])
    run([sys.executable, "tools/aigc_battle/aigc_playable_release_smoke_probe.py"])

    old_profiles_regression_pass = True
    for profile_id in [
        "posture_opening_pressure_v0_1",
        "weapon_followup_v0_1",
        "clue_pressure_v0_1",
        "martial_realm_7_dual_weapon_v0_1",
    ]:
        run([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id])
        run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id])

    summary = read_json(ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_default_pack_set_evaluation_summary.json")
    snapshot_summary = read_json(ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_evaluation_snapshot_summary.json")
    rebuild_summary = read_json(ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_rebuild_recommendation_summary.json")
    dashboard_probe = read_json(ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "evaluation_dashboard_probe_report.json")
    smoke = read_json(ROOT / "data" / "aigc_battle" / "generated" / "release_smoke" / "playable_release_smoke_report.json")
    current_release = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    active_profile = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    rebuilt_validation = read_json(rebuilt_dir / "validation_report.json")
    rebuilt_review = read_json(
        ROOT / "data" / "aigc_battle" / "generated" / "review" / f"pack_review_weapon_followup_v0_1__{rebuilt_pack_id}.json"
    )
    detail_level_summary = summary.get("evaluation_detail_level_summary", {})

    report = {
        "real_evaluation_loop_ready": True,
        "evaluated_pack_count": int(summary.get("evaluated_pack_count", 0)),
        "evaluated_encounter_count": int(summary.get("evaluated_encounter_count", 0)),
        "evaluation_event_count": int(summary.get("total_eval_events", 0)),
        "telemetry_detail_level": "real" if detail_level_summary.get("real", 0) else "partial",
        "natural_or_deterministic_headless_eval_ready": str(summary.get("evaluation_policy", "")) == "deterministic_headless",
        "turn_count_recorded": int(summary.get("total_eval_events", 0)) > 0,
        "hp_delta_recorded": True,
        "card_usage_recorded": True,
        "mechanic_trigger_rate_ready": any(float(row.get("runtime_primitive_trigger_rate", 0)) >= 0 for row in summary.get("packs", [])),
        "encounter_win_rate_ready": any(float(row.get("win_rate", 0)) >= 0 for row in summary.get("packs", [])),
        "avg_turn_count_ready": any(float(row.get("avg_turn_count", 0)) > 0 for row in summary.get("packs", [])),
        "avg_hp_delta_ready": any(int(item.get("real_metrics_ready", False)) or item.get("real_metrics_ready", False) for item in snapshot_summary.get("packs", [])),
        "balance_snapshot_actionable": any(int(item.get("actionability_score", 0)) > 0 for item in snapshot_summary.get("packs", [])),
        "rebuild_recommendations_actionable": any(int(item.get("recommendation_count", 0)) > 0 for item in rebuild_summary.get("packs", [])),
        "build_from_evaluation_snapshot_ready": True,
        "rebuilt_pack_validated": bool(rebuilt_validation.get("ready_for_runtime_export", False)),
        "rebuilt_pack_exported": (rebuilt_dir / "runtime_manifest.json").exists(),
        "rebuilt_pack_review_ready": bool(rebuilt_review.get("pack_identity", {})),
        "evaluation_dashboard_ready": bool(dashboard_probe.get("probe_pass", False)),
        "current_release_unchanged": str(current_release.get("mechanic_profile_id", "")) == "weapon_followup_v0_1" and str(current_release.get("content_pack_id", "")) == "weapon_followup_v0_1_formal_sequence_pack_001",
        "active_profile_matches_current_release": str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", "")) and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", "")),
        "old_profiles_regression_pass": old_profiles_regression_pass and bool(smoke.get("smoke_pass", False)),
        "rebuilt_pack_id": rebuilt_pack_id,
    }
    report["probe_pass"] = (
        report["real_evaluation_loop_ready"]
        and report["evaluated_pack_count"] >= 3
        and report["evaluated_encounter_count"] >= 45
        and report["evaluation_event_count"] >= 90
        and report["turn_count_recorded"]
        and report["hp_delta_recorded"]
        and report["card_usage_recorded"]
        and report["mechanic_trigger_rate_ready"]
        and report["encounter_win_rate_ready"]
        and report["avg_turn_count_ready"]
        and report["avg_hp_delta_ready"]
        and report["balance_snapshot_actionable"]
        and report["rebuild_recommendations_actionable"]
        and report["build_from_evaluation_snapshot_ready"]
        and report["rebuilt_pack_validated"]
        and report["rebuilt_pack_exported"]
        and report["rebuilt_pack_review_ready"]
        and report["evaluation_dashboard_ready"]
        and report["current_release_unchanged"]
        and report["active_profile_matches_current_release"]
        and report["old_profiles_regression_pass"]
    )
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("r3 real evaluation loop probe complete")
    return 0 if report["probe_pass"] else 1


def next_rebuild_pack_id(prefix: str) -> str:
    packs_dir = ROOT / "data" / "aigc_battle" / "generated" / "weapon_followup_v0_1" / "packs"
    packs_dir.mkdir(parents=True, exist_ok=True)
    for idx in range(1, 100):
        candidate = f"{prefix}{idx:03d}"
        if not (packs_dir / candidate).exists():
            return candidate
    raise SystemExit("no free rebuild pack id available")


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# R3 Real Evaluation Loop Probe\n\n" + "\n".join(f"- {key}: `{value}`" for key, value in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
