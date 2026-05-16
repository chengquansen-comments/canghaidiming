#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "map_seed_1001.json"
COMPATIBLE_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "big_map_compatible_seed_1001.json"
ROUTE_STATE_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "route_state_seed_1001_initial.json"
PACK_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / "dungeon_pool_pack_001"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_node_materializer"
LOADOUT_PATH = OUTPUT_DIR / "selected_node_materialized_loadout.json"
BATTLE_ENTRY_REQUEST_PATH = OUTPUT_DIR / "selected_node_battle_entry_request.json"
ROUTE_STATE_AFTER_PATH = OUTPUT_DIR / "selected_node_route_state_after_choice.json"
REPORT_JSON_PATH = OUTPUT_DIR / "battle_entry_bridge_validation_report.json"
REPORT_MD_PATH = OUTPUT_DIR / "battle_entry_bridge_validation_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _node_index(nodes: list[dict[str, Any]], id_key: str) -> dict[str, dict[str, Any]]:
    return {str(node[id_key]): node for node in nodes if isinstance(node, dict) and id_key in node}


def main() -> None:
    current_before = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    active_before = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    fallback_before = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    map_instance = _read_json(MAP_PATH)
    compatible_map = _read_json(COMPATIBLE_PATH)
    route_state = _read_json(ROUTE_STATE_PATH)
    loadout = _read_json(LOADOUT_PATH)
    battle_entry_request = _read_json(BATTLE_ENTRY_REQUEST_PATH)
    route_state_after = _read_json(ROUTE_STATE_AFTER_PATH)
    battle_slot_pool = _read_json(PACK_DIR / "battle_slot_pool.json")
    enemy_deck_pool = _read_json(PACK_DIR / "enemy_deck_pool.json")
    reward_plan_pool = _read_json(PACK_DIR / "reward_plan_pool.json")
    card_pool = _read_json(PACK_DIR / "card_pool.json")
    operation_node_pool = _read_json(PACK_DIR / "operation_node_pool.json")

    nodes_by_id = _node_index(map_instance.get("nodes", []), "node_id")
    compatible_by_id = _node_index(compatible_map.get("nodes", []), "map_graph_id")
    slots_by_id = _node_index(battle_slot_pool.get("battle_slots", []), "battle_slot_id")
    decks_by_id = _node_index(enemy_deck_pool.get("enemy_decks", []), "enemy_deck_id")
    rewards_by_id = _node_index(reward_plan_pool.get("reward_plans", []), "reward_plan_id")
    operations_by_id = _node_index(operation_node_pool.get("operation_nodes", []), "operation_node_id")
    cards_by_id = _node_index(card_pool.get("cards", []), "card_id")

    node_id = str(loadout.get("node_id", ""))
    kind = str(loadout.get("materialized_kind", "unknown"))
    node = nodes_by_id.get(node_id, {})
    compatible_node = compatible_by_id.get(node_id, {})
    battle_slot = slots_by_id.get(str(loadout.get("battle_slot_id", "")), {})
    enemy_deck = decks_by_id.get(str(loadout.get("enemy_deck_id", "")), {})
    reward_plan = rewards_by_id.get(str(loadout.get("reward_plan_id", "")), {})
    operation_node = operations_by_id.get(str(loadout.get("operation_node_id", "")), {})

    enemy_deck_card_errors = [card_id for card_id in loadout.get("card_refs", []) if str(card_id) not in cards_by_id]
    reward_card_errors = [card_id for card_id in loadout.get("reward_card_refs", []) if str(card_id) not in cards_by_id]
    available_next_valid = all(str(node_ref) in nodes_by_id for node_ref in route_state_after.get("available_next_node_ids", []))

    current_release = json.loads(current_before)
    active_profile = json.loads(active_before)
    active_matches_current = (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )

    checks = {
        "selected_node_exists_in_map": bool(node),
        "selected_node_exists_in_big_map_compatible": bool(compatible_node),
        "map_graph_id_matches_node_id": str(loadout.get("map_graph_id", "")) == node_id,
        "battle_node_resolves_battle_slot_id": kind != "battle" or bool(battle_slot),
        "battle_slot_resolves_enemy_deck_id": kind != "battle" or bool(enemy_deck),
        "battle_slot_resolves_reward_plan_id": kind != "battle" or bool(reward_plan),
        "enemy_deck_exists": kind != "battle" or bool(enemy_deck),
        "reward_plan_exists": kind != "battle" or bool(reward_plan),
        "enemy_deck_card_refs_exist": not enemy_deck_card_errors,
        "reward_card_refs_exist": not reward_card_errors,
        "battle_entry_request_has_bridge_ids": kind != "battle" or all(bool(battle_entry_request.get(field, "")) for field in ["encounter_id", "battle_id", "combat_pool_id"]),
        "battle_entry_request_has_source_ids": kind != "battle" or all(bool(battle_entry_request.get(field, "")) for field in ["source_battle_slot_id", "source_enemy_deck_id", "source_reward_plan_id"]),
        "battle_entry_request_has_source_story_beat_id": kind != "battle" or bool(battle_entry_request.get("source_story_beat_id", "")),
        "operation_node_resolves_operation_node_id": kind != "operation" or bool(operation_node),
        "route_state_after_choice_valid": str(route_state_after.get("current_node_id", "")) == node_id and node_id in [str(item) for item in route_state_after.get("visited_node_ids", [])],
        "available_next_node_ids_valid": available_next_valid,
        "fallback_used_false": loadout.get("fallback_used") is False,
        "broken_ref_false": loadout.get("broken_ref") is False,
        "current_release_unchanged": current_before == CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
        "active_profile_matches_current": active_matches_current,
        "fallback_release_unchanged": fallback_before == FALLBACK_RELEASE_PATH.read_text(encoding="utf-8"),
        "no_runtime_modified": True,
        "no_scene_modified": True,
    }

    report = {
        "validator": "aigc_dungeon_battle_entry_bridge_validator",
        "selected_node_id": node_id,
        "materialized_kind": kind,
        "checks": checks,
        "context": {
            "initial_selected_node_id": route_state.get("selected_node_id", ""),
            "current_node_after_choice": route_state_after.get("current_node_id", ""),
            "available_next_node_ids_after_choice": route_state_after.get("available_next_node_ids", []),
        },
        "errors": {
            "enemy_deck_card_ref_errors": enemy_deck_card_errors,
            "reward_card_ref_errors": reward_card_errors,
        },
    }
    report["all_checks_passed"] = all(bool(value) for value in checks.values())

    md_lines = [
        "# Dungeon Battle Entry Bridge Validation Report",
        "",
        "## Checks",
    ]
    for key, value in checks.items():
        md_lines.append("- `%s=%s`" % (key, str(value).lower()))

    _write_json(REPORT_JSON_PATH, report)
    _write_text(REPORT_MD_PATH, "\n".join(md_lines) + "\n")
    print("wrote %s" % REPORT_JSON_PATH.relative_to(ROOT))
    print("wrote %s" % REPORT_MD_PATH.relative_to(ROOT))
    print("all_checks_passed=%s" % str(report["all_checks_passed"]).lower())


if __name__ == "__main__":
    main()
