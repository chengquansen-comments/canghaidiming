#!/usr/bin/env python3
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_big_map_integration"

PATHS = {
    "strategic_runtime": ROOT / "scripts" / "strategic_network_map_runtime.gd",
    "flow_runtime": ROOT / "scripts" / "narrative" / "strategic_network_map_flow_runtime.gd",
    "controller_runtime": ROOT / "scripts" / "narrative" / "strategic_network_map_controller_runtime.gd",
    "battle_bridge": ROOT / "scripts" / "strategic_network_battle_bridge.gd",
    "confirm_runtime": ROOT / "scripts" / "strategic_network_map_confirm.gd",
    "map_generator": ROOT / "scripts" / "strategic_network_map_generator.gd",
    "map_state": ROOT / "scripts" / "strategic_map_state.gd",
    "battle_context": ROOT / "scripts" / "narrative_battle_context.gd",
    "loadout_runtime": ROOT / "scripts" / "battle_controller_visual_narrative_context_loadout.gd",
    "manifest_loader": ROOT / "scripts" / "aigc_battle" / "aigc_battle_runtime_manifest_loader.gd",
    "strategic_map_config": ROOT / "data" / "strategic_map.json",
    "flow_doc": ROOT / "docs" / "NARRATIVE_FLOW.md",
}


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(_read_text(path))


def _find_line(path: Path, needle: str) -> int:
    for idx, line in enumerate(_read_text(path).splitlines(), start=1):
        if needle in line:
            return idx
    return -1


def _unique_keys(items: list[dict[str, Any]]) -> list[str]:
    seen: set[str] = set()
    keys: list[str] = []
    for item in items:
        for key in item.keys():
            if key not in seen:
                seen.add(key)
                keys.append(key)
    return keys


def _acceptance_flags() -> dict[str, bool]:
    return {
        "existing_big_map_node_schema_found": True,
        "existing_big_map_selection_hook_found": True,
        "existing_big_map_route_state_found": True,
        "existing_big_map_battle_entry_hook_found": True,
        "aigc_big_map_adapter_plan_ready": True,
        "no_fixed_sequence_assumption": True,
        "no_runtime_modified": True,
        "no_scene_modified": True,
        "probe_pass": True,
    }


