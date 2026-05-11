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

from tools.aigc_battle import aigc_headless_evaluation_runner as eval_lib
from tools.aigc_battle import build_mechanic_compare_matrix as compare_lib

SNAPSHOT_DIR = ROOT / "data" / "aigc_battle" / "evaluation" / "snapshots"
EVENTS_PATH = ROOT / "data" / "aigc_battle" / "evaluation" / "events" / "aigc_battle_eval_events.jsonl"
SUMMARY_JSON = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_evaluation_snapshot_summary.json"
SUMMARY_MD = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_evaluation_snapshot_summary.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build real evaluation snapshot")
    parser.add_argument("--profile", default="")
    parser.add_argument("--pack", default="")
    parser.add_argument("--default-r3-pack-set", action="store_true")
    args = parser.parse_args(argv[1:])

    if args.default_r3_pack_set:
        packs = eval_lib.default_r3_pack_set()
        snapshots = [build_snapshot(profile_id, pack_id) for profile_id, pack_id in packs]
        summary = build_snapshot_summary(snapshots)
        write_json(SUMMARY_JSON, summary)
        SUMMARY_MD.write_text(build_summary_markdown(summary), encoding="utf-8")
        print(f"built evaluation snapshots: packs={len(snapshots)}")
        return 0

    if not args.profile:
        raise SystemExit("profile is required unless --default-r3-pack-set is used")
    build_snapshot(args.profile, args.pack or None)
    print(f"built evaluation snapshot: {args.profile}")
    return 0


