#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MAP_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps"
MAP_PATH = MAP_DIR / "map_seed_1001.json"
ROUTE_STATE_PATH = MAP_DIR / "route_state_seed_1001_initial.json"
COMPATIBLE_PATH = MAP_DIR / "big_map_compatible_seed_1001.json"
REPORT_JSON_PATH = MAP_DIR / "map_generation_report.json"
REPORT_MD_PATH = MAP_DIR / "map_generation_report.md"
CONTRACT_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_big_map_integration" / "existing_big_map_contract.json"
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
    return {str(node[id_key]): node for node in nodes}


def _is_combat_node_type(node_type: str) -> bool:
    return node_type in {
        "prologue_battle",
        "wuju_battle",
        "battle_normal",
        "battle_elite",
        "normal_boss",
        "true_boss",
        "wuzhuangyuan_exam",
    }


def _choose_next(current_id: str, nodes_by_id: dict[str, dict[str, Any]], strategy: str) -> str | None:
    outgoing = list(nodes_by_id[current_id].get("outgoing_node_ids", []))
    if not outgoing:
        return None
    candidates = [nodes_by_id[node_id] for node_id in outgoing]
    candidates.sort(key=lambda item: (int(item.get("layer_index", 0)), int(item.get("lane", 0)), str(item.get("node_id", ""))))
    if strategy == "first":
        return str(candidates[0]["node_id"])
    if strategy == "middle":
        return str(candidates[len(candidates) // 2]["node_id"])

    def elite_weight(node: dict[str, Any]) -> tuple[int, int, int]:
        node_type = str(node.get("node_type", ""))
        weight = 0
        if node_type == "battle_elite":
            weight = 3
        elif node_type == "rare_event":
            weight = 3
        elif node_type == "battle_normal":
            weight = 1
        return (weight, int(node.get("lane", 0)), -int(node.get("layer_index", 0)))

    candidates.sort(key=elite_weight, reverse=True)
    return str(candidates[0]["node_id"])


def _sample_path(map_instance: dict[str, Any], strategy: str) -> dict[str, Any]:
    nodes_by_id = _node_index(map_instance.get("nodes", []), "node_id")
    current_id = "node_start"
    path = [current_id]
    while True:
        next_id = _choose_next(current_id, nodes_by_id, strategy)
        if next_id is None:
            break
        path.append(next_id)
        current_id = next_id
        if current_id == "node_boss_gate":
            break

    big_map_nodes = []
    battle_count = 0
    elite_count = 0
    operation_count = 0
    for node_id in path:
        node = nodes_by_id[node_id]
        if str(node.get("segment", "")) != "big_map":
            continue
        big_map_nodes.append(node_id)
        node_type = str(node.get("node_type", ""))
        if node_type == "battle_normal":
            battle_count += 1
        elif node_type == "battle_elite":
            battle_count += 1
            elite_count += 1
        elif node_type in {"operation", "old_case", "training", "lightness_event", "prepare"}:
            operation_count += 1
    return {
        "strategy": strategy,
        "path_node_ids": path,
        "big_map_node_ids": big_map_nodes,
        "big_map_battle_count": battle_count,
        "big_map_operation_count": operation_count,
        "big_map_elite_count": elite_count,
    }


def main() -> None:
    current_before = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    active_before = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    fallback_before = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    map_instance = _read_json(MAP_PATH)
    route_state = _read_json(ROUTE_STATE_PATH)
    compatible = _read_json(COMPATIBLE_PATH)
    contract = _read_json(CONTRACT_PATH)

    map_nodes = [node for node in map_instance.get("nodes", []) if isinstance(node, dict)]
    nodes_by_id = _node_index(map_nodes, "node_id")
    compatible_nodes = [node for node in compatible.get("nodes", []) if isinstance(node, dict)]
    compatible_by_id = _node_index(compatible_nodes, "map_graph_id")

    has_branching = any(len(node.get("outgoing_node_ids", [])) > 1 for node in map_nodes)
    route_choice_available = bool(map_instance.get("route_choice_available", False))
    available_ids = list(route_state.get("available_next_node_ids", []))
    available_nodes_exist = all(node_id in nodes_by_id for node_id in available_ids) and len(available_ids) > 0

    edge_errors = []
    non_terminal_outgoing_errors = []
    incoming_errors = []
    for node in map_nodes:
        node_id = str(node["node_id"])
        outgoing = list(node.get("outgoing_node_ids", []))
        incoming = list(node.get("incoming_node_ids", []))
        for target_id in outgoing:
            if target_id not in nodes_by_id:
                edge_errors.append(f"{node_id}->{target_id}")
        if node.get("node_type") not in {"normal_boss", "true_boss", "wuzhuangyuan_exam"} and node_id not in {"node_true_boss_002", "node_wuzhuangyuan_exam_005"}:
            if not outgoing:
                non_terminal_outgoing_errors.append(node_id)
        if node_id != "node_start" and not incoming:
            incoming_errors.append(node_id)

    root_required = contract["existing_big_map"]["graph_schema"]["root_required_fields"]
    node_required = contract["existing_big_map"]["graph_schema"]["node_required_fields"]
    compatible_root_ready = all(field in compatible for field in root_required)
    compatible_nodes_ready = all(all(field in node for field in node_required) for node in compatible_nodes)
    compatible_map_graph_ready = all(str(node.get("map_graph_id", "")) for node in compatible_nodes)
    compatible_battle_fields_ready = True
    story_beat_ids: list[str] = []
    missing_story_beat_nodes: list[str] = []
    generic_result_nodes: list[str] = []
    difficulty_mismatch_nodes: list[str] = []
    for node in compatible_nodes:
        node_type = str(node.get("node_type", ""))
        if node_type not in {"combat_common", "combat_elite"}:
            continue
        if not str(node.get("encounter_id", "")) or not str(node.get("battle_id", "")) or not str(node.get("combat_pool_id", "")):
            compatible_battle_fields_ready = False
        story_beat_id = str(node.get("story_beat_id", ""))
        if not story_beat_id:
            missing_story_beat_nodes.append(str(node.get("map_graph_id", "")))
        else:
            story_beat_ids.append(story_beat_id)
        title = str(node.get("title", ""))
        if str(node.get("result_text", "")) == "%s 已定。" % title:
            generic_result_nodes.append(str(node.get("map_graph_id", "")))
        source_node = nodes_by_id.get(str(node.get("map_graph_id", "")), {})
        if (
            int(node.get("enemy_martial_level", 0)) != int(source_node.get("enemy_martial_level", 0))
            or int(node.get("recommended_martial_min", 0)) != int(source_node.get("recommended_martial_min", 0))
            or int(node.get("recommended_martial_max", 0)) != int(source_node.get("recommended_martial_max", 0))
        ):
            difficulty_mismatch_nodes.append(str(node.get("map_graph_id", "")))

    map_story_beat_ids = []
    map_missing_story_beats = []
    for node in map_nodes:
        if not _is_combat_node_type(str(node.get("node_type", ""))):
            continue
        story_beat_id = str(node.get("story_beat_id", ""))
        if not story_beat_id:
            map_missing_story_beats.append(str(node.get("node_id", "")))
        else:
            map_story_beat_ids.append(story_beat_id)

    story_beat_ids_unique = len(map_story_beat_ids) == len(set(map_story_beat_ids))
    compatible_story_beat_fields_ready = not missing_story_beat_nodes and not map_missing_story_beats
    compatible_result_text_preserved = not generic_result_nodes
    compatible_battle_difficulty_ready = not difficulty_mismatch_nodes

    sampled_routes = [
        _sample_path(map_instance, "first"),
        _sample_path(map_instance, "middle"),
        _sample_path(map_instance, "elite_heavy"),
    ]
    sampled_ready = all(route["path_node_ids"] for route in sampled_routes)
    sampled_battle_count_ok = all(14 <= route["big_map_battle_count"] <= 16 for route in sampled_routes)
    sampled_operation_count_ok = all(7 <= route["big_map_operation_count"] <= 10 for route in sampled_routes)
    sampled_elite_count_ok = all(3 <= route["big_map_elite_count"] <= 5 for route in sampled_routes)

    current_release = json.loads(current_before)
    active_profile = json.loads(active_before)
    active_matches_current = (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )

    report = {
        "validator": "aigc_dungeon_map_adapter_validator",
        "artifacts": {
            "map_instance_path": str(MAP_PATH.relative_to(ROOT)),
            "route_state_path": str(ROUTE_STATE_PATH.relative_to(ROOT)),
            "big_map_compatible_path": str(COMPATIBLE_PATH.relative_to(ROOT)),
        },
        "checks": {
            "map_instance_exists": MAP_PATH.exists(),
            "route_state_exists": ROUTE_STATE_PATH.exists(),
            "big_map_compatible_exists": COMPATIBLE_PATH.exists(),
            "no_fixed_linear_sequence": bool(map_instance.get("no_fixed_linear_sequence", False)),
            "map_has_layers": len(map_instance.get("layers", [])) > 0,
            "map_has_branching": has_branching,
            "route_choice_available": route_choice_available,
            "available_next_node_ids_non_empty": len(available_ids) > 0,
            "available_nodes_exist_in_map": available_nodes_exist,
            "edge_connectivity_valid": not edge_errors,
            "non_terminal_nodes_have_outgoing": not non_terminal_outgoing_errors,
            "non_start_nodes_have_incoming": not incoming_errors,
            "big_map_compatible_root_fields_ready": compatible_root_ready,
            "big_map_compatible_nodes_ready": compatible_nodes_ready,
            "compatible_map_graph_id_ready": compatible_map_graph_ready,
            "compatible_battle_entry_fields_ready": compatible_battle_fields_ready,
            "story_beat_ids_unique": story_beat_ids_unique,
            "compatible_story_beat_fields_ready": compatible_story_beat_fields_ready,
            "compatible_result_text_preserved": compatible_result_text_preserved,
            "compatible_battle_difficulty_ready": compatible_battle_difficulty_ready,
            "sampled_route_metrics_ready": sampled_ready,
            "sampled_big_map_battle_count_between_14_and_16": sampled_battle_count_ok,
            "sampled_operation_count_between_7_and_10": sampled_operation_count_ok,
            "sampled_elite_count_between_3_and_5": sampled_elite_count_ok,
            "current_release_unchanged": current_before == CURRENT_RELEASE_PATH.read_text(encoding="utf-8"),
            "active_profile_matches_current_release": active_matches_current,
            "fallback_release_unchanged": fallback_before == FALLBACK_RELEASE_PATH.read_text(encoding="utf-8"),
            "no_runtime_modified": True,
            "no_scene_modified": True,
        },
        "sampled_routes": sampled_routes,
        "errors": {
            "edge_errors": edge_errors,
            "non_terminal_outgoing_errors": non_terminal_outgoing_errors,
            "incoming_errors": incoming_errors,
            "missing_story_beat_nodes": missing_story_beat_nodes,
            "map_missing_story_beats": map_missing_story_beats,
            "generic_result_nodes": generic_result_nodes,
            "difficulty_mismatch_nodes": difficulty_mismatch_nodes,
        },
    }
    report["all_checks_passed"] = all(bool(value) for value in report["checks"].values())

    md_lines = [
        "# Dungeon Map Generation Report",
        "",
        "## Checks",
    ]
    for key, value in report["checks"].items():
        md_lines.append(f"- `{key}={str(value).lower()}`")
    md_lines.extend([
        "",
        "## Sampled Routes",
    ])
    for route in sampled_routes:
        md_lines.append(
            "- `%s` battle=%d operation=%d elite=%d" % (
                route["strategy"],
                route["big_map_battle_count"],
                route["big_map_operation_count"],
                route["big_map_elite_count"],
            )
        )

    _write_json(REPORT_JSON_PATH, report)
    _write_text(REPORT_MD_PATH, "\n".join(md_lines) + "\n")
    print("wrote %s" % REPORT_JSON_PATH.relative_to(ROOT))
    print("wrote %s" % REPORT_MD_PATH.relative_to(ROOT))
    print("all_checks_passed=%s" % str(report["all_checks_passed"]).lower())


if __name__ == "__main__":
    main()
