#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_build_from_evaluation_snapshot as rebuild_lib
from tools.aigc_battle import aigc_headless_evaluation_runner as eval_lib
from tools.aigc_battle import build_playable_hardening_plan as plan_lib
from tools.aigc_battle import build_real_evaluation_snapshot as snapshot_lib
from tools.aigc_battle import build_rebuild_recommendations as rec_lib
from tools.aigc_battle import resolve_rebuild_recommendation_conflicts as conflict_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="build hardened playable candidate")
    parser.add_argument("--target", choices=["fast", "bossrush"], required=True)
    args = parser.parse_args(argv[1:])
    result = build_hardened_candidate(args.target)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("hardened_pack_exported", False) else 1


def build_hardened_candidate(target: str) -> dict[str, Any]:
    plan = plan_lib.read_json(plan_lib.PLAN_JSON) if plan_lib.PLAN_JSON.exists() else plan_lib.build_plan()
    target_plan = next(item for item in plan.get("hardening_targets", []) if str(item.get("target", "")) == target)
    profile_id = str(target_plan.get("mechanic_profile_id", ""))
    source_pack_id = str(target_plan.get("source_pack_id", ""))
    requested_pack_id = str(target_plan.get("target_pack_id", ""))
    actual_pack_id = next_available_pack_id(profile_id, requested_pack_id)

    source_eval_report = eval_lib.evaluate_pack(profile_id, source_pack_id, 2)
    snapshot = snapshot_lib.build_snapshot(profile_id, source_pack_id)
    base_recommendations = rec_lib.build_recommendations(profile_id, source_pack_id)
    conflict_report = conflict_lib.resolve_conflicts(profile_id, source_pack_id)
    resolved_payload = read_json(conflict_lib.RESOLVED_JSON)
    hardening_recommendations = build_hardening_recommendations(target_plan, snapshot, resolved_payload, source_eval_report)
    write_json(target_resolved_json_path(target), hardening_recommendations)
    target_resolved_md_path(target).write_text(build_resolved_markdown(hardening_recommendations), encoding="utf-8")

    source_dir = rebuild_lib.resolve_source_generated_dir(profile_id, source_pack_id)
    target_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs" / actual_pack_id
    if source_dir.name == profile_id:
        shutil.copytree(source_dir, target_dir, ignore=shutil.ignore_patterns("packs"))
    else:
        shutil.copytree(source_dir, target_dir)

    old_pack_id = str(read_json(target_dir / "content_pack_summary.json").get("content_pack_id", source_pack_id))
    rebuild_lib.replace_content_pack_ids_in_dir(target_dir, old_pack_id, actual_pack_id)

    card_pool = read_json(target_dir / "card_pool.generated.json")
    deck_pool = read_json(target_dir / "enemy_deck_pool.generated.json")
    battle_slots = read_json(target_dir / "battle_slot_bindings.generated.json")
    rewards = read_json(target_dir / "rewards.generated.json")
    mappings = read_json(target_dir / "formal_sequence_mapping.generated.json")
    inventory = read_json(target_dir / "formal_sequence_inventory.generated.json")
    content_pack_summary = read_json(target_dir / "content_pack_summary.json")
    balance_summary = read_json(target_dir / "sequence_balance_summary.json")

    before_decks = {str(deck.get("deck_id", "")): float(deck.get("deck_power_score", 0) or 0) for deck in deck_pool}
    before_rewards = {str(item.get("reward_plan_id", "")): str(item.get("reward_tier", "")) for item in rewards}
    before_followup = {str(deck.get("deck_id", "")): float(deck.get("followup_density", 0) or 0) for deck in deck_pool}

    card_by_id = {str(card.get("card_id", "")): card for card in card_pool}
    deck_by_id = {str(deck.get("deck_id", "")): deck for deck in deck_pool}
    slot_by_deck = {str(slot.get("deck_id", "")): slot for slot in battle_slots}
    applied: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for recommendation in hardening_recommendations.get("recommendations", []):
        if not recommendation.get("safe_to_auto_apply", False):
            skipped.append(recommendation)
            continue
        action = str(recommendation.get("action_type", ""))
        changed = False
        if action == "increase_deck_power":
            changed = rebuild_lib.apply_power_adjustment(deck_by_id, card_by_id, recommendation, stronger=True)
        elif action == "reduce_enemy_pressure":
            changed = rebuild_lib.reduce_enemy_pressure(deck_by_id, slot_by_deck, card_by_id, recommendation)
        elif action == "reduce_defensive_drag":
            changed = rebuild_lib.reduce_defensive_drag(deck_by_id, card_by_id, slot_by_deck, recommendation)
        elif action in {"adjust_reward_tier", "upgrade_reward_tier"}:
            changed = rebuild_lib.adjust_reward_tier(rewards, mappings, recommendation)
        elif action == "improve_followup_chain":
            changed = rebuild_lib.improve_followup_chain(deck_by_id, card_by_id, recommendation)
        elif action == "replace_dead_card":
            changed = rebuild_lib.replace_specific_card(deck_by_id, card_by_id, str(recommendation.get("card_id", "")), prefer_lower_usage=False)
        elif action == "reduce_overused_card":
            changed = rebuild_lib.replace_specific_card(deck_by_id, card_by_id, str(recommendation.get("card_id", "")), prefer_lower_usage=True)
        elif action == "reduce_deck_power":
            changed = rebuild_lib.apply_power_adjustment(deck_by_id, card_by_id, recommendation, stronger=False)
        if changed:
            applied.append(recommendation)
        else:
            skipped.append(recommendation)

    rebuild_lib.repair_followup_chains(deck_pool, card_by_id)
    rebuild_lib.recalc_deck_metrics(deck_pool, card_by_id)
    lift_decks_to_template_floor(deck_pool, battle_slots, card_by_id)
    rebuild_lib.repair_followup_chains(deck_pool, card_by_id)
    rebuild_lib.recalc_deck_metrics(deck_pool, card_by_id)
    apply_hardening_pressure_budget(target, deck_pool, battle_slots, source_eval_report)
    rebuild_lib.sync_target_power_ranges(deck_pool, battle_slots, mappings, inventory)
    rebuild_lib.update_sequence_detail_links(deck_pool, battle_slots, mappings, rewards)

    after_decks = {str(deck.get("deck_id", "")): float(deck.get("deck_power_score", 0) or 0) for deck in deck_pool}
    after_rewards = {str(item.get("reward_plan_id", "")): str(item.get("reward_tier", "")) for item in rewards}
    after_followup = {str(deck.get("deck_id", "")): float(deck.get("followup_density", 0) or 0) for deck in deck_pool}

    build_variant = actual_pack_id.split("__")[-1] if "__" in actual_pack_id else actual_pack_id
    recommended_release_mode = "fast_run" if target == "fast" else "bossrush"
    content_pack_summary.update({
        "content_pack_id": actual_pack_id,
        "build_variant": build_variant,
        "playable_hardening": True,
        "hardening_target": target,
        "source_matrix_pack_id": source_pack_id,
        "source_pack_id": source_pack_id,
        "recommended_release_mode": recommended_release_mode,
        "applied_recommendation_count": len(applied),
        "skipped_recommendation_count": len(skipped),
        "deck_power_delta_summary": deck_power_delta_summary(before_decks, after_decks),
        "reward_tier_delta_summary": reward_tier_delta_summary(before_rewards, after_rewards),
        "followup_density_delta_summary": followup_delta_summary(before_followup, after_followup),
    })
    balance_summary.update({
        "generated_loadout_count": len(mappings),
        "fallback_loadout_count": 0,
        "reward_coverage_complete": len(rewards) == len(battle_slots),
        "playable_hardening": True,
        "hardening_target": target,
    })

    write_json(target_dir / "card_pool.generated.json", card_pool)
    write_json(target_dir / "enemy_deck_pool.generated.json", deck_pool)
    write_json(target_dir / "battle_slot_bindings.generated.json", battle_slots)
    write_json(target_dir / "rewards.generated.json", rewards)
    write_json(target_dir / "formal_sequence_mapping.generated.json", mappings)
    write_json(target_dir / "formal_sequence_inventory.generated.json", inventory)
    write_json(target_dir / "content_pack_summary.json", content_pack_summary)
    write_json(target_dir / "sequence_balance_summary.json", balance_summary)

    rebuild_lib.run_serial([sys.executable, "tools/aigc_battle/validate_content_pack.py", profile_id, "--generated-dir", str(target_dir)])
    rebuild_lib.run_serial([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", profile_id, "--generated-dir", str(target_dir)])
    rebuild_lib.run_serial([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    rebuild_lib.run_serial([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    rebuild_lib.run_serial([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

    result = {
        "target": target,
        "source_pack_id": source_pack_id,
        "requested_pack_id": requested_pack_id,
        "actual_pack_id": actual_pack_id,
        "sequence_template_id": str(target_plan.get("sequence_template_id", "")),
        "mechanic_profile_id": profile_id,
        "applied_recommendation_count": len(applied),
        "skipped_recommendation_count": len(skipped),
        "deck_power_delta_summary": content_pack_summary.get("deck_power_delta_summary", {}),
        "reward_tier_delta_summary": content_pack_summary.get("reward_tier_delta_summary", {}),
        "followup_density_delta_summary": content_pack_summary.get("followup_density_delta_summary", {}),
        "hardened_pack_generated": True,
        "hardened_pack_validated": True,
        "hardened_pack_exported": True,
        "hardened_pack_review_ready": True,
        "source_snapshot_path": snapshot.get("snapshot_path", ""),
        "base_recommendation_count": base_recommendations.get("recommendation_count", 0),
        "conflict_resolved": conflict_report.get("conflict_resolved", False),
        "resolved_recommendation_count": len(hardening_recommendations.get("recommendations", [])),
        "generated_dir": target_dir.relative_to(ROOT).as_posix(),
    }
    write_json(build_report_json_path(target), result)
    build_report_md_path(target).write_text(build_report_markdown(result), encoding="utf-8")
    return result


def build_hardening_recommendations(
    target_plan: dict[str, Any],
    snapshot: dict[str, Any],
    resolved_payload: dict[str, Any],
    source_eval_report: dict[str, Any],
) -> dict[str, Any]:
    recommendations: list[dict[str, Any]] = []
    existing_ids: set[str] = set()
    target = str(target_plan.get("target", ""))
    profile_id = str(target_plan.get("mechanic_profile_id", ""))
    pack_id = str(target_plan.get("source_pack_id", ""))
    long_turn_threshold = 7.0 if target == "fast" else 8.0

    def add(row: dict[str, Any]) -> None:
        rec_id = str(row.get("recommendation_id", ""))
        if rec_id in existing_ids:
            return
        existing_ids.add(rec_id)
        recommendations.append(row)

    for row in resolved_payload.get("recommendations", []):
        action = str(row.get("action_type", ""))
        if action in {"replace_dead_card", "reduce_overused_card", "improve_followup_chain"}:
            updated = dict(row)
            updated["safe_to_auto_apply"] = True
            updated["requires_designer_review"] = False
            add(updated)

    for item in snapshot.get("too_hard_candidates", []):
        add(base_hardening_recommendation(profile_id, pack_id, target, item, "reduce_enemy_pressure", {"power_bias": -2}))
    for item in snapshot.get("too_long_candidates", []):
        add(base_hardening_recommendation(profile_id, pack_id, target, item, "reduce_defensive_drag", {"drag_bias": -1}))
    for item in snapshot.get("reward_mismatch_candidates", []):
        add(base_hardening_recommendation(profile_id, pack_id, target, item, "upgrade_reward_tier", {"reward_tier_shift": 1}))

    for row in source_eval_report.get("encounter_metrics", []):
        encounter_win_rate = float(row.get("win_rate", 0) or 0)
        encounter_turn_count = float(row.get("avg_turn_count", 0) or 0)
        if encounter_win_rate >= 0.75 and encounter_turn_count > long_turn_threshold:
            add(extra_pressure_recommendation(profile_id, pack_id, target, row))

    trigger_rate = float(snapshot.get("mechanic_metrics", {}).get("weapon_followup_trigger_rate", 0) or 0)
    target_trigger_min = float(target_plan.get("target_metrics", {}).get("target_weapon_followup_trigger_rate_min", 0) or 0)
    if trigger_rate < target_trigger_min:
        for item in snapshot.get("too_hard_candidates", [])[:4]:
            add(base_hardening_recommendation(profile_id, pack_id, target, item, "improve_followup_chain", {"mechanic_density_shift": 1}))

    return {
        "generated_at": now_iso(),
        "target": target,
        "mechanic_profile_id": profile_id,
        "source_pack_id": pack_id,
        "recommendation_count": len(recommendations),
        "recommendations": recommendations,
    }


def extra_pressure_recommendation(
    profile_id: str,
    pack_id: str,
    target: str,
    row: dict[str, Any],
) -> dict[str, Any]:
    encounter_id = str(row.get("formal_encounter_id", ""))
    deck_id = str(row.get("generated_deck_id", ""))
    return {
        "recommendation_id": f"{profile_id}__{pack_id}__{target}__increase_deck_power__{encounter_id or deck_id or 'global'}",
        "severity": "medium",
        "action_type": "increase_deck_power",
        "mechanic_profile_id": profile_id,
        "content_pack_id": pack_id,
        "sequence_template_id": str(row.get("sequence_template_id", "")),
        "stage": str(row.get("stage", "")),
        "stage_level_action": "increase_stage_mechanic_density",
        "formal_encounter_id": encounter_id,
        "generated_battle_slot_id": str(row.get("generated_battle_slot_id", "")),
        "generated_deck_id": deck_id,
        "reward_plan_id": str(row.get("reward_plan_id", "")),
        "reason": "preserve_pressure_in_long_easy_encounter",
        "evidence": row,
        "suggested_delta": {"power_bias": 1, "goal": "lower_turns_without_flattening_pressure"},
        "safe_to_auto_apply": True,
        "requires_designer_review": False,
    }


def base_hardening_recommendation(
    profile_id: str,
    pack_id: str,
    target: str,
    item: dict[str, Any],
    action_type: str,
    delta: dict[str, Any],
) -> dict[str, Any]:
    suffix = str(item.get("generated_battle_slot_id", item.get("formal_encounter_id", "global")))
    return {
        "recommendation_id": f"{profile_id}__{pack_id}__{target}__{action_type}__{suffix}",
        "severity": "medium",
        "action_type": action_type,
        "mechanic_profile_id": profile_id,
        "content_pack_id": pack_id,
        "sequence_template_id": str(item.get("sequence_template_id", "")),
        "stage": str(item.get("stage", "")),
        "stage_level_action": "lower_stage_power" if action_type in {"reduce_enemy_pressure", "reduce_defensive_drag"} else "raise_stage_reward",
        "formal_encounter_id": str(item.get("formal_encounter_id", "")),
        "generated_battle_slot_id": str(item.get("generated_battle_slot_id", "")),
        "generated_deck_id": str(item.get("generated_deck_id", "")),
        "reward_plan_id": str(item.get("reward_plan_id", "")),
        "reason": str(item.get("reason", action_type)),
        "evidence": item,
        "suggested_delta": delta,
        "safe_to_auto_apply": True,
        "requires_designer_review": False,
    }


def deck_power_delta_summary(before: dict[str, float], after: dict[str, float]) -> dict[str, Any]:
    deltas = [round(after.get(deck_id, 0.0) - before.get(deck_id, 0.0), 2) for deck_id in before]
    return {
        "count": len(deltas),
        "avg_delta": round(sum(deltas) / len(deltas), 2) if deltas else 0.0,
        "min_delta": min(deltas) if deltas else 0.0,
        "max_delta": max(deltas) if deltas else 0.0,
    }


def reward_tier_delta_summary(before: dict[str, str], after: dict[str, str]) -> dict[str, Any]:
    changed = [reward_id for reward_id, tier in before.items() if after.get(reward_id, tier) != tier]
    return {
        "shifted_reward_count": len(changed),
        "upgraded_only": all(rank(after.get(reward_id, "")) >= rank(before.get(reward_id, "")) for reward_id in changed),
    }


def followup_delta_summary(before: dict[str, float], after: dict[str, float]) -> dict[str, Any]:
    deltas = [round(after.get(deck_id, 0.0) - before.get(deck_id, 0.0), 2) for deck_id in before]
    return {
        "count": len(deltas),
        "avg_delta": round(sum(deltas) / len(deltas), 2) if deltas else 0.0,
        "min_delta": min(deltas) if deltas else 0.0,
        "max_delta": max(deltas) if deltas else 0.0,
    }


def lift_decks_to_template_floor(
    deck_pool: list[dict[str, Any]],
    battle_slots: list[dict[str, Any]],
    card_by_id: dict[str, dict[str, Any]],
) -> None:
    slot_by_deck = {str(slot.get("deck_id", "")): slot for slot in battle_slots}
    deck_by_id = {str(deck.get("deck_id", "")): deck for deck in deck_pool}
    for deck_id, deck in deck_by_id.items():
        slot = slot_by_deck.get(deck_id, {})
        floor = float(slot.get("target_power_min", deck.get("target_power_min", 0)) or 0)
        if float(deck.get("deck_power_score", 0) or 0) >= floor:
            continue
        recommendation = {"generated_deck_id": deck_id}
        for _ in range(3):
            changed = rebuild_lib.apply_power_adjustment({deck_id: deck}, card_by_id, recommendation, stronger=True)
            if not changed:
                break
            rebuild_lib.recalc_deck_metrics([deck], card_by_id)
            if float(deck.get("deck_power_score", 0) or 0) >= floor:
                break


def apply_hardening_pressure_budget(
    target: str,
    deck_pool: list[dict[str, Any]],
    battle_slots: list[dict[str, Any]],
    source_eval_report: dict[str, Any],
) -> None:
    slot_by_deck = {str(slot.get("deck_id", "")): slot for slot in battle_slots}
    source_encounters = {
        str(item.get("formal_encounter_id", "")): item
        for item in source_eval_report.get("encounter_metrics", [])
    }
    stage_delta_map = {
        "fast": {"early": 14.0, "mid": 16.0, "late": 18.0, "boss": 20.0},
        "bossrush": {"early": 8.0, "mid": 10.0, "late": 12.0, "boss": 14.0},
    }
    deltas = stage_delta_map[target]
    for deck in deck_pool:
        slot = slot_by_deck.get(str(deck.get("deck_id", "")), {})
        stage = str(slot.get("stage", "mid"))
        delta = float(deltas.get(stage, 5.0))
        sequence_position = int(slot.get("sequence_position", 0) or 0)
        source_metrics = source_encounters.get(str(slot.get("formal_encounter_id", "")), {})
        source_win_rate = float(source_metrics.get("win_rate", 0) or 0)
        source_turn_count = float(source_metrics.get("avg_turn_count", 0) or 0)
        source_player_hp_end = float(source_metrics.get("avg_player_hp_end", 0) or 0)
        if target == "fast":
            if source_win_rate <= 0.25 or source_player_hp_end <= 2.0:
                delta += 5.0
            elif source_win_rate <= 0.50 or source_player_hp_end <= 8.0:
                delta += 2.0
            elif source_win_rate >= 1.0 and source_turn_count >= 8.0:
                delta = max(0.0, delta - 6.0)
            elif source_win_rate >= 0.75 and source_turn_count >= 7.5:
                delta = max(0.0, delta - 4.0)
            if sequence_position == 1:
                delta += 2.0
            elif sequence_position in {2, 3}:
                delta += 1.0
            elif sequence_position >= 7 and source_win_rate <= 0.5:
                delta += 2.0
        power = float(deck.get("deck_power_score", 0) or 0)
        if target == "bossrush":
            if source_win_rate <= 0.25 or source_player_hp_end <= 2.0:
                delta += 3.0
            elif source_win_rate <= 0.50 or source_player_hp_end <= 8.0:
                delta += 1.0
            elif source_win_rate >= 1.0 and source_turn_count >= 8.5:
                delta = max(0.0, delta - 8.0)
            elif source_win_rate >= 0.75 and source_turn_count >= 8.0:
                delta = max(0.0, delta - 5.0)
            if stage == "boss" and source_win_rate <= 0.5:
                delta += 1.0
        floor = 20.0 if target == "fast" else 24.0
        deck["deck_power_score"] = round(max(floor, power - delta), 2)


def next_available_pack_id(profile_id: str, requested: str) -> str:
    packs_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs"
    if not (packs_dir / requested).exists():
        return requested
    prefix, _, suffix = requested.rpartition("_")
    if suffix.isdigit():
        base = prefix
        start = int(suffix)
    else:
        base = requested
        start = 1
    value = start + 1
    while True:
        candidate = f"{base}_{value:03d}"
        if not (packs_dir / candidate).exists():
            return candidate
        value += 1


def rank(tier: str) -> int:
    tiers = ["basic", "standard", "advanced", "boss", "rare"]
    try:
        return tiers.index(tier)
    except ValueError:
        return -1


def target_resolved_json_path(target: str) -> Path:
    return OUT_DIR / f"{target}_resolved_recommendations.json"


def target_resolved_md_path(target: str) -> Path:
    return OUT_DIR / f"{target}_resolved_recommendations.md"


def build_report_json_path(target: str) -> Path:
    return OUT_DIR / f"{target}_hardened_build_report.json"


def build_report_md_path(target: str) -> Path:
    return OUT_DIR / f"{target}_hardened_build_report.md"


def build_resolved_markdown(payload: dict[str, Any]) -> str:
    lines = [
        f"# {payload.get('target', '')} Resolved Hardening Recommendations",
        "",
        f"- recommendation_count: `{payload.get('recommendation_count', 0)}`",
        "",
    ]
    for row in payload.get("recommendations", []):
        lines.append(
            f"- `{row.get('action_type', '')}` | encounter={row.get('formal_encounter_id', '') or '-'} | deck={row.get('generated_deck_id', '') or '-'}"
        )
    return "\n".join(lines) + "\n"


def build_report_markdown(result: dict[str, Any]) -> str:
    return "\n".join([
        f"# {result.get('target', '')} Hardened Build Report",
        "",
        f"- source_pack_id: `{result.get('source_pack_id', '')}`",
        f"- actual_pack_id: `{result.get('actual_pack_id', '')}`",
        f"- applied_recommendation_count: `{result.get('applied_recommendation_count', 0)}`",
        f"- skipped_recommendation_count: `{result.get('skipped_recommendation_count', 0)}`",
        f"- hardened_pack_generated: `{result.get('hardened_pack_generated', False)}`",
        f"- hardened_pack_validated: `{result.get('hardened_pack_validated', False)}`",
        f"- hardened_pack_exported: `{result.get('hardened_pack_exported', False)}`",
        f"- hardened_pack_review_ready: `{result.get('hardened_pack_review_ready', False)}`",
        "",
    ]) + "\n"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
