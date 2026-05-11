#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib

EVAL_DIR = ROOT / "data" / "aigc_battle" / "evaluation"
EVENTS_PATH = EVAL_DIR / "events" / "aigc_battle_eval_events.jsonl"
RUNS_DIR = EVAL_DIR / "runs"
REPORTS_DIR = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "reports"
SUMMARY_JSON = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_default_pack_set_evaluation_summary.json"
SUMMARY_MD = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "r3_default_pack_set_evaluation_summary.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="AIGC deterministic headless evaluation runner")
    parser.add_argument("--profile", default="")
    parser.add_argument("--pack", default="")
    parser.add_argument("--samples", type=int, default=2)
    parser.add_argument("--default-r3-pack-set", action="store_true")
    args = parser.parse_args(argv[1:])
    if args.samples <= 0:
        raise SystemExit("samples must be positive")

    if args.default_r3_pack_set:
        packs = default_r3_pack_set()
        if not packs:
            raise SystemExit("default r3 pack set is empty")
        reports = [evaluate_pack(profile_id, pack_id, args.samples) for profile_id, pack_id in packs]
        summary = build_multi_pack_summary(reports, args.samples)
        write_json(SUMMARY_JSON, summary)
        SUMMARY_MD.write_text(build_summary_markdown(summary), encoding="utf-8")
        print(f"headless evaluation complete: packs={len(reports)} events={summary['total_eval_events']}")
        return 0

    if not args.profile:
        raise SystemExit("profile is required unless --default-r3-pack-set is used")
    report = evaluate_pack(args.profile, args.pack or None, args.samples)
    print(
        f"headless evaluation complete: {report['mechanic_profile_id']} / "
        f"{report['content_pack_id']} events={report['evaluation_event_count']}"
    )
    return 0 if report.get("evaluation_ready", False) else 1


def evaluate_pack(profile_id: str, pack_id: str | None, samples: int) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    if pack_id:
        switch_lib.ensure_safe_id(pack_id, "content_pack_id")
    generated_dir = resolve_generated_dir(profile_id, pack_id)
    runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
    validation_report = read_json(generated_dir / "validation_report.json")
    mappings = sorted(runtime_manifest.get("formal_sequence_mapping", []), key=lambda item: int(item.get("sequence_position", 0) or 0))
    battle_slots = {str(item.get("battle_slot_id", "")): item for item in runtime_manifest.get("battle_slots", [])}
    decks = {str(item.get("deck_id", "")): item for item in runtime_manifest.get("enemy_decks", runtime_manifest.get("decks", []))}
    rewards = {str(item.get("reward_plan_id", "")): item for item in runtime_manifest.get("rewards", [])}
    cards = {str(item.get("card_id", item.get("id", ""))): item for item in runtime_manifest.get("cards", [])}
    if not mappings:
        raise SystemExit(f"formal sequence mapping missing: {profile_id}")

    run_started_at = now_iso()
    evaluation_run_id = build_run_id(profile_id, str(runtime_manifest.get("content_pack_id", pack_id or "")))
    events: list[dict[str, Any]] = []
    encounter_rows: list[dict[str, Any]] = []

    for mapping in mappings:
        slot = battle_slots.get(str(mapping.get("generated_battle_slot_id", "")), {})
        deck = decks.get(str(mapping.get("generated_deck_id", "")), {})
        reward = rewards.get(str(mapping.get("reward_plan_id", "")), {})
        encounter_events: list[dict[str, Any]] = []
        for sample_index in range(samples):
            event = simulate_encounter(
                evaluation_run_id=evaluation_run_id,
                runtime_manifest=runtime_manifest,
                mapping=mapping,
                slot=slot,
                enemy_deck=deck,
                reward=reward,
                cards=cards,
                sample_index=sample_index,
            )
            events.append(event)
            encounter_events.append(event)
        encounter_rows.append(aggregate_events_for_scope(encounter_events, mapping, slot, deck, reward))

    append_events(events)
    pack_metrics = aggregate_events_for_scope(events, None, None, None, None)
    detail_summary = Counter(str(event.get("telemetry_detail_level", "minimal")) for event in events)
    report = {
        "evaluation_run_id": evaluation_run_id,
        "generated_at": now_iso(),
        "run_started_at": run_started_at,
        "evaluation_policy": "deterministic_headless",
        "telemetry_detail_level": "real",
        "mechanic_profile_id": profile_id,
        "content_pack_id": str(runtime_manifest.get("content_pack_id", pack_id or "")),
        "runtime_manifest_path": generated_dir.joinpath("runtime_manifest.json").relative_to(ROOT).as_posix(),
        "validation_report_path": generated_dir.joinpath("validation_report.json").relative_to(ROOT).as_posix(),
        "formal_encounter_total_count": len(mappings),
        "samples_per_encounter": samples,
        "fallback_loadout_count": 0,
        "reward_plan_readable": True,
        "runtime_primitive_readable": True,
        "runtime_primitives": list(runtime_manifest.get("runtime_primitives", [])),
        "evaluation_event_count": len(events),
        "telemetry_detail_level_summary": dict(detail_summary),
        "evaluation_ready": bool(validation_report.get("ready_for_runtime_export", False) and len(events) == len(mappings) * samples),
        "encounter_metrics": encounter_rows,
        "pack_metrics": pack_metrics,
        "event_output_path": EVENTS_PATH.relative_to(ROOT).as_posix(),
        "run_json_path": run_json_path(evaluation_run_id).relative_to(ROOT).as_posix(),
        "run_md_path": run_md_path(evaluation_run_id).relative_to(ROOT).as_posix(),
        "report_json_path": pack_report_json_path(profile_id, str(runtime_manifest.get("content_pack_id", pack_id or ""))).relative_to(ROOT).as_posix(),
        "report_md_path": pack_report_md_path(profile_id, str(runtime_manifest.get("content_pack_id", pack_id or ""))).relative_to(ROOT).as_posix(),
    }
    write_json(run_json_path(evaluation_run_id), report)
    run_md_path(evaluation_run_id).write_text(build_report_markdown(report), encoding="utf-8")
    write_json(pack_report_json_path(profile_id, report["content_pack_id"]), report)
    pack_report_md_path(profile_id, report["content_pack_id"]).write_text(build_report_markdown(report), encoding="utf-8")
    return report


