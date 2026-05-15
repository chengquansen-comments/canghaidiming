#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening"
PLAN_JSON = OUT_DIR / "playable_hardening_plan.json"
PLAN_MD = OUT_DIR / "playable_hardening_plan.md"
MATRIX_EVAL_PATH = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix" / "matrix_evaluation_report.json"
MATRIX_STRATEGY_PATH = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix" / "matrix_release_strategy.json"

TARGETS = {
    "fast": {
        "source_pack_id": "weapon_followup_v0_1__formal_sequence_12_fast_v1__matrix_001",
        "target_pack_id": "weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_001",
        "sequence_template_id": "formal_sequence_12_fast_v1",
        "mechanic_profile_id": "weapon_followup_v0_1",
        "balance_direction": "reduce_enemy_pressure_and_drag_keep_fast_pacing",
        "expected_actions": [
            "reduce_enemy_pressure",
            "reduce_defensive_drag",
            "upgrade_reward_tier",
            "improve_followup_chain",
        ],
        "hardening_priority": "high",
        "target_metrics": {
            "target_win_rate_min": 0.45,
            "target_win_rate_max": 0.85,
            "target_avg_turn_count_max": 7.0,
            "target_too_hard_candidates_max": 4,
            "target_too_long_candidates_max": 4,
            "target_reward_mismatch_candidates_max": 3,
            "target_weapon_followup_trigger_rate_min": 0.60,
        },
    },
    "bossrush": {
        "source_pack_id": "weapon_followup_v0_1__bossrush_9_v1__matrix_001",
        "target_pack_id": "weapon_followup_v0_1__bossrush_9_v1__hardened_001",
        "sequence_template_id": "bossrush_9_v1",
        "mechanic_profile_id": "weapon_followup_v0_1",
        "balance_direction": "reduce_pressure_keep_bossrush_identity",
        "expected_actions": [
            "reduce_enemy_pressure",
            "reduce_defensive_drag",
            "upgrade_reward_tier",
            "improve_followup_chain",
        ],
        "hardening_priority": "high",
        "target_metrics": {
            "target_win_rate_min": 0.30,
            "target_win_rate_max": 0.75,
            "target_avg_turn_count_max": 8.0,
            "target_too_hard_candidates_max": 4,
            "target_too_long_candidates_max": 4,
            "target_reward_mismatch_candidates_max": 2,
            "target_weapon_followup_trigger_rate_min": 0.70,
        },
    },
}


def main() -> int:
    payload = build_plan()
    write_json(PLAN_JSON, payload)
    PLAN_MD.write_text(build_markdown(payload), encoding="utf-8")
    print("built playable hardening plan")
    return 0


def build_plan() -> dict[str, Any]:
    matrix_eval = read_json(MATRIX_EVAL_PATH)
    matrix_strategy = read_json(MATRIX_STRATEGY_PATH)
    slot_map = {
        (str(item.get("mechanic_profile_id", "")), str(item.get("sequence_template_id", "")), str(item.get("content_pack_id", ""))): item
        for item in matrix_eval.get("slots", [])
    }
    hardening_targets: list[dict[str, Any]] = []
    for target, config in TARGETS.items():
        source_metrics = slot_map.get(
            (config["mechanic_profile_id"], config["sequence_template_id"], config["source_pack_id"]),
            {},
        )
        hardening_targets.append({
            "target": target,
            **config,
            "source_metrics": source_metrics,
        })

    current = release_lib.show_channels().get("current_release", {})
    payload = {
        "generated_at": now_iso(),
        "playable_hardening_plan_ready": True,
        "fast_target_selected": True,
        "bossrush_target_selected": True,
        "current_release_should_remain_unchanged": True,
        "current_release_reference": current,
        "matrix_strategy_reference": {
            "recommended_fast_candidate": matrix_strategy.get("recommended_fast_candidate", {}),
            "recommended_bossrush_candidate": matrix_strategy.get("recommended_bossrush_candidate", {}),
            "recommended_standard_candidate": matrix_strategy.get("recommended_standard_candidate", {}),
        },
        "hardening_targets": hardening_targets,
    }
    return payload


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Playable Hardening Plan",
        "",
        f"- playable_hardening_plan_ready: `{payload.get('playable_hardening_plan_ready', False)}`",
        f"- current_release_should_remain_unchanged: `{payload.get('current_release_should_remain_unchanged', False)}`",
        "",
    ]
    for item in payload.get("hardening_targets", []):
        metrics = item.get("source_metrics", {})
        lines.extend([
            f"## {item.get('target', '')}",
            "",
            f"- source_pack_id: `{item.get('source_pack_id', '')}`",
            f"- target_pack_id: `{item.get('target_pack_id', '')}`",
            f"- sequence_template_id: `{item.get('sequence_template_id', '')}`",
            f"- balance_direction: `{item.get('balance_direction', '')}`",
            f"- expected_actions: `{', '.join(item.get('expected_actions', []))}`",
            f"- source_win_rate: `{metrics.get('win_rate', 0)}`",
            f"- source_avg_turn_count: `{metrics.get('avg_turn_count', 0)}`",
            f"- source_too_hard_candidates: `{metrics.get('too_hard_candidates', 0)}`",
            f"- source_too_long_candidates: `{metrics.get('too_long_candidates', 0)}`",
            f"- source_reward_mismatch_candidates: `{metrics.get('reward_mismatch_candidates', 0)}`",
            "",
        ])
    return "\n".join(lines) + "\n"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main())