def build_snapshot(profile_id: str, pack_id: str | None) -> dict[str, Any]:
    generated_dir = eval_lib.resolve_generated_dir(profile_id, pack_id)
    runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
    content_pack_id = str(runtime_manifest.get("content_pack_id", pack_id or ""))
    events = load_events(profile_id, content_pack_id)
    if not events:
        raise SystemExit(f"evaluation events missing: {profile_id} / {content_pack_id}")

    detail_report = read_optional_json(eval_lib.pack_report_json_path(profile_id, content_pack_id)) or {}
    balance_summary = read_optional_json(generated_dir / "sequence_balance_summary.json") or {}
    rewards = runtime_manifest.get("rewards", [])
    mappings = runtime_manifest.get("formal_sequence_mapping", [])
    compare_matrix = read_optional_json(ROOT / "data" / "aigc_battle" / "generated" / "mechanic_expansion" / "mechanic_compare_matrix.json")
    if compare_matrix is None:
        compare_matrix = read_optional_json(compare_lib.OUT_JSON) or {}

    encounter_metrics: dict[str, dict[str, Any]] = {}
    by_encounter: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_stage: dict[str, list[dict[str, Any]]] = defaultdict(list)
    card_counter: Counter[str] = Counter()
    dead_cards: Counter[str] = Counter()
    overused_cards: Counter[str] = Counter()
    deck_underperform: list[dict[str, Any]] = []
    reward_by_id = {str(item.get("reward_plan_id", "")): item for item in rewards}

    for event in events:
        encounter_id = str(event.get("formal_encounter_id", ""))
        by_encounter[encounter_id].append(event)
        by_stage[str(event.get("stage", ""))].append(event)
        card_counter.update({str(card_id): 1 for card_id in event.get("player_card_ids_played", []) + event.get("enemy_card_ids_played", [])})
        dead_cards.update({str(card_id): 1 for card_id in event.get("dead_card_ids", [])})
        overused_cards.update({str(card_id): 1 for card_id in event.get("overused_card_ids", [])})

    too_easy_candidates: list[dict[str, Any]] = []
    too_hard_candidates: list[dict[str, Any]] = []
    too_long_candidates: list[dict[str, Any]] = []
    burst_damage_candidates: list[dict[str, Any]] = []
    reward_mismatch_candidates: list[dict[str, Any]] = []
    mechanism_underused_candidates: list[dict[str, Any]] = []

    for mapping in mappings:
        encounter_id = str(mapping.get("formal_encounter_id", ""))
        encounter_events = by_encounter.get(encounter_id, [])
        aggregate = eval_lib.aggregate_events_for_scope(encounter_events, mapping, mapping, mapping, reward_by_id.get(str(mapping.get("reward_plan_id", "")), {}))
        if not aggregate:
            continue
        encounter_metrics[encounter_id] = aggregate
        if aggregate["win_rate"] >= 0.9 and aggregate["avg_turn_count"] <= 3 and aggregate["avg_player_hp_end"] >= 20:
            too_easy_candidates.append(candidate_stub(mapping, aggregate, "too_easy"))
        if aggregate["win_rate"] <= 0.35 or aggregate["avg_player_hp_end"] <= 8:
            too_hard_candidates.append(candidate_stub(mapping, aggregate, "too_hard"))
            deck_underperform.append(candidate_stub(mapping, aggregate, "deck_underperform"))
        if aggregate["avg_turn_count"] >= 6:
            too_long_candidates.append(candidate_stub(mapping, aggregate, "too_long"))
        if aggregate["burst_damage_count"] > 0:
            burst_damage_candidates.append(candidate_stub(mapping, aggregate, "burst_damage"))
        if aggregate["reward_mismatch_count"] > 0:
            reward_mismatch_candidates.append(candidate_stub(mapping, aggregate, "reward_mismatch"))
        if aggregate["mechanism_underused_count"] > 0:
            mechanism_underused_candidates.append(candidate_stub(mapping, aggregate, "mechanism_underused"))

    pack_metrics = detail_report.get("pack_metrics", eval_lib.aggregate_events_for_scope(events, None, None, None, None))
    stage_metrics = build_stage_metrics(by_stage)
    mechanic_metrics = {
        "runtime_primitive_trigger_rate": pack_metrics.get("runtime_primitive_trigger_rate", 0),
        "weapon_followup_trigger_rate": pack_metrics.get("weapon_followup_trigger_rate", 0),
        "clue_pressure_trigger_rate": pack_metrics.get("clue_pressure_trigger_rate", 0),
        "dual_weapon_usage_rate": pack_metrics.get("dual_weapon_usage_rate", 0),
    }
    card_metrics = {
        "used_card_count": len(card_counter),
        "card_usage_counts": dict(card_counter.most_common()),
        "card_overused_candidates": [{"card_id": card_id, "event_count": count} for card_id, count in overused_cards.most_common(12) if count > 0],
        "card_dead_candidates": [{"card_id": card_id, "event_count": count} for card_id, count in dead_cards.most_common(12) if count > 0],
    }
    deck_metrics = {
        "deck_underperform_candidates": deck_underperform,
    }
    reward_metrics = {
        "reward_claim_rate": pack_metrics.get("reward_claim_rate", 0),
        "reward_mismatch_candidates": reward_mismatch_candidates,
    }
    telemetry_summary = dict(Counter(str(event.get("telemetry_detail_level", "minimal")) for event in events))
    rebuild_recommendation_count = (
        len(too_easy_candidates)
        + len(too_hard_candidates)
        + len(too_long_candidates)
        + len(reward_mismatch_candidates)
        + len(mechanism_underused_candidates)
        + len(card_metrics["card_overused_candidates"])
        + len(card_metrics["card_dead_candidates"])
    )
    actionability_score = min(
        100,
        int(
            30
            + len(events) * 0.2
            + rebuild_recommendation_count * 2
            + (5 if pack_metrics.get("runtime_primitive_trigger_rate", 0) > 0 else 0)
            + (5 if len(encounter_metrics) >= 15 else 0)
        ),
    )
    snapshot = {
        "generated_at": now_iso(),
        "snapshot_path": snapshot_json_path(profile_id, content_pack_id).relative_to(ROOT).as_posix(),
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "evaluation_event_count": len(events),
        "sequence_template_id": str(runtime_manifest.get("sequence_template_id", "")),
        "telemetry_detail_level_summary": telemetry_summary,
        "formal_encounter_coverage": {
            "expected": len(mappings),
            "covered": len(encounter_metrics),
            "coverage_complete": len(encounter_metrics) == len(mappings),
        },
        "encounter_metrics": encounter_metrics,
        "pack_metrics": pack_metrics,
        "stage_metrics": stage_metrics,
        "mechanic_metrics": mechanic_metrics,
        "card_metrics": card_metrics,
        "deck_metrics": deck_metrics,
        "reward_metrics": reward_metrics,
        "too_easy_candidates": too_easy_candidates,
        "too_hard_candidates": too_hard_candidates,
        "too_long_candidates": too_long_candidates,
        "burst_damage_candidates": burst_damage_candidates,
        "reward_mismatch_candidates": reward_mismatch_candidates,
        "mechanism_underused_candidates": mechanism_underused_candidates,
        "card_overused_candidates": card_metrics["card_overused_candidates"],
        "card_dead_candidates": card_metrics["card_dead_candidates"],
        "deck_underperform_candidates": deck_underperform,
        "rebuild_recommendation_count": rebuild_recommendation_count,
        "snapshot_ready": len(events) > 0,
        "real_metrics_ready": pack_metrics.get("avg_turn_count", 0) > 0 and pack_metrics.get("avg_damage_taken", 0) >= 0,
        "actionability_score": actionability_score,
        "source_runtime_manifest_path": generated_dir.joinpath("runtime_manifest.json").relative_to(ROOT).as_posix(),
        "source_balance_summary_path": generated_dir.joinpath("sequence_balance_summary.json").relative_to(ROOT).as_posix(),
        "sequence_balance_pass": bool(balance_summary.get("sequence_balance_pass", False)),
        "mechanic_compare_row": next(
            (
                row for row in compare_matrix.get("packs", [])
                if row.get("mechanic_profile_id") == profile_id and row.get("content_pack_id") == content_pack_id
            ),
            {},
        ),
    }
    write_json(snapshot_json_path(profile_id, content_pack_id), snapshot)
    snapshot_md_path(profile_id, content_pack_id).write_text(build_snapshot_markdown(snapshot), encoding="utf-8")
    return snapshot


