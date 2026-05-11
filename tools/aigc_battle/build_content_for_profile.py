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
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_sequence_template_plan as template_plan_lib
from tools.aigc_battle import load_sequence_template as template_lib

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
    parser.add_argument("--use-real-telemetry-snapshot", dest="real_telemetry_snapshot_path", default="")
    parser.add_argument("--sequence-template", dest="sequence_template_id", default=template_lib.DEFAULT_SEQUENCE_TEMPLATE_ID)
    parser.add_argument("--build-variant", dest="build_variant", default="")
    parser.add_argument("--pack-id", dest="pack_id", default="")
    args = parser.parse_args(argv[1:])
    profile_id = args.profile_id
    mechanic_profile = read_json(MECHANICS_DIR / profile_id / "mechanic_profile.json")
    content_recipe = read_json(MECHANICS_DIR / profile_id / "content_recipe.json")
    sequence_template = template_lib.load_sequence_template(args.sequence_template_id)
    stage_plan = template_plan_lib.build_sequence_template_plan(args.sequence_template_id)
    story_encounters = index_rows(read_tsv(STORY_ENCOUNTERS_PATH), "encounter_id")
    inventory = build_formal_sequence_inventory(content_recipe, story_encounters, sequence_template)
    if not inventory:
        raise SystemExit("formal sequence inventory is empty")
    snapshot = read_json(Path(args.snapshot_path)) if args.snapshot_path else None
    real_telemetry_snapshot = read_json(Path(args.real_telemetry_snapshot_path)) if args.real_telemetry_snapshot_path else None

    build_variant = str(args.build_variant or "").strip()
    use_pack_contract = bool(args.pack_id or args.sequence_template_id != template_lib.DEFAULT_SEQUENCE_TEMPLATE_ID or build_variant)
    if use_pack_contract:
        build_variant = build_variant or "baseline_001"
        content_pack_id = str(args.pack_id or f"{profile_id}__{args.sequence_template_id}__{build_variant}")
        output_dir = GENERATED_DIR / profile_id / "packs" / content_pack_id
    else:
        content_pack_id = str(content_recipe["content_pack_id"])
        build_variant = template_lib.infer_build_variant(profile_id, content_pack_id)
        output_dir = GENERATED_DIR / profile_id
    output_dir.mkdir(parents=True, exist_ok=True)

    balance_policy = content_recipe["balance_policy"]
    runtime_primitives = [str(item) for item in mechanic_profile.get("runtime_primitives", [])]
    clue_pressure_enabled = "clue_pressure" in runtime_primitives
    martial_realm_enabled = "martial_realm_7" in runtime_primitives
    dual_weapon_enabled = "dual_weapon" in runtime_primitives
    inventory = annotate_inventory_balance(inventory, story_encounters, balance_policy, content_recipe, stage_plan, args.sequence_template_id)
    inventory, snapshot_metadata = apply_snapshot_rebuild_flags(inventory, snapshot)
    inventory, telemetry_rebuild_metadata = apply_real_telemetry_rebuild_flags(inventory, real_telemetry_snapshot, content_recipe)
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
            content_recipe,
            player_wujing_cap,
            entry,
        )
        deck_id = f"{profile_id}_deck_{int(entry['sequence_position']):03d}"
        reward_plan_id = f"{profile_id}_reward_{int(entry['sequence_position']):03d}"
        battle_slot_id = f"{profile_id}_slot_{int(entry['sequence_position']):03d}"
        deck_power_score = round(sum(float(card_index[card_id]["power_score"]) for card_id in card_ids), 2)
        target_power_min = int(entry["target_power_min"])
        target_power_max = int(entry["target_power_max"])
        power_range_pass = target_power_min <= deck_power_score <= target_power_max
        opening_pressure = build_opening_pressure(entry, content_recipe) if "opening_pressure" in runtime_primitives else {}
        weapon_followup = build_weapon_followup_slot_metadata(entry, card_ids, card_index, content_recipe) if "weapon_followup" in runtime_primitives else {}
        clue_pressure = build_clue_pressure_slot_metadata(entry, content_recipe) if clue_pressure_enabled else {}
        followup_summary = summarize_deck_followup(card_ids, card_index)
        martial_slot_metadata = build_martial_slot_metadata(entry, content_recipe) if martial_realm_enabled or dual_weapon_enabled else {}
        deck_martial_metadata = build_deck_martial_metadata(card_ids, card_index, martial_slot_metadata) if martial_realm_enabled or dual_weapon_enabled else {}

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
                "stage": entry["stage"],
                "sequence_template_id": args.sequence_template_id,
                "build_variant": build_variant,
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "card_ids": card_ids,
                "deck_power_score": deck_power_score,
                "power_range_pass": power_range_pass,
                "realm_eligibility_checked": True,
                "invalid_realm_card_count": 0,
                "tags": [entry["encounter_tier"], entry["encounter_kind"], enemy_role],
                "followup_chain_count": int(followup_summary["followup_chain_count"]),
                "followup_card_count": int(followup_summary["followup_card_count"]),
                "followup_density": float(followup_summary["followup_density"]),
                "followup_groups": list(followup_summary["followup_groups"]),
                "followup_chain_valid": bool(followup_summary["followup_chain_valid"]),
                "weapon_loadout": list(deck_martial_metadata.get("weapon_loadout", [])),
                "primary_weapon_style": str(deck_martial_metadata.get("primary_weapon_style", "")),
                "secondary_weapon_style": str(deck_martial_metadata.get("secondary_weapon_style", "")),
                "dual_weapon_enabled": bool(deck_martial_metadata.get("dual_weapon_enabled", False)),
                "primary_weapon_ratio": float(deck_martial_metadata.get("primary_weapon_ratio", 0.0)),
                "secondary_weapon_ratio": float(deck_martial_metadata.get("secondary_weapon_ratio", 0.0)),
                "generic_ratio": float(deck_martial_metadata.get("generic_ratio", 0.0)),
                "max_required_wujing": int(deck_martial_metadata.get("max_required_wujing", 0)),
                "max_closing_form_tier": int(deck_martial_metadata.get("max_closing_form_tier", 0)),
                "dual_weapon_synergy_count": int(deck_martial_metadata.get("dual_weapon_synergy_count", 0)),
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
                "stage": entry["stage"],
                "sequence_template_id": args.sequence_template_id,
                "build_variant": build_variant,
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "reward_tier": entry["reward_tier"],
                "mechanic_density_target": float(entry.get("mechanic_density_target", 0.0)),
                "deck_id": deck_id,
                "reward_plan_id": reward_plan_id,
                "runtime_primitives": list(runtime_primitives),
                "opening_pressure": opening_pressure,
                "weapon_followup": weapon_followup,
                "clue_pressure": clue_pressure,
                "max_enemy_wujing": int(martial_slot_metadata.get("max_enemy_wujing", player_wujing_cap)),
                "weapon_loadout": list(martial_slot_metadata.get("weapon_loadout", [])),
                "dual_weapon_enabled": bool(martial_slot_metadata.get("dual_weapon_enabled", False)),
                "martial_realm_stage": str(martial_slot_metadata.get("martial_realm_stage", "")),
                "realm_pressure_level": str(martial_slot_metadata.get("realm_pressure_level", "")),
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
                "sequence_template_id": args.sequence_template_id,
                "build_variant": build_variant,
                "sequence_position": entry["sequence_position"],
                "stage": entry["stage"],
                "stage_index": entry["stage_index"],
                "encounter_tier": entry["encounter_tier"],
                "encounter_kind": entry["encounter_kind"],
                "player_wujing_cap": player_wujing_cap,
                "target_power_min": target_power_min,
                "target_power_max": target_power_max,
                "reward_tier": entry["reward_tier"],
                "mechanic_density_target": float(entry.get("mechanic_density_target", 0.0)),
                "runtime_primitives": list(runtime_primitives),
                "weapon_followup_enabled": bool(weapon_followup.get("enabled", False)),
                "clue_pressure_enabled": bool(clue_pressure.get("enabled", False)),
                "dual_weapon_enabled": bool(martial_slot_metadata.get("dual_weapon_enabled", False)),
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
        "sequence_template_id": args.sequence_template_id,
        "build_variant": build_variant,
        "content_pack_id": content_pack_id,
        "target_sequence_id": content_recipe["target_sequence_id"],
        "formal_encounter_total_count": len(inventory),
        "generated_battle_slot_count": len(battle_slots),
        "generated_deck_count": len(deck_pool),
        "generated_card_count": len(card_pool),
        "generated_reward_count": len(rewards),
        "replacement_mode": "full_sequence",
        "total_encounter_count": len(inventory),
        "stage_counts": dict(Counter(str(item.get("stage", "")) for item in inventory)),
        "runtime_primitives_used": runtime_primitives,
        "opening_pressure_slot_count": sum(1 for slot in battle_slots if _dict(slot.get("opening_pressure", {}))),
        "weapon_followup_card_count": sum(1 for card in card_pool if bool(card.get("followup_group"))),
        "weapon_followup_deck_count": sum(1 for deck in deck_pool if int(deck.get("followup_card_count", 0)) > 0),
        "weapon_followup_slot_count": sum(1 for slot in battle_slots if bool(_dict(slot.get("weapon_followup", {})).get("enabled", False))),
        "weapon_followup_chain_count": sum(int(deck.get("followup_chain_count", 0)) for deck in deck_pool),
        "realm_eligibility_rule_enabled": bool(mechanic_profile.get("card_eligibility_rules", {}).get("technique_requires_player_realm", False)),
        "deck_card_realm_eligibility_valid": True,
        "invalid_realm_card_count": 0,
        "clue_pressure_slot_count": sum(1 for slot in battle_slots if bool(_dict(slot.get("clue_pressure", {})).get("enabled", False))),
        "clue_pressure_trigger_count": sum(1 for slot in battle_slots if bool(_dict(slot.get("clue_pressure", {})).get("enabled", False))),
        "clue_pressure_effect_counts": dict(Counter(str(_dict(slot.get("clue_pressure", {})).get("pressure_effect", "")) for slot in battle_slots if _dict(slot.get("clue_pressure", {})).get("pressure_effect"))),
        "clue_tag_counts": dict(Counter(tag for slot in battle_slots for tag in _dict(slot.get("clue_pressure", {})).get("clue_tags", []))),
        "clue_pressure_density_by_tier": build_clue_pressure_density_by_tier(battle_slots),
        "max_wujing": int(mechanic_profile.get("max_wujing", 0)),
        "max_closing_form_tier": int(mechanic_profile.get("max_closing_form_tier", 0)),
        "card_count_by_wujing": build_count_by_key(card_pool, "required_wujing"),
        "card_count_by_closing_form_tier": build_count_by_key(card_pool, "closing_form_tier"),
        "dual_weapon_slot_count": sum(1 for slot in battle_slots if bool(slot.get("dual_weapon_enabled", False))),
        "dual_weapon_deck_count": sum(1 for deck in deck_pool if bool(deck.get("dual_weapon_enabled", False))),
        "dual_weapon_ratio": round(sum(1 for slot in battle_slots if bool(slot.get("dual_weapon_enabled", False))) / float(max(len(battle_slots), 1)), 2),
        "weapon_loadout_counts": dict(Counter(format_weapon_loadout(slot.get("weapon_loadout", [])) for slot in battle_slots if slot.get("weapon_loadout"))),
        "realm_stage_counts": dict(Counter(str(slot.get("martial_realm_stage", "")) for slot in battle_slots if str(slot.get("martial_realm_stage", "")).strip())),
        "seven_realm_card_count": sum(1 for card in card_pool if int(card.get("required_wujing", 0)) >= 7 or int(card.get("closing_form_tier", 0)) >= 7),
        "dual_weapon_synergy_count": sum(int(deck.get("dual_weapon_synergy_count", 0)) for deck in deck_pool),
        "rebuild_uses_snapshot": snapshot_metadata["rebuild_uses_snapshot"],
        "snapshot_source_path": snapshot_metadata["snapshot_source_path"],
        "flagged_deck_count": len(snapshot_metadata["flagged_deck_ids"]),
        "flagged_deck_ids": snapshot_metadata["flagged_deck_ids"],
        "rebuild_uses_real_telemetry": telemetry_rebuild_metadata["rebuild_uses_real_telemetry"],
        "real_telemetry_snapshot_path": telemetry_rebuild_metadata["real_telemetry_snapshot_path"],
        "telemetry_rebuild_adjustments": telemetry_rebuild_metadata["telemetry_rebuild_adjustments"],
        "adjusted_or_flagged_encounters": telemetry_rebuild_metadata["adjusted_or_flagged_encounters"],
        "pack_identity": template_lib.build_pack_identity(args.sequence_template_id, profile_id, build_variant, content_pack_id),
    }
    balance_summary["rebuild_uses_snapshot"] = snapshot_metadata["rebuild_uses_snapshot"]
    balance_summary["snapshot_source_path"] = snapshot_metadata["snapshot_source_path"]
    balance_summary["adjusted_or_flagged_encounters"] = snapshot_metadata["adjusted_or_flagged_encounters"]
    balance_summary["rebuild_uses_real_telemetry"] = telemetry_rebuild_metadata["rebuild_uses_real_telemetry"]
    balance_summary["real_telemetry_snapshot_path"] = telemetry_rebuild_metadata["real_telemetry_snapshot_path"]
    balance_summary["telemetry_rebuild_adjustments"] = telemetry_rebuild_metadata["telemetry_rebuild_adjustments"]
    balance_summary["adjusted_or_flagged_encounters"].extend(telemetry_rebuild_metadata["adjusted_or_flagged_encounters"])
    balance_summary["snapshot_rebuild_pass"] = (
        not snapshot_metadata["rebuild_uses_snapshot"]
        or bool(balance_summary.get("sequence_balance_pass", False))
    )
    balance_summary["sequence_template_id"] = args.sequence_template_id
    balance_summary["build_variant"] = build_variant
    balance_summary["stage_counts"] = dict(Counter(str(item.get("stage", "")) for item in inventory))
    balance_summary["total_encounter_count"] = len(inventory)

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


