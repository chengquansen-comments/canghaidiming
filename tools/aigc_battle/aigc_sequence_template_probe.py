#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_sequence_template_plan as plan_lib
from tools.aigc_battle import load_sequence_template as template_lib
from tools.aigc_battle import validate_sequence_template as validate_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "sequence_template_validation"
REPORT_JSON = OUT_DIR / "sequence_template_probe_report.json"
REPORT_MD = OUT_DIR / "sequence_template_probe_report.md"
TEMPLATES = ["formal_sequence_15_v1", "formal_sequence_12_fast_v1"]


def main() -> int:
    results: dict[str, dict[str, Any]] = {}
    for template_id in TEMPLATES:
        results[template_id] = probe_template(template_id)

    report = {
        "formal_sequence_15_v1_valid": bool(results["formal_sequence_15_v1"]["sequence_template_valid"]),
        "formal_sequence_12_fast_v1_valid": bool(results["formal_sequence_12_fast_v1"]["sequence_template_valid"]),
        "stage_plan_generated": all(item["stage_plan_generated"] for item in results.values()),
        "stage_count_sum_matches_total": all(item["stage_count_sum_matches_total"] for item in results.values()),
        "difficulty_curve_valid": all(item["difficulty_curve_valid"] for item in results.values()),
        "reward_curve_valid": all(item["reward_curve_valid"] for item in results.values()),
        "realm_curve_valid": all(item["realm_curve_valid"] for item in results.values()),
        "mechanic_density_curve_valid": all(item["mechanic_density_curve_valid"] for item in results.values()),
    }
    report["probe_pass"] = all(report.values())
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("sequence template probe complete")
    return 0 if report["probe_pass"] else 1


def probe_template(template_id: str) -> dict[str, Any]:
    template = template_lib.load_sequence_template(template_id)
    validation = validate_lib.validate_sequence_template(template_id)
    stage_plan = plan_lib.build_sequence_template_plan(template_id)
    return {
        "sequence_template_valid": bool(validation.get("sequence_template_valid", False)),
        "stage_plan_generated": len(stage_plan) == int(template.get("total_encounter_count", 0) or 0),
        "stage_count_sum_matches_total": bool(validation.get("stage_count_sum_matches_total", False)),
        "difficulty_curve_valid": bool(validation.get("difficulty_curve_valid", False)),
        "reward_curve_valid": bool(validation.get("reward_curve_valid", False)),
        "realm_curve_valid": bool(validation.get("realm_curve_valid", False)),
        "mechanic_density_curve_valid": bool(validation.get("mechanic_density_curve_valid", False)),
    }


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# R5 Sequence Template Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
