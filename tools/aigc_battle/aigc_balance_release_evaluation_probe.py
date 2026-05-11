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

from tools.aigc_battle import aigc_headless_evaluation_runner as eval_lib
from tools.aigc_battle import build_real_evaluation_snapshot as snapshot_lib
from tools.aigc_battle import switch_active_profile as switch_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "balance_release"
REPORT_JSON = OUT_DIR / "balance_release_evaluation_report.json"
REPORT_MD = OUT_DIR / "balance_release_evaluation_report.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="evaluate balanced release pack")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--source-pack", required=True)
    parser.add_argument("--balanced-pack", required=True)
    parser.add_argument("--samples", type=int, default=3)
    args = parser.parse_args(argv[1:])
    report = evaluate_balance_release(args.profile, args.source_pack, args.balanced_pack, args.samples)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("probe_pass", False) else 1


def evaluate_balance_release(profile_id: str, source_pack_id: str, balanced_pack_id: str, samples: int) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(source_pack_id, "source_pack_id")
    switch_lib.ensure_safe_id(balanced_pack_id, "balanced_pack_id")
    if samples < 3:
        raise SystemExit("samples_per_encounter must be >= 3")

    source_report = read_json(eval_lib.pack_report_json_path(profile_id, source_pack_id))
    source_snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, source_pack_id))

    run_serial([
        sys.executable,
        "tools/aigc_battle/aigc_headless_evaluation_runner.py",
        "--profile",
        profile_id,
        "--pack",
        balanced_pack_id,
        "--samples",
        str(samples),
    ])
    run_serial([
        sys.executable,
        "tools/aigc_battle/build_real_evaluation_snapshot.py",
        "--profile",
        profile_id,
        "--pack",
        balanced_pack_id,
    ])

    balanced_report = read_json(eval_lib.pack_report_json_path(profile_id, balanced_pack_id))
    balanced_snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, balanced_pack_id))
    balanced_pack_metrics = balanced_report.get("pack_metrics", {}) if isinstance(balanced_report.get("pack_metrics", {}), dict) else {}
    source_pack_metrics = source_report.get("pack_metrics", {}) if isinstance(source_report.get("pack_metrics", {}), dict) else {}
    source_generated_dir = eval_lib.resolve_generated_dir(profile_id, source_pack_id)
    balanced_generated_dir = eval_lib.resolve_generated_dir(profile_id, balanced_pack_id)
    source_validation = read_json(source_generated_dir / "validation_report.json")
    balanced_validation = read_json(balanced_generated_dir / "validation_report.json")

    source_win_rate = float(source_pack_metrics.get("win_rate", 0) or 0)
    balanced_win_rate = float(balanced_pack_metrics.get("win_rate", 0) or 0)
    source_avg_turn_count = float(source_pack_metrics.get("avg_turn_count", 0) or 0)
    balanced_avg_turn_count = float(balanced_pack_metrics.get("avg_turn_count", 0) or 0)
    source_avg_player_hp_end = float(source_pack_metrics.get("avg_player_hp_end", 0) or 0)
    balanced_avg_player_hp_end = float(balanced_pack_metrics.get("avg_player_hp_end", 0) or 0)
    source_too_hard_candidates = len(source_snapshot.get("too_hard_candidates", []))
    balanced_too_hard_candidates = len(balanced_snapshot.get("too_hard_candidates", []))
    source_too_long_candidates = len(source_snapshot.get("too_long_candidates", []))
    balanced_too_long_candidates = len(balanced_snapshot.get("too_long_candidates", []))
    source_reward_mismatch_candidates = len(source_snapshot.get("reward_mismatch_candidates", []))
    balanced_reward_mismatch_candidates = len(balanced_snapshot.get("reward_mismatch_candidates", []))
    weapon_followup_trigger_rate = float(balanced_pack_metrics.get("weapon_followup_trigger_rate", 0) or 0)
    overall_win_rate_improved = balanced_win_rate > source_win_rate
    too_hard_candidates_reduced = balanced_too_hard_candidates < source_too_hard_candidates
    too_long_candidates_reduced = balanced_too_long_candidates < source_too_long_candidates
    reward_mismatch_candidates_reduced = balanced_reward_mismatch_candidates < source_reward_mismatch_candidates
    absolute_win_rate_still_low = balanced_win_rate < 0.30
    warning_pass = absolute_win_rate_still_low and balanced_win_rate >= source_win_rate + 0.20

    playable_balance_gate_pass = (
        overall_win_rate_improved
        and balanced_win_rate >= 0.30
        and balanced_win_rate <= 0.85
        and too_hard_candidates_reduced
        and balanced_too_hard_candidates <= 7
        and too_long_candidates_reduced
        and balanced_too_long_candidates <= 7
        and reward_mismatch_candidates_reduced
        and balanced_reward_mismatch_candidates <= 5
        and weapon_followup_trigger_rate >= 0.6
        and balanced_avg_turn_count <= source_avg_turn_count
        and balanced_avg_player_hp_end > source_avg_player_hp_end
    )

    report = {
        "generated_at": now_iso(),
        "source_profile_id": profile_id,
        "source_pack_id": source_pack_id,
        "balanced_pack_id": balanced_pack_id,
        "samples_per_encounter": samples,
        "evaluated_encounter_count": int(balanced_report.get("formal_encounter_total_count", 0)),
        "evaluation_event_count": int(balanced_report.get("evaluation_event_count", 0)),
        "fallback_loadout_count": 0,
        "reward_coverage_complete": bool(balanced_validation.get("full_sequence_coverage_complete", False)),
        "sequence_balance_pass": bool(balanced_validation.get("sequence_balance_pass", False)),
        "weapon_followup_trigger_rate_ready": weapon_followup_trigger_rate >= 0.6,
        "source_win_rate": source_win_rate,
        "balanced_win_rate": balanced_win_rate,
        "source_avg_turn_count": source_avg_turn_count,
        "balanced_avg_turn_count": balanced_avg_turn_count,
        "source_avg_player_hp_end": source_avg_player_hp_end,
        "balanced_avg_player_hp_end": balanced_avg_player_hp_end,
        "source_too_hard_candidates": source_too_hard_candidates,
        "balanced_too_hard_candidates": balanced_too_hard_candidates,
        "source_too_long_candidates": source_too_long_candidates,
        "balanced_too_long_candidates": balanced_too_long_candidates,
        "source_reward_mismatch_candidates": source_reward_mismatch_candidates,
        "balanced_reward_mismatch_candidates": balanced_reward_mismatch_candidates,
        "weapon_followup_trigger_rate": weapon_followup_trigger_rate,
        "overall_win_rate_improved": overall_win_rate_improved,
        "too_hard_candidates_reduced": too_hard_candidates_reduced,
        "too_long_candidates_reduced": too_long_candidates_reduced,
        "reward_mismatch_candidates_reduced": reward_mismatch_candidates_reduced,
        "playable_balance_gate_pass": playable_balance_gate_pass,
        "absolute_win_rate_still_low": absolute_win_rate_still_low,
        "warning_pass": warning_pass,
        "balanced_pack_evaluated": True,
        "probe_pass": playable_balance_gate_pass,
    }
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding="utf-8")
    return report