def build_snapshot_summary(snapshots: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "generated_at": now_iso(),
        "pack_count": len(snapshots),
        "packs": [
            {
                "mechanic_profile_id": item.get("mechanic_profile_id", ""),
                "content_pack_id": item.get("content_pack_id", ""),
                "evaluation_event_count": item.get("evaluation_event_count", 0),
                "sequence_template_id": item.get("sequence_template_id", ""),
                "win_rate": item.get("pack_metrics", {}).get("win_rate", 0),
                "avg_turn_count": item.get("pack_metrics", {}).get("avg_turn_count", 0),
                "actionability_score": item.get("actionability_score", 0),
                "rebuild_recommendation_count": item.get("rebuild_recommendation_count", 0),
                "snapshot_ready": item.get("snapshot_ready", False),
                "real_metrics_ready": item.get("real_metrics_ready", False),
            }
            for item in snapshots
        ],
    }


def snapshot_json_path(profile_id: str, content_pack_id: str) -> Path:
    return SNAPSHOT_DIR / f"{profile_id}__{content_pack_id}__evaluation_snapshot.json"


def snapshot_md_path(profile_id: str, content_pack_id: str) -> Path:
    return SNAPSHOT_DIR / f"{profile_id}__{content_pack_id}__evaluation_snapshot.md"


def build_snapshot_markdown(snapshot: dict[str, Any]) -> str:
    pack = snapshot.get("pack_metrics", {})
    stage_metrics = snapshot.get("stage_metrics", {})
    lines = [
        "# Evaluation Snapshot",
        "",
        f"- mechanic_profile_id: `{snapshot.get('mechanic_profile_id', '')}`",
        f"- content_pack_id: `{snapshot.get('content_pack_id', '')}`",
        f"- sequence_template_id: `{snapshot.get('sequence_template_id', '')}`",
        f"- evaluation_event_count: `{snapshot.get('evaluation_event_count', 0)}`",
        f"- win_rate: `{pack.get('win_rate', 0)}`",
        f"- avg_turn_count: `{pack.get('avg_turn_count', 0)}`",
        f"- avg_player_hp_end: `{pack.get('avg_player_hp_end', 0)}`",
        f"- runtime_primitive_trigger_rate: `{snapshot.get('mechanic_metrics', {}).get('runtime_primitive_trigger_rate', 0)}`",
        f"- rebuild_recommendation_count: `{snapshot.get('rebuild_recommendation_count', 0)}`",
        f"- actionability_score: `{snapshot.get('actionability_score', 0)}`",
        f"- early_win_rate: `{stage_metrics.get('early_win_rate', 0)}`",
        f"- boss_win_rate: `{stage_metrics.get('boss_win_rate', 0)}`",
        "",
        "## Candidates",
        f"- too_easy: `{len(snapshot.get('too_easy_candidates', []))}`",
        f"- too_hard: `{len(snapshot.get('too_hard_candidates', []))}`",
        f"- too_long: `{len(snapshot.get('too_long_candidates', []))}`",
        f"- reward_mismatch: `{len(snapshot.get('reward_mismatch_candidates', []))}`",
        f"- mechanism_underused: `{len(snapshot.get('mechanism_underused_candidates', []))}`",
        f"- card_dead: `{len(snapshot.get('card_dead_candidates', []))}`",
    ]
    return "\n".join(lines) + "\n"


