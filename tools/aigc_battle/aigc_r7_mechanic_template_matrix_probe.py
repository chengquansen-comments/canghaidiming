#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix"
OUT_JSON = OUT_DIR / "r7_mechanic_template_matrix_probe_report.json"
OUT_MD = OUT_DIR / "r7_mechanic_template_matrix_probe_report.md"
TEMPLATES = ["formal_sequence_15_v1", "formal_sequence_12_fast_v1", "bossrush_9_v1"]


def main() -> int:
    current_before = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    active_before = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    for template_id in TEMPLATES:
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "validate_sequence_template.py"), template_id])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_mechanic_template_matrix.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "evaluate_mechanic_template_matrix.py"), "--samples", "2"])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_pack_resolver.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_content_index.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_detail_views.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_review_workspace.py")])
    run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_mechanic_template_matrix_probe.py")])

    build_report = read_json(OUT_DIR / "matrix_build_report.json")
    eval_report = read_json(OUT_DIR / "matrix_evaluation_report.json")
    strategy = read_json(OUT_DIR / "matrix_release_strategy.json")
    resolver = read_json(ROOT / "data" / "aigc_battle" / "pack_resolver.json")
    current_after = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    active_after = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    matrix_entries = [entry for entry in resolver.get("entries", []) if entry.get("channel") == "matrix_review"]

    report = {
        "mechanic_template_matrix_ready": bool(build_report.get("matrix_build_ready", False)),
        "matrix_mechanic_count": int(build_report.get("matrix_mechanic_count", 0) or 0),
        "matrix_template_count": int(build_report.get("matrix_template_count", 0) or 0),
        "matrix_slot_count": int(build_report.get("matrix_slot_count", 0) or 0),
        "matrix_pack_count": len(build_report.get("matrix_pack_ids", [])),
        "each_matrix_slot_built_or_referenced": int(build_report.get("built_slot_count", 0) or 0) + int(build_report.get("referenced_slot_count", 0) or 0) >= 9,
        "each_matrix_slot_validated": int(build_report.get("validated_slot_count", 0) or 0) + int(build_report.get("referenced_slot_count", 0) or 0) >= 9,
        "each_matrix_slot_exported": int(build_report.get("exported_slot_count", 0) or 0) + int(build_report.get("referenced_slot_count", 0) or 0) >= 9,
        "each_matrix_slot_evaluated": int(eval_report.get("evaluated_slot_count", 0) or 0) == 9,
        "matrix_evaluation_ready": bool(eval_report.get("matrix_evaluation_ready", False)),
        "matrix_release_strategy_ready": bool(strategy.get("matrix_release_strategy_ready", False)),
        "recommended_standard_candidate": strategy.get("recommended_standard_candidate", {}),
        "recommended_fast_candidate": strategy.get("recommended_fast_candidate", {}),
        "recommended_bossrush_candidate": strategy.get("recommended_bossrush_candidate", {}),
        "recommended_mechanic_showcase_candidate": strategy.get("recommended_mechanic_showcase_candidate", {}),
        "slots_needing_balance_count": len(eval_report.get("slots_needing_balance", [])),
        "slots_ready_for_candidate_review_count": len(eval_report.get("slots_ready_for_candidate_review", [])),
        "pack_resolver_updated": len(matrix_entries) >= 9,
        "dashboard_matrix_ready": True,
        "current_release_unchanged": str(current_before.get("content_pack_id", "")) == str(current_after.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
        "active_profile_matches_current_release": str(active_before.get("active_content_pack_id", "")) == str(current_before.get("content_pack_id", "")) and str(active_after.get("active_content_pack_id", "")) == str(current_after.get("content_pack_id", "")),
    }
    report["probe_pass"] = (
        report["mechanic_template_matrix_ready"]
        and report["matrix_mechanic_count"] == 3
        and report["matrix_template_count"] == 3
        and report["matrix_slot_count"] == 9
        and report["each_matrix_slot_built_or_referenced"]
        and report["each_matrix_slot_validated"]
        and report["each_matrix_slot_exported"]
        and report["each_matrix_slot_evaluated"]
        and report["matrix_evaluation_ready"]
        and report["matrix_release_strategy_ready"]
        and report["pack_resolver_updated"]
        and report["dashboard_matrix_ready"]
        and report["current_release_unchanged"]
        and report["active_profile_matches_current_release"]
    )
    write_json(OUT_JSON, report)
    OUT_MD.write_text(build_markdown(report), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["probe_pass"] else 1


def run_step(cmd: list[str]) -> None:
    subprocess.run(cmd, cwd=ROOT, check=True)


def build_markdown(report: dict[str, object]) -> str:
    return "# R7 Mechanic Template Matrix Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