def apply_real_telemetry_rebuild_flags(
    inventory: list[dict[str, Any]],
    snapshot: dict[str, Any] | None,
    content_recipe: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    metadata = {
        "rebuild_uses_real_telemetry": False,
        "real_telemetry_snapshot_path": "",
        "telemetry_rebuild_adjustments": [],
        "adjusted_or_flagged_encounters": [],
    }
    if not snapshot:
        return inventory, metadata
    metadata["rebuild_uses_real_telemetry"] = True
    metadata["real_telemetry_snapshot_path"] = str(snapshot.get("snapshot_path", ""))
    adjustment_index = index_real_telemetry_adjustments(snapshot)
    density_policy = _dict(content_recipe.get("weapon_followup_policy", {}))
    for item in inventory:
        encounter_id = str(item.get("formal_encounter_id", ""))
        adjustment = adjustment_index.get(encounter_id)
        if not adjustment:
            continue
        shift = int(adjustment.get("target_power_shift", 0))
        if shift != 0:
            item["target_power_min"] = int(item.get("target_power_min", 0)) + shift
            item["target_power_max"] = int(item.get("target_power_max", 0)) + shift
        tier = str(item.get("encounter_tier", ""))
        tier_policy = _dict(density_policy.get(tier, {}))
        current_density = float(tier_policy.get("target_density", 0))
        density_shift = float(adjustment.get("followup_density_shift", 0))
        if density_shift != 0:
            tier_policy["target_density"] = round(max(0.2, min(0.85, current_density + density_shift)), 2)
            density_policy[tier] = tier_policy
        metadata["telemetry_rebuild_adjustments"].append(adjustment)
        metadata["adjusted_or_flagged_encounters"].append(
            {
                "formal_encounter_id": encounter_id,
                "adjustment_type": str(adjustment.get("reason", "telemetry_adjustment")),
                "target_power_shift": shift,
                "followup_density_shift": density_shift,
            }
        )
    if metadata["rebuild_uses_real_telemetry"]:
        content_recipe["weapon_followup_policy"] = density_policy
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


def index_real_telemetry_adjustments(snapshot: dict[str, Any]) -> dict[str, dict[str, Any]]:
    adjustments: dict[str, dict[str, Any]] = {}
    for item in snapshot.get("rebuild_recommendations", []):
        encounter_id = str(item.get("formal_encounter_id", ""))
        if not encounter_id:
            continue
        adjustment = {
            "formal_encounter_id": encounter_id,
            "reason": str(item.get("reason", "")),
            "action": str(item.get("action", "")),
            "target_power_shift": 0,
            "followup_density_shift": 0.0,
        }
        action = adjustment["action"]
        if action == "raise_target_range":
            adjustment["target_power_shift"] = 2
            adjustment["followup_density_shift"] = 0.05
        elif action == "lower_target_range":
            adjustment["target_power_shift"] = -2
            adjustment["followup_density_shift"] = -0.05
        elif action == "raise_followup_density":
            adjustment["followup_density_shift"] = 0.1
        elif action == "reduce_defensive_delay":
            adjustment["target_power_shift"] = 1
            adjustment["followup_density_shift"] = 0.05
        adjustments[encounter_id] = adjustment
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
    if "weapon_followup_curve_ready" in summary:
        lines.extend([
            f"- weapon_followup_curve_ready: {str(summary['weapon_followup_curve_ready']).lower()}",
            f"- early_avg_followup_density: {summary['early_avg_followup_density']}",
            f"- mid_avg_followup_density: {summary['mid_avg_followup_density']}",
            f"- late_avg_followup_density: {summary['late_avg_followup_density']}",
            f"- boss_avg_followup_density: {summary['boss_avg_followup_density']}",
        ])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def index_rows(rows: list[dict[str, str]], key: str) -> dict[str, dict[str, str]]:
    return {str(row[key]): row for row in rows if str(row.get(key, "")).strip()}


def build_formal_sequence_inventory(
    content_recipe: dict[str, Any],
    story_encounters: dict[str, dict[str, str]],
    sequence_template: dict[str, Any],
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
                    "target_sequence_id": str(sequence_template.get("target_sequence_id", target_sequence_id)),
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
    total_count = int(sequence_template.get("total_encounter_count", len(inventory)) or len(inventory))
    return inventory[:total_count]


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
    stage_plan: list[dict[str, Any]],
    sequence_template_id: str,
) -> list[dict[str, Any]]:
    total = len(inventory)
    plan_by_position = {int(item["sequence_position"]): item for item in stage_plan}
    for index, item in enumerate(inventory, start=1):
        encounter = story_encounters[str(item["formal_encounter_id"])]
        plan = plan_by_position[index]
        kind = str(plan["encounter_kind"])
        tier = "boss" if plan["stage"] == "boss" else ("late" if plan["stage"] == "late" else ("mid" if plan["stage"] == "mid" else "early"))
        item["sequence_template_id"] = sequence_template_id
        item["sequence_position"] = index
        item["sequence_count"] = total
        item["stage"] = str(plan["stage"])
        item["stage_index"] = int(plan["stage_index"])
        item["difficulty_label"] = str(plan["difficulty_label"])
        item["encounter_kind"] = kind
        item["encounter_tier"] = tier
        item["target_power_min"] = int(plan["target_power_min"])
        item["target_power_max"] = int(plan["target_power_max"])
        item["reward_tier"] = str(plan["reward_tier"])
        item["player_wujing_cap"] = int(plan["player_wujing_cap"])
        item["mechanic_density_target"] = float(plan["mechanic_density_target"])
        item["encounter_label"] = str(encounter.get("display_name", encounter.get("encounter_id", "")))
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
    if str(mechanic_profile.get("mechanic_profile_id", "")) == "martial_realm_7_dual_weapon_v0_1":
        return build_martial_realm_dual_weapon_card_pool(mechanic_profile, content_recipe, content_pack_id)
    return build_standard_card_pool(mechanic_profile, content_recipe, content_pack_id)


def build_standard_card_pool(
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    content_pack_id: str,
) -> list[dict[str, Any]]:
    profile_id = str(mechanic_profile["mechanic_profile_id"])
    weights = mechanic_profile.get("power_model", {})
    stat_adjustments = content_recipe.get("card_generation_policy", {}).get("stat_adjustments", {})
    followup_enabled = "weapon_followup" in [str(item) for item in mechanic_profile.get("runtime_primitives", [])]
    followup_constraints = _dict(mechanic_profile.get("runtime_primitive_constraints", {})).get("weapon_followup", {})
    card_multiplier = int(content_recipe.get("card_generation_policy", {}).get("card_multiplier", 1))
    cards: list[dict[str, Any]] = []
    for style, tier_map in CARD_LIBRARY.items():
        for tier, entries in tier_map.items():
            for template in entries:
                for variant_index in range(card_multiplier):
                    card = build_standard_card(
                        profile_id=profile_id,
                        content_pack_id=content_pack_id,
                        style=style,
                        tier=tier,
                        template=template,
                        weights=weights,
                        stat_adjustments=stat_adjustments,
                        followup_enabled=followup_enabled,
                        followup_constraints=followup_constraints,
                        variant_index=variant_index,
                    )
                    cards.append(card)
    return cards


def build_standard_card(
    profile_id: str,
    content_pack_id: str,
    style: str,
    tier: str,
    template: dict[str, Any],
    weights: dict[str, Any],
    stat_adjustments: dict[str, Any],
    followup_enabled: bool,
    followup_constraints: dict[str, Any],
    variant_index: int,
) -> dict[str, Any]:
    adjustment = resolve_card_adjustment(stat_adjustments, style, tier)
    damage_value = max(0, int(template["damage"]) + int(adjustment.get("damage", 0)) + variant_index)
    guard_value = max(0, int(template["guard"]) + int(adjustment.get("guard", 0)) + (1 if variant_index and template["card_type"] == "defense" else 0))
    gain_value = max(0, int(template["gain"]) + int(adjustment.get("gain", 0)))
    break_value = max(0, int(template["break"]) + int(adjustment.get("break", 0)) + (1 if variant_index and template["key"] == "pressure" else 0))
    suffix = "" if variant_index == 0 else f"_variant_{variant_index + 1}"
    card_id = f"{profile_id}_{style}_{tier}_{template['key']}{suffix}"
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
    if variant_index:
        tags.append(f"variant_{variant_index + 1}")
    realm_cap = resolve_realm_cap_for_card_tier(tier)
    return {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "card_id": card_id,
        "id": card_id,
        "name": f"{template['name']}·{variant_index + 1}" if variant_index else template["name"],
        "card_type": template["card_type"],
        "weapon_style": style,
        "style": "枪" if style == "spearman" else ("刀" if style == "blademaster" else "杂"),
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
        "power_score": round(max(2.0, power_score), 2),
        "followup_group": build_followup_group(style, tier) if followup_enabled else "",
        "followup_trigger": build_followup_trigger(template["key"], followup_enabled),
        "followup_bonus": build_followup_bonus(template["key"], tier, followup_constraints) if followup_enabled else {},
        "followup_chain_role": build_followup_chain_role(template["key"], followup_enabled),
    }


def build_martial_realm_dual_weapon_card_pool(
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    content_pack_id: str,
) -> list[dict[str, Any]]:
    profile_id = str(mechanic_profile["mechanic_profile_id"])
    weights = mechanic_profile.get("power_model", {})
    cards: list[dict[str, Any]] = []
    template_keys = ["strike", "guard", "pressure", "finisher"]
    for style in ["spearman", "blademaster"]:
        for realm in range(1, 8):
            for template_key in template_keys:
                template = martial_template(style, realm, template_key)
                tags = [template["difficulty_tier"], style, template["card_type"], "technique", template["realm_band"]]
                if template_key == "finisher":
                    tags.append("closing_form")
                if template.get("dual_weapon_synergy_tag"):
                    tags.append("dual_weapon")
                cards.append(build_martial_card(profile_id, content_pack_id, template, weights, tags))
    for realm in range(1, 8):
        for template_key in ["bridge", "focus"]:
            template = martial_generic_template(realm, template_key)
            tags = [template["difficulty_tier"], "generic", template["card_type"], "technique", template["realm_band"], "dual_weapon"]
            cards.append(build_martial_card(profile_id, content_pack_id, template, weights, tags))
    return cards


def martial_template(style: str, realm: int, template_key: str) -> dict[str, Any]:
    tier = realm_tier_for_value(realm)
    base_style = CARD_LIBRARY[style][tier]
    template = next(item for item in base_style if item["key"] == ("focus" if template_key == "bridge" else template_key))
    damage = int(template["damage"]) + max(0, realm - 2)
    guard = int(template["guard"]) + max(0, realm - 2)
    gain = int(template["gain"]) + (1 if realm >= 5 and template_key in {"focus", "pressure"} else 0)
    brk = int(template["break"]) + max(0, realm - 3)
    return {
        "card_id": "",
        "name": f"{template['name']}·{realm}境",
        "card_type": template["card_type"],
        "weapon_style": style,
        "style": "枪" if style == "spearman" else "刀",
        "cost": min(2, int(template["cost"]) + (1 if realm >= 6 and template_key in {"finisher", "pressure"} else 0)),
        "damage": damage,
        "guard": guard,
        "gain": gain,
        "break": brk,
        "difficulty_tier": tier,
        "required_wujing": realm,
        "closing_form_tier": realm,
        "realm_band": realm_band_for_value(realm),
        "dual_weapon_synergy_tag": dual_weapon_synergy_tag(style, template_key),
        "template_key": template_key,
        "min": 0,
        "max": 4 if style == "spearman" else 2,
    }


def martial_generic_template(realm: int, template_key: str) -> dict[str, Any]:
    tier = realm_tier_for_value(realm)
    if template_key == "bridge":
        return {
            "name": f"转锋借势·{realm}境",
            "card_type": "skill",
            "weapon_style": "generic",
            "style": "杂",
            "cost": 1,
            "damage": 0,
            "guard": 2 + max(0, realm - 3),
            "gain": 1 + max(0, realm - 4),
            "break": 2 + max(0, realm - 4),
            "difficulty_tier": tier,
            "required_wujing": realm,
            "closing_form_tier": realm,
            "realm_band": realm_band_for_value(realm),
            "dual_weapon_synergy_tag": "generic_bridge",
            "template_key": template_key,
            "min": 0,
            "max": 3,
        }
    return {
        "name": f"并势换手·{realm}境",
        "card_type": "skill",
        "weapon_style": "generic",
        "style": "杂",
        "cost": 1,
        "damage": 0,
        "guard": 0,
        "gain": 2 + max(0, realm - 4),
        "break": 1 + max(0, realm - 5),
        "difficulty_tier": tier,
        "required_wujing": realm,
        "closing_form_tier": realm,
        "realm_band": realm_band_for_value(realm),
        "dual_weapon_synergy_tag": "finishing_form",
        "template_key": template_key,
        "min": 0,
        "max": 3,
    }


def build_martial_card(profile_id: str, content_pack_id: str, template: dict[str, Any], weights: dict[str, Any], tags: list[str]) -> dict[str, Any]:
    card_id = f"{profile_id}_{template['weapon_style']}_{template['required_wujing']}_{template['template_key']}"
    power_score = (
        float(template["damage"]) * float(weights.get("damage_weight", 1.0))
        + float(template["guard"]) * float(weights.get("block_weight", 1.0))
        + float(template["gain"]) * float(weights.get("gain_momentum_weight", 0.8))
        + float(template["break"]) * float(weights.get("break_momentum_weight", 0.8))
    )
    realm = int(template["required_wujing"])
    realm_scale = {
        1: 1.7,
        2: 1.5,
        3: 1.25,
        4: 1.15,
        5: 0.9,
        6: 0.85,
        7: 0.9,
    }.get(realm, 1.0)
    power_score *= 0.52 * realm_scale
    effects = []
    if int(template["damage"]) > 0:
        effects.append({"type": "damage", "value": int(template["damage"])})
    if int(template["guard"]) > 0:
        effects.append({"type": "gain_block", "value": int(template["guard"])})
    if int(template["gain"]) > 0:
        effects.append({"type": "gain_momentum", "value": int(template["gain"])})
    if int(template["break"]) > 0:
        effects.append({"type": "break_momentum", "value": int(template["break"])})
    return {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "card_id": card_id,
        "id": card_id,
        "name": template["name"],
        "card_type": template["card_type"],
        "weapon_style": template["weapon_style"],
        "style": template["style"],
        "cost": int(template["cost"]),
        "min": int(template["min"]),
        "max": int(template["max"]),
        "role": runtime_role_for_card(str(template["card_type"])),
        "gain": int(template["gain"]),
        "break": int(template["break"]),
        "damage": int(template["damage"]),
        "guard": int(template["guard"]),
        "effects": effects,
        "tags": tags,
        "difficulty_tier": template["difficulty_tier"],
        "required_wujing": int(template["required_wujing"]),
        "closing_form_tier": int(template["closing_form_tier"]),
        "realm_band": template["realm_band"],
        "dual_weapon_synergy_tag": template["dual_weapon_synergy_tag"],
        "power_score": round(max(2.0, power_score), 2),
        "followup_group": "",
        "followup_trigger": "",
        "followup_bonus": {},
        "followup_chain_role": "standalone",
    }


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


def build_followup_group(style: str, tier: str) -> str:
    return f"{style}_{tier}_chain"


def build_followup_trigger(card_key: str, followup_enabled: bool) -> str:
    if not followup_enabled:
        return ""
    if card_key in {"strike", "pressure", "finisher"}:
        return "same_weapon_previous_card"
    return ""


def build_followup_chain_role(card_key: str, followup_enabled: bool) -> str:
    if not followup_enabled:
        return "standalone"
    if card_key == "strike":
        return "opener"
    if card_key == "pressure":
        return "linker"
    if card_key == "finisher":
        return "finisher"
    return "standalone"


def build_followup_bonus(card_key: str, tier: str, constraints: dict[str, Any]) -> dict[str, int]:
    max_damage = int(constraints.get("max_bonus_damage", 4))
    max_momentum = int(constraints.get("max_bonus_momentum", 2))
    max_block = int(constraints.get("max_bonus_block", 4))
    tier_scale = {"early": 0, "mid": 1, "late": 2, "boss": 3}.get(tier, 0)
    if card_key == "strike":
        return {"bonus_momentum": min(max_momentum, 1)}
    if card_key == "pressure":
        return {"bonus_momentum": min(max_momentum, 1 + min(tier_scale, 1))}
    if card_key == "finisher":
        return {
            "bonus_damage": min(max_damage, 1 + tier_scale),
            "bonus_block": min(max_block, max(0, tier_scale)),
        }
    if card_key == "guard":
        return {"bonus_block": min(max_block, 1 + tier_scale)}
    return {}


def build_followup_deck_pattern(prefix: str, encounter_tier: str, encounter_kind: str, entry: dict[str, Any]) -> list[str]:
    sequence_position = int(entry.get("sequence_position", 1))
    if encounter_tier == "boss":
        base = ["strike", "pressure", "strike", "finisher", "guard", "pressure", "focus", "finisher"]
    elif encounter_tier == "late":
        base = ["strike", "pressure", "strike", "finisher", "guard", "pressure", "focus", "finisher"] if encounter_kind == "elite" else ["strike", "pressure", "strike", "finisher", "guard", "pressure", "focus"]
    elif encounter_tier == "mid":
        base = ["strike", "pressure", "strike", "guard", "focus", "finisher", "pressure"] if encounter_kind == "elite" else ["strike", "pressure", "strike", "guard", "focus", "finisher"]
    elif encounter_kind == "elite" or sequence_position >= 4:
        base = ["strike", "pressure", "guard", "strike", "focus", "finisher", "pressure"]
    else:
        base = ["strike", "guard", "focus", "strike", "guard", "pressure"]
    return [f"{prefix}_{key}" for key in base]


def summarize_deck_followup(card_ids: list[str], card_index: dict[str, dict[str, Any]]) -> dict[str, Any]:
    followup_cards = [card_index[card_id] for card_id in card_ids if bool(card_index.get(card_id, {}).get("followup_group"))]
    groups = sorted({str(card.get("followup_group", "")) for card in followup_cards if str(card.get("followup_group", "")).strip()})
    trigger_cards = [card for card in followup_cards if str(card.get("followup_trigger", "")).strip()]
    chain_cards = [
        card for card in followup_cards
        if str(card.get("followup_chain_role", "")) in {"opener", "linker", "finisher"}
    ]
    chain_roles = {str(card.get("followup_chain_role", "")) for card in chain_cards}
    chain_valid = ("opener" in chain_roles or "standalone" in {str(card.get("followup_chain_role", "")) for card in followup_cards}) and not (
        chain_cards and chain_roles.issubset({"linker", "finisher"})
    )
    return {
        "followup_chain_count": len(trigger_cards),
        "followup_card_count": len(followup_cards),
        "followup_density": round(float(len(followup_cards)) / float(max(len(card_ids), 1)), 2),
        "followup_groups": groups,
        "followup_chain_valid": chain_valid,
    }


def build_weapon_followup_slot_metadata(
    entry: dict[str, Any],
    card_ids: list[str],
    card_index: dict[str, dict[str, Any]],
    content_recipe: dict[str, Any],
) -> dict[str, Any]:
    policy = _dict(content_recipe.get("weapon_followup_policy", {}))
    tier = str(entry.get("encounter_tier", ""))
    tier_policy = _dict(policy.get(tier, {}))
    summary = summarize_deck_followup(card_ids, card_index)
    primary_style = Counter(str(card_index[card_id].get("weapon_style", "")) for card_id in card_ids if card_id in card_index).most_common(1)
    return {
        "enabled": True,
        "expected_chain_count": int(summary["followup_chain_count"]),
        "primary_weapon_style": primary_style[0][0] if primary_style else "",
        "pressure_level": str(tier_policy.get("pressure_level", "steady")),
        "source": "runtime_primitive_policy",
    }


def build_clue_pressure_slot_metadata(entry: dict[str, Any], content_recipe: dict[str, Any]) -> dict[str, Any]:
    policy = _dict(content_recipe.get("runtime_primitive_policy", {}))
    tier = str(entry.get("encounter_tier", "early"))
    tier_policy = _dict(_dict(policy.get("sequence_tier_scaling", {})).get(tier, {}))
    tag_rotation = list(_dict(policy.get("clue_tag_rotation", {})).get(tier, []))
    constraints = _dict(_dict(content_recipe).get("runtime_primitive_policy", {}))
    sequence_position = int(entry.get("sequence_position", 1))
    effect_options = list(tier_policy.get("pressure_effects", []))
    pressure_effect = str(effect_options[(sequence_position - 1) % len(effect_options)]) if effect_options else ""
    required_clue_count = int(tier_policy.get("required_clue_count", 1))
    tag_count = max(required_clue_count, 1 if tier in {"early", "mid"} else 2)
    if not tag_rotation:
        tag_rotation = ["old_case"]
    offset = (sequence_position - 1) % len(tag_rotation)
    clue_tags = [str(tag_rotation[(offset + index) % len(tag_rotation)]) for index in range(tag_count)]
    narrative_hint = "、".join(clue_tags)
    return {
        "enabled": True,
        "clue_tags": clue_tags,
        "required_clue_count": required_clue_count,
        "pressure_effect": pressure_effect,
        "pressure_value": int(tier_policy.get("pressure_value", 1)),
        "trigger_timing": str(tier_policy.get("trigger_timing", "battle_start")),
        "narrative_hint": f"{tier}线索指向{narrative_hint}，压制敌方节奏",
        "source": "runtime_primitive_policy",
        "max_clue_pressure_triggers_per_battle": int(_dict(constraints.get("clue_pressure", {})).get("max_clue_pressure_triggers_per_battle", 1)),
    }


def build_martial_slot_metadata(entry: dict[str, Any], content_recipe: dict[str, Any]) -> dict[str, Any]:
    dual_weapon_policy = _dict(content_recipe.get("dual_weapon_policy", {}))
    tier = str(entry.get("encounter_tier", "early"))
    sequence_position = int(entry.get("sequence_position", 1))
    player_wujing_cap = int(entry.get("player_wujing_cap", 1))
    loadout_rotation = list(_dict(dual_weapon_policy.get("weapon_loadout_rotation", {})).get(tier, [["spearman"]]))
    rotation_index = (sequence_position - 1) % len(loadout_rotation)
    weapon_loadout = [str(item) for item in list(loadout_rotation[rotation_index])]
    forced_dual_positions = {int(item) for item in dual_weapon_policy.get("dual_weapon_sequence_positions", [])}
    dual_weapon_enabled = sequence_position in forced_dual_positions or (tier == "boss" and bool(dual_weapon_policy.get("boss_force_dual_weapon", False)))
    if dual_weapon_enabled and len(weapon_loadout) < 2:
        weapon_loadout = ["spearman", "blademaster"]
    martial_realm_stage = realm_band_for_value(player_wujing_cap)
    max_enemy_wujing = min(7, player_wujing_cap + (1 if tier in {"late", "boss"} else 0))
    realm_pressure_level = {
        "early": "measured",
        "mid": "rising",
        "late": "heavy",
        "boss": "peak",
    }.get(tier, "measured")
    return {
        "player_wujing_cap": player_wujing_cap,
        "max_enemy_wujing": max_enemy_wujing,
        "weapon_loadout": weapon_loadout,
        "dual_weapon_enabled": dual_weapon_enabled,
        "martial_realm_stage": martial_realm_stage,
        "realm_pressure_level": realm_pressure_level,
    }


def build_deck_martial_metadata(
    card_ids: list[str],
    card_index: dict[str, dict[str, Any]],
    martial_slot_metadata: dict[str, Any],
) -> dict[str, Any]:
    weapon_styles = [str(card_index[card_id].get("weapon_style", "")) for card_id in card_ids if card_id in card_index]
    counts = Counter(style for style in weapon_styles if style)
    total = float(max(len(card_ids), 1))
    primary_style = ""
    secondary_style = ""
    weapon_loadout = [str(item) for item in martial_slot_metadata.get("weapon_loadout", [])]
    if weapon_loadout:
        primary_style = weapon_loadout[0]
        secondary_style = weapon_loadout[1] if len(weapon_loadout) > 1 else ""
    elif counts:
        primary_style = counts.most_common(1)[0][0]
    return {
        "weapon_loadout": weapon_loadout,
        "primary_weapon_style": primary_style,
        "secondary_weapon_style": secondary_style,
        "dual_weapon_enabled": bool(martial_slot_metadata.get("dual_weapon_enabled", False)),
        "primary_weapon_ratio": round(float(counts.get(primary_style, 0)) / total, 2) if primary_style else 0.0,
        "secondary_weapon_ratio": round(float(counts.get(secondary_style, 0)) / total, 2) if secondary_style else 0.0,
        "generic_ratio": round(float(counts.get("generic", 0)) / total, 2),
        "max_required_wujing": max(int(card_index[card_id].get("required_wujing", 1)) for card_id in card_ids) if card_ids else 0,
        "max_closing_form_tier": max(int(card_index[card_id].get("closing_form_tier", 1)) for card_id in card_ids) if card_ids else 0,
        "dual_weapon_synergy_count": sum(1 for card_id in card_ids if str(card_index[card_id].get("dual_weapon_synergy_tag", "")).strip()),
    }


def build_count_by_key(items: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for item in items:
        if key not in item:
            continue
        counts[str(item[key])] += 1
    return dict(counts)


def build_clue_pressure_density_by_tier(battle_slots: list[dict[str, Any]]) -> dict[str, float]:
    tier_totals: Counter[str] = Counter()
    tier_enabled: Counter[str] = Counter()
    for slot in battle_slots:
        tier = str(slot.get("encounter_tier", ""))
        if not tier:
            continue
        tier_totals[tier] += 1
        if bool(_dict(slot.get("clue_pressure", {})).get("enabled", False)):
            tier_enabled[tier] += 1
    return {
        tier: round(float(tier_enabled.get(tier, 0)) / float(max(total, 1)), 2)
        for tier, total in sorted(tier_totals.items())
    }


def format_weapon_loadout(weapon_loadout: Any) -> str:
    if not isinstance(weapon_loadout, list):
        return ""
    return "+".join(str(item) for item in weapon_loadout if str(item).strip())


def realm_tier_for_value(realm: int) -> str:
    if realm >= 7:
        return "boss"
    if realm >= 5:
        return "late"
    if realm >= 3:
        return "mid"
    return "early"


def realm_band_for_value(realm: int) -> str:
    if realm >= 7:
        return "realm_7"
    if realm >= 5:
        return "realm_5_6"
    if realm >= 3:
        return "realm_3_4"
    return "realm_1_2"


def dual_weapon_synergy_tag(style: str, template_key: str) -> str:
    if style == "spearman" and template_key in {"pressure", "finisher"}:
        return "spear_to_blade"
    if style == "blademaster" and template_key in {"pressure", "finisher"}:
        return "blade_to_spear"
    if style == "generic":
        return "generic_bridge"
    if template_key == "finisher":
        return "finishing_form"
    return ""


def build_deck_card_ids(
    profile_id: str,
    enemy_role: str,
    encounter_tier: str,
    encounter_kind: str,
    card_index: dict[str, dict[str, Any]],
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    player_wujing_cap: int,
    entry: dict[str, Any],
) -> list[str]:
    if str(mechanic_profile.get("mechanic_profile_id", "")) == "martial_realm_7_dual_weapon_v0_1":
        return build_martial_deck_card_ids(card_index, mechanic_profile, content_recipe, entry)
    prefix = f"{profile_id}_{enemy_role}_{encounter_tier}"
    runtime_primitives = [str(item) for item in mechanic_profile.get("runtime_primitives", [])]
    if "weapon_followup" in runtime_primitives:
        pattern = build_followup_deck_pattern(prefix, encounter_tier, encounter_kind, entry)
    elif encounter_tier == "boss":
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


def build_martial_deck_card_ids(
    card_index: dict[str, dict[str, Any]],
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    entry: dict[str, Any],
) -> list[str]:
    constraints = _dict(_dict(mechanic_profile.get("runtime_primitive_constraints", {})).get("dual_weapon", {}))
    max_same = int(_dict(mechanic_profile.get("deck_constraints", {})).get("max_same_card", 2))
    tier = str(entry.get("encounter_tier", "early"))
    sequence_position = int(entry.get("sequence_position", 1))
    player_wujing_cap = int(entry.get("player_wujing_cap", 1))
    slot_metadata = build_martial_slot_metadata(entry, content_recipe)
    weapon_loadout = list(slot_metadata.get("weapon_loadout", []))
    dual_weapon_enabled = bool(slot_metadata.get("dual_weapon_enabled", False))
    deck_size = 8
    primary_style = weapon_loadout[0] if weapon_loadout else "spearman"
    secondary_style = weapon_loadout[1] if len(weapon_loadout) > 1 else ""
    generic_target = 0 if tier == "early" else 1
    if dual_weapon_enabled and tier in {"late", "boss"}:
        generic_target = min(2, generic_target + 1)
    generic_target = min(generic_target, int(deck_size * float(constraints.get("max_generic_ratio", 0.35))))
    if dual_weapon_enabled:
        primary_target = max(3, int(round(deck_size * float(constraints.get("min_primary_weapon_ratio", 0.45)))))
        secondary_target = max(2, int(round(deck_size * float(constraints.get("min_secondary_weapon_ratio", 0.20)))))
        if primary_target + secondary_target + generic_target > deck_size:
            generic_target = max(0, deck_size - primary_target - secondary_target)
        remainder = deck_size - primary_target - secondary_target - generic_target
        primary_target += max(0, remainder)
    else:
        secondary_target = 0
        primary_target = deck_size - generic_target
    result: list[str] = []
    counts: Counter[str] = Counter()
    req_floor = {"early": 1, "mid": 3, "late": 5, "boss": 7}.get(tier, 1)
    preferred_realms = {
        "early": [2, 1],
        "mid": [4, 3, 2, 1],
        "late": [6, 5, 4, 3],
        "boss": [7, 6, 5, 4],
    }.get(tier, [player_wujing_cap, max(1, player_wujing_cap - 1)])

    def eligible(style: str, *, require_bridge: bool = False) -> list[str]:
        pool = []
        for card in card_index.values():
            if str(card.get("weapon_style", "")) != style:
                continue
            if not card_allowed_for_player_cap(card, player_wujing_cap):
                continue
            required_wujing = int(card.get("required_wujing", 1))
            if required_wujing > player_wujing_cap:
                continue
            if tier == "early" and required_wujing > 2:
                continue
            if tier == "mid" and required_wujing > 4:
                continue
            if tier == "late" and required_wujing > 6:
                continue
            if require_bridge and not str(card.get("dual_weapon_synergy_tag", "")).strip():
                continue
            pool.append(card["card_id"])
        pool.sort(
            key=lambda cid: (
                int(card_index[cid].get("required_wujing", 1)) in preferred_realms,
                int(card_index[cid].get("required_wujing", 1)),
                float(card_index[cid].get("power_score", 0)),
                cid,
            ),
            reverse=True,
        )
        return pool

    def add_from_pool(pool: list[str], target_count: int) -> None:
        for card_id in pool:
            if len([cid for cid in result if cid == card_id]) >= max_same:
                continue
            result.append(card_id)
            counts[card_id] += 1
            if len(result) >= target_count:
                return

    add_from_pool(eligible(primary_style), primary_target)
    if secondary_style:
        add_from_pool(eligible(secondary_style, require_bridge=True) or eligible(secondary_style), primary_target + secondary_target)
    if generic_target:
        add_from_pool(eligible("generic", require_bridge=True) or eligible("generic"), primary_target + secondary_target + generic_target)
    fill_styles = [primary_style]
    if secondary_style:
        fill_styles.append(secondary_style)
    fill_styles.append("generic")
    for style in fill_styles:
        add_from_pool(eligible(style), deck_size)
        if len(result) >= deck_size:
            break
    if len(result) < deck_size:
        raise SystemExit(f"unable to build martial realm deck for tier={tier} position={sequence_position} cap={player_wujing_cap}")
    if tier in {"mid", "late", "boss"}:
        has_curve_card = any(int(card_index[cid].get("required_wujing", 1)) >= req_floor for cid in result)
        if not has_curve_card:
            curve_pool = [cid for style in fill_styles for cid in eligible(style) if int(card_index[cid].get("required_wujing", 1)) >= req_floor]
            if curve_pool:
                result[-1] = curve_pool[0]
    return result[:deck_size]


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
    followup_density_by_tier = {"early": [], "mid": [], "late": [], "boss": []}
    if battle_slots:
        for slot in battle_slots:
            opening_pressure: dict[str, Any] = _dict(slot.get("opening_pressure", {}))
            if not opening_pressure:
                tier = str(slot.get("encounter_tier", ""))
            else:
                tier = str(slot.get("encounter_tier", ""))
                pressure_score = float(opening_pressure.get("enemy_start_momentum_bonus", 0)) + float(opening_pressure.get("enemy_start_block_bonus", 0)) / 2.0
                if tier in opening_pressure_by_tier:
                    opening_pressure_by_tier[tier].append(pressure_score)
            weapon_followup = _dict(slot.get("weapon_followup", {}))
            if weapon_followup and tier in followup_density_by_tier:
                expected_chain_count = float(weapon_followup.get("expected_chain_count", 0))
                followup_density_by_tier[tier].append(round(expected_chain_count / 8.0, 2))
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
    if "weapon_followup" in [str(item) for item in mechanic_profile.get("runtime_primitives", [])]:
        early_avg_followup_density = average(followup_density_by_tier["early"])
        mid_avg_followup_density = average(followup_density_by_tier["mid"])
        late_avg_followup_density = average(followup_density_by_tier["late"])
        boss_avg_followup_density = average(followup_density_by_tier["boss"])
        weapon_followup_curve_ready = (
            len(followup_density_by_tier["early"]) > 0
            and len(followup_density_by_tier["mid"]) > 0
            and len(followup_density_by_tier["late"]) > 0
            and len(followup_density_by_tier["boss"]) > 0
            and early_avg_followup_density < late_avg_followup_density <= boss_avg_followup_density
            and mid_avg_followup_density <= late_avg_followup_density
        )
        summary.update({
            "weapon_followup_curve_ready": weapon_followup_curve_ready,
            "early_avg_followup_density": early_avg_followup_density,
            "mid_avg_followup_density": mid_avg_followup_density,
            "late_avg_followup_density": late_avg_followup_density,
            "boss_avg_followup_density": boss_avg_followup_density,
        })
        summary["sequence_balance_pass"] = bool(summary["sequence_balance_pass"]) and weapon_followup_curve_ready
    return summary


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
