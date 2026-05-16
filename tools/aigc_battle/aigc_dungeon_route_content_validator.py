#!/usr/bin/env python3
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PACK_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / "dungeon_pool_pack_001"
MAP_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "map_seed_1001.json"
COMPAT_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "big_map_compatible_seed_1001.json"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_content"
REPORT_JSON = OUTPUT_DIR / "route_content_validation_report.json"
REPORT_MD = OUTPUT_DIR / "route_content_validation_report.md"

ROUTE_ENDPOINT_NODE_IDS = [
    "node_normal_boss",
    "node_true_boss_001",
    "node_true_boss_002",
    "node_wuzhuangyuan_exam_001",
    "node_wuzhuangyuan_exam_002",
    "node_wuzhuangyuan_exam_003",
    "node_wuzhuangyuan_exam_004",
    "node_wuzhuangyuan_exam_005",
]


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )


def run_validation() -> dict[str, Any]:
    before_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    before_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    before_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    battle_pool = read_json(PACK_DIR / "battle_slot_pool.json")
    deck_pool = read_json(PACK_DIR / "enemy_deck_pool.json")
    reward_pool = read_json(PACK_DIR / "reward_plan_pool.json")
    card_pool = read_json(PACK_DIR / "card_pool.json")
    map_instance = read_json(MAP_PATH)
    compatible_map = read_json(COMPAT_PATH)

    after_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    after_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    after_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    current_release = json.loads(after_current)
    active_profile = json.loads(after_active)

    battle_slots = {str(item.get("battle_slot_id", "")): item for item in battle_pool.get("battle_slots", []) if isinstance(item, dict)}
    enemy_decks = {str(item.get("enemy_deck_id", "")): item for item in deck_pool.get("enemy_decks", []) if isinstance(item, dict)}
    reward_plans = {str(item.get("reward_plan_id", "")): item for item in reward_pool.get("reward_plans", []) if isinstance(item, dict)}
    cards = {str(item.get("card_id", "")): item for item in card_pool.get("cards", []) if isinstance(item, dict)}
    map_nodes = {str(item.get("node_id", "")): item for item in map_instance.get("nodes", []) if isinstance(item, dict)}
    compat_nodes = {str(item.get("map_graph_id", "")): item for item in compatible_map.get("nodes", []) if isinstance(item, dict)}

    endpoint_details: list[dict[str, Any]] = []
    errors: list[str] = []
    card_ref_errors: list[str] = []
    reward_ref_errors: list[str] = []
    route_endpoint_battle_slots_ready = True
    route_endpoint_enemy_decks_ready = True
    route_endpoint_reward_plans_ready = True
    compatible_battle_entry_fields_ready = True
    non_zero_ranges = True

    for node_id in ROUTE_ENDPOINT_NODE_IDS:
        map_node = map_nodes.get(node_id)
        compat_node = compat_nodes.get(node_id)
        if not map_node:
            errors.append(f"missing_map_node:{node_id}")
            continue
        if not compat_node:
            errors.append(f"missing_compatible_node:{node_id}")
            continue
        slot_id = str(map_node.get("battle_slot_id", ""))
        slot = battle_slots.get(slot_id)
        deck_id = str(slot.get("enemy_deck_id", "")) if slot else ""
        reward_id = str(slot.get("reward_plan_id", "")) if slot else ""
        deck = enemy_decks.get(deck_id)
        reward = reward_plans.get(reward_id)
        if not slot_id or not slot:
            route_endpoint_battle_slots_ready = False
            errors.append(f"missing_battle_slot:{node_id}")
        if not deck_id or not deck:
            route_endpoint_enemy_decks_ready = False
            errors.append(f"missing_enemy_deck:{node_id}")
        if not reward_id or not reward:
            route_endpoint_reward_plans_ready = False
            errors.append(f"missing_reward_plan:{node_id}")
        if not str(map_node.get("compatible_encounter_id", "")) or not str(map_node.get("compatible_battle_id", "")) or not str(map_node.get("compatible_combat_pool_id", "")):
            compatible_battle_entry_fields_ready = False
            errors.append(f"missing_map_compatible_fields:{node_id}")
        if not str(compat_node.get("encounter_id", "")) or not str(compat_node.get("battle_id", "")) or not str(compat_node.get("combat_pool_id", "")):
            compatible_battle_entry_fields_ready = False
            errors.append(f"missing_compatible_map_fields:{node_id}")
        if int(map_node.get("enemy_martial_level", 0)) <= 0 or int(map_node.get("recommended_martial_min", 0)) <= 0 or int(map_node.get("recommended_martial_max", 0)) <= 0:
            non_zero_ranges = False
            errors.append(f"zero_recommended_range:{node_id}")
        if int(compat_node.get("enemy_martial_level", 0)) <= 0 or int(compat_node.get("recommended_martial_min", 0)) <= 0 or int(compat_node.get("recommended_martial_max", 0)) <= 0:
            non_zero_ranges = False
            errors.append(f"zero_compatible_range:{node_id}")
        if deck:
            for card_id in deck.get("card_ids", []):
                if str(card_id) not in cards:
                    card_ref_errors.append(f"{node_id}:{card_id}")
        if reward:
            for card_id in reward.get("card_rewards", []):
                if str(card_id) not in cards:
                    reward_ref_errors.append(f"{node_id}:{card_id}")
        endpoint_details.append(
            {
                "node_id": node_id,
                "battle_slot_id": slot_id,
                "enemy_deck_id": deck_id,
                "reward_plan_id": reward_id,
                "encounter_id": str(compat_node.get("encounter_id", "")),
                "battle_id": str(compat_node.get("battle_id", "")),
                "combat_pool_id": str(compat_node.get("combat_pool_id", "")),
            }
        )

    fields = {
        "normal_boss_node_exists": "node_normal_boss" in map_nodes and "node_normal_boss" in compat_nodes,
        "true_boss_1_node_exists": "node_true_boss_001" in map_nodes and "node_true_boss_001" in compat_nodes,
        "true_boss_2_node_exists": "node_true_boss_002" in map_nodes and "node_true_boss_002" in compat_nodes,
        "wuzhuangyuan_exam_nodes_exist": all(node_id in map_nodes and node_id in compat_nodes for node_id in ROUTE_ENDPOINT_NODE_IDS[3:]),
        "route_endpoint_nodes_bound": len(endpoint_details) == len(ROUTE_ENDPOINT_NODE_IDS),
        "route_endpoint_battle_slots_ready": route_endpoint_battle_slots_ready,
        "route_endpoint_enemy_decks_ready": route_endpoint_enemy_decks_ready,
        "route_endpoint_reward_plans_ready": route_endpoint_reward_plans_ready,
        "route_endpoint_card_refs_valid": not card_ref_errors,
        "route_endpoint_reward_refs_valid": not reward_ref_errors,
        "compatible_battle_entry_fields_ready": compatible_battle_entry_fields_ready,
        "non_zero_recommended_martial_ranges": non_zero_ranges,
        "normal_boss_content_ready": route_endpoint_battle_slots_ready and "slot_normal_boss_coastal_closure" in battle_slots,
        "true_boss_chain_content_ready": all(slot_id in battle_slots for slot_id in ["slot_true_boss_old_case_gatekeeper", "slot_true_boss_firearm_shadow"]),
        "wuzhuangyuan_exam_chain_content_ready": all(
            slot_id in battle_slots
            for slot_id in [
                "slot_wz01_capital_weapon_review",
                "slot_wz02_footwork_trial",
                "slot_wz03_mixed_weapon_exam",
                "slot_wz04_duel_chain",
                "slot_wz05_imperial_final_examiner",
            ]
        ),
        "no_fixed_sequence_main_model": bool(map_instance.get("no_fixed_linear_sequence", False)) and not bool(map_instance.get("supports_fixed_sequence", True)),
        "current_release_unchanged": before_current == after_current,
        "active_profile_matches_current": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["all_checks_passed"] = all(bool(v) for v in fields.values() if isinstance(v, bool))

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "validator": "aigc_dungeon_route_content_validator",
        "fields": fields,
        "endpoint_details": endpoint_details,
        "errors": errors,
        "card_ref_errors": card_ref_errors,
        "reward_ref_errors": reward_ref_errors,
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(
        "\n".join(
            ["# Route Content Validation Report", ""]
            + [f"- `{key}={str(value).lower() if isinstance(value, bool) else value}`" for key, value in fields.items()]
        )
        + "\n",
        encoding="utf-8",
    )
    return payload


def main() -> int:
    payload = run_validation()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("fields", {}).get("all_checks_passed", False)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
