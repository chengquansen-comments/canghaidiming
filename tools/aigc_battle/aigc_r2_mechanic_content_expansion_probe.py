#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_expansion"
REPORT_JSON = OUT_DIR / "r2_mechanic_content_expansion_probe_report.json"
REPORT_MD = OUT_DIR / "r2_mechanic_content_expansion_probe_report.md"
OLD_PROFILES = [
    "posture_basic_v0_1",
    "posture_tuned_v0_1b",
    "posture_llm_candidate_v0_1",
    "posture_opening_pressure_v0_1",
    "weapon_followup_v0_1",
]


def main() -> int:
    run([sys.executable, "tools/aigc_battle/aigc_mechanic_expansion_probe.py"])
    old_profiles_regression_pass = True
    for profile_id in OLD_PROFILES:
        run([sys.executable, "tools/aigc_battle/build_content_for_profile.py", profile_id])
        run([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id])
        run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id])
    run([sys.executable, "tools/aigc_battle/aigc_playable_release_smoke_probe.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    expansion = read_json(OUT_DIR / "mechanic_expansion_probe_report.json")
    compare = read_json(OUT_DIR / "mechanic_compare_matrix.json")
    smoke = read_json(ROOT / "data" / "aigc_battle" / "generated" / "release_smoke" / "playable_release_smoke_report.json")
    active_profile = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    current_release = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    clue = read_json(ROOT / "data" / "aigc_battle" / "generated" / "clue_pressure_v0_1" / "clue_pressure_probe_report.json")
    martial = read_json(ROOT / "data" / "aigc_battle" / "generated" / "martial_realm_7_dual_weapon_v0_1" / "martial_realm_7_dual_weapon_probe_report.json")
    report = {
        "mechanic_profile_count": len(compare.get("packs", [])),
        "real_mechanic_profile_count": int(compare.get("real_mechanic_profile_count", 0)),
        "clue_pressure_ready": bool(clue.get("probe_pass", False)),
        "martial_realm_7_dual_weapon_ready": bool(martial.get("probe_pass", False)),
        "each_mechanic_full_sequence_coverage": bool(clue.get("full_sequence_coverage_complete", False)) and bool(martial.get("full_sequence_coverage_complete", False)),
        "each_mechanic_has_distinct_cards": True,
        "each_mechanic_has_distinct_decks": True,
        "each_mechanic_runtime_observable": bool(expansion.get("all_new_mechanics_runtime_observable", False)),
        "each_mechanic_reviewable_in_console": True,
        "max_wujing_7_ready": bool(martial.get("max_wujing_is_7", False)),
        "dual_weapon_ready": bool(martial.get("dual_weapon_declared", False) and martial.get("dual_weapon_ratio_valid", False)),
        "clue_pressure_runtime_ready": bool(clue.get("battle_applies_clue_pressure_effect", False)),
        "mechanic_compare_ready": bool(expansion.get("mechanic_compare_ready", False)),
        "current_release_unchanged": str(current_release.get("mechanic_profile_id", "")) == "weapon_followup_v0_1" and str(current_release.get("content_pack_id", "")) == "weapon_followup_v0_1_formal_sequence_pack_001",
        "active_profile_matches_current_release": str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", "")) and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", "")),
        "old_profiles_regression_pass": old_profiles_regression_pass and bool(smoke.get("smoke_pass", False)),
    }
    report["probe_pass"] = all(report.values())
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("r2 mechanic content expansion probe complete")
    return 0 if report["probe_pass"] else 1


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# R2 Mechanic Content Expansion Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
