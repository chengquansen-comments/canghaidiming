#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_real_evaluation_snapshot as snapshot_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix"
BUILD_JSON = OUT_DIR / "matrix_build_report.json"
EVAL_JSON = OUT_DIR / "matrix_evaluation_report.json"
EVAL_MD = OUT_DIR / "matrix_evaluation_report.md"
STRATEGY_JSON = OUT_DIR / "matrix_release_strategy.json"
STRATEGY_MD = OUT_DIR / "matrix_release_strategy.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Evaluate mechanic x template matrix")
    parser.add_argument("--samples", type=int, default=2)
    args = parser.parse_args(argv[1:])
    if args.samples <= 0:
        raise SystemExit("samples must be positive")
    build_report = read_json(BUILD_JSON)
    report, strategy = evaluate_matrix(build_report, args.samples)
    write_json(EVAL_JSON, report)
    EVAL_MD.write_text(build_eval_markdown(report), encoding="utf-8")
    write_json(STRATEGY_JSON, strategy)
    STRATEGY_MD.write_text(build_strategy_markdown(strategy), encoding="utf-8")
    print(f"evaluated mechanic template matrix: slots={report['evaluated_slot_count']} events={report['evaluation_event_count']}")
    return 0 if report["matrix_evaluation_ready"] and strategy["matrix_release_strategy_ready"] else 1


def evaluate_matrix(build_report: dict[str, Any], samples: int) -> tuple[dict[str, Any], dict[str, Any]]:
    current_release = read_json(CURRENT_RELEASE_PATH)
    current_pack_id = str(current_release.get("content_pack_id", ""))
    rows: list[dict[str, Any]] = []
    total_events = 0
    for slot in build_report.get("matrix_slots", []):
        profile_id = str(slot.get("mechanic_profile_id", ""))
        content_pack_id = str(slot.get("content_pack_id", ""))
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_headless_evaluation_runner.py"), "--profile", profile_id, "--pack", content_pack_id, "--samples", str(samples)])
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_real_evaluation_snapshot.py"), "--profile", profile_id, "--pack", content_pack_id])
        snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, content_pack_id))
        metrics = snapshot.get("pack_metrics", {})
        row = {
            "mechanic_profile_id": profile_id,
            "sequence_template_id": str(slot.get("sequence_template_id", "")),
            "content_pack_id": content_pack_id,
            "total_encounter_count": int(snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or slot.get("total_encounter_count", 0) or 0),
            "evaluation_event_count": int(snapshot.get("evaluation_event_count", 0) or 0),
            "win_rate": float(metrics.get("win_rate", 0) or 0),
            "avg_turn_count": float(metrics.get("avg_turn_count", 0) or 0),
            "avg_player_hp_end": float(metrics.get("avg_player_hp_end", 0) or 0),
            "too_hard_candidates": len(snapshot.get("too_hard_candidates", [])),
            "too_long_candidates": len(snapshot.get("too_long_candidates", [])),
            "reward_mismatch_candidates": len(snapshot.get("reward_mismatch_candidates", [])),
            "mechanic_trigger_rate": float(snapshot.get("mechanic_metrics", {}).get("runtime_primitive_trigger_rate", 0) or 0),
            "runtime_primitive_observed": bool(float(snapshot.get("mechanic_metrics", {}).get("runtime_primitive_trigger_rate", 0) or 0) > 0),
            "stage_metrics": snapshot.get("stage_metrics", {}),
            "evaluation_pass": bool(
                int(snapshot.get("formal_encounter_coverage", {}).get("covered", 0) or 0) == int(snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0)
            ),
            "ready_for_candidate_review": bool(
                float(metrics.get("win_rate", 0) or 0) >= 0.3
                and len(snapshot.get("too_hard_candidates", [])) <= max(4, int((snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0) * 0.45))
                and len(snapshot.get("too_long_candidates", [])) <= max(4, int((snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0) * 0.6))
            ),
            "needs_balance_before_release": bool(
                float(metrics.get("win_rate", 0) or 0) < 0.3
                or len(snapshot.get("too_hard_candidates", [])) > max(4, int((snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0) * 0.45))
                or len(snapshot.get("too_long_candidates", [])) > max(4, int((snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0) * 0.6))
                or len(snapshot.get("reward_mismatch_candidates", [])) > max(2, int((snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0) * 0.25))
            ),
            "matrix_slot": True,
            "matrix_build_variant": str(slot.get("build_variant", "")),
        }
        total_events += row["evaluation_event_count"]
        rows.append(row)

    best_overall = max(rows, key=lambda item: score_slot(item))
    safest = max(rows, key=lambda item: (item["win_rate"], -item["too_hard_candidates"], item["avg_player_hp_end"]))
    fastest = min(rows, key=lambda item: (item["avg_turn_count"], item["reward_mismatch_candidates"], -item["win_rate"]))
    highest_pressure = min(rows, key=lambda item: (-is_bossrush(item), item["win_rate"], item["avg_turn_count"], -item["mechanic_trigger_rate"]))
    best_mechanic_by_template = {
        template_id: slot_ref(max([row for row in rows if row["sequence_template_id"] == template_id], key=lambda item: score_slot(item)))
        for template_id in sorted({row["sequence_template_id"] for row in rows})
    }
    best_template_by_mechanic = {
        profile_id: slot_ref(max([row for row in rows if row["mechanic_profile_id"] == profile_id], key=lambda item: score_slot(item)))
        for profile_id in sorted({row["mechanic_profile_id"] for row in rows})
    }
    slots_needing_balance = [slot_ref(row) for row in rows if row["needs_balance_before_release"]]
    slots_ready = [slot_ref(row) for row in rows if row["ready_for_candidate_review"]]

    report = {
        "generated_at": now_iso(),
        "evaluated_slot_count": len(rows),
        "evaluation_event_count": total_events,
        "best_overall_slot": slot_ref(best_overall),
        "safest_slot": slot_ref(safest),
        "fastest_slot": slot_ref(fastest),
        "highest_pressure_slot": slot_ref(highest_pressure),
        "best_mechanic_by_template": best_mechanic_by_template,
        "best_template_by_mechanic": best_template_by_mechanic,
        "slots_needing_balance": slots_needing_balance,
        "slots_ready_for_candidate_review": slots_ready,
        "matrix_evaluation_ready": len(rows) == 9 and all(row["evaluation_pass"] for row in rows),
        "slots": rows,
        "current_release_baseline": {
            "mechanic_profile_id": str(current_release.get("mechanic_profile_id", "")),
            "content_pack_id": current_pack_id,
        },
    }
    strategy = {
        "generated_at": now_iso(),
        "recommended_current_keep": slot_ref(next(row for row in rows if row["content_pack_id"] == current_pack_id)),
        "recommended_standard_candidate": slot_ref(best_mechanic_row(rows, "formal_sequence_15_v1")),
        "recommended_fast_candidate": slot_ref(best_ready_row(rows, "formal_sequence_12_fast_v1")),
        "recommended_bossrush_candidate": slot_ref(best_ready_row(rows, "bossrush_9_v1")),
        "recommended_mechanic_showcase_candidate": slot_ref(max(rows, key=lambda item: (item["mechanic_trigger_rate"], item["win_rate"], -item["avg_turn_count"]))),
        "recommended_clue_pressure_template": slot_ref(best_profile_row(rows, "clue_pressure_v0_1")),
        "recommended_dual_weapon_template": slot_ref(best_profile_row(rows, "martial_realm_7_dual_weapon_v0_1")),
        "recommended_weapon_followup_template": slot_ref(best_profile_row(rows, "weapon_followup_v0_1")),
        "slots_ready_for_release_candidate": slots_ready[:2],
        "slots_need_balance_before_release": slots_needing_balance,
        "slots_not_recommended": [slot_ref(row) for row in rows if not row["ready_for_candidate_review"]],
        "matrix_release_strategy_ready": True,
    }
    return report, strategy