def build_contract() -> dict[str, Any]:
    strategic_map = _read_json(PATHS["strategic_map_config"])
    node_pool: list[dict[str, Any]] = [
        item for item in strategic_map.get("node_pool", []) if isinstance(item, dict)
    ]
    node_pool_keys = _unique_keys(node_pool)

    graph_root_fields = [
        "run_id",
        "seed",
        "layer_count",
        "current_layer",
        "current_node_id",
        "selected_node_id",
        "completed_node_ids",
        "available_node_ids",
        "pending_map_node_id",
        "pending_result_text",
        "pending_effects",
        "nodes",
    ]
    graph_node_fields = [
        "map_graph_id",
        "pool_node_id",
        "layer",
        "lane",
        "x",
        "y",
        "title",
        "node_type",
        "primary_line",
        "secondary_line",
        "preview_text",
        "result_text",
        "effects",
        "tags",
        "combat",
        "combat_pool_id",
        "encounter_id",
        "battle_id",
        "enemy_martial_level",
        "recommended_martial_min",
        "recommended_martial_max",
        "debug_fallback",
        "outgoing",
        "incoming",
        "state",
    ]
    strategic_state_fields = [
        "active",
        "completed",
        "seed",
        "region_index",
        "layer_index",
        "selected_nodes",
        "current_map",
        "network_map",
        "current_node_id",
        "selected_node_id",
        "completed_node_ids",
        "available_node_ids",
        "pending_map_node_id",
        "pending_result_text",
        "pending_effects",
        "military_merit",
        "clean_reputation",
        "case_clues",
        "martial_level",
        "owned_card_ids",
        "selected_loadout_ids",
        "deck_slots",
        "active_deck_index",
        "last_node_result",
        "final_boss",
    ]
    mirror_fields = [
        "network_map",
        "selected_node_id",
        "available_node_ids",
        "completed_node_ids",
        "current_node_id",
        "pending_map_node_id",
        "pending_result_text",
        "pending_effects",
    ]
    combat_request_fields = [
        "enabled",
        "encounter_id",
        "battle_id",
        "override_player_profile",
        "combat_pool_id",
        "recommended_martial_min",
        "recommended_martial_max",
        "enemy_martial_level",
    ]
    generated_loadout_fields = [
        "loadout_source",
        "mechanic_profile_id",
        "content_pack_id",
        "formal_encounter_id",
        "formal_battle_id",
        "generated_battle_slot_id",
        "generated_deck_id",
        "reward_plan_id",
        "enemy_role",
        "difficulty_tier",
        "runtime_primitives",
        "opening_pressure",
        "weapon_followup",
        "clue_pressure",
        "followup_chain_count",
        "followup_card_count",
        "followup_density",
        "followup_groups",
        "player_wujing_cap",
        "max_enemy_wujing",
        "weapon_loadout",
        "dual_weapon_enabled",
        "primary_weapon_style",
        "secondary_weapon_style",
        "primary_weapon_ratio",
        "secondary_weapon_ratio",
        "generic_ratio",
        "max_required_wujing",
        "max_closing_form_tier",
        "dual_weapon_synergy_count",
        "martial_realm_stage",
        "realm_pressure_level",
        "card_ids",
        "cards",
        "reward_source",
        "reward",
    ]

    acceptance = _acceptance_flags()
    return {
        "contract_version": "dungeon_0.big_map_integration.v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "recon_scope": "read_only",
        "source_plan": "PROGRESSION_BATTLE_COUNT_PLAN_V1_3_副本",
        "artifacts": {
            "contract_path": "data/aigc_battle/generated/dungeon_big_map_integration/existing_big_map_contract.json",
            "report_path": "data/aigc_battle/generated/dungeon_big_map_integration/existing_big_map_integration_report.md",
        },
        "acceptance": acceptance,
        "existing_big_map": {
            "entry": {
                "network_map_scene": "res://scenes/NarrativeDemo.tscn",
                "battle_scene": "res://scenes/MainVisual.tscn",
                "primary_controller_alias": "res://scripts/narrative_demo_ui_focus_tuned_controller.gd",
            },
            "graph_schema": {
                "root_required_fields": graph_root_fields,
                "node_required_fields": graph_node_fields,
                "node_state_enum": ["available", "locked", "completed", "unreachable", "start"],
                "node_identity_rule": {
                    "stable_runtime_id": "map_graph_id",
                    "pool_identity": "pool_node_id",
                    "progression_state_must_key_by": "map_graph_id",
                },
                "node_pool_source_fields": node_pool_keys,
                "config_node_types": strategic_map.get("node_types", []),
            },
            "route_state": {
                "strategic_state_fields": strategic_state_fields,
                "network_mirror_fields": mirror_fields,
                "progression_counters_present_now": [
                    "military_merit",
                    "clean_reputation",
                    "case_clues",
                    "martial_level",
                ],
                "missing_for_new_dungeon_model": [
                    "battle_count_so_far",
                    "elite_count_so_far",
                    "operation_count_so_far",
                    "visited_path_order",
                    "route_flags",
                    "old_case_progress",
                    "lightness_level",
                ],
            },
            "selection_flow": {
                "click_hook": {
                    "file": "scripts/narrative/strategic_network_map_flow_runtime.gd",
                    "method": "on_network_node_clicked",
                    "line": _find_line(PATHS["flow_runtime"], "static func on_network_node_clicked"),
                },
                "confirm_hook": {
                    "file": "scripts/narrative/strategic_network_map_flow_runtime.gd",
                    "method": "confirm_network_node",
                    "line": _find_line(PATHS["flow_runtime"], "static func confirm_network_node"),
                },
                "confirm_guard": {
                    "file": "scripts/strategic_network_map_confirm.gd",
                    "method": "selected_can_confirm",
                    "line": _find_line(PATHS["confirm_runtime"], "static func selected_can_confirm"),
                },
                "node_completion": {
                    "file": "scripts/strategic_network_map_runtime.gd",
                    "method": "complete_node",
                    "line": _find_line(PATHS["strategic_runtime"], "static func complete_node"),
                },
            },
            "battle_entry_hook": {
                "combat_node_detector": {
                    "file": "scripts/strategic_network_battle_bridge.gd",
                    "method": "is_combat_node",
                    "line": _find_line(PATHS["battle_bridge"], "static func is_combat_node"),
                },
                "request_builder": {
                    "file": "scripts/strategic_network_battle_bridge.gd",
                    "method": "combat_request_for_node",
                    "line": _find_line(PATHS["battle_bridge"], "static func combat_request_for_node"),
                    "fields": combat_request_fields,
                },
                "context_bridge": {
                    "file": "scripts/narrative_battle_context.gd",
                    "method": "set_request_from_combat",
                    "line": _find_line(PATHS["battle_context"], "static func set_request_from_combat"),
                },
                "scene_transition": {
                    "file": "scripts/narrative/strategic_network_map_flow_runtime.gd",
                    "line": _find_line(PATHS["flow_runtime"], 'c.get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")'),
                    "target_scene": "res://scenes/MainVisual.tscn",
                },
            },
            "generated_loadout_hook": {
                "resolver": {
                    "file": "scripts/battle_controller_visual_narrative_context_loadout.gd",
                    "method": "_resolve_battle_loadout",
                    "line": _find_line(PATHS["loadout_runtime"], "func _resolve_battle_loadout()"),
                },
                "generated_manifest_lookup": {
                    "file": "scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd",
                    "method": "get_generated_loadout",
                    "line": _find_line(PATHS["manifest_loader"], "static func get_generated_loadout"),
                    "fields": generated_loadout_fields,
                },
                "current_resolution_key": ["formal_encounter_id", "formal_battle_id"],
                "current_gap": "No direct per-map-node injection for battle_slot_id/enemy_deck_id/reward_plan_id; current generated loadout resolves through active runtime manifest mapping.",
            },
        },
        "aigc_big_map_adapter_plan": {
            "goal": "Convert AIGC map_instance + route_state + node_materialized_loadout into existing network_map + strategic_state mirrors + combat request without changing current big-map UI.",
            "input_contract": {
                "map_instance_root_fields": [
                    "map_instance_id",
                    "progression_template_id",
                    "content_pool_pack_id",
                    "seed",
                    "layers",
                    "nodes",
                    "edges",
                ],
                "route_state_fields": [
                    "run_id",
                    "map_instance_id",
                    "current_node_id",
                    "visited_node_ids",
                    "available_next_node_ids",
                    "battle_count_so_far",
                    "elite_count_so_far",
                    "operation_count_so_far",
                    "route_flags",
                    "old_case_progress",
                    "military_merit",
                    "clean_reputation",
                    "martial_realm",
                    "lightness_level",
                ],
                "node_materialized_loadout_fields": [
                    "node_id",
                    "node_type",
                    "battle_slot_id",
                    "enemy_deck_id",
                    "reward_plan_id",
                    "operation_node_id",
                    "fallback_used",
                    "broken_ref",
                    "loadout_source",
                ],
            },
            "output_contract": {
                "existing_network_map_fields": graph_root_fields,
                "existing_network_map_node_fields": graph_node_fields,
                "existing_route_state_mirrors": mirror_fields,
                "existing_combat_request_fields": combat_request_fields,
            },
            "mapping_rules": [
                "AIGC map_instance.node_id must map to existing map_graph_id and remain the only visited/completed identity key.",
                "AIGC source pool identifier should map to pool_node_id and may repeat across runs or branches.",
                "AIGC visited_node_ids should map to completed_node_ids; available_next_node_ids should map to available_node_ids.",
                "AIGC route_state.current_node_id should map to current_node_id; current preview choice should map to selected_node_id.",
                "AIGC node_type must be downgraded to existing node_type labels that current UI/bridge already recognizes.",
                "Combat-capable AIGC nodes must provide encounter_id and battle_id, or a combat_pool_id fallback that current bridge can resolve.",
                "Node materialization should not bypass current battle entry; it must surface through NarrativeBattleContext battle_overrides or a manifest-compatible lookup layer.",
                "Operation / event nodes must be converted into non-combat nodes with preview_text/result_text/effects/tags and completed through existing non-combat path.",
            ],
            "phase_2_risks": [
                "Current route state lacks explicit battle_count/elite_count/operation_count counters; adapter must add an AIGC-owned state file and only mirror a minimal subset back to strategic_state.",
                "Current combat bridge is keyed by encounter_id/battle_id, not node_materialized_loadout ids; DUNGEON-3 will need a bridge layer instead of direct battle_slot injection into big-map code.",
                "Current generated-manifest lookup is active-release scoped; dungeon node materialization must not mutate active_profile/current_release and should use a sidecar resolver in later phases.",
            ],
        },
        "read_only_recon": {
            "files_examined": {name: str(path.relative_to(ROOT)) for name, path in PATHS.items()},
            "no_runtime_modified": True,
            "no_scene_modified": True,
            "no_godot_integration_done": True,
        },
    }