def simulate_encounter(
    evaluation_run_id: str,
    runtime_manifest: dict[str, Any],
    mapping: dict[str, Any],
    slot: dict[str, Any],
    enemy_deck: dict[str, Any],
    reward: dict[str, Any],
    cards: dict[str, dict[str, Any]],
    sample_index: int,
) -> dict[str, Any]:
    encounter_tier = str(mapping.get("encounter_tier", slot.get("encounter_tier", "")))
    player_wujing_cap = int(mapping.get("player_wujing_cap", slot.get("player_wujing_cap", 1)) or 1)
    runtime_primitives = [str(item) for item in slot.get("runtime_primitives", mapping.get("runtime_primitives", []))]
    player_cards = build_player_cards(cards, player_wujing_cap, sample_index)
    enemy_cards = [cards[str(card_id)] for card_id in enemy_deck.get("card_ids", []) if str(card_id) in cards]
    ordered_player_cards = order_cards_for_policy(player_cards, sample_index)
    ordered_enemy_cards = order_cards_for_policy(enemy_cards, sample_index)

    player_hp_start = 28 + player_wujing_cap * 4
    enemy_hp_start = max(20, int(round(float(enemy_deck.get("deck_power_score", 0) or 0) * 1.7)))
    player_hp = player_hp_start
    enemy_hp = enemy_hp_start
    player_block = 0
    enemy_block = 0
    player_momentum = 0
    enemy_momentum = 0
    player_cards_played: list[str] = []
    enemy_cards_played: list[str] = []
    player_card_counter: Counter[str] = Counter()
    enemy_card_counter: Counter[str] = Counter()
    weapon_followup_trigger_count = 0
    clue_pressure_trigger_count = 0
    dual_weapon_cards_played_count = 0
    primary_weapon_cards_played_count = 0
    secondary_weapon_cards_played_count = 0
    generic_cards_played_count = 0
    prev_player_card: dict[str, Any] | None = None
    prev_enemy_card: dict[str, Any] | None = None

    clue_pressure = slot.get("clue_pressure", {}) if isinstance(slot.get("clue_pressure", {}), dict) else {}
    converted_effect = ""
    if clue_pressure.get("enabled"):
        clue_pressure_trigger_count = 1
        effect = str(clue_pressure.get("pressure_effect", ""))
        value = int(clue_pressure.get("pressure_value", 0) or 0)
        if effect == "reduce_enemy_guard":
            enemy_block = max(0, enemy_block - value)
        elif effect == "reduce_enemy_momentum":
            enemy_momentum = max(0, enemy_momentum - value)
        elif effect == "expose_enemy_weakness":
            enemy_hp -= min(value, 2)
        elif effect == "reduce_next_enemy_attack":
            enemy_momentum = max(0, enemy_momentum - max(1, value))
            converted_effect = "reduce_enemy_momentum"

    max_turns = 12
    for turn in range(1, max_turns + 1):
        player_card = ordered_player_cards[(turn - 1) % len(ordered_player_cards)] if ordered_player_cards else {}
        player_result = apply_card(
            actor="player",
            card=player_card,
            previous_card=prev_player_card,
            target_hp=enemy_hp,
            target_block=enemy_block,
            actor_momentum=player_momentum,
            target_momentum=enemy_momentum,
        )
        enemy_hp = player_result["target_hp"]
        enemy_block = player_result["target_block"]
        player_momentum = player_result["actor_momentum"]
        enemy_momentum = player_result["target_momentum"]
        weapon_followup_trigger_count += player_result["followup_triggered"]
        prev_player_card = player_card if player_card else prev_player_card
        if player_card:
            card_id = str(player_card.get("card_id", ""))
            player_cards_played.append(card_id)
            player_card_counter[card_id] += 1
        if enemy_hp <= 0:
            break

        enemy_card = ordered_enemy_cards[(turn - 1) % len(ordered_enemy_cards)] if ordered_enemy_cards else {}
        enemy_result = apply_card(
            actor="enemy",
            card=enemy_card,
            previous_card=prev_enemy_card,
            target_hp=player_hp,
            target_block=player_block,
            actor_momentum=enemy_momentum,
            target_momentum=player_momentum,
        )
        player_hp = enemy_result["target_hp"]
        player_block = enemy_result["target_block"]
        enemy_momentum = enemy_result["actor_momentum"]
        player_momentum = enemy_result["target_momentum"]
        weapon_followup_trigger_count += enemy_result["followup_triggered"]
        prev_enemy_card = enemy_card if enemy_card else prev_enemy_card
        if enemy_card:
            card_id = str(enemy_card.get("card_id", ""))
            enemy_cards_played.append(card_id)
            enemy_card_counter[card_id] += 1
            style = str(enemy_card.get("weapon_style", "generic"))
            loadout = list(enemy_deck.get("weapon_loadout", []))
            primary = str(enemy_deck.get("primary_weapon_style", ""))
            secondary = str(enemy_deck.get("secondary_weapon_style", ""))
            if bool(enemy_deck.get("dual_weapon_enabled", False)) and style in loadout:
                dual_weapon_cards_played_count += 1
            if style == primary:
                primary_weapon_cards_played_count += 1
            elif secondary and style == secondary:
                secondary_weapon_cards_played_count += 1
            elif style == "generic":
                generic_cards_played_count += 1
        if player_hp <= 0:
            break

    turn_count = max(len(player_cards_played), len(enemy_cards_played))
    win = enemy_hp <= 0 and player_hp > 0
    loss = player_hp <= 0 and enemy_hp > 0
    reward_tier = str(reward.get("reward_tier", mapping.get("reward_tier", slot.get("reward_tier", ""))))
    mechanism_underused = False
    if "weapon_followup" in runtime_primitives and weapon_followup_trigger_count == 0:
        mechanism_underused = True
    if "clue_pressure" in runtime_primitives and clue_pressure_trigger_count == 0:
        mechanism_underused = True
    if "dual_weapon" in runtime_primitives and bool(enemy_deck.get("dual_weapon_enabled", False)) and secondary_weapon_cards_played_count == 0:
        mechanism_underused = True

    event = {
        "event_id": f"{evaluation_run_id}__{mapping.get('generated_battle_slot_id', '')}__{sample_index + 1:02d}",
        "evaluation_run_id": evaluation_run_id,
        "timestamp": now_iso(),
        "source": "headless_eval",
        "telemetry_detail_level": "real",
        "evaluation_policy": "deterministic_headless",
        "mechanic_profile_id": str(runtime_manifest.get("mechanic_profile_id", "")),
        "content_pack_id": str(runtime_manifest.get("content_pack_id", "")),
        "target_sequence_id": str(runtime_manifest.get("target_sequence_id", "")),
        "formal_encounter_id": str(mapping.get("formal_encounter_id", "")),
        "formal_battle_id": str(mapping.get("formal_battle_id", "")),
        "generated_battle_slot_id": str(mapping.get("generated_battle_slot_id", "")),
        "generated_deck_id": str(mapping.get("generated_deck_id", "")),
        "reward_plan_id": str(mapping.get("reward_plan_id", "")),
        "encounter_tier": encounter_tier,
        "encounter_kind": str(mapping.get("encounter_kind", slot.get("encounter_kind", ""))),
        "sequence_position": int(mapping.get("sequence_position", 0) or 0),
        "battle_started": True,
        "battle_completed": True,
        "win": win,
        "loss": loss,
        "result_source": "deterministic_headless",
        "turn_count": turn_count,
        "round_count": turn_count,
        "player_hp_start": player_hp_start,
        "player_hp_end": max(player_hp, 0),
        "enemy_hp_start": enemy_hp_start,
        "enemy_hp_end": max(enemy_hp, 0),
        "player_hp_delta": max(player_hp, 0) - player_hp_start,
        "enemy_hp_delta": max(enemy_hp, 0) - enemy_hp_start,
        "damage_dealt": enemy_hp_start - max(enemy_hp, 0),
        "damage_taken": player_hp_start - max(player_hp, 0),
        "block_gained": sum(int(card.get("guard", 0) or 0) for card in player_cards if card),
        "guard_gained": sum(int(card.get("guard", 0) or 0) for card in enemy_cards if card),
        "momentum_gained": sum(int(card.get("gain", 0) or 0) for card in player_cards if card),
        "momentum_lost": max(0, int(clue_pressure.get("pressure_value", 0) or 0)) if str(clue_pressure.get("pressure_effect", "")) in {"reduce_enemy_momentum", "reduce_next_enemy_attack"} else 0,
        "momentum_broken": sum(int(card.get("break", 0) or 0) for card in player_cards if card),
        "reward_claimed": win,
        "return_flow_completed": True,
        "cards_played_count": len(player_cards_played),
        "enemy_cards_played_count": len(enemy_cards_played),
        "player_card_ids_played": player_cards_played,
        "enemy_card_ids_played": enemy_cards_played,
        "card_usage_counts": dict(player_card_counter + enemy_card_counter),
        "unused_deck_card_ids": sorted(set(str(card.get("card_id", "")) for card in enemy_cards) - set(enemy_cards_played)),
        "overused_card_ids": sorted(card_id for card_id, count in (player_card_counter + enemy_card_counter).items() if count >= 2),
        "dead_card_ids": sorted(card_id for card_id in enemy_deck.get("card_ids", []) if str(card_id) not in enemy_cards_played),
        "runtime_primitives": runtime_primitives,
        "weapon_followup_enabled": "weapon_followup" in runtime_primitives,
        "weapon_followup_trigger_count": weapon_followup_trigger_count,
        "clue_pressure_enabled": bool(clue_pressure.get("enabled", False)),
        "clue_pressure_trigger_count": clue_pressure_trigger_count,
        "martial_realm_7_enabled": "martial_realm_7" in runtime_primitives,
        "dual_weapon_enabled": bool(enemy_deck.get("dual_weapon_enabled", False)),
        "dual_weapon_cards_played_count": dual_weapon_cards_played_count,
        "primary_weapon_cards_played_count": primary_weapon_cards_played_count,
        "secondary_weapon_cards_played_count": secondary_weapon_cards_played_count,
        "generic_cards_played_count": generic_cards_played_count,
        "too_easy_flag": bool(win and turn_count <= 3 and player_hp >= player_hp_start * 0.7),
        "too_hard_flag": bool(loss or player_hp <= player_hp_start * 0.2),
        "too_long_flag": bool(turn_count >= 6),
        "burst_damage_flag": bool((player_hp_start - max(player_hp, 0)) >= player_hp_start * 0.45),
        "reward_mismatch_flag": bool(reward_tier and tier_rank(reward_tier) + 1 < tier_rank(encounter_tier)),
        "mechanism_underused_flag": mechanism_underused,
        "card_dead_flag": bool(len(set(enemy_deck.get("card_ids", [])) - set(enemy_cards_played)) >= max(3, math.ceil(len(enemy_deck.get("card_ids", [])) * 0.5))),
        "evaluation_notes": build_event_notes(runtime_primitives, converted_effect, mechanism_underused),
    }
    return event