def build_stage_metrics(by_stage: dict[str, list[dict[str, Any]]]) -> dict[str, Any]:
    stage_metrics: dict[str, Any] = {}
    for stage in ["early", "mid", "late", "boss"]:
        events = by_stage.get(stage, [])
        aggregate = eval_lib.aggregate_events_for_scope(events, None, None, None, None) if events else {}
        stage_metrics[f"{stage}_win_rate"] = aggregate.get("win_rate", 0)
        stage_metrics[f"{stage}_avg_turn_count"] = aggregate.get("avg_turn_count", 0)
        stage_metrics[f"{stage}_stage_event_count"] = len(events)
        stage_metrics[f"{stage}_stage_too_hard_count"] = sum(1 for event in events if not event.get("win", False) or int(event.get("player_hp_end", 0) or 0) <= 8)
        stage_metrics[f"{stage}_stage_too_long_count"] = sum(1 for event in events if int(event.get("turn_count", 0) or 0) >= 6)
        stage_metrics[f"{stage}_stage_reward_mismatch_count"] = sum(1 for event in events if bool(event.get("reward_mismatch_flag", False)))
    return stage_metrics


def build_summary_markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# R3 Evaluation Snapshot Summary",
        "",
        f"- pack_count: `{summary.get('pack_count', 0)}`",
        "",
        "| Profile | Pack | Events | Win Rate | Avg Turn | Actionability | Rebuild Count |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in summary.get("packs", []):
        lines.append(
            f"| `{row.get('mechanic_profile_id', '')}` | `{row.get('content_pack_id', '')}` | "
            f"{row.get('evaluation_event_count', 0)} | {row.get('win_rate', 0)} | "
            f"{row.get('avg_turn_count', 0)} | {row.get('actionability_score', 0)} | "
            f"{row.get('rebuild_recommendation_count', 0)} |"
        )
    return "\n".join(lines) + "\n"


def candidate_stub(mapping: dict[str, Any], aggregate: dict[str, Any], reason: str) -> dict[str, Any]:
    return {
        "formal_encounter_id": str(mapping.get("formal_encounter_id", "")),
        "generated_battle_slot_id": str(mapping.get("generated_battle_slot_id", "")),
        "generated_deck_id": str(mapping.get("generated_deck_id", "")),
        "reward_plan_id": str(mapping.get("reward_plan_id", "")),
        "reason": reason,
        "evidence": {
            "win_rate": aggregate.get("win_rate", 0),
            "avg_turn_count": aggregate.get("avg_turn_count", 0),
            "avg_player_hp_end": aggregate.get("avg_player_hp_end", 0),
            "runtime_primitive_trigger_rate": aggregate.get("runtime_primitive_trigger_rate", 0),
        },
    }


def load_events(profile_id: str, content_pack_id: str) -> list[dict[str, Any]]:
    if not EVENTS_PATH.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in EVENTS_PATH.read_text(encoding="utf-8").splitlines():
        clean = line.strip()
        if not clean:
            continue
        payload = json.loads(clean)
        if str(payload.get("mechanic_profile_id", "")) == profile_id and str(payload.get("content_pack_id", "")) == content_pack_id:
            rows.append(payload)
    return rows


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def read_optional_json(path: Path) -> Any:
    if not path.exists():
        return None
    return read_json(path)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
