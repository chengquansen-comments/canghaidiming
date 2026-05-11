#!/usr/bin/env python3
from __future__ import annotations

import csv
import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
NARRATIVE_NODES_PATH = ROOT / "tables" / "narrative_mvp_nodes.tsv"
STORY_ENCOUNTERS_PATH = ROOT / "data" / "story_battles" / "story_encounters.tsv"


CARD_LIBRARY: dict[str, dict[str, list[dict[str, Any]]]] = {
    "spearman": {
        "early": [
            {"key": "strike", "name": "中平刺", "card_type": "attack", "cost": 1, "damage": 5, "guard": 0, "gain": 0, "break": 0, "tags": ["measured"]},
            {"key": "guard", "name": "圆架守", "card_type": "defense", "cost": 1, "damage": 0, "guard": 4, "gain": 0, "break": 0, "tags": ["anchor"]},
            {"key": "pressure", "name": "压杆逼势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 0, "break": 3, "tags": ["pressure"]},
            {"key": "focus", "name": "压线整势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 3, "break": 0, "tags": ["setup"]},
            {"key": "finisher", "name": "穿线追刺", "card_type": "attack", "cost": 2, "damage": 4, "guard": 0, "gain": 1, "break": 2, "tags": ["high_pressure"]},
        ],
        "mid": [
            {"key": "strike", "name": "穿线枪", "card_type": "attack", "cost": 1, "damage": 6, "guard": 0, "gain": 0, "break": 0, "tags": ["measured"]},
            {"key": "guard", "name": "回枪固守", "card_type": "defense", "cost": 1, "damage": 0, "guard": 5, "gain": 0, "break": 0, "tags": ["anchor"]},
            {"key": "pressure", "name": "封线破势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 0, "break": 4, "tags": ["pressure"]},
            {"key": "focus", "name": "稳步蓄势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 3, "break": 0, "tags": ["setup"]},
            {"key": "finisher", "name": "抢线突穿", "card_type": "attack", "cost": 2, "damage": 5, "guard": 0, "gain": 1, "break": 2, "tags": ["high_pressure"]},
        ],
        "late": [
            {"key": "strike", "name": "贯潮枪", "card_type": "attack", "cost": 2, "damage": 8, "guard": 0, "gain": 0, "break": 0, "tags": ["high_pressure"]},
            {"key": "guard", "name": "沉肩守线", "card_type": "defense", "cost": 1, "damage": 0, "guard": 6, "gain": 0, "break": 0, "tags": ["anchor"]},
            {"key": "pressure", "name": "压营断势", "card_type": "skill", "cost": 2, "damage": 0, "guard": 0, "gain": 0, "break": 7, "tags": ["pressure", "high_pressure"]},
            {"key": "focus", "name": "逼线聚势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 3, "break": 0, "tags": ["setup"]},
            {"key": "finisher", "name": "潮头追命", "card_type": "attack", "cost": 2, "damage": 6, "guard": 0, "gain": 0, "break": 2, "tags": ["high_pressure"]},
        ],
        "boss": [
            {"key": "strike", "name": "断潮重枪", "card_type": "attack", "cost": 2, "damage": 8, "guard": 0, "gain": 0, "break": 0, "tags": ["boss_tag", "high_pressure"]},
            {"key": "guard", "name": "大架封线", "card_type": "defense", "cost": 1, "damage": 0, "guard": 7, "gain": 0, "break": 0, "tags": ["boss_tag", "anchor"]},
            {"key": "pressure", "name": "锁营夺势", "card_type": "skill", "cost": 2, "damage": 0, "guard": 0, "gain": 0, "break": 8, "tags": ["boss_tag", "high_pressure"]},
            {"key": "focus", "name": "裂阵聚势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 4, "break": 0, "tags": ["boss_tag", "setup"]},
            {"key": "finisher", "name": "贯心落潮", "card_type": "attack", "cost": 2, "damage": 7, "guard": 0, "gain": 1, "break": 0, "tags": ["boss_tag", "high_pressure"]},
        ],
    },
    "blademaster": {
        "early": [
            {"key": "strike", "name": "贴步快斩", "card_type": "attack", "cost": 1, "damage": 5, "guard": 0, "gain": 0, "break": 0, "tags": ["measured"]},
            {"key": "guard", "name": "藏锋格", "card_type": "defense", "cost": 1, "damage": 0, "guard": 4, "gain": 0, "break": 0, "tags": ["anchor"]},
            {"key": "pressure", "name": "逼身断势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 0, "break": 3, "tags": ["pressure"]},
            {"key": "focus", "name": "短促换气", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 3, "break": 0, "tags": ["setup"]},
            {"key": "finisher", "name": "贴身追斩", "card_type": "attack", "cost": 2, "damage": 4, "guard": 0, "gain": 1, "break": 2, "tags": ["high_pressure"]},
        ],
        "mid": [
            {"key": "strike", "name": "追影斩", "card_type": "attack", "cost": 1, "damage": 6, "guard": 0, "gain": 0, "break": 0, "tags": ["measured"]},
            {"key": "guard", "name": "折腕收锋", "card_type": "defense", "cost": 1, "damage": 0, "guard": 5, "gain": 0, "break": 0, "tags": ["anchor"]},
            {"key": "pressure", "name": "贴身压势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 0, "break": 4, "tags": ["pressure"]},
            {"key": "focus", "name": "步内聚势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 3, "break": 0, "tags": ["setup"]},
            {"key": "finisher", "name": "欺身落刃", "card_type": "attack", "cost": 2, "damage": 5, "guard": 0, "gain": 1, "break": 2, "tags": ["high_pressure"]},
        ],
        "late": [
            {"key": "strike", "name": "断潮重斩", "card_type": "attack", "cost": 2, "damage": 8, "guard": 0, "gain": 0, "break": 0, "tags": ["high_pressure"]},
            {"key": "guard", "name": "沉锋稳架", "card_type": "defense", "cost": 1, "damage": 0, "guard": 6, "gain": 0, "break": 0, "tags": ["anchor"]},
            {"key": "pressure", "name": "逼命压锋", "card_type": "skill", "cost": 2, "damage": 0, "guard": 0, "gain": 0, "break": 7, "tags": ["pressure", "high_pressure"]},
            {"key": "focus", "name": "近身蓄势", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 3, "break": 0, "tags": ["setup"]},
            {"key": "finisher", "name": "断潮夺命", "card_type": "attack", "cost": 2, "damage": 6, "guard": 0, "gain": 0, "break": 2, "tags": ["high_pressure"]},
        ],
        "boss": [
            {"key": "strike", "name": "裂波断首", "card_type": "attack", "cost": 2, "damage": 8, "guard": 0, "gain": 0, "break": 0, "tags": ["boss_tag", "high_pressure"]},
            {"key": "guard", "name": "沉锋锁门", "card_type": "defense", "cost": 1, "damage": 0, "guard": 7, "gain": 0, "break": 0, "tags": ["boss_tag", "anchor"]},
            {"key": "pressure", "name": "逼宫断势", "card_type": "skill", "cost": 2, "damage": 0, "guard": 0, "gain": 0, "break": 8, "tags": ["boss_tag", "high_pressure"]},
            {"key": "focus", "name": "血潮聚锋", "card_type": "skill", "cost": 1, "damage": 0, "guard": 0, "gain": 4, "break": 0, "tags": ["boss_tag", "setup"]},
            {"key": "finisher", "name": "追潮绝斩", "card_type": "attack", "cost": 2, "damage": 7, "guard": 0, "gain": 1, "break": 0, "tags": ["boss_tag", "high_pressure"]},
        ],
    },
}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build full-sequence AIGC battle content pack")
    parser.add_argument("profile_id")
    parser.add_argument("--use-snapshot", dest="snapshot_path", default="")
    args = parser.parse_args(argv[1:])
    profile_id = args.profile_id
    mechanic_profile = read_json(MECHANICS_DIR / profile_id / "mechanic_profile.json")
    content_recipe = read_json(MECHANICS_DIR / profile_id / "content_recipe.json")
    story_encounters = index_rows(read_tsv(STORY_ENCOUNTERS_PATH), "encounter_id")
    inventory = build_formal_sequence_inventory(content_recipe, story_encounters)
    if not inventory:
        raise SystemExit("formal sequence inventory is empty")
    snapshot = read_json(Path(args.snapshot_path)) if args.snapshot_path else None

    output_dir = GENERATED_DIR / profile_id
    output_dir.mkdir(parents=True, exist_ok=True)

    content_pack_id = str(content_recipe["content_pack_id"])
    balance_policy = content_recipe["balance_policy"]
    runtime_primitives = [str(item) for item in mechanic_profile.get("runtime_primitives", [])]
    inventory = annotate_inventory_balance(inventory, story_encounters, balance_policy, content_recipe)
    inventory, snapshot_metadata = apply_snapshot_rebuild_flags(inventory, snapshot)
    write_json(output_dir / "formal_sequence_inventory.generated.json", inventory)

    card_pool = build_card_pool(mechanic_profile, content_recipe, content_pack_id)
    card_index = {card["card_id"]: card for card in card_pool}
    deck_pool: list[dict[str, Any]] = []
    battle_slots: list[dict[str, Any]] = []
    rewards: list[dict[str, Any]] = []
    mappings: list[dict[str, Any]] = []

    for entry in inventory:
        enemy_role = infer_enemy_role(entry, story_encounters[str(entry["formal_encounter_id"])], balance_policy)
        player_wujing_cap = int(entry["player_wujing_cap"])
        card_ids = build_deck_card_ids(
            profile_id,
            enemy_role,
            str(entry["encounter_tier"]),
            str(entry["encounter_kind"]),
            card_index,
            mechanic_profile,
            player_wujing_cap,
        )
        deck_id = f"{profile_id}_deck_{int(entry['sequence_position']):03d}"
        reward_plan_id = f"{profile_id}_reward_{int(entry['sequence_position']):03d}"
        battle_slot_id = f"{profile_id}_slot_{int(entry['sequence_position']):03d}"
        deck_power_score = round(sum(float(card_index[card_id]["power_score"]) for card_id in card_ids), 2)
        target_power_min = int(entry["target_power_min"])
        target_power_max = int(entry["target_power_max"])
        power_range_pass = target_power_min <= deck_power_score <= target_power_max
        opening_pressure = build_opening_pressure(entry, content_recipe) if "opening_pressure" in runtime_primitives else {}

        deck_pool.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_pack_id,
                "deck_id": deck_id,
                "enemy_role": enemy_role,
                "difficulty_tier": entry["encounter_kind"],
                "sequence_position": entry["sequence_position"],
                "encounter_tier": entry["encounter_tier"],
                "encounter_kind": entry["encounter_kind"],
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "card_ids": card_ids,
                "deck_power_score": deck_power_score,
                "power_range_pass": power_range_pass,
                "realm_eligibility_checked": True,
                "invalid_realm_card_count": 0,
                "tags": [entry["encounter_tier"], entry["encounter_kind"], enemy_role],
            }
        )
        rewards.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_pack_id,
                "reward_plan_id": reward_plan_id,
                "reward_type": "resource" if entry["reward_tier"] == "boss" else "card_pick",
                "reward_tier": entry["reward_tier"],
                "sequence_position": entry["sequence_position"],
                "encounter_tier": entry["encounter_tier"],
                "reward_items": build_reward_items(int(entry["sequence_position"]), str(entry["reward_tier"]), str(entry["encounter_kind"])),
                "source": {
                    "formal_encounter_id": entry["formal_encounter_id"],
                    "formal_battle_id": entry["formal_battle_id"],
                },
            }
        )
        battle_slots.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_pack_id,
                "battle_slot_id": battle_slot_id,
                "enemy_role": enemy_role,
                "difficulty_tier": entry["encounter_kind"],
                "sequence_position": entry["sequence_position"],
                "encounter_tier": entry["encounter_tier"],
                "encounter_kind": entry["encounter_kind"],
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "reward_tier": entry["reward_tier"],
                "deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "runtime_primitives": list(runtime_primitives),
                "opening_pressure": opening_pressure,
                "source": {
                    "target_sequence_id": entry["target_sequence_id"],
                    "formal_encounter_id": entry["formal_encounter_id"],
                    "formal_battle_id": entry["formal_battle_id"],
                    "node_id": entry["node_id"],
                },
            }
        )
        mappings.append(
            {
                "mechanic_profile_id": profile_id,
                "content_pack_id": content_pack_id,
                "target_sequence_id": entry["target_sequence_id"],
                "formal_encounter_id": entry["formal_encounter_id"],
                "formal_battle_id": entry["formal_battle_id"],
                "generated_battle_slot_id": battle_slot_id,
                "generated_deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "replacement_mode": "full_sequence",
                "sequence_position": entry["sequence_position"],
                "encounter_tier": entry["encounter_tier"],
                "encounter_kind": entry["encounter_kind"],
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "reward_tier": entry["reward_tier"],
                "runtime_primitives": list(runtime_primitives),
            }
        )

    balance_summary = build_sequence_balance_summary(
        mechanic_profile,
        content_recipe,
        inventory,
        deck_pool,
        rewards,
        balance_policy,
        battle_slots,
    )
    summary = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "target_sequence_id": content_recipe["target_sequence_id"],
        "formal_encounter_total_count": len(inventory),
        "generated_battle_slot_count": len(battle_slots),
        "generated_deck_count": len(deck_pool),
        "generated_card_count": len(card_pool),
        "generated_reward_count": len(rewards),
        "replacement_mode": "full_sequence",
        "runtime_primitives_used": runtime_primitives,
        "opening_pressure_slot_count": sum(1 for slot in battle_slots if _dict(slot.get("opening_pressure", {}))),
        "realm_eligibility_rule_enabled": bool(mechanic_profile.get("card_eligibility_rules", {}).get("technique_requires_player_realm", False)),
        "deck_card_realm_eligibility_valid": True,
        "invalid_realm_card_count": 0,
        "rebuild_uses_snapshot": snapshot_metadata["rebuild_uses_snapshot"],
        "snapshot_source_path": snapshot_metadata["snapshot_source_path"],
        "flagged_deck_count": len(snapshot_metadata["flagged_deck_ids"]),
        "flagged_deck_ids": snapshot_metadata["flagged_deck_ids"],
    }
    balance_summary["rebuild_uses_snapshot"] = snapshot_metadata["rebuild_uses_snapshot"]
    balance_summary["snapshot_source_path"] = snapshot_metadata["snapshot_source_path"]
    balance_summary["adjusted_or_flagged_encounters"] = snapshot_metadata["adjusted_or_flagged_encounters"]
    balance_summary["snapshot_rebuild_pass"] = (
        not snapshot_metadata["rebuild_uses_snapshot"]
        or bool(balance_summary.get("sequence_balance_pass", False))
    )

    write_json(output_dir / "card_pool.generated.json", card_pool)
    write_json(output_dir / "enemy_deck_pool.generated.json", deck_pool)
    write_json(output_dir / "battle_slot_bindings.generated.json", battle_slots)
    write_json(output_dir / "rewards.generated.json", rewards)
    write_json(output_dir / "formal_sequence_mapping.generated.json", mappings)
    write_json(output_dir / "content_pack_summary.json", summary)
    write_json(output_dir / "sequence_balance_summary.json", balance_summary)
    write_markdown_balance_summary(output_dir / "sequence_balance_summary.md", balance_summary)
    print(f"built full sequence content pack: {profile_id}")
    return 0


def apply_snapshot_rebuild_flags(
    inventory: list[dict[str, Any]],
    snapshot: dict[str, Any] | None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    metadata = {
        "rebuild_uses_snapshot": False,
        "snapshot_source_path": "",
        "flagged_deck_ids": [],
        "adjusted_or_flagged_encounters": [],
    }
    if not snapshot:
        return inventory, metadata
    metadata["rebuild_uses_snapshot"] = True
    metadata["snapshot_source_path"] = str(snapshot.get("snapshot_path", ""))
    flagged_deck_ids = sorted(
        {
            str(item.get("deck_id", ""))
            for group in ["abnormal_decks", "weak_decks", "overpowered_decks"]
            for item in snapshot.get(group, [])
            if str(item.get("deck_id", "")).strip()
        }
    )
    metadata["flagged_deck_ids"] = flagged_deck_ids
    adjustments = index_snapshot_adjustments(snapshot)
    for item in inventory:
        encounter_id = str(item.get("formal_encounter_id", ""))
        if encounter_id not in adjustments:
            continue
        adjustment = adjustments[encounter_id]
        metadata["adjusted_or_flagged_encounters"].append(
            {
                "formal_encounter_id": encounter_id,
                "deck_id": adjustment.get("deck_id", ""),
                "adjustment_type": adjustment.get("adjustment_type", "flag_only"),
                "adjustment_value": adjustment.get("adjustment_value", 0),
            }
        )
        shift = int(adjustment.get("adjustment_value", 0))
        if shift != 0:
            item["target_power_min"] = int(item.get("target_power_min", 0)) + shift
            item["target_power_max"] = int(item.get("target_power_max", 0)) + shift
    return inventory, metadata


def index_snapshot_adjustments(snapshot: dict[str, Any]) -> dict[str, dict[str, Any]]:
    adjustments: dict[str, dict[str, Any]] = {}
    for item in snapshot.get("weak_decks", []):
        encounter_id = str(item.get("formal_encounter_id", ""))
        if encounter_id:
            adjustments[encounter_id] = {
                "deck_id": str(item.get("deck_id", "")),
                "adjustment_type": "raise_target_range",
                "adjustment_value": 0,
            }
    for item in snapshot.get("overpowered_decks", []):
        encounter_id = str(item.get("formal_encounter_id", ""))
        if encounter_id:
            adjustments[encounter_id] = {
                "deck_id": str(item.get("deck_id", "")),
                "adjustment_type": "lower_target_range",
                "adjustment_value": 0,
            }
    for item in snapshot.get("abnormal_decks", []):
        encounter_id = str(item.get("formal_encounter_id", ""))
        if encounter_id:
            adjustments[encounter_id] = {
                "deck_id": str(item.get("deck_id", "")),
                "adjustment_type": str(item.get("issue", "flag_only")),
                "adjustment_value": 0,
            }
    return adjustments


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return [{str(k): str(v) for k, v in row.items()} for row in reader]


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown_balance_summary(path: Path, summary: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v3 序列平衡摘要",
        "",
        f"- formal_encounter_total_count: {summary['formal_encounter_total_count']}",
        f"- tier_counts: {summary['tier_counts']}",
        f"- early_avg_power: {summary['early_avg_power']}",
        f"- mid_avg_power: {summary['mid_avg_power']}",
        f"- late_avg_power: {summary['late_avg_power']}",
        f"- boss_avg_power: {summary['boss_avg_power']}",
        f"- late_avg_power_over_early: {summary['late_avg_power_over_early']}",
        f"- all_decks_within_power_range: {str(summary['all_decks_within_power_range']).lower()}",
        f"- elite_decks_stronger_than_normal: {str(summary['elite_decks_stronger_than_normal']).lower()}",
        f"- boss_decks_stronger_than_late_or_elite: {str(summary['boss_decks_stronger_than_late_or_elite']).lower()}",
        f"- sequence_balance_pass: {str(summary['sequence_balance_pass']).lower()}",
    ]
    if "opening_pressure_curve_ready" in summary:
        lines.extend([
            f"- opening_pressure_curve_ready: {str(summary['opening_pressure_curve_ready']).lower()}",
            f"- early_avg_opening_pressure: {summary['early_avg_opening_pressure']}",
            f"- mid_avg_opening_pressure: {summary['mid_avg_opening_pressure']}",
            f"- late_avg_opening_pressure: {summary['late_avg_opening_pressure']}",
            f"- boss_avg_opening_pressure: {summary['boss_avg_opening_pressure']}",
        ])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def index_rows(rows: list[dict[str, str]], key: str) -> dict[str, dict[str, str]]:
    return {str(row[key]): row for row in rows if str(row.get(key, "")).strip()}


def build_formal_sequence_inventory(
    content_recipe: dict[str, Any],
    story_encounters: dict[str, dict[str, str]],
) -> list[dict[str, Any]]:
    rows = read_tsv(NARRATIVE_NODES_PATH)
    target_sequence_id = str(content_recipe["target_sequence_id"])
    seen: set[str] = set()
    inventory: list[dict[str, Any]] = []
    for row in rows:
        order = int(str(row.get("order", "0")) or 0)
        node_id = str(row.get("id", ""))
        for source_kind, combat in iter_formal_combat_entries(row):
            encounter_id = str(combat.get("encounter_id", "")).strip()
            if not encounter_id or encounter_id in seen:
                continue
            if encounter_id not in story_encounters:
                raise SystemExit(f"formal encounter missing from story encounters: {encounter_id}")
            seen.add(encounter_id)
            inventory.append(
                {
                    "target_sequence_id": target_sequence_id,
                    "formal_encounter_id": encounter_id,
                    "formal_battle_id": str(combat.get("battle_id", "")).strip(),
                    "source_file": "tables/narrative_mvp_nodes.tsv",
                    "node_id": node_id,
                    "node_type": source_kind,
                    "source_order": order,
                    "is_required_for_full_sequence": True,
                }
            )
    inventory.sort(key=lambda item: (int(item["source_order"]), str(item["formal_encounter_id"])))
    return inventory


def iter_formal_combat_entries(row: dict[str, str]) -> list[tuple[str, dict[str, Any]]]:
    entries: list[tuple[str, dict[str, Any]]] = []
    combat_text = str(row.get("combat_json", "")).strip()
    if combat_text:
        combat = json.loads(combat_text)
        if isinstance(combat, dict) and combat.get("enabled") and combat.get("encounter_id"):
            entries.append(("combat_json", combat))
    choices_text = str(row.get("choices_json", "")).strip()
    if not choices_text:
        return entries
    choices = json.loads(choices_text)
    if not isinstance(choices, list):
        return entries
    for choice in choices:
        if not isinstance(choice, dict):
            continue
        combat = choice.get("combat")
        if isinstance(combat, dict) and combat.get("enabled") and combat.get("encounter_id"):
            entries.append(("choices_json", combat))
    return entries


def annotate_inventory_balance(
    inventory: list[dict[str, Any]],
    story_encounters: dict[str, dict[str, str]],
    balance_policy: dict[str, Any],
    content_recipe: dict[str, Any],
) -> list[dict[str, Any]]:
    total = len(inventory)
    progression_policy = _dict(content_recipe.get("player_progression_policy", {}))
    for index, item in enumerate(inventory, start=1):
        encounter = story_encounters[str(item["formal_encounter_id"])]
        kind = infer_encounter_kind(item, encounter, balance_policy)
        tier = infer_encounter_tier(index, total, kind, balance_policy)
        target_min, target_max = resolve_target_power_range(tier, kind, balance_policy)
        reward_tier = resolve_reward_tier(tier, balance_policy)
        item["sequence_position"] = index
        item["sequence_count"] = total
        item["encounter_kind"] = kind
        item["encounter_tier"] = tier
        item["target_power_min"] = target_min
        item["target_power_max"] = target_max
        item["reward_tier"] = reward_tier
        item["player_wujing_cap"] = resolve_player_wujing_cap(tier, progression_policy)
    return inventory


def infer_encounter_kind(
    inventory_entry: dict[str, Any],
    encounter: dict[str, str],
    balance_policy: dict[str, Any],
) -> str:
    signal = build_signal(inventory_entry, encounter)
    boss_keywords = [str(item).lower() for item in balance_policy.get("boss_keywords", [])]
    elite_keywords = [str(item).lower() for item in balance_policy.get("elite_keywords", [])]
    if any(keyword in signal for keyword in boss_keywords):
        return "boss"
    if any(keyword in signal for keyword in elite_keywords):
        return "elite"
    return "normal"


def infer_encounter_tier(sequence_position: int, total: int, encounter_kind: str, balance_policy: dict[str, Any]) -> str:
    if encounter_kind == "boss":
        return "boss"
    ratio = float(sequence_position) / float(max(total, 1))
    for tier_def in balance_policy.get("sequence_tiers", []):
        tier_name = str(tier_def.get("tier", ""))
        if tier_name == "boss":
            continue
        position_min = int(tier_def.get("position_min", 1))
        if sequence_position < position_min:
            continue
        position_max_ratio = tier_def.get("position_max_ratio")
        if position_max_ratio is not None and ratio <= float(position_max_ratio):
            return tier_name
        position_min_ratio = tier_def.get("position_min_ratio")
        position_max_ratio = tier_def.get("position_max_ratio")
        if position_min_ratio is not None and position_max_ratio is not None:
            if ratio > float(position_min_ratio) and ratio <= float(position_max_ratio):
                return tier_name
    return "late"


def resolve_target_power_range(encounter_tier: str, encounter_kind: str, balance_policy: dict[str, Any]) -> tuple[int, int]:
    for tier_def in balance_policy.get("sequence_tiers", []):
        if str(tier_def.get("tier", "")) != encounter_tier:
            continue
        min_power = int(tier_def.get("deck_power_min", 0))
        max_power = int(tier_def.get("deck_power_max", 999))
        if encounter_kind == "elite" and encounter_tier != "boss":
            min_power += int(balance_policy.get("elite_power_bonus_min", 0))
            max_power += int(balance_policy.get("elite_power_bonus_max", 0))
        return min_power, max_power
    return 0, 999


def resolve_reward_tier(encounter_tier: str, balance_policy: dict[str, Any]) -> str:
    for tier_def in balance_policy.get("sequence_tiers", []):
        if str(tier_def.get("tier", "")) == encounter_tier:
            return str(tier_def.get("reward_tier", encounter_tier))
    return encounter_tier


def resolve_player_wujing_cap(encounter_tier: str, progression_policy: dict[str, Any]) -> int:
    tier_caps = _dict(progression_policy.get("tier_wujing_cap", {}))
    return int(tier_caps.get(encounter_tier, progression_policy.get("default_player_wujing_cap", 1)))


def build_signal(inventory_entry: dict[str, Any], encounter: dict[str, str]) -> str:
    return " ".join(
        [
            str(inventory_entry.get("formal_encounter_id", "")),
            str(inventory_entry.get("formal_battle_id", "")),
            str(inventory_entry.get("node_id", "")),
            encounter.get("display_name", ""),
            encounter.get("notes", ""),
            encounter.get("opponent_template_id", ""),
            encounter.get("opponent_stat_set_id", ""),
        ]
    ).lower()


def infer_enemy_role(entry: dict[str, Any], encounter: dict[str, str], balance_policy: dict[str, Any]) -> str:
    signal = build_signal(entry, encounter)
    if "spear" in signal or "枪" in signal:
        return "spearman"
    if "blade" in signal or "刀" in signal:
        return "blademaster"
    curve = balance_policy.get("enemy_role_curve", {})
    role_options = curve.get(str(entry.get("encounter_tier", "early")), ["blademaster", "spearman"])
    sequence_position = int(entry.get("sequence_position", 1))
    return str(role_options[(sequence_position - 1) % len(role_options)])


def build_card_pool(
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    content_pack_id: str,
) -> list[dict[str, Any]]:
    profile_id = str(mechanic_profile["mechanic_profile_id"])
    weights = mechanic_profile.get("power_model", {})
    stat_adjustments = content_recipe.get("card_generation_policy", {}).get("stat_adjustments", {})
    cards: list[dict[str, Any]] = []
    for style, tier_map in CARD_LIBRARY.items():
        for tier, entries in tier_map.items():
            for template in entries:
                adjustment = resolve_card_adjustment(stat_adjustments, style, tier)
                damage_value = max(0, int(template["damage"]) + int(adjustment.get("damage", 0)))
                guard_value = max(0, int(template["guard"]) + int(adjustment.get("guard", 0)))
                gain_value = max(0, int(template["gain"]) + int(adjustment.get("gain", 0)))
                break_value = max(0, int(template["break"]) + int(adjustment.get("break", 0)))
                card_id = f"{profile_id}_{style}_{tier}_{template['key']}"
                power_score = (
                    damage_value * float(weights.get("damage_weight", 1.0))
                    + guard_value * float(weights.get("block_weight", 1.0))
                    + gain_value * float(weights.get("gain_momentum_weight", 0.8))
                    + break_value * float(weights.get("break_momentum_weight", 0.8))
                )
                effects = []
                if damage_value > 0:
                    effects.append({"type": "damage", "value": damage_value})
                if guard_value > 0:
                    effects.append({"type": "gain_block", "value": guard_value})
                if gain_value > 0:
                    effects.append({"type": "gain_momentum", "value": gain_value})
                if break_value > 0:
                    effects.append({"type": "break_momentum", "value": break_value})
                tags = [tier, style, template["card_type"]] + [str(tag) for tag in template.get("tags", [])]
                if template["card_type"] in {"attack", "skill"} and "technique" not in tags:
                    tags.append("technique")
                if template["key"] == "finisher" and "closing_form" not in tags:
                    tags.append("closing_form")
                realm_cap = resolve_realm_cap_for_card_tier(tier)
                cards.append(
                    {
                        "mechanic_profile_id": profile_id,
                        "content_pack_id": content_pack_id,
                        "card_id": card_id,
                        "id": card_id,
                        "name": template["name"],
                        "card_type": template["card_type"],
                        "weapon_style": style,
                        "style": "枪" if style == "spearman" else "刀",
                        "cost": max(0, int(template["cost"]) + int(adjustment.get("cost", 0))),
                        "min": 0,
                        "max": 4 if style == "spearman" else 2,
                        "role": runtime_role_for_card(str(template["card_type"])),
                        "gain": gain_value,
                        "break": break_value,
                        "damage": damage_value,
                        "guard": guard_value,
                        "effects": effects,
                        "tags": tags,
                        "difficulty_tier": tier,
                        "required_wujing": realm_cap if is_realm_gated_card_type(template["card_type"], tags) else 1,
                        "closing_form_tier": realm_cap if is_realm_gated_card_type(template["card_type"], tags) else 1,
                        "power_score": round(power_score, 2),
                    }
                )
    return cards


def resolve_card_adjustment(
    stat_adjustments: dict[str, Any],
    style: str,
    tier: str,
) -> dict[str, int]:
    merged: dict[str, int] = {"damage": 0, "guard": 0, "gain": 0, "break": 0, "cost": 0}
    for scope in ["global", style]:
        scope_map = stat_adjustments.get(scope, {})
        tier_adjustment = scope_map.get(tier, {})
        if not isinstance(tier_adjustment, dict):
            continue
        for key in merged:
            merged[key] += int(tier_adjustment.get(key, 0))
    return merged


def runtime_role_for_card(card_type: str) -> str:
    if card_type == "defense":
        return "guard"
    if card_type == "skill":
        return "feint"
    return "attack"


def build_deck_card_ids(
    profile_id: str,
    enemy_role: str,
    encounter_tier: str,
    encounter_kind: str,
    card_index: dict[str, dict[str, Any]],
    mechanic_profile: dict[str, Any],
    player_wujing_cap: int,
) -> list[str]:
    prefix = f"{profile_id}_{enemy_role}_{encounter_tier}"
    if encounter_tier == "boss":
        pattern = [
            f"{prefix}_strike",
            f"{prefix}_strike",
            f"{prefix}_pressure",
            f"{prefix}_pressure",
            f"{prefix}_guard",
            f"{prefix}_guard",
            f"{prefix}_focus",
            f"{prefix}_finisher",
        ]
    elif encounter_tier == "late":
        if encounter_kind == "elite":
            pattern = [
                f"{prefix}_strike",
                f"{prefix}_strike",
                f"{prefix}_pressure",
                f"{prefix}_pressure",
                f"{prefix}_guard",
                f"{prefix}_guard",
                f"{prefix}_focus",
                f"{prefix}_finisher",
            ]
        else:
            pattern = [
            f"{prefix}_strike",
            f"{prefix}_strike",
            f"{prefix}_pressure",
            f"{prefix}_pressure",
            f"{prefix}_guard",
            f"{prefix}_focus",
            f"{prefix}_finisher",
        ]
    elif encounter_tier == "mid":
        if encounter_kind == "elite":
            pattern = [
                f"{prefix}_strike",
                f"{prefix}_strike",
                f"{prefix}_pressure",
                f"{prefix}_pressure",
                f"{prefix}_guard",
                f"{prefix}_focus",
                f"{prefix}_finisher",
            ]
        else:
            pattern = [
            f"{prefix}_strike",
            f"{prefix}_strike",
            f"{prefix}_pressure",
            f"{prefix}_guard",
            f"{prefix}_focus",
            f"{prefix}_finisher",
        ]
    elif encounter_kind == "elite":
        pattern = [
            f"{prefix}_strike",
            f"{prefix}_strike",
            f"{prefix}_pressure",
            f"{prefix}_pressure",
            f"{prefix}_guard",
            f"{prefix}_focus",
            f"{prefix}_finisher",
        ]
    else:
        pattern = [
        f"{prefix}_strike",
        f"{prefix}_strike",
        f"{prefix}_pressure",
        f"{prefix}_guard",
        f"{prefix}_guard",
        f"{prefix}_focus",
    ]
    return filter_and_fill_eligible_deck(pattern, enemy_role, card_index, mechanic_profile, player_wujing_cap)


def filter_and_fill_eligible_deck(
    pattern: list[str],
    enemy_role: str,
    card_index: dict[str, dict[str, Any]],
    mechanic_profile: dict[str, Any],
    player_wujing_cap: int,
) -> list[str]:
    max_same = int(mechanic_profile["deck_constraints"]["max_same_card"])
    min_size = int(mechanic_profile["deck_constraints"]["min_deck_size"])
    counts: Counter[str] = Counter()
    result: list[str] = []
    for card_id in pattern:
        card = card_index.get(card_id, {})
        if not card or not card_allowed_for_player_cap(card, player_wujing_cap):
            continue
        if counts[card_id] >= max_same:
            continue
        result.append(card_id)
        counts[card_id] += 1
    legal_pool = [
        card["card_id"]
        for card in card_index.values()
        if str(card.get("weapon_style", "")) == enemy_role and card_allowed_for_player_cap(card, player_wujing_cap)
    ]
    legal_pool.sort(key=lambda cid: (float(card_index[cid].get("power_score", 0)), cid))
    legal_pool.reverse()
    for card_id in legal_pool:
        while len(result) < min_size and counts[card_id] < max_same:
            result.append(card_id)
            counts[card_id] += 1
    if len(result) < min_size:
        raise SystemExit(f"realm eligibility filtering produced undersized deck for role={enemy_role} cap={player_wujing_cap}")
    return result


def resolve_realm_cap_for_card_tier(tier: str) -> int:
    return {"early": 1, "mid": 2, "late": 3, "boss": 4}.get(tier, 1)


def is_realm_gated_card_type(card_type: str, tags: list[str]) -> bool:
    if card_type == "technique":
        return True
    normalized_tags = {str(tag).lower() for tag in tags}
    return bool({"technique", "closing_form", "招式", "收式"} & normalized_tags) or card_type in {"attack", "skill"}


def card_allowed_for_player_cap(card: dict[str, Any], player_wujing_cap: int) -> bool:
    required_wujing = int(card.get("required_wujing", 1))
    closing_form_tier = int(card.get("closing_form_tier", 1))
    return required_wujing <= player_wujing_cap and closing_form_tier <= player_wujing_cap


def build_reward_items(sequence_index: int, reward_tier: str, encounter_kind: str) -> list[dict[str, Any]]:
    if reward_tier == "boss":
        return [
            {"item_id": "boss_reward_token", "quantity": 1},
            {"item_id": "resource_merit", "quantity": 3},
        ]
    if reward_tier in {"advanced", "advanced_plus"}:
        return [
            {"item_id": f"advanced_reward_card_{sequence_index:03d}", "quantity": 1},
            {"item_id": "resource_merit", "quantity": 2 if encounter_kind == 'elite' else 1},
        ]
    if reward_tier in {"standard", "standard_plus"}:
        return [
            {"item_id": f"standard_reward_card_{sequence_index:03d}", "quantity": 1},
            {"item_id": "resource_merit", "quantity": 2 if reward_tier == "standard_plus" else 1},
        ]
    return [
        {"item_id": f"basic_reward_card_{sequence_index:03d}", "quantity": 1},
    ]


def build_opening_pressure(entry: dict[str, Any], content_recipe: dict[str, Any]) -> dict[str, Any]:
    policy = _dict(content_recipe.get("runtime_primitive_policy", {}))
    tier_scaling = _dict(policy.get("sequence_tier_scaling", {}))
    tier_policy = _dict(tier_scaling.get(str(entry.get("encounter_tier", "")), {}))
    return {
        "enemy_start_momentum_bonus": int(tier_policy.get("enemy_start_momentum_bonus", 0)),
        "enemy_start_block_bonus": int(tier_policy.get("enemy_start_block_bonus", 0)),
        "source": "runtime_primitive_policy",
    }


def _dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def average(values: list[float]) -> float:
    if not values:
        return 0.0
    return round(sum(values) / len(values), 2)


def build_sequence_balance_summary(
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    inventory: list[dict[str, Any]],
    deck_pool: list[dict[str, Any]],
    rewards: list[dict[str, Any]],
    balance_policy: dict[str, Any],
    battle_slots: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    deck_power_by_encounter = []
    tier_counts = Counter(str(item["encounter_tier"]) for item in inventory)
    kind_counts = Counter(str(item["encounter_kind"]) for item in inventory)
    early_scores = [float(deck["deck_power_score"]) for deck in deck_pool if str(deck["encounter_tier"]) == "early"]
    mid_scores = [float(deck["deck_power_score"]) for deck in deck_pool if str(deck["encounter_tier"]) == "mid"]
    late_scores = [float(deck["deck_power_score"]) for deck in deck_pool if str(deck["encounter_tier"]) == "late"]
    boss_scores = [float(deck["deck_power_score"]) for deck in deck_pool if str(deck["encounter_tier"]) == "boss"]
    normal_scores = [float(deck["deck_power_score"]) for deck in deck_pool if str(deck["encounter_kind"]) == "normal"]
    elite_scores = [float(deck["deck_power_score"]) for deck in deck_pool if str(deck["encounter_kind"]) == "elite"]
    all_decks_within_power_range = all(bool(deck.get("power_range_pass", False)) for deck in deck_pool)
    early_avg_power = average(early_scores)
    mid_avg_power = average(mid_scores)
    late_avg_power = average(late_scores)
    boss_avg_power = average(boss_scores)
    min_gap = float(balance_policy.get("min_late_avg_power_over_early", 0))
    gap = round(late_avg_power - early_avg_power, 2)
    no_elite_detected = not elite_scores
    no_boss_detected = not boss_scores
    elite_decks_stronger_than_normal = average(elite_scores) > average(normal_scores) if elite_scores and normal_scores else True
    boss_decks_stronger_than_late_or_elite = boss_avg_power > max(late_avg_power, average(elite_scores)) if boss_scores else False
    opening_pressure_by_tier = {"early": [], "mid": [], "late": [], "boss": []}
    if battle_slots:
        for slot in battle_slots:
            opening_pressure: dict[str, Any] = _dict(slot.get("opening_pressure", {}))
            if not opening_pressure:
                continue
            tier = str(slot.get("encounter_tier", ""))
            pressure_score = float(opening_pressure.get("enemy_start_momentum_bonus", 0)) + float(opening_pressure.get("enemy_start_block_bonus", 0)) / 2.0
            if tier in opening_pressure_by_tier:
                opening_pressure_by_tier[tier].append(pressure_score)
    for item, deck, reward in zip(inventory, deck_pool, rewards):
        deck_power_by_encounter.append(
            {
                "formal_encounter_id": item["formal_encounter_id"],
                "sequence_position": item["sequence_position"],
                "encounter_tier": item["encounter_tier"],
                "encounter_kind": item["encounter_kind"],
                "target_power_min": item["target_power_min"],
                "target_power_max": item["target_power_max"],
                "deck_power_score": deck["deck_power_score"],
                "reward_tier": reward["reward_tier"],
            }
        )
    sequence_balance_curve_ready = all_decks_within_power_range and gap >= min_gap and boss_decks_stronger_than_late_or_elite
    summary = {
        "mechanic_profile_id": mechanic_profile["mechanic_profile_id"],
        "content_pack_id": content_recipe["content_pack_id"],
        "target_sequence_id": content_recipe["target_sequence_id"],
        "formal_encounter_total_count": len(inventory),
        "tier_counts": dict(tier_counts),
        "encounter_kind_counts": dict(kind_counts),
        "deck_power_by_encounter": deck_power_by_encounter,
        "early_avg_power": early_avg_power,
        "mid_avg_power": mid_avg_power,
        "late_avg_power": late_avg_power,
        "boss_avg_power": boss_avg_power,
        "min_late_avg_power_over_early": min_gap,
        "late_avg_power_over_early": gap,
        "all_decks_within_power_range": all_decks_within_power_range,
        "elite_decks_stronger_than_normal": elite_decks_stronger_than_normal,
        "boss_decks_stronger_than_late_or_elite": boss_decks_stronger_than_late_or_elite,
        "boss_decks_stronger_than_elite": boss_decks_stronger_than_late_or_elite,
        "sequence_balance_curve_ready": sequence_balance_curve_ready,
        "sequence_balance_pass": sequence_balance_curve_ready and elite_decks_stronger_than_normal and (not no_boss_detected),
        "no_elite_detected": no_elite_detected,
        "no_boss_detected": no_boss_detected,
    }
    if "opening_pressure" in [str(item) for item in mechanic_profile.get("runtime_primitives", [])]:
        early_avg_opening_pressure = average(opening_pressure_by_tier["early"])
        mid_avg_opening_pressure = average(opening_pressure_by_tier["mid"])
        late_avg_opening_pressure = average(opening_pressure_by_tier["late"])
        boss_avg_opening_pressure = average(opening_pressure_by_tier["boss"])
        opening_pressure_curve_ready = (
            len(opening_pressure_by_tier["early"]) > 0
            and len(opening_pressure_by_tier["mid"]) > 0
            and len(opening_pressure_by_tier["late"]) > 0
            and len(opening_pressure_by_tier["boss"]) > 0
            and early_avg_opening_pressure <= mid_avg_opening_pressure <= late_avg_opening_pressure <= boss_avg_opening_pressure
            and boss_avg_opening_pressure > early_avg_opening_pressure
        )
        summary.update({
            "opening_pressure_curve_ready": opening_pressure_curve_ready,
            "early_avg_opening_pressure": early_avg_opening_pressure,
            "mid_avg_opening_pressure": mid_avg_opening_pressure,
            "late_avg_opening_pressure": late_avg_opening_pressure,
            "boss_avg_opening_pressure": boss_avg_opening_pressure,
        })
        summary["sequence_balance_pass"] = bool(summary["sequence_balance_pass"]) and opening_pressure_curve_ready
    return summary


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