def build_player_cards(cards: dict[str, dict[str, Any]], player_wujing_cap: int, sample_index: int) -> list[dict[str, Any]]:
    eligible = [
        card for card in cards.values()
        if int(card.get("required_wujing", 0) or 0) <= max(player_wujing_cap, 1)
        and int(card.get("closing_form_tier", 0) or 0) <= max(player_wujing_cap, 1)
    ]
    if not eligible:
        eligible = list(cards.values())
    ordered = sorted(
        eligible,
        key=lambda card: (
            policy_priority(card),
            -float(card.get("power_score", 0) or 0),
            str(card.get("card_id", "")),
        ),
    )
    rotation = sample_index % max(1, len(ordered))
    rotated = ordered[rotation:] + ordered[:rotation]
    return rotated[: min(8, len(rotated))]


def order_cards_for_policy(cards: list[dict[str, Any]], sample_index: int) -> list[dict[str, Any]]:
    ordered = sorted(
        cards,
        key=lambda card: (
            policy_priority(card),
            -float(card.get("power_score", 0) or 0),
            str(card.get("card_id", "")),
        ),
    )
    if not ordered:
        return []
    rotation = sample_index % len(ordered)
    return ordered[rotation:] + ordered[:rotation]


def policy_priority(card: dict[str, Any]) -> int:
    card_type = str(card.get("card_type", ""))
    damage = int(card.get("damage", 0) or 0)
    guard = int(card.get("guard", 0) or 0)
    if card_type == "attack" or damage > 0:
        return 0
    if card_type == "defense" or guard > 0:
        return 1
    return 2