def build_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Balance Release Evaluation Report",
        "",
        f"- source_pack_id: `{report.get('source_pack_id', '')}`",
        f"- balanced_pack_id: `{report.get('balanced_pack_id', '')}`",
        f"- source_win_rate: `{report.get('source_win_rate', 0)}`",
        f"- balanced_win_rate: `{report.get('balanced_win_rate', 0)}`",
        f"- source_avg_turn_count: `{report.get('source_avg_turn_count', 0)}`",
        f"- balanced_avg_turn_count: `{report.get('balanced_avg_turn_count', 0)}`",
        f"- source_too_hard_candidates: `{report.get('source_too_hard_candidates', 0)}`",
        f"- balanced_too_hard_candidates: `{report.get('balanced_too_hard_candidates', 0)}`",
        f"- source_too_long_candidates: `{report.get('source_too_long_candidates', 0)}`",
        f"- balanced_too_long_candidates: `{report.get('balanced_too_long_candidates', 0)}`",
        f"- weapon_followup_trigger_rate: `{report.get('weapon_followup_trigger_rate', 0)}`",
        f"- playable_balance_gate_pass: `{report.get('playable_balance_gate_pass', False)}`",
        f"- absolute_win_rate_still_low: `{report.get('absolute_win_rate_still_low', False)}`",
    ]
    return "\n".join(lines) + "\n"


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
