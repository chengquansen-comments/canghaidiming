#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_headless_evaluation_runner as eval_lib
from tools.aigc_battle import aigc_release_gate as release_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening"
REPORT_JSON = OUT_DIR / "hardened_candidates_evaluation_report.json"
REPORT_MD = OUT_DIR / "hardened_candidates_evaluation_report.md"
STRATEGY_JSON = OUT_DIR / "playable_hardening_strategy.json"
STRATEGY_MD = OUT_DIR / "playable_hardening_strategy.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="evaluate hardened candidates")
    parser.add_argument("--samples", type=int, default=4)
    args = parser.parse_args(argv[1:])
    result = evaluate_hardened_candidates(max(1, args.samples))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("hardened_candidates_evaluated", False) else 1


def evaluate_hardened_candidates(samples: int) -> dict[str, Any]:
    fast_build = read_json(OUT_DIR / "fast_hardened_build_report.json")
    boss_build = read_json(OUT_DIR / "bossrush_hardened_build_report.json")
    current = release_lib.show_channels().get("current_release", {})

    fast_source_pack_id = str(fast_build.get("source_pack_id", ""))
    fast_hardened_pack_id = str(fast_build.get("actual_pack_id", ""))
    boss_source_pack_id = str(boss_build.get("source_pack_id", ""))
    boss_hardened_pack_id = str(boss_build.get("actual_pack_id", ""))
    current_pack_id = str(current.get("content_pack_id", ""))
    current_profile_id = str(current.get("mechanic_profile_id", ""))

    fast_source_report = eval_lib.evaluate_pack("weapon_followup_v0_1", fast_source_pack_id, samples)
    fast_hardened_report = eval_lib.evaluate_pack("weapon_followup_v0_1", fast_hardened_pack_id, samples)
    boss_source_report = eval_lib.evaluate_pack("weapon_followup_v0_1", boss_source_pack_id, samples)
    boss_hardened_report = eval_lib.evaluate_pack("weapon_followup_v0_1", boss_hardened_pack_id, samples)
    current_report = eval_lib.evaluate_pack(current_profile_id, current_pack_id, samples)

    fast_metrics = flatten_metrics(fast_hardened_report)
    boss_metrics = flatten_metrics(boss_hardened_report)
    fast_source_metrics = flatten_metrics(fast_source_report)
    boss_source_metrics = flatten_metrics(boss_source_report)
    current_metrics = flatten_metrics(current_report)
    fast_gate = gate_fast(fast_metrics)
    boss_gate = gate_bossrush(boss_metrics)

    payload = {
        "generated_at": now_iso(),
        "evaluated_candidate_count": 2,
        "evaluation_event_count": int(
            fast_hardened_report.get("evaluation_event_count", 0)
            + boss_hardened_report.get("evaluation_event_count", 0)
            + current_report.get("evaluation_event_count", 0)
        ),
        "fast_source_pack_id": fast_source_pack_id,
        "fast_hardened_pack_id": fast_hardened_pack_id,
        "bossrush_source_pack_id": boss_source_pack_id,
        "bossrush_hardened_pack_id": boss_hardened_pack_id,
        "fast_source_metrics": fast_source_metrics,
        "fast_hardened_metrics": fast_metrics,
        "bossrush_source_metrics": boss_source_metrics,
        "bossrush_hardened_metrics": boss_metrics,
        "fast_target_gate_pass": fast_gate["pass"],
        "bossrush_target_gate_pass": boss_gate["pass"],
        "fast_win_rate": fast_metrics["win_rate"],
        "bossrush_win_rate": boss_metrics["win_rate"],
        "fast_avg_turn_count": fast_metrics["avg_turn_count"],
        "bossrush_avg_turn_count": boss_metrics["avg_turn_count"],
        "fast_too_hard_candidates": fast_metrics["too_hard_candidates"],
        "bossrush_too_hard_candidates": boss_metrics["too_hard_candidates"],
        "fast_too_long_candidates": fast_metrics["too_long_candidates"],
        "bossrush_too_long_candidates": boss_metrics["too_long_candidates"],
        "fast_reward_mismatch_candidates": fast_metrics["reward_mismatch_candidates"],
        "bossrush_reward_mismatch_candidates": boss_metrics["reward_mismatch_candidates"],
        "fast_weapon_followup_trigger_rate": fast_metrics["weapon_followup_trigger_rate"],
        "bossrush_weapon_followup_trigger_rate": boss_metrics["weapon_followup_trigger_rate"],
        "current_release_reference_still_playable": bool(current_metrics["win_rate"] >= 0.5 and current_metrics["avg_turn_count"] <= 6.0),
        "current_release_reference_metrics": current_metrics,
        "hardened_candidates_evaluated": True,
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    strategy = build_strategy(payload)
    write_json(STRATEGY_JSON, strategy)
    STRATEGY_MD.write_text(build_strategy_markdown(strategy), encoding="utf-8")
    return payload


def flatten_metrics(report: dict[str, Any]) -> dict[str, Any]:
    pack_metrics = report.get("pack_metrics", {})
    encounter_metrics = report.get("encounter_metrics", [])
    content_pack_id = str(report.get("content_pack_id", ""))
    too_long_threshold = long_turn_threshold(content_pack_id)
    return {
        "content_pack_id": content_pack_id,
        "total_encounter_count": int(report.get("formal_encounter_total_count", 0) or 0),
        "evaluation_event_count": int(report.get("evaluation_event_count", 0) or 0),
        "win_rate": float(pack_metrics.get("win_rate", 0) or 0),
        "avg_turn_count": float(pack_metrics.get("avg_turn_count", 0) or 0),
        "avg_player_hp_end": float(pack_metrics.get("avg_player_hp_end", 0) or 0),
        "too_hard_candidates": sum(1 for row in encounter_metrics if float(row.get("win_rate", 0) or 0) <= 0.35 or float(row.get("avg_player_hp_end", 0) or 0) <= 8),
        "too_long_candidates": sum(1 for row in encounter_metrics if float(row.get("avg_turn_count", 0) or 0) > too_long_threshold),
        "reward_mismatch_candidates": sum(1 for row in encounter_metrics if int(row.get("reward_mismatch_count", 0) or 0) > 0),
        "weapon_followup_trigger_rate": float(pack_metrics.get("weapon_followup_trigger_rate", 0) or 0),
        "runtime_primitive_trigger_rate": float(pack_metrics.get("runtime_primitive_trigger_rate", 0) or 0),
    }


def gate_fast(metrics: dict[str, Any]) -> dict[str, Any]:
    win_rate = round(float(metrics["win_rate"]), 2)
    passed = (
        0.45 <= win_rate <= 0.85
        and metrics["avg_turn_count"] <= 7.0
        and metrics["too_hard_candidates"] <= 4
        and metrics["too_long_candidates"] <= 4
        and metrics["reward_mismatch_candidates"] <= 3
        and metrics["weapon_followup_trigger_rate"] >= 0.60
    )
    return {"pass": passed}


def gate_bossrush(metrics: dict[str, Any]) -> dict[str, Any]:
    win_rate = round(float(metrics["win_rate"]), 2)
    passed = (
        0.30 <= win_rate <= 0.75
        and metrics["avg_turn_count"] <= 8.0
        and metrics["too_hard_candidates"] <= 4
        and metrics["too_long_candidates"] <= 4
        and metrics["reward_mismatch_candidates"] <= 2
        and metrics["weapon_followup_trigger_rate"] >= 0.70
    )
    return {"pass": passed}


def build_strategy(payload: dict[str, Any]) -> dict[str, Any]:
    fast_pass = bool(payload.get("fast_target_gate_pass", False))
    boss_pass = bool(payload.get("bossrush_target_gate_pass", False))
    return {
        "generated_at": now_iso(),
        "playable_hardening_ready": fast_pass and boss_pass,
        "recommended_standard_keep": "weapon_followup_balance_release_007",
        "recommended_fast_candidate": payload.get("fast_hardened_pack_id", "") if fast_pass else "",
        "recommended_bossrush_candidate": payload.get("bossrush_hardened_pack_id", "") if boss_pass else "",
        "targets_ready_for_release_candidate": [pack for pack, ok in [
            (payload.get("fast_hardened_pack_id", ""), fast_pass),
            (payload.get("bossrush_hardened_pack_id", ""), boss_pass),
        ] if pack and ok],
        "targets_needing_more_balance": [pack for pack, ok in [
            (payload.get("fast_hardened_pack_id", ""), fast_pass),
            (payload.get("bossrush_hardened_pack_id", ""), boss_pass),
        ] if pack and not ok],
    }


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        "# Hardened Candidates Evaluation",
        "",
        f"- fast_hardened_pack_id: `{payload.get('fast_hardened_pack_id', '')}`",
        f"- bossrush_hardened_pack_id: `{payload.get('bossrush_hardened_pack_id', '')}`",
        f"- fast_target_gate_pass: `{payload.get('fast_target_gate_pass', False)}`",
        f"- bossrush_target_gate_pass: `{payload.get('bossrush_target_gate_pass', False)}`",
        f"- current_release_reference_still_playable: `{payload.get('current_release_reference_still_playable', False)}`",
        "",
    ]) + "\n"


def build_strategy_markdown(strategy: dict[str, Any]) -> str:
    return "\n".join([
        "# Playable Hardening Strategy",
        "",
        f"- playable_hardening_ready: `{strategy.get('playable_hardening_ready', False)}`",
        f"- recommended_fast_candidate: `{strategy.get('recommended_fast_candidate', '')}`",
        f"- recommended_bossrush_candidate: `{strategy.get('recommended_bossrush_candidate', '')}`",
        f"- targets_ready_for_release_candidate: `{strategy.get('targets_ready_for_release_candidate', [])}`",
        f"- targets_needing_more_balance: `{strategy.get('targets_needing_more_balance', [])}`",
        "",
    ]) + "\n"


def long_turn_threshold(content_pack_id: str) -> float:
    if "__formal_sequence_12_fast_v1__" in content_pack_id:
        return 7.0
    if "__bossrush_9_v1__" in content_pack_id:
        return 8.0
    return 6.0


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