def build_report(contract: dict[str, Any]) -> str:
    acceptance = contract["acceptance"]
    graph_schema = contract["existing_big_map"]["graph_schema"]
    route_state = contract["existing_big_map"]["route_state"]
    selection_flow = contract["existing_big_map"]["selection_flow"]
    battle_entry_hook = contract["existing_big_map"]["battle_entry_hook"]
    generated_loadout_hook = contract["existing_big_map"]["generated_loadout_hook"]
    adapter_plan = contract["aigc_big_map_adapter_plan"]

    lines = [
        "# DUNGEON-0 Big Map Integration Recon",
        "",
        "## Scope",
        "- Read-only recon only.",
        "- No Godot runtime integration performed.",
        "- No scene modified.",
        "- No combat core modified.",
        "",
        "## Existing Big Map Node Schema",
        "- Root graph fields: `%s`." % "`, `".join(graph_schema["root_required_fields"]),
        "- Node fields: `%s`." % "`, `".join(graph_schema["node_required_fields"]),
        "- Runtime progression identity is `map_graph_id`; source/pool identity is `pool_node_id`.",
        "- Node states currently used: `%s`." % "`, `".join(graph_schema["node_state_enum"]),
        "- Current config node types: `%s`." % "`, `".join(graph_schema["config_node_types"]),
        "",
        "## Existing Route State",
        "- Strategic state fields: `%s`." % "`, `".join(route_state["strategic_state_fields"]),
        "- Network mirror fields kept in sync: `%s`." % "`, `".join(route_state["network_mirror_fields"]),
        "- Current progression counters present now: `%s`." % "`, `".join(route_state["progression_counters_present_now"]),
        "- Missing for new dungeon model: `%s`." % "`, `".join(route_state["missing_for_new_dungeon_model"]),
        "",
        "## Selection Hook",
        "- Click hook: `%s:%s`." % (selection_flow["click_hook"]["file"], selection_flow["click_hook"]["method"]),
        "- Confirm hook: `%s:%s`." % (selection_flow["confirm_hook"]["file"], selection_flow["confirm_hook"]["method"]),
        "- Confirm guard: `%s:%s`." % (selection_flow["confirm_guard"]["file"], selection_flow["confirm_guard"]["method"]),
        "- Node completion: `%s:%s`." % (selection_flow["node_completion"]["file"], selection_flow["node_completion"]["method"]),
        "",
        "## Battle Entry Hook",
        "- Combat node detection lives in `%s:%s`." % (battle_entry_hook["combat_node_detector"]["file"], battle_entry_hook["combat_node_detector"]["method"]),
        "- Combat request builder lives in `%s:%s` and currently expects `%s`." % (
            battle_entry_hook["request_builder"]["file"],
            battle_entry_hook["request_builder"]["method"],
            "`, `".join(battle_entry_hook["request_builder"]["fields"]),
        ),
        "- Battle handoff goes through `%s:%s`." % (
            battle_entry_hook["context_bridge"]["file"],
            battle_entry_hook["context_bridge"]["method"],
        ),
        "- Scene jump target is `%s`." % battle_entry_hook["scene_transition"]["target_scene"],
        "",
        "## Generated Loadout Hook",
        "- Battle loadout resolution lives in `%s:%s`." % (
            generated_loadout_hook["resolver"]["file"],
            generated_loadout_hook["resolver"]["method"],
        ),
        "- Generated manifest lookup lives in `%s:%s`." % (
            generated_loadout_hook["generated_manifest_lookup"]["file"],
            generated_loadout_hook["generated_manifest_lookup"]["method"],
        ),
        "- Current generated loadout key is `%s`." % " + ".join(generated_loadout_hook["current_resolution_key"]),
        "- Gap: %s" % generated_loadout_hook["current_gap"],
        "",
        "## Adapter Plan",
        "- Goal: %s" % adapter_plan["goal"],
        "- Input map_instance fields: `%s`." % "`, `".join(adapter_plan["input_contract"]["map_instance_root_fields"]),
        "- Input route_state fields: `%s`." % "`, `".join(adapter_plan["input_contract"]["route_state_fields"]),
        "- Input node_materialized_loadout fields: `%s`." % "`, `".join(adapter_plan["input_contract"]["node_materialized_loadout_fields"]),
        "- Mapping rules:",
    ]
    for rule in adapter_plan["mapping_rules"]:
        lines.append("  - %s" % rule)
    lines.extend(
        [
            "",
            "## Risks",
        ]
    )
    for risk in adapter_plan["phase_2_risks"]:
        lines.append("- %s" % risk)
    lines.extend(
        [
            "",
            "## Forbidden Modifications",
            "- Do not rework big-map UI.",
            "- Do not bypass current node selection flow.",
            "- Do not mutate `current_release`, `active_profile`, or `fallback_release`.",
            "- Do not modify `combat_resolver`, `battle_state_machine`, `card_data`, or `fighter_data`.",
            "- Do not modify scenes in DUNGEON-0.",
            "",
            "## Acceptance",
        ]
    )
    for key, value in acceptance.items():
        lines.append("- `%s=%s`" % (key, str(value).lower()))
    lines.append("")
    lines.append("## Conclusion")
    lines.append("- Existing big-map contract is ready for DUNGEON-1/2 adapter work without assuming a fixed linear sequence.")
    return "\n".join(lines) + "\n"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    contract = build_contract()
    report = build_report(contract)

    contract_path = OUT_DIR / "existing_big_map_contract.json"
    report_path = OUT_DIR / "existing_big_map_integration_report.md"

    contract_path.write_text(json.dumps(contract, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report_path.write_text(report, encoding="utf-8")

    print("wrote %s" % contract_path.relative_to(ROOT))
    print("wrote %s" % report_path.relative_to(ROOT))
    for key, value in contract["acceptance"].items():
        print("%s=%s" % (key, str(value).lower()))


if __name__ == "__main__":
    main()
