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
from tools.aigc_battle import load_sequence_template as template_lib

GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio"
EVAL_JSON = GENERATED_DIR / "template_portfolio_evaluation_report.json"
EVAL_MD = GENERATED_DIR / "template_portfolio_evaluation_report.md"
STRATEGY_JSON = GENERATED_DIR / "template_release_strategy.json"
STRATEGY_MD = GENERATED_DIR / "template_release_strategy.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Evaluate R6 template portfolio")
    parser.add_argument("--mechanic", required=True)
    parser.add_argument("--samples", type=int, default=2)
    args = parser.parse_args(argv[1:])
    if str(args.mechanic).strip() != "weapon_followup_v0_1":
        raise SystemExit("R6 portfolio currently targets weapon_followup_v0_1 only")
    if args.samples <= 0:
        raise SystemExit("samples must be positive")
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    report, strategy = evaluate_portfolio(str(args.mechanic).strip(), args.samples)
    write_json(EVAL_JSON, report)
    EVAL_MD.write_text(build_eval_markdown(report), encoding="utf-8")
    write_json(STRATEGY_JSON, strategy)
    STRATEGY_MD.write_text(build_strategy_markdown(strategy), encoding="utf-8")
    print(f"evaluated template portfolio: packs={report['evaluated_pack_count']} events={report['evaluation_event_count']}")
    return 0 if report["template_portfolio_evaluated"] and strategy["template_release_strategy_ready"] else 1


def evaluate_portfolio(profile_id: str, samples: int) -> tuple[dict[str, Any], dict[str, Any]]:
    current_release = read_json(CURRENT_RELEASE_PATH)
    fallback_release = read_json(FALLBACK_RELEASE_PATH)
    packs = [
        {
            "template_id": str(current_release.get("sequence_template_id", template_lib.DEFAULT_SEQUENCE_TEMPLATE_ID)),
            "content_pack_id": str(current_release.get("content_pack_id", "")),
            "role": "standard_current_release",
        },
        {
            "template_id": "formal_sequence_12_fast_v1",
            "content_pack_id": "weapon_followup_v0_1__formal_sequence_12_fast_v1__portfolio_001",
            "role": "fast_run_candidate",
        },
        {
            "template_id": "bossrush_9_v1",
            "content_pack_id": "weapon_followup_v0_1__bossrush_9_v1__portfolio_001",
            "role": "boss_rush_candidate",
        },
        {
            "template_id": "elite_heavy_15_v1",
            "content_pack_id": "weapon_followup_v0_1__elite_heavy_15_v1__portfolio_001",
            "role": "elite_pressure_candidate",
        },
    ]

    rows: list[dict[str, Any]] = []
    evaluation_event_count = 0
    for pack in packs:
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_headless_evaluation_runner.py"), "--profile", profile_id, "--pack", pack["content_pack_id"], "--samples", str(samples)])
        run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_real_evaluation_snapshot.py"), "--profile", profile_id, "--pack", pack["content_pack_id"]])
        snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, pack["content_pack_id"]))
        pack_metrics = snapshot.get("pack_metrics", {})
        row = {
            "template_id": pack["template_id"],
            "content_pack_id": pack["content_pack_id"],
            "total_encounter_count": int(snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0),
            "win_rate": float(pack_metrics.get("win_rate", 0) or 0),
            "avg_turn_count": float(pack_metrics.get("avg_turn_count", 0) or 0),
            "avg_player_hp_end": float(pack_metrics.get("avg_player_hp_end", 0) or 0),
            "too_hard_candidates": len(snapshot.get("too_hard_candidates", [])),
            "too_long_candidates": len(snapshot.get("too_long_candidates", [])),
            "reward_mismatch_candidates": len(snapshot.get("reward_mismatch_candidates", [])),
            "mechanic_trigger_rate": float(snapshot.get("mechanic_metrics", {}).get("runtime_primitive_trigger_rate", 0) or 0),
            "stage_metrics": snapshot.get("stage_metrics", {}),
            "fallback_loadout_count": 0,
            "needs_balance": bool(
                float(pack_metrics.get("win_rate", 0) or 0) < 0.3
                or len(snapshot.get("too_hard_candidates", [])) > max(2, int((snapshot.get("formal_encounter_coverage", {}).get("expected", 0) or 0) * 0.4))
            ),
            "role": pack["role"],
            "snapshot_path": snapshot.get("snapshot_path", ""),
        }
        evaluation_event_count += int(snapshot.get("evaluation_event_count", 0) or 0)
        rows.append(row)

    current_row = rows[0]
    fast_row = next(row for row in rows if row["template_id"] == "formal_sequence_12_fast_v1")
    boss_row = next(row for row in rows if row["template_id"] == "bossrush_9_v1")
    elite_row = next(row for row in rows if row["template_id"] == "elite_heavy_15_v1")
    recommended = {
        "standard_run": current_row["template_id"],
        "fast_run": fast_row["template_id"] if is_fast_releasable(fast_row, current_row) else "",
        "boss_rush": boss_row["template_id"] if is_pressure_usable(boss_row) else "",
        "elite_pressure": elite_row["template_id"] if is_pressure_usable(elite_row) else "",
    }
    best_playable = max(rows, key=lambda item: (item["win_rate"], item["avg_player_hp_end"], -item["avg_turn_count"]))
    highest_pressure = min(rows, key=lambda item: (item["win_rate"], -item["avg_turn_count"], item["avg_player_hp_end"]))
    fastest = min(rows, key=lambda item: (item["avg_turn_count"], -item["win_rate"]))
    safest = max(rows, key=lambda item: (item["avg_player_hp_end"], item["win_rate"], -item["too_hard_candidates"]))
    ready_candidates = [row["template_id"] for row in rows[1:] if not row["needs_balance"] and row["win_rate"] >= 0.3]
    needs_balance = [row["template_id"] for row in rows[1:] if row["needs_balance"]]

    report = {
        "generated_at": now_iso(),
        "evaluated_template_count": len(rows),
        "evaluated_pack_count": len(rows),
        "evaluation_event_count": evaluation_event_count,
        "samples_per_template": samples,
        "template_metrics": rows,
        "recommended_template_usage": recommended,
        "best_playable_template": best_playable["template_id"],
        "highest_pressure_template": highest_pressure["template_id"],
        "fastest_template": fastest["template_id"],
        "safest_template": safest["template_id"],
        "current_release_baseline_comparison": {
            row["template_id"]: {
                "win_rate_delta": round(row["win_rate"] - current_row["win_rate"], 4),
                "avg_turn_delta": round(row["avg_turn_count"] - current_row["avg_turn_count"], 4),
                "player_hp_delta": round(row["avg_player_hp_end"] - current_row["avg_player_hp_end"], 4),
            }
            for row in rows
        },
        "template_portfolio_evaluated": True,
    }
    strategy = {
        "generated_at": now_iso(),
        "current_release_template": current_row["template_id"],
        "fallback_template": str(fallback_release.get("sequence_template_id", template_lib.DEFAULT_SEQUENCE_TEMPLATE_ID)),
        "candidate_templates": [row["template_id"] for row in rows[1:]],
        "recommended_standard_template": recommended["standard_run"],
        "recommended_fast_template": recommended["fast_run"],
        "recommended_bossrush_template": recommended["boss_rush"],
        "recommended_elite_template": recommended["elite_pressure"],
        "templates_ready_for_release_candidate": ready_candidates[:1],
        "templates_needing_balance": needs_balance,
        "template_release_strategy_ready": True,
    }
    return report, strategy


