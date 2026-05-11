#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
TELEMETRY_PATH = ROOT / "data" / "aigc_battle" / "telemetry" / "aigc_sequence_telemetry.jsonl"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: python3 tools/aigc_battle/build_real_telemetry_snapshot.py <profile_id>", file=sys.stderr)
        return 1
    profile_id = argv[1]
    generated_dir = GENERATED_DIR / profile_id
    runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")
    events = read_telemetry_events(profile_id)
    pack_id = str(runtime_manifest.get("content_pack_id", ""))
    slot_index = {str(slot.get("battle_slot_id", "")): slot for slot in runtime_manifest.get("battle_slots", [])}
    deck_index = {str(deck.get("deck_id", "")): deck for deck in runtime_manifest.get("decks", [])}
    card_index = {str(card.get("card_id", card.get("id", ""))): card for card in runtime_manifest.get("cards", [])}

    by_encounter: dict[str, list[dict[str, Any]]] = defaultdict(list)
    card_usage: Counter[str] = Counter()
    for event in events:
        encounter_id = str(event.get("formal_encounter_id", ""))
        by_encounter[encounter_id].append(event)
        for card_id in event.get("enemy_cards_played", []) or []:
            card_usage[str(card_id)] += 1

    avg_turn_count = average([int(event.get("turn_count", 0)) for event in events])
    avg_damage_taken = average([int(event.get("damage_taken", 0)) for event in events])
    avg_damage_dealt = average([int(event.get("damage_dealt", 0)) for event in events])
    avg_player_hp_end = average([int(event.get("player_hp_end", 0)) for event in events])
    avg_enemy_hp_end = average([int(event.get("enemy_hp_end", 0)) for event in events])
    followup_total = sum(int(event.get("weapon_followup_trigger_count", 0)) for event in events)
    followup_by_encounter = {
        encounter_id: sum(int(event.get("weapon_followup_trigger_count", 0)) for event in encounter_events)
        for encounter_id, encounter_events in by_encounter.items()
    }
    encounter_ids = [str(item.get("formal_encounter_id", "")) for item in read_json(generated_dir / "formal_sequence_inventory.generated.json")]
    missing = [enc_id for enc_id in encounter_ids if enc_id not in by_encounter]

    too_easy: list[dict[str, Any]] = []
    too_hard: list[dict[str, Any]] = []
    long_battles: list[dict[str, Any]] = []
    burst_damage: list[dict[str, Any]] = []
    reward_mismatch: list[dict[str, Any]] = []
    followup_underused: list[dict[str, Any]] = []
    adjusted: list[dict[str, Any]] = []

    for encounter_id, encounter_events in by_encounter.items():
        event = encounter_events[-1]
        slot = slot_index.get(str(event.get("generated_battle_slot_id", "")), {})
        turn_count = int(event.get("turn_count", 0))
        player_hp_end = int(event.get("player_hp_end", 0))
        player_hp_start = int(event.get("player_hp_start", 0))
        damage_taken = int(event.get("damage_taken", 0))
        win = bool(event.get("win", False))
        followup_count = int(event.get("weapon_followup_trigger_count", 0))
        encounter_tier = str(slot.get("encounter_tier", event.get("encounter_tier", "")))
        reward_tier = str(slot.get("reward_tier", ""))
        sequence_position = int(slot.get("sequence_position", event.get("sequence_position", 0)))
        if win and turn_count <= 2 and player_hp_end >= max(player_hp_start - 2, 0):
            too_easy.append({"formal_encounter_id": encounter_id, "generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "reason": "fast_win_high_hp"})
            adjusted.append({"generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "recommendation": "too_easy"})
        if (not win) or player_hp_end <= max(player_hp_start // 3, 4):
            too_hard.append({"formal_encounter_id": encounter_id, "generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "reason": "low_hp_or_loss"})
            adjusted.append({"generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "recommendation": "too_hard"})
        if turn_count >= 4:
            long_battles.append({"formal_encounter_id": encounter_id, "generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "turn_count": turn_count})
            adjusted.append({"generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "recommendation": "long_battle"})
        if damage_taken >= 8:
            burst_damage.append({"formal_encounter_id": encounter_id, "generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "damage_taken": damage_taken})
        if reward_tier and encounter_tier and reward_tier_rank(reward_tier) < reward_tier_rank(encounter_tier):
            reward_mismatch.append({"formal_encounter_id": encounter_id, "generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "reward_tier": reward_tier, "encounter_tier": encounter_tier})
        if followup_count <= 0:
            followup_underused.append({"formal_encounter_id": encounter_id, "generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "sequence_position": sequence_position})
            adjusted.append({"generated_battle_slot_id": event.get("generated_battle_slot_id", ""), "recommendation": "followup_underused"})

    used_cards = [card_id for card_id, count in card_usage.items() if count > 0]
    overused = [{"card_id": card_id, "usage_count": count} for card_id, count in card_usage.most_common(5) if count >= 2]
    underused = [{"card_id": card_id, "usage_count": card_usage.get(card_id, 0)} for card_id in card_index.keys() if card_usage.get(card_id, 0) == 0][:10]

    recs = build_recommendations(too_easy, too_hard, long_battles, followup_underused)
    snapshot = {
        "snapshot_path": str((generated_dir / "real_telemetry_snapshot.json").relative_to(ROOT)),
        "mechanic_profile_id": profile_id,
        "content_pack_id": pack_id,
        "telemetry_event_count": len(events),
        "encounters_with_real_telemetry_count": len(by_encounter),
        "missing_real_telemetry_encounters": missing,
        "avg_turn_count": avg_turn_count,
        "avg_damage_taken": avg_damage_taken,
        "avg_damage_dealt": avg_damage_dealt,
        "avg_player_hp_end": avg_player_hp_end,
        "avg_enemy_hp_end": avg_enemy_hp_end,
        "weapon_followup_trigger_total": followup_total,
        "weapon_followup_trigger_by_encounter": followup_by_encounter,
        "too_easy_candidates": too_easy,
        "too_hard_candidates": too_hard,
        "long_battle_candidates": long_battles,
        "burst_damage_candidates": burst_damage,
        "reward_mismatch_candidates": reward_mismatch,
        "overused_card_candidates": overused,
        "underused_card_candidates": underused,
        "followup_underused_candidates": followup_underused,
        "rebuild_recommendations": recs,
        "adjusted_or_flagged_encounters": adjusted,
        "snapshot_ready": len(events) > 0,
        "real_metrics_ready": len(events) > 0 and avg_turn_count > 0,
        "sequence_balance_summary_path": str((generated_dir / "sequence_balance_summary.json").relative_to(ROOT)),
        "runtime_manifest_path": str((generated_dir / "runtime_manifest.json").relative_to(ROOT)),
        "telemetry_detail_level": "partial" if events else "minimal",
    }
    json_path = generated_dir / "real_telemetry_snapshot.json"
    md_path = generated_dir / "real_telemetry_snapshot.md"
    write_json(json_path, snapshot)
    write_markdown(md_path, snapshot)
    print(f"wrote {json_path.relative_to(ROOT)}")
    return 0


def build_recommendations(too_easy: list[dict[str, Any]], too_hard: list[dict[str, Any]], long_battles: list[dict[str, Any]], followup_underused: list[dict[str, Any]]) -> list[dict[str, Any]]:
    recs: list[dict[str, Any]] = []
    for item in too_easy:
        recs.append({"generated_battle_slot_id": item["generated_battle_slot_id"], "recommendation": "too_easy", "adjustment": {"target_power_shift": 2, "followup_density_shift": 0.05}})
    for item in too_hard:
        recs.append({"generated_battle_slot_id": item["generated_battle_slot_id"], "recommendation": "too_hard", "adjustment": {"target_power_shift": -2, "followup_density_shift": -0.05}})
    for item in long_battles:
        recs.append({"generated_battle_slot_id": item["generated_battle_slot_id"], "recommendation": "long_battle", "adjustment": {"pressure_bias": "increase_output"}})
    for item in followup_underused:
        recs.append({"generated_battle_slot_id": item["generated_battle_slot_id"], "recommendation": "followup_underused", "adjustment": {"ensure_linker_match": True, "followup_density_shift": 0.08}})
    return recs


def reward_tier_rank(value: str) -> int:
    mapping = {"basic": 1, "mid": 2, "late": 3, "boss": 4, "early": 1}
    return mapping.get(value, 0)


def average(values: list[int]) -> float:
    clean = [value for value in values if value is not None]
    if not clean:
        return 0.0
    return round(sum(clean) / len(clean), 2)


def read_telemetry_events(profile_id: str) -> list[dict[str, Any]]:
    if not TELEMETRY_PATH.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in TELEMETRY_PATH.read_text(encoding="utf-8").splitlines():
        clean = line.strip()
        if not clean:
            continue
        payload = json.loads(clean)
        if str(payload.get("mechanic_profile_id", "")) == profile_id:
            rows.append(payload)
    return rows


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, snapshot: dict[str, Any]) -> None:
    lines = [
        "# Real Telemetry Snapshot",
        "",
        f"- mechanic_profile_id: {snapshot['mechanic_profile_id']}",
        f"- content_pack_id: {snapshot['content_pack_id']}",
        f"- telemetry_event_count: {snapshot['telemetry_event_count']}",
        f"- encounters_with_real_telemetry_count: {snapshot['encounters_with_real_telemetry_count']}",
        f"- avg_turn_count: {snapshot['avg_turn_count']}",
        f"- avg_damage_taken: {snapshot['avg_damage_taken']}",
        f"- avg_damage_dealt: {snapshot['avg_damage_dealt']}",
        f"- weapon_followup_trigger_total: {snapshot['weapon_followup_trigger_total']}",
        f"- real_metrics_ready: {str(snapshot['real_metrics_ready']).lower()}",
        "",
        "## Rebuild Recommendations",
    ]
    for item in snapshot["rebuild_recommendations"]:
        lines.append(f"- {item['generated_battle_slot_id']}: {item['recommendation']}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