def score_slot(row: dict[str, Any]) -> tuple[float, float, float, float]:
    return (
        float(row["win_rate"]) - float(row["too_hard_candidates"]) * 0.05 - float(row["too_long_candidates"]) * 0.03,
        float(row["mechanic_trigger_rate"]),
        float(row["avg_player_hp_end"]),
        -float(row["avg_turn_count"]),
    )


def is_bossrush(row: dict[str, Any]) -> int:
    return 1 if row["sequence_template_id"] == "bossrush_9_v1" else 0


def best_ready_row(rows: list[dict[str, Any]], template_id: str) -> dict[str, Any]:
    candidates = [row for row in rows if row["sequence_template_id"] == template_id and row["ready_for_candidate_review"]]
    if candidates:
        return max(candidates, key=lambda item: score_slot(item))
    return max([row for row in rows if row["sequence_template_id"] == template_id], key=lambda item: score_slot(item))


def best_profile_row(rows: list[dict[str, Any]], profile_id: str) -> dict[str, Any]:
    return max([row for row in rows if row["mechanic_profile_id"] == profile_id], key=lambda item: score_slot(item))


def best_mechanic_row(rows: list[dict[str, Any]], template_id: str) -> dict[str, Any]:
    return max([row for row in rows if row["sequence_template_id"] == template_id], key=lambda item: score_slot(item))


def slot_ref(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "mechanic_profile_id": row["mechanic_profile_id"],
        "sequence_template_id": row["sequence_template_id"],
        "content_pack_id": row["content_pack_id"],
    }


def build_eval_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Mechanic Template Matrix Evaluation",
        "",
        f"- evaluated_slot_count: `{report.get('evaluated_slot_count', 0)}`",
        f"- evaluation_event_count: `{report.get('evaluation_event_count', 0)}`",
        f"- best_overall_slot: `{json.dumps(report.get('best_overall_slot', {}), ensure_ascii=False)}`",
    ]
    for row in report.get("slots", []):
        lines.append(
            f"- {row['mechanic_profile_id']} x {row['sequence_template_id']} | "
            f"win_rate={row['win_rate']} | avg_turn={row['avg_turn_count']} | too_hard={row['too_hard_candidates']} | ready={row['ready_for_candidate_review']}"
        )
    return "\n".join(lines) + "\n"


def build_strategy_markdown(strategy: dict[str, Any]) -> str:
    lines = [
        "# Matrix Release Strategy",
        "",
        f"- recommended_standard_candidate: `{json.dumps(strategy.get('recommended_standard_candidate', {}), ensure_ascii=False)}`",
        f"- recommended_fast_candidate: `{json.dumps(strategy.get('recommended_fast_candidate', {}), ensure_ascii=False)}`",
        f"- recommended_bossrush_candidate: `{json.dumps(strategy.get('recommended_bossrush_candidate', {}), ensure_ascii=False)}`",
        f"- recommended_mechanic_showcase_candidate: `{json.dumps(strategy.get('recommended_mechanic_showcase_candidate', {}), ensure_ascii=False)}`",
    ]
    return "\n".join(lines) + "\n"


def run_step(cmd: list[str]) -> None:
    subprocess.run(cmd, cwd=ROOT, check=True)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