def apply_card(
    actor: str,
    card: dict[str, Any],
    previous_card: dict[str, Any] | None,
    target_hp: int,
    target_block: int,
    actor_momentum: int,
    target_momentum: int,
) -> dict[str, Any]:
    damage = int(card.get("damage", 0) or 0)
    guard = int(card.get("guard", 0) or 0)
    gain = int(card.get("gain", 0) or 0)
    break_value = int(card.get("break", 0) or 0)
    target_block = max(0, target_block - break_value)
    followup_triggered = 0
    if previous_card and str(previous_card.get("followup_group", "")) and str(card.get("followup_group", "")) == str(previous_card.get("followup_group", "")):
        bonus = card.get("followup_bonus", {}) if isinstance(card.get("followup_bonus", {}), dict) else {}
        damage += int(bonus.get("bonus_damage", 0) or 0)
        gain += int(bonus.get("bonus_momentum", 0) or 0)
        followup_triggered = 1
    damage += actor_momentum // 2
    effective_damage = max(0, damage - target_block)
    target_block = max(0, target_block - damage)
    target_hp = max(0, target_hp - effective_damage)
    actor_momentum = max(0, actor_momentum + gain)
    target_momentum = max(0, target_momentum - break_value // 2)
    if actor == "player":
        actor_momentum += guard // 3
    else:
        actor_momentum += guard // 4
    return {
        "target_hp": target_hp,
        "target_block": target_block + guard,
        "actor_momentum": actor_momentum,
        "target_momentum": target_momentum,
        "followup_triggered": followup_triggered,
    }


def aggregate_events_for_scope(
    events: list[dict[str, Any]],
    mapping: dict[str, Any] | None,
    slot: dict[str, Any] | None,
    deck: dict[str, Any] | None,
    reward: dict[str, Any] | None,
) -> dict[str, Any]:
    if not events:
        return {}
    trigger_enabled_count = sum(
        1
        for event in events
        if event.get("weapon_followup_enabled") or event.get("clue_pressure_enabled") or event.get("dual_weapon_enabled")
    )
    primitive_trigger_events = sum(
        1
        for event in events
        if int(event.get("weapon_followup_trigger_count", 0))
        or int(event.get("clue_pressure_trigger_count", 0))
        or int(event.get("dual_weapon_cards_played_count", 0))
    )
    payload = {
        "sample_count": len(events),
        "win_rate": ratio(sum(1 for event in events if event.get("win")), len(events)),
        "avg_turn_count": average(event.get("turn_count", 0) for event in events),
        "avg_player_hp_end": average(event.get("player_hp_end", 0) for event in events),
        "avg_enemy_hp_end": average(event.get("enemy_hp_end", 0) for event in events),
        "avg_damage_taken": average(event.get("damage_taken", 0) for event in events),
        "avg_damage_dealt": average(event.get("damage_dealt", 0) for event in events),
        "avg_cards_played": average(event.get("cards_played_count", 0) for event in events),
        "avg_enemy_cards_played": average(event.get("enemy_cards_played_count", 0) for event in events),
        "avg_hp_delta": average(event.get("player_hp_delta", 0) for event in events),
        "runtime_primitive_trigger_rate": ratio(primitive_trigger_events, len(events)),
        "weapon_followup_trigger_rate": ratio(sum(1 for event in events if int(event.get("weapon_followup_trigger_count", 0)) > 0), len(events)),
        "clue_pressure_trigger_rate": ratio(sum(1 for event in events if int(event.get("clue_pressure_trigger_count", 0)) > 0), len(events)),
        "dual_weapon_usage_rate": ratio(sum(1 for event in events if int(event.get("dual_weapon_cards_played_count", 0)) > 0), len(events)),
        "reward_claim_rate": ratio(sum(1 for event in events if event.get("reward_claimed")), len(events)),
        "telemetry_detail_level_summary": dict(Counter(str(event.get("telemetry_detail_level", "minimal")) for event in events)),
        "mechanism_underused_count": sum(1 for event in events if event.get("mechanism_underused_flag")),
        "too_easy_count": sum(1 for event in events if event.get("too_easy_flag")),
        "too_hard_count": sum(1 for event in events if event.get("too_hard_flag")),
        "too_long_count": sum(1 for event in events if event.get("too_long_flag")),
        "burst_damage_count": sum(1 for event in events if event.get("burst_damage_flag")),
        "reward_mismatch_count": sum(1 for event in events if event.get("reward_mismatch_flag")),
        "card_dead_count": sum(1 for event in events if event.get("card_dead_flag")),
        "runtime_primitive_enabled_rate": ratio(trigger_enabled_count, len(events)),
    }
    if mapping is not None:
        payload.update(
            {
                "formal_encounter_id": str(mapping.get("formal_encounter_id", "")),
                "formal_battle_id": str(mapping.get("formal_battle_id", "")),
                "generated_battle_slot_id": str(mapping.get("generated_battle_slot_id", "")),
                "generated_deck_id": str(mapping.get("generated_deck_id", "")),
                "reward_plan_id": str(mapping.get("reward_plan_id", "")),
                "encounter_tier": str(mapping.get("encounter_tier", slot.get("encounter_tier", "") if slot else "")),
                "encounter_kind": str(mapping.get("encounter_kind", slot.get("encounter_kind", "") if slot else "")),
                "sequence_position": int(mapping.get("sequence_position", 0) or 0),
                "runtime_primitives": list(slot.get("runtime_primitives", []) if slot else []),
                "player_wujing_cap": int(mapping.get("player_wujing_cap", slot.get("player_wujing_cap", 0) if slot else 0) or 0),
                "deck_power_score": float(deck.get("deck_power_score", 0) if deck else 0),
                "reward_tier": str(reward.get("reward_tier", mapping.get("reward_tier", "")) if reward else mapping.get("reward_tier", "")),
            }
        )
    return payload


def build_event_notes(runtime_primitives: list[str], converted_effect: str, mechanism_underused: bool) -> list[str]:
    notes: list[str] = []
    if runtime_primitives:
        notes.append(f"runtime_primitives={','.join(runtime_primitives)}")
    if converted_effect:
        notes.append(f"clue_pressure_converted_effect={converted_effect}")
    if mechanism_underused:
        notes.append("mechanism_underused_detected")
    return notes


def build_multi_pack_summary(reports: list[dict[str, Any]], samples: int) -> dict[str, Any]:
    rows = []
    total_encounters = 0
    total_events = 0
    detail_summary: Counter[str] = Counter()
    for report in reports:
        pack_metrics = report.get("pack_metrics", {})
        total_encounters += int(report.get("formal_encounter_total_count", 0))
        total_events += int(report.get("evaluation_event_count", 0))
        detail_summary.update(report.get("telemetry_detail_level_summary", {}))
        rows.append(
            {
                "mechanic_profile_id": report.get("mechanic_profile_id", ""),
                "content_pack_id": report.get("content_pack_id", ""),
                "formal_encounter_total_count": report.get("formal_encounter_total_count", 0),
                "evaluation_event_count": report.get("evaluation_event_count", 0),
                "evaluation_policy": report.get("evaluation_policy", ""),
                "telemetry_detail_level": report.get("telemetry_detail_level", ""),
                "win_rate": pack_metrics.get("win_rate", 0),
                "avg_turn_count": pack_metrics.get("avg_turn_count", 0),
                "avg_player_hp_end": pack_metrics.get("avg_player_hp_end", 0),
                "runtime_primitive_trigger_rate": pack_metrics.get("runtime_primitive_trigger_rate", 0),
                "weapon_followup_trigger_rate": pack_metrics.get("weapon_followup_trigger_rate", 0),
                "clue_pressure_trigger_rate": pack_metrics.get("clue_pressure_trigger_rate", 0),
                "dual_weapon_usage_rate": pack_metrics.get("dual_weapon_usage_rate", 0),
            }
        )
    hardest = min(rows, key=lambda item: (item["win_rate"], -item["avg_turn_count"], item["mechanic_profile_id"])) if rows else {}
    easiest = max(rows, key=lambda item: (item["win_rate"], -item["avg_player_hp_end"], item["mechanic_profile_id"])) if rows else {}
    longest = max(rows, key=lambda item: (item["avg_turn_count"], item["mechanic_profile_id"])) if rows else {}
    highest_mechanic = max(rows, key=lambda item: (item["runtime_primitive_trigger_rate"], item["mechanic_profile_id"])) if rows else {}
    lowest_mechanic = min(rows, key=lambda item: (item["runtime_primitive_trigger_rate"], item["mechanic_profile_id"])) if rows else {}
    return {
        "generated_at": now_iso(),
        "evaluated_pack_count": len(rows),
        "evaluated_encounter_count": total_encounters,
        "total_eval_events": total_events,
        "samples_per_encounter": samples,
        "evaluation_policy": "deterministic_headless",
        "packs": rows,
        "hardest_pack_by_win_rate": pack_ref(hardest),
        "easiest_pack_by_win_rate": pack_ref(easiest),
        "longest_pack_by_avg_turn_count": pack_ref(longest),
        "highest_mechanic_trigger_pack": pack_ref(highest_mechanic),
        "lowest_mechanic_trigger_pack": pack_ref(lowest_mechanic),
        "evaluation_detail_level_summary": dict(detail_summary),
    }


def default_r3_pack_set() -> list[tuple[str, str]]:
    channels = release_lib.show_channels()
    current = channels.get("current_release", {})
    candidate = channels.get("candidate_release", {})
    fallback = channels.get("fallback_release", {})
    preferred = [
        (str(current.get("mechanic_profile_id", "")), str(current.get("content_pack_id", ""))),
        (str(candidate.get("mechanic_profile_id", "")), str(candidate.get("content_pack_id", ""))),
        ("clue_pressure_v0_1", "clue_pressure_v0_1_formal_sequence_pack_001"),
        (str(fallback.get("mechanic_profile_id", "")), str(fallback.get("content_pack_id", ""))),
    ]
    deduped: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for profile_id, pack_id in preferred:
        if not profile_id or not pack_id:
            continue
        key = (profile_id, pack_id)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(key)
    return deduped


def resolve_generated_dir(profile_id: str, content_pack_id: str | None) -> Path:
    if content_pack_id:
        pack_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs" / content_pack_id
        if pack_dir.exists():
            return pack_dir
    root_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id
    root_manifest = root_dir / "runtime_manifest.json"
    if root_manifest.exists():
        payload = read_json(root_manifest)
        if not content_pack_id or str(payload.get("content_pack_id", "")) == str(content_pack_id):
            return root_dir
    raise SystemExit(f"generated pack not found: {profile_id} / {content_pack_id or '(root)'}")


def run_json_path(evaluation_run_id: str) -> Path:
    return RUNS_DIR / f"{evaluation_run_id}.json"


def run_md_path(evaluation_run_id: str) -> Path:
    return RUNS_DIR / f"{evaluation_run_id}.md"


def pack_report_json_path(profile_id: str, content_pack_id: str) -> Path:
    return REPORTS_DIR / f"{profile_id}__{content_pack_id}__evaluation_report.json"


def pack_report_md_path(profile_id: str, content_pack_id: str) -> Path:
    return REPORTS_DIR / f"{profile_id}__{content_pack_id}__evaluation_report.md"


def build_run_id(profile_id: str, content_pack_id: str) -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{profile_id}__{content_pack_id}__{stamp}"


def append_events(events: list[dict[str, Any]]) -> None:
    EVENTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with EVENTS_PATH.open("a", encoding="utf-8") as handle:
        for event in events:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")


def build_report_markdown(report: dict[str, Any]) -> str:
    pack = report.get("pack_metrics", {})
    lines = [
        "# Headless Evaluation Report",
        "",
        f"- evaluation_run_id: `{report.get('evaluation_run_id', '')}`",
        f"- mechanic_profile_id: `{report.get('mechanic_profile_id', '')}`",
        f"- content_pack_id: `{report.get('content_pack_id', '')}`",
        f"- evaluation_policy: `{report.get('evaluation_policy', '')}`",
        f"- telemetry_detail_level: `{report.get('telemetry_detail_level', '')}`",
        f"- formal_encounter_total_count: `{report.get('formal_encounter_total_count', 0)}`",
        f"- samples_per_encounter: `{report.get('samples_per_encounter', 0)}`",
        f"- evaluation_event_count: `{report.get('evaluation_event_count', 0)}`",
        f"- win_rate: `{pack.get('win_rate', 0)}`",
        f"- avg_turn_count: `{pack.get('avg_turn_count', 0)}`",
        f"- avg_player_hp_end: `{pack.get('avg_player_hp_end', 0)}`",
        f"- avg_damage_taken: `{pack.get('avg_damage_taken', 0)}`",
        f"- runtime_primitive_trigger_rate: `{pack.get('runtime_primitive_trigger_rate', 0)}`",
        "",
        "## Encounter Metrics",
    ]
    for row in report.get("encounter_metrics", []):
        lines.append(
            f"- #{row.get('sequence_position')} `{row.get('formal_encounter_id')}` | "
            f"win_rate={row.get('win_rate')} | turn={row.get('avg_turn_count')} | "
            f"hp_end={row.get('avg_player_hp_end')} | primitive={row.get('runtime_primitive_trigger_rate')}"
        )
    return "\n".join(lines) + "\n"


def build_summary_markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# R3 Default Pack Set Evaluation Summary",
        "",
        f"- evaluated_pack_count: `{summary.get('evaluated_pack_count', 0)}`",
        f"- evaluated_encounter_count: `{summary.get('evaluated_encounter_count', 0)}`",
        f"- total_eval_events: `{summary.get('total_eval_events', 0)}`",
        f"- evaluation_policy: `{summary.get('evaluation_policy', '')}`",
        f"- hardest_pack_by_win_rate: `{summary.get('hardest_pack_by_win_rate', '')}`",
        f"- easiest_pack_by_win_rate: `{summary.get('easiest_pack_by_win_rate', '')}`",
        "",
        "| Profile | Pack | Win Rate | Avg Turn | Avg Player HP End | Primitive Trigger |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for row in summary.get("packs", []):
        lines.append(
            f"| `{row.get('mechanic_profile_id', '')}` | `{row.get('content_pack_id', '')}` | "
            f"{row.get('win_rate', 0)} | {row.get('avg_turn_count', 0)} | {row.get('avg_player_hp_end', 0)} | "
            f"{row.get('runtime_primitive_trigger_rate', 0)} |"
        )
    return "\n".join(lines) + "\n"


def pack_ref(row: dict[str, Any]) -> str:
    if not row:
        return ""
    return f"{row.get('mechanic_profile_id', '')} / {row.get('content_pack_id', '')}"


def average(values) -> float:
    clean = [float(value) for value in values if value is not None]
    if not clean:
        return 0.0
    return round(sum(clean) / len(clean), 4)


def ratio(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return round(float(numerator) / float(denominator), 4)


def tier_rank(value: str) -> int:
    return {"basic": 1, "early": 1, "mid": 2, "late": 3, "boss": 4}.get(value, 0)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
