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
        raise SystemExit("usage: build_sequence_template_plan.py <sequence_template_id>")
    template_id = argv[1]
    plan = build_sequence_template_plan(template_id)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / f"{template_id}_stage_plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"built sequence template plan: {template_id}")
    return 0


def build_sequence_template_plan(template_id: str) -> list[dict[str, Any]]:
    template = template_lib.load_sequence_template(template_id)
    plan: list[dict[str, Any]] = []
    for stage_index, stage in enumerate(template.get("stage_order", []), start=1):
        payload = template.get("stages", {}).get(stage, {})
        kinds = expand_kind_plan(payload)
        reward_tiers = list(payload.get("reward_tiers", []))
        caps = interpolate_int_range(payload.get("player_wujing_cap_range", [1, 1]), len(payload.get("sequence_positions", [])))
        power_ranges = interpolate_range(payload.get("deck_power_range", [0, 0]), len(payload.get("sequence_positions", [])))
        density_ranges = interpolate_float_range(payload.get("mechanic_density_range", [0.0, 0.0]), len(payload.get("sequence_positions", [])))
        for idx, sequence_position in enumerate(payload.get("sequence_positions", [])):
            plan.append(
                {
                    "sequence_template_id": template_id,
                    "sequence_position": int(sequence_position),
                    "stage": stage,
                    "stage_index": stage_index,
                    "encounter_kind": kinds[idx],
                    "player_wujing_cap": caps[idx],
                    "target_power_min": power_ranges[idx][0],
                    "target_power_max": power_ranges[idx][1],
                    "reward_tier": reward_tiers[min(idx, len(reward_tiers) - 1)] if reward_tiers else stage,
                    "mechanic_density_target": density_ranges[idx],
                    "difficulty_label": str(payload.get("difficulty_label", "")),
                }
            )
    return sorted(plan, key=lambda item: item["sequence_position"])


def expand_kind_plan(payload: dict[str, Any]) -> list[str]:
    preferred = payload.get("preferred_encounter_kind_counts", {})
    values: list[str] = []
    for kind, count in preferred.items():
        values.extend([str(kind)] * int(count))
    if len(values) != len(payload.get("sequence_positions", [])):
        allowed = list(payload.get("allowed_encounter_kinds", []))
        while len(values) < len(payload.get("sequence_positions", [])):
            values.append(str(allowed[min(len(values), len(allowed) - 1)] if allowed else "normal"))
        values = values[: len(payload.get("sequence_positions", []))]
    return values


def interpolate_int_range(bounds: list[Any], count: int) -> list[int]:
    low, high = int(bounds[0]), int(bounds[1])
    if count <= 1:
        return [high]
    return [round(low + (high - low) * (idx / (count - 1))) for idx in range(count)]


def interpolate_range(bounds: list[Any], count: int) -> list[tuple[int, int]]:
    low, high = int(bounds[0]), int(bounds[1])
    return [(low, high) for _ in range(max(count, 1))]


def interpolate_float_range(bounds: list[Any], count: int) -> list[float]:
    low, high = float(bounds[0]), float(bounds[1])
    if count <= 1:
        return [round(high, 2)]
    return [round(low + (high - low) * (idx / (count - 1)), 2) for idx in range(count)]


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