def is_fast_releasable(row: dict[str, Any], current_row: dict[str, Any]) -> bool:
    return (
        row["win_rate"] >= 0.3
        and row["avg_turn_count"] < current_row["avg_turn_count"]
        and row["too_hard_candidates"] <= max(4, current_row["too_hard_candidates"])
    )


def is_pressure_usable(row: dict[str, Any]) -> bool:
    return row["fallback_loadout_count"] == 0 and row["mechanic_trigger_rate"] >= 0.6 and row["win_rate"] >= 0.15


def build_eval_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Template Portfolio Evaluation",
        "",
        f"- evaluated_template_count: `{report.get('evaluated_template_count', 0)}`",
        f"- evaluated_pack_count: `{report.get('evaluated_pack_count', 0)}`",
        f"- evaluation_event_count: `{report.get('evaluation_event_count', 0)}`",
    ]
    for row in report.get("template_metrics", []):
        lines.append(
            f"- `{row['template_id']}` | pack=`{row['content_pack_id']}` | "
            f"encounters={row['total_encounter_count']} | win_rate={row['win_rate']} | "
            f"avg_turn={row['avg_turn_count']} | too_hard={row['too_hard_candidates']} | too_long={row['too_long_candidates']}"
        )
    return "\n".join(lines) + "\n"


def build_strategy_markdown(strategy: dict[str, Any]) -> str:
    lines = [
        "# Template Release Strategy",
        "",
        f"- current_release_template: `{strategy.get('current_release_template', '')}`",
        f"- recommended_standard_template: `{strategy.get('recommended_standard_template', '')}`",
        f"- recommended_fast_template: `{strategy.get('recommended_fast_template', '') or '-'}`",
        f"- recommended_bossrush_template: `{strategy.get('recommended_bossrush_template', '') or '-'}`",
        f"- recommended_elite_template: `{strategy.get('recommended_elite_template', '') or '-'}`",
        f"- templates_ready_for_release_candidate: `{', '.join(strategy.get('templates_ready_for_release_candidate', [])) or '-'}`",
        f"- templates_needing_balance: `{', '.join(strategy.get('templates_needing_balance', [])) or '-'}`",
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
