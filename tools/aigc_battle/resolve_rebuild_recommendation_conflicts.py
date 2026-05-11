#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_build_from_evaluation_snapshot as rebuild_lib
from tools.aigc_battle import build_rebuild_recommendations as rec_lib
from tools.aigc_battle import build_real_evaluation_snapshot as snapshot_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "balance_release"
REPORT_JSON = OUT_DIR / "recommendation_conflict_report.json"
REPORT_MD = OUT_DIR / "recommendation_conflict_report.md"
RESOLVED_JSON = OUT_DIR / "resolved_rebuild_recommendations.json"
RESOLVED_MD = OUT_DIR / "resolved_rebuild_recommendations.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="resolve conflicting rebuild recommendations")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    report = resolve_conflicts(args.profile, args.pack)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("conflict_resolved", False) else 1


def resolve_conflicts(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")
    snapshot = read_json(snapshot_lib.snapshot_json_path(profile_id, content_pack_id))
    recommendations = read_json(rec_lib.rebuild_json_path(profile_id, content_pack_id))
    review_json = read_json(review_lib.pack_review_json_path(profile_id, content_pack_id))
    validation = read_json(rebuild_lib.resolve_source_generated_dir(profile_id, content_pack_id) / "validation_report.json")

    pack_metrics = snapshot.get("pack_metrics", {}) if isinstance(snapshot.get("pack_metrics", {}), dict) else {}
    encounter_metrics = snapshot.get("encounter_metrics", []) if isinstance(snapshot.get("encounter_metrics", []), list) else []
    encounter_by_slot = {str(row.get("generated_battle_slot_id", "")): row for row in encounter_metrics}
    too_hard_coverage = ratio(len(snapshot.get("too_hard_candidates", [])), max(len(encounter_metrics), 1))
    too_easy_coverage = ratio(len(snapshot.get("too_easy_candidates", [])), max(len(encounter_metrics), 1))
    pack_overall_too_hard = float(pack_metrics.get("win_rate", 0) or 0) < 0.25 or too_hard_coverage > 0.5
    pack_overall_too_easy = too_easy_coverage > 0.5

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    global_rows: list[dict[str, Any]] = []
    for row in recommendations.get("recommendations", []):
        slot_id = str(row.get("generated_battle_slot_id", "") or row.get("formal_encounter_id", ""))
        if slot_id:
            grouped[slot_id].append(dict(row))
        else:
            global_rows.append(dict(row))

    resolved: list[dict[str, Any]] = []
    removed: list[dict[str, Any]] = []
    downgraded: list[dict[str, Any]] = []

    for row in global_rows:
        outcome = resolve_global_recommendation(row, pack_overall_too_hard, pack_overall_too_easy)
        if outcome["decision"] == "keep":
            resolved.append(outcome["row"])
        elif outcome["decision"] == "downgrade":
            downgraded.append(outcome["row"])
        else:
            removed.append(outcome["row"])

    for slot_id, rows in grouped.items():
        encounter = encounter_by_slot.get(slot_id, {})
        resolved_rows, removed_rows, downgraded_rows = resolve_encounter_rows(
            rows,
            encounter,
            pack_overall_too_hard=pack_overall_too_hard,
            pack_overall_too_easy=pack_overall_too_easy,
        )
        resolved.extend(resolved_rows)
        removed.extend(removed_rows)
        downgraded.extend(downgraded_rows)

    before_counts = Counter(str(row.get("action_type", "")) for row in recommendations.get("recommendations", []))
    after_counts = Counter(str(row.get("action_type", "")) for row in resolved)
    payload = {
        "generated_at": now_iso(),
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "original_recommendation_count": len(recommendations.get("recommendations", [])),
        "resolved_recommendation_count": len(resolved),
        "conflict_count": len(removed) + len(downgraded),
        "removed_conflict_count": len(removed),
        "downgraded_to_designer_review_count": len(downgraded),
        "pack_overall_too_hard": pack_overall_too_hard,
        "pack_overall_too_easy": pack_overall_too_easy,
        "action_type_counts_before": dict(before_counts),
        "action_type_counts_after": dict(after_counts),
        "conflicting_recommendations": removed + downgraded,
        "resolved_recommendations": resolved,
        "review_summary_path": review_lib.pack_review_json_path(profile_id, content_pack_id).relative_to(ROOT).as_posix(),
        "validation_report_path": (rebuild_lib.resolve_source_generated_dir(profile_id, content_pack_id) / "validation_report.json").relative_to(ROOT).as_posix(),
        "conflict_resolved": bool(validation.get("ready_for_runtime_export", False)) and (not pack_overall_too_hard or after_counts.get("increase_deck_power", 0) == 0),
    }
    report = dict(payload)
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_report_markdown(report), encoding="utf-8")
    resolved_payload = {
        **payload,
        "recommendations": resolved,
        "conflict_removed": removed,
        "designer_review_recommendations": downgraded,
    }
    write_json(RESOLVED_JSON, resolved_payload)
    RESOLVED_MD.write_text(build_resolved_markdown(resolved_payload), encoding="utf-8")
    return report


