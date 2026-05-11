#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import load_sequence_template as template_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "sequence_template_validation"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        raise SystemExit("usage: validate_sequence_template.py <sequence_template_id>")
    template_id = argv[1]
    report = validate_sequence_template(template_id)
    report_path(template_id).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["sequence_template_valid"] else 1


def validate_sequence_template(template_id: str) -> dict[str, Any]:
    template = template_lib.load_sequence_template(template_id)
    total = int(template.get("total_encounter_count", 0) or 0)
    stage_counts = template.get("stage_counts", {})
    stages = template.get("stages", {})
    positions: list[int] = []
    encounter_kind_counts_valid = True
    reward_curve_valid = bool(template.get("reward_curve", {}).get("boss_reward_required", False))
    realm_curve_valid = int(template.get("realm_curve", {}).get("max_wujing", 0) or 0) == 7
    mechanic_density_curve_valid = True
    difficulty_curve_valid = True

    prev_power_min = -1
    for stage in template.get("stage_order", []):
        stage_payload = stages.get(stage, {})
        positions.extend(int(item) for item in stage_payload.get("sequence_positions", []))
        preferred = stage_payload.get("preferred_encounter_kind_counts", {})
        if sum(int(v) for v in preferred.values()) != int(stage_counts.get(stage, 0)):
            encounter_kind_counts_valid = False
        deck_power = stage_payload.get("deck_power_range", [0, 0])
        mechanic_density = stage_payload.get("mechanic_density_range", [0.0, 0.0])
        if deck_power[0] < prev_power_min:
            difficulty_curve_valid = False
        prev_power_min = int(deck_power[0])
        if float(mechanic_density[0]) > float(mechanic_density[1]):
            mechanic_density_curve_valid = False
        if not stage_payload.get("reward_tiers"):
            reward_curve_valid = False

    stage_count_sum_matches_total = sum(int(v) for v in stage_counts.values()) == total
    no_duplicate_sequence_positions = len(positions) == len(set(positions))
    stage_positions_complete = sorted(positions) == list(range(1, total + 1))

    report = {
        "sequence_template_loaded": True,
        "sequence_template_id_valid": str(template.get("sequence_template_id", "")) == template_id,
        "total_encounter_count_valid": total > 0,
        "stage_count_sum_matches_total": stage_count_sum_matches_total,
        "stage_positions_complete": stage_positions_complete,
        "no_duplicate_sequence_positions": no_duplicate_sequence_positions,
        "encounter_kind_counts_valid": encounter_kind_counts_valid,
        "difficulty_curve_valid": difficulty_curve_valid,
        "reward_curve_valid": reward_curve_valid,
        "realm_curve_valid": realm_curve_valid,
        "mechanic_density_curve_valid": mechanic_density_curve_valid,
    }
    report["sequence_template_valid"] = all(report.values())
    return report


def report_path(template_id: str) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    return OUT_DIR / f"{template_id}_validation_report.json"


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
