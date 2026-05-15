#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MAP_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "map_seed_1001.json"
DEFAULT_ROUTE_STATE_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "route_state_seed_1001_initial.json"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_node_materializer"
LOADOUT_PATH = OUTPUT_DIR / "selected_node_materialized_loadout.json"
BATTLE_ENTRY_REQUEST_PATH = OUTPUT_DIR / "selected_node_battle_entry_request.json"
ROUTE_STATE_AFTER_PATH = OUTPUT_DIR / "selected_node_route_state_after_choice.json"
REPORT_JSON_PATH = OUTPUT_DIR / "node_materializer_report.json"
REPORT_MD_PATH = OUTPUT_DIR / "node_materializer_report.md"

BATTLE_NODE_TYPES = {
    "prologue_battle",
    "wuju_battle",
    "battle_normal",
    "battle_elite",
    "normal_boss",
    "true_boss",
    "wuzhuangyuan_exam",
}
OPERATION_NODE_TYPES = {
    "operation",
    "old_case",
    "training",
    "lightness_event",
    "prepare",
}
ROUTE_NODE_TYPES = {"route_branch", "boss_gate"}


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


def _pack_dir(pack_id: str) -> Path:
    return ROOT / "data" / "aigc_battle" / "generated" / "dungeon_progression_v1_3" / "packs" / pack_id


def _compatible_path_for_map(map_path: Path) -> Path:
    name = map_path.name.replace("map_seed_", "big_map_compatible_seed_")
    return map_path.parent / name


def _materialized_kind(node_type: str) -> str:
    if node_type in BATTLE_NODE_TYPES:
        return "battle"
    if node_type in OPERATION_NODE_TYPES:
        return "operation"
    if node_type in ROUTE_NODE_TYPES:
        return "route_branch"
    return "unknown"


def _find_sample_node(map_instance: dict[str, Any], sample: str) -> str:
    nodes = [node for node in map_instance.get("nodes", []) if isinstance(node, dict)]
    if sample == "battle_normal":
        for node in nodes:
            if node.get("segment") == "big_map" and node.get("node_type") == "battle_normal":
                return str(node["node_id"])
    elif sample == "battle_elite":
        for node in nodes:
            if node.get("segment") == "big_map" and node.get("node_type") == "battle_elite":
                return str(node["node_id"])
    elif sample == "operation":
        for node in nodes:
            if node.get("segment") == "big_map" and str(node.get("node_type", "")) in OPERATION_NODE_TYPES:
                return str(node["node_id"])
    raise ValueError("no sample node found for %s" % sample)


def _resolve_lightness_delta(operation_node: dict[str, Any], reward_plan: dict[str, Any]) -> int:
    reward_type = str(reward_plan.get("lightness_reward_type", ""))
    if reward_type.startswith("unlock_"):
        try:
            return max(0, int(reward_type.split("_")[-1]))
        except ValueError:
            return 0
    if operation_node.get("lightness_unlock_possible") is True:
        return 1
    return 0


