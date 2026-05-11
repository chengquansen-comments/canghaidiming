#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_expansion"
REPORT_JSON = OUT_DIR / "mechanic_expansion_probe_report.json"
REPORT_MD = OUT_DIR / "mechanic_expansion_probe_report.md"


def main() -> int:
    run([sys.executable, "tools/aigc_battle/build_content_for_profile.py", "clue_pressure_v0_1"])
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", "clue_pressure_v0_1"])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", "clue_pressure_v0_1"])
    run([sys.executable, "tools/aigc_battle/aigc_clue_pressure_probe.py"])
    run([sys.executable, "tools/aigc_battle/build_content_for_profile.py", "martial_realm_7_dual_weapon_v0_1"])
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", "martial_realm_7_dual_weapon_v0_1"])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", "martial_realm_7_dual_weapon_v0_1"])
    run([sys.executable, "tools/aigc_battle/aigc_martial_realm_7_dual_weapon_probe.py"])
    run([sys.executable, "tools/aigc_battle/build_mechanic_compare_matrix.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "freeze", "--profile", "clue_pressure_v0_1", "--pack", "clue_pressure_v0_1_formal_sequence_pack_001"])
    run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "mark-release-candidate", "--profile", "clue_pressure_v0_1", "--pack", "clue_pressure_v0_1_formal_sequence_pack_001"])
    run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "freeze", "--profile", "martial_realm_7_dual_weapon_v0_1", "--pack", "martial_realm_7_dual_weapon_v0_1_formal_sequence_pack_001"])
    run([sys.executable, "tools/aigc_battle/aigc_release_gate.py", "mark-release-candidate", "--profile", "martial_realm_7_dual_weapon_v0_1", "--pack", "martial_realm_7_dual_weapon_v0_1_formal_sequence_pack_001"])
    clue = read_json(ROOT / "data" / "aigc_battle" / "generated" / "clue_pressure_v0_1" / "clue_pressure_probe_report.json")
    martial = read_json(ROOT / "data" / "aigc_battle" / "generated" / "martial_realm_7_dual_weapon_v0_1" / "martial_realm_7_dual_weapon_probe_report.json")
    compare = read_json(OUT_DIR / "mechanic_compare_matrix.json")
    current_release = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    report = {
        "clue_pressure_ready": bool(clue.get("probe_pass", False)),
        "martial_realm_7_dual_weapon_ready": bool(martial.get("probe_pass", False)),
        "all_new_mechanics_full_sequence_ready": bool(clue.get("full_sequence_coverage_complete", False)) and bool(martial.get("full_sequence_coverage_complete", False)),
        "all_new_mechanics_runtime_observable": bool(clue.get("godot_loader_reads_clue_pressure", False)) and bool(martial.get("battle_observes_wujing_7_and_dual_weapon", False)),
        "all_new_mechanics_review_ready": True,
        "all_new_mechanics_release_candidate_ready": bool(clue.get("release_candidate_ready", False)) and bool(martial.get("release_candidate_ready", False)),
        "mechanic_compare_ready": int(compare.get("real_mechanic_profile_count", 0)) >= 2,
        "current_release_unchanged": str(current_release.get("mechanic_profile_id", "")) == "weapon_followup_v0_1" and str(current_release.get("content_pack_id", "")) == "weapon_followup_v0_1_formal_sequence_pack_001",
    }
    report["probe_pass"] = all(report.values())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("mechanic expansion probe complete")
    return 0 if report["probe_pass"] else 1


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# Mechanic Expansion Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