def resolve_global_recommendation(row: dict[str, Any], pack_overall_too_hard: bool, pack_overall_too_easy: bool) -> dict[str, Any]:
    action = str(row.get("action_type", ""))
    if pack_overall_too_hard and action == "increase_deck_power":
        return {"decision": "remove", "row": annotate_conflict(row, "removed", "pack_overall_too_hard")}
    if pack_overall_too_easy and action == "reduce_deck_power":
        downgraded = dict(row)
        downgraded["safe_to_auto_apply"] = False
        downgraded["requires_designer_review"] = True
        return {"decision": "downgrade", "row": annotate_conflict(downgraded, "downgraded", "pack_overall_too_easy")}
    return {"decision": "keep", "row": row}


def resolve_encounter_rows(
    rows: list[dict[str, Any]],
    encounter: dict[str, Any],
    *,
    pack_overall_too_hard: bool,
    pack_overall_too_easy: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    keep: list[dict[str, Any]] = []
    removed: list[dict[str, Any]] = []
    downgraded: list[dict[str, Any]] = []

    reduce_rows = [row for row in rows if str(row.get("action_type", "")) == "reduce_deck_power"]
    increase_rows = [row for row in rows if str(row.get("action_type", "")) == "increase_deck_power"]
    other_rows = [row for row in rows if str(row.get("action_type", "")) not in {"reduce_deck_power", "increase_deck_power"}]

    if pack_overall_too_hard:
        keep.extend(reduce_rows)
        removed.extend(annotate_conflict(row, "removed", "pack_overall_too_hard") for row in increase_rows)
    elif pack_overall_too_easy:
        keep.extend(increase_rows)
        downgraded.extend(
            annotate_conflict({**row, "safe_to_auto_apply": False, "requires_designer_review": True}, "downgraded", "pack_overall_too_easy")
            for row in reduce_rows
        )
    elif reduce_rows and increase_rows:
        selected = choose_power_direction(encounter)
        if selected == "reduce":
            keep.extend(reduce_rows[:1])
            removed.extend(annotate_conflict(row, "removed", "encounter_prefers_reduce_deck_power") for row in increase_rows)
            removed.extend(annotate_conflict(row, "removed", "duplicate_reduce_deck_power") for row in reduce_rows[1:])
        else:
            keep.extend(increase_rows[:1])
            removed.extend(annotate_conflict(row, "removed", "encounter_prefers_increase_deck_power") for row in reduce_rows)
            removed.extend(annotate_conflict(row, "removed", "duplicate_increase_deck_power") for row in increase_rows[1:])
    else:
        keep.extend(reduce_rows[:1])
        keep.extend(increase_rows[:1])
        removed.extend(annotate_conflict(row, "removed", "duplicate_power_adjustment") for row in reduce_rows[1:] + increase_rows[1:])

    for row in other_rows:
        action = str(row.get("action_type", ""))
        if action == "improve_followup_chain" and pack_overall_too_hard:
            updated = dict(row)
            updated["safe_to_auto_apply"] = True
            updated["requires_designer_review"] = False
            keep.append(updated)
        elif action == "adjust_reward_tier":
            updated = dict(row)
            updated["safe_to_auto_apply"] = True
            updated["requires_designer_review"] = False
            keep.append(updated)
        else:
            keep.append(row)
    return keep, removed, downgraded


def choose_power_direction(encounter: dict[str, Any]) -> str:
    win_rate = float(encounter.get("win_rate", 0) or 0)
    avg_turn_count = float(encounter.get("avg_turn_count", 0) or 0)
    avg_player_hp_end = float(encounter.get("avg_player_hp_end", 0) or 0)
    if win_rate < 0.4 or avg_player_hp_end <= 6 or avg_turn_count >= 6:
        return "reduce"
    return "increase"


def annotate_conflict(row: dict[str, Any], status: str, reason: str) -> dict[str, Any]:
    updated = dict(row)
    updated["conflict_status"] = status
    updated["conflict_reason"] = reason
    return updated


def build_report_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Recommendation Conflict Report",
        "",
        f"- original_recommendation_count: `{report.get('original_recommendation_count', 0)}`",
        f"- resolved_recommendation_count: `{report.get('resolved_recommendation_count', 0)}`",
        f"- conflict_count: `{report.get('conflict_count', 0)}`",
        f"- removed_conflict_count: `{report.get('removed_conflict_count', 0)}`",
        f"- downgraded_to_designer_review_count: `{report.get('downgraded_to_designer_review_count', 0)}`",
        f"- pack_overall_too_hard: `{report.get('pack_overall_too_hard', False)}`",
        f"- pack_overall_too_easy: `{report.get('pack_overall_too_easy', False)}`",
        f"- conflict_resolved: `{report.get('conflict_resolved', False)}`",
        "",
        "## Action Counts",
        f"- before: `{json.dumps(report.get('action_type_counts_before', {}), ensure_ascii=False)}`",
        f"- after: `{json.dumps(report.get('action_type_counts_after', {}), ensure_ascii=False)}`",
    ]
    return "\n".join(lines) + "\n"


def build_resolved_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Resolved Rebuild Recommendations",
        "",
        f"- recommendation_count: `{len(payload.get('recommendations', []))}`",
        "",
        "## Recommendations",
    ]
    for row in payload.get("recommendations", []):
        lines.append(
            f"- `{row.get('action_type', '')}` | encounter={row.get('formal_encounter_id', '') or '-'} | "
            f"deck={row.get('generated_deck_id', '') or '-'} | safe={row.get('safe_to_auto_apply', False)}"
        )
    return "\n".join(lines) + "\n"


def ratio(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return float(numerator) / float(denominator)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