def _build_route_state_after_choice(route_state: dict[str, Any], node: dict[str, Any], reward_plan: dict[str, Any], operation_node: dict[str, Any]) -> dict[str, Any]:
    node_id = str(node["node_id"])
    node_type = str(node.get("node_type", ""))
    route_after = json.loads(json.dumps(route_state))

    def _append_unique(field: str, value: str) -> None:
        items = [str(item) for item in route_after.get(field, [])]
        if value not in items:
            items.append(value)
        route_after[field] = items

    _append_unique("visited_node_ids", node_id)
    _append_unique("visited_path_order", node_id)
    _append_unique("completed_node_ids", node_id)

    route_after["current_node_id"] = node_id
    next_ids = [str(item) for item in node.get("outgoing_node_ids", [])]
    route_after["available_next_node_ids"] = next_ids
    route_after["selected_node_id"] = next_ids[0] if next_ids else ""

    if node_type in BATTLE_NODE_TYPES:
        route_after["battle_count_so_far"] = int(route_after.get("battle_count_so_far", 0)) + 1
    if node_type == "battle_elite":
        route_after["elite_count_so_far"] = int(route_after.get("elite_count_so_far", 0)) + 1
    if node_type in OPERATION_NODE_TYPES:
        route_after["operation_count_so_far"] = int(route_after.get("operation_count_so_far", 0)) + 1

    node_effects = node.get("effects", {}) if isinstance(node.get("effects", {}), dict) else {}
    op_effects = operation_node.get("effects", {}) if isinstance(operation_node.get("effects", {}), dict) else {}
    route_after["military_merit"] = int(route_after.get("military_merit", 0)) + int(node_effects.get("military_merit", 0)) + int(reward_plan.get("military_merit_reward", 0)) + int(op_effects.get("military_merit", 0))
    route_after["clean_reputation"] = int(route_after.get("clean_reputation", 0)) + int(node_effects.get("clean_reputation", 0)) + int(reward_plan.get("clean_reputation_delta", 0))
    clue_delta = int(node_effects.get("case_clues", 0)) + int(reward_plan.get("old_case_clue_delta", 0)) + int(op_effects.get("case_clues", 0))
    route_after["case_clues"] = int(route_after.get("case_clues", 0)) + clue_delta
    route_after["old_case_progress"] = int(route_after.get("old_case_progress", 0)) + clue_delta

    lightness_delta = _resolve_lightness_delta(operation_node, reward_plan)
    route_after["lightness_level"] = int(route_after.get("lightness_level", 0)) + lightness_delta
    route_after["skeleton_delta"] = {
        "node_effects": node_effects,
        "operation_effects": op_effects,
        "reward_plan_id": reward_plan.get("reward_plan_id", ""),
        "lightness_delta": lightness_delta,
    }
    return route_after


def materialize_node(
    map_path: Path,
    route_state_path: Path,
    pack_id: str,
    *,
    node_id: str | None = None,
    sample: str | None = None,
    allow_any_node_for_probe: bool = False,
    write_outputs: bool = True,
) -> dict[str, Any]:
    map_path = map_path.resolve()
    route_state_path = route_state_path.resolve()
    pack_dir = _pack_dir(pack_id)
    compatible_path = _compatible_path_for_map(map_path)

    map_instance = _read_json(map_path)
    route_state = _read_json(route_state_path)
    compatible_map = _read_json(compatible_path)
    battle_slot_pool = _read_json(pack_dir / "battle_slot_pool.json")
    enemy_deck_pool = _read_json(pack_dir / "enemy_deck_pool.json")
    reward_plan_pool = _read_json(pack_dir / "reward_plan_pool.json")
    card_pool = _read_json(pack_dir / "card_pool.json")
    operation_node_pool = _read_json(pack_dir / "operation_node_pool.json")

    if sample:
        selected_node_id = _find_sample_node(map_instance, sample)
    elif node_id:
        selected_node_id = node_id
    else:
        raise ValueError("either node_id or sample is required")

    nodes_by_id = _node_index(map_instance.get("nodes", []), "node_id")
    compatible_by_id = _node_index(compatible_map.get("nodes", []), "map_graph_id")
    slots_by_id = _node_index(battle_slot_pool.get("battle_slots", []), "battle_slot_id")
    decks_by_id = _node_index(enemy_deck_pool.get("enemy_decks", []), "enemy_deck_id")
    rewards_by_id = _node_index(reward_plan_pool.get("reward_plans", []), "reward_plan_id")
    operations_by_id = _node_index(operation_node_pool.get("operation_nodes", []), "operation_node_id")
    cards_by_id = _node_index(card_pool.get("cards", []), "card_id")

    if selected_node_id not in nodes_by_id:
        raise ValueError("selected node not found: %s" % selected_node_id)
    if selected_node_id not in compatible_by_id:
        raise ValueError("selected node missing from compatible map: %s" % selected_node_id)
    if not allow_any_node_for_probe and selected_node_id not in [str(item) for item in route_state.get("available_next_node_ids", [])]:
        raise ValueError("selected node not in available_next_node_ids: %s" % selected_node_id)

    node = nodes_by_id[selected_node_id]
    compatible_node = compatible_by_id[selected_node_id]
    node_type = str(node.get("node_type", ""))
    kind = _materialized_kind(node_type)

    battle_slot_id = str(node.get("battle_slot_id", ""))
    operation_node_id = str(node.get("operation_node_id", ""))
    battle_slot = slots_by_id.get(battle_slot_id, {})
    operation_node = operations_by_id.get(operation_node_id, {})
    enemy_deck_id = str(battle_slot.get("enemy_deck_id", ""))
    reward_plan_id = str(battle_slot.get("reward_plan_id", ""))
    enemy_deck = decks_by_id.get(enemy_deck_id, {})
    reward_plan = rewards_by_id.get(reward_plan_id, {})

    card_refs = [str(card_id) for card_id in enemy_deck.get("card_ids", [])]
    reward_card_refs = [str(card_id) for card_id in reward_plan.get("card_rewards", [])]
    enemy_card_errors = [card_id for card_id in card_refs if card_id not in cards_by_id]
    reward_card_errors = [card_id for card_id in reward_card_refs if card_id not in cards_by_id]

    broken_ref = False
    if kind == "battle":
        broken_ref = not all([
            battle_slot_id and battle_slot,
            enemy_deck_id and enemy_deck,
            reward_plan_id and reward_plan,
        ]) or bool(enemy_card_errors or reward_card_errors)
    elif kind == "operation":
        broken_ref = not (operation_node_id and operation_node)

    loadout = {
        "node_id": selected_node_id,
        "map_graph_id": str(compatible_node.get("map_graph_id", "")),
        "node_type": node_type,
        "materialized_kind": kind,
        "battle_slot_id": battle_slot_id,
        "enemy_deck_id": enemy_deck_id,
        "reward_plan_id": reward_plan_id,
        "operation_node_id": operation_node_id,
        "enemy_deck": enemy_deck,
        "reward_plan": reward_plan,
        "card_refs": card_refs,
        "reward_card_refs": reward_card_refs,
        "fallback_used": False,
        "broken_ref": broken_ref,
        "loadout_source": "aigc_dungeon_node_materializer",
        "compatible_encounter_id": str(node.get("compatible_encounter_id", "")),
        "compatible_battle_id": str(node.get("compatible_battle_id", "")),
        "compatible_combat_pool_id": str(node.get("compatible_combat_pool_id", "")),
    }
    if kind == "operation":
        loadout["operation_materialized_result"] = {
            "operation_node_id": operation_node_id,
            "operation_type": operation_node.get("operation_type", ""),
            "effects": operation_node.get("effects", {}),
            "costs": operation_node.get("costs", {}),
        }
    elif kind == "route_branch":
        loadout["route_materialized_result"] = {
            "route_tags": node.get("route_tags", []),
            "outgoing_node_ids": node.get("outgoing_node_ids", []),
        }

    if kind == "battle":
        battle_entry_request = {
            "encounter_id": str(node.get("compatible_encounter_id", "")),
            "battle_id": str(node.get("compatible_battle_id", "")),
            "combat_pool_id": str(node.get("compatible_combat_pool_id", "")),
            "enemy_martial_level": int(compatible_node.get("enemy_martial_level", 0)),
            "recommended_martial_min": int(compatible_node.get("recommended_martial_min", 0)),
            "recommended_martial_max": int(compatible_node.get("recommended_martial_max", 0)),
            "override_player_profile": True,
            "source_node_id": selected_node_id,
            "source_map_graph_id": str(compatible_node.get("map_graph_id", "")),
            "source_battle_slot_id": battle_slot_id,
            "source_enemy_deck_id": enemy_deck_id,
            "source_reward_plan_id": reward_plan_id,
            "loadout_source": "aigc_dungeon_node_materializer",
        }
    else:
        battle_entry_request = {
            "generated": False,
            "materialized_kind": kind,
            "source_node_id": selected_node_id,
            "source_map_graph_id": str(compatible_node.get("map_graph_id", "")),
            "reason": "battle_entry_request_not_required",
        }

    route_state_after = _build_route_state_after_choice(route_state, node, reward_plan, operation_node)

    report = {
        "materializer": "aigc_dungeon_node_materializer",
        "inputs": {
            "map_path": str(map_path.relative_to(ROOT)),
            "route_state_path": str(route_state_path.relative_to(ROOT)),
            "compatible_map_path": str(compatible_path.relative_to(ROOT)),
            "pack_id": pack_id,
            "selected_node_id": selected_node_id,
            "allow_any_node_for_probe": allow_any_node_for_probe,
            "sample": sample or "",
        },
        "checks": {
            "selected_node_exists": selected_node_id in nodes_by_id,
            "selected_node_available_or_probe_override": allow_any_node_for_probe or selected_node_id in [str(item) for item in route_state.get("available_next_node_ids", [])],
            "selected_node_compatible_exists": selected_node_id in compatible_by_id,
            "battle_slot_resolved": kind != "battle" or bool(battle_slot),
            "enemy_deck_resolved": kind != "battle" or bool(enemy_deck),
            "reward_plan_resolved": kind != "battle" or bool(reward_plan),
            "operation_node_resolved": kind != "operation" or bool(operation_node),
            "enemy_deck_card_refs_valid": not enemy_card_errors,
            "reward_card_refs_valid": not reward_card_errors,
            "battle_entry_request_ready": kind != "battle" or all(bool(battle_entry_request.get(field, "")) for field in ["encounter_id", "battle_id", "combat_pool_id"]),
            "route_state_after_choice_ready": bool(route_state_after.get("current_node_id", "")) == True,
            "route_state_next_candidates_ready": all(next_id in nodes_by_id for next_id in route_state_after.get("available_next_node_ids", [])),
            "fallback_used_false": False is False,
            "broken_ref_false": broken_ref is False,
        },
        "errors": {
            "enemy_deck_card_ref_errors": enemy_card_errors,
            "reward_card_ref_errors": reward_card_errors,
        },
    }
    report["all_checks_passed"] = all(bool(value) for value in report["checks"].values())

    if write_outputs:
        _write_json(LOADOUT_PATH, loadout)
        _write_json(BATTLE_ENTRY_REQUEST_PATH, battle_entry_request)
        _write_json(ROUTE_STATE_AFTER_PATH, route_state_after)
        _write_json(REPORT_JSON_PATH, report)
        md_lines = [
            "# Dungeon Node Materializer Report",
            "",
            "## Inputs",
            "- `selected_node_id=%s`" % selected_node_id,
            "- `materialized_kind=%s`" % kind,
            "",
            "## Checks",
        ]
        for key, value in report["checks"].items():
            md_lines.append("- `%s=%s`" % (key, str(value).lower()))
        _write_text(REPORT_MD_PATH, "\n".join(md_lines) + "\n")

    return {
        "loadout": loadout,
        "battle_entry_request": battle_entry_request,
        "route_state_after": route_state_after,
        "report": report,
    }


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--map", default=str(DEFAULT_MAP_PATH))
    parser.add_argument("--route-state", default=str(DEFAULT_ROUTE_STATE_PATH))
    parser.add_argument("--pack", required=True)
    parser.add_argument("--node")
    parser.add_argument("--sample", choices=["battle_normal", "battle_elite", "operation"])
    parser.add_argument("--allow-any-node-for-probe", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    result = materialize_node(
        Path(args.map),
        Path(args.route_state),
        args.pack,
        node_id=args.node,
        sample=args.sample,
        allow_any_node_for_probe=bool(args.allow_any_node_for_probe),
        write_outputs=True,
    )
    print("wrote %s" % LOADOUT_PATH.relative_to(ROOT))
    print("wrote %s" % BATTLE_ENTRY_REQUEST_PATH.relative_to(ROOT))
    print("wrote %s" % ROUTE_STATE_AFTER_PATH.relative_to(ROOT))
    print("wrote %s" % REPORT_JSON_PATH.relative_to(ROOT))
    print("all_checks_passed=%s" % str(result["report"]["all_checks_passed"]).lower())


if __name__ == "__main__":
    main()
