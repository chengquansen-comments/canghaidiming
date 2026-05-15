# DUNGEON-0 Big Map Integration Recon

## Scope
- Read-only recon only.
- No Godot runtime integration performed.
- No scene modified.
- No combat core modified.

## Existing Big Map Node Schema
- Root graph fields: `run_id`, `seed`, `layer_count`, `current_layer`, `current_node_id`, `selected_node_id`, `completed_node_ids`, `available_node_ids`, `pending_map_node_id`, `pending_result_text`, `pending_effects`, `nodes`.
- Node fields: `map_graph_id`, `pool_node_id`, `layer`, `lane`, `x`, `y`, `title`, `node_type`, `primary_line`, `secondary_line`, `preview_text`, `result_text`, `effects`, `tags`, `combat`, `combat_pool_id`, `encounter_id`, `battle_id`, `enemy_martial_level`, `recommended_martial_min`, `recommended_martial_max`, `debug_fallback`, `outgoing`, `incoming`, `state`.
- Runtime progression identity is `map_graph_id`; source/pool identity is `pool_node_id`.
- Node states currently used: `available`, `locked`, `completed`, `unreachable`, `start`.
- Current config node types: `case`, `combat_common`, `combat_elite`, `military`, `reputation`, `rest`, `risk`.

## Existing Route State
- Strategic state fields: `active`, `completed`, `seed`, `region_index`, `layer_index`, `selected_nodes`, `current_map`, `network_map`, `current_node_id`, `selected_node_id`, `completed_node_ids`, `available_node_ids`, `pending_map_node_id`, `pending_result_text`, `pending_effects`, `military_merit`, `clean_reputation`, `case_clues`, `martial_level`, `owned_card_ids`, `selected_loadout_ids`, `deck_slots`, `active_deck_index`, `last_node_result`, `final_boss`.
- Network mirror fields kept in sync: `network_map`, `selected_node_id`, `available_node_ids`, `completed_node_ids`, `current_node_id`, `pending_map_node_id`, `pending_result_text`, `pending_effects`.
- Current progression counters present now: `military_merit`, `clean_reputation`, `case_clues`, `martial_level`.
- Missing for new dungeon model: `battle_count_so_far`, `elite_count_so_far`, `operation_count_so_far`, `visited_path_order`, `route_flags`, `old_case_progress`, `lightness_level`.

## Selection Hook
- Click hook: `scripts/narrative/strategic_network_map_flow_runtime.gd:on_network_node_clicked`.
- Confirm hook: `scripts/narrative/strategic_network_map_flow_runtime.gd:confirm_network_node`.
- Confirm guard: `scripts/strategic_network_map_confirm.gd:selected_can_confirm`.
- Node completion: `scripts/strategic_network_map_runtime.gd:complete_node`.

## Battle Entry Hook
- Combat node detection lives in `scripts/strategic_network_battle_bridge.gd:is_combat_node`.
- Combat request builder lives in `scripts/strategic_network_battle_bridge.gd:combat_request_for_node` and currently expects `enabled`, `encounter_id`, `battle_id`, `override_player_profile`, `combat_pool_id`, `recommended_martial_min`, `recommended_martial_max`, `enemy_martial_level`.
- Battle handoff goes through `scripts/narrative_battle_context.gd:set_request_from_combat`.
- Scene jump target is `res://scenes/MainVisual.tscn`.

## Generated Loadout Hook
- Battle loadout resolution lives in `scripts/battle_controller_visual_narrative_context_loadout.gd:_resolve_battle_loadout`.
- Generated manifest lookup lives in `scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd:get_generated_loadout`.
- Current generated loadout key is `formal_encounter_id + formal_battle_id`.
- Gap: No direct per-map-node injection for battle_slot_id/enemy_deck_id/reward_plan_id; current generated loadout resolves through active runtime manifest mapping.

## Adapter Plan
- Goal: Convert AIGC map_instance + route_state + node_materialized_loadout into existing network_map + strategic_state mirrors + combat request without changing current big-map UI.
- Input map_instance fields: `map_instance_id`, `progression_template_id`, `content_pool_pack_id`, `seed`, `layers`, `nodes`, `edges`.
- Input route_state fields: `run_id`, `map_instance_id`, `current_node_id`, `visited_node_ids`, `available_next_node_ids`, `battle_count_so_far`, `elite_count_so_far`, `operation_count_so_far`, `route_flags`, `old_case_progress`, `military_merit`, `clean_reputation`, `martial_realm`, `lightness_level`.
- Input node_materialized_loadout fields: `node_id`, `node_type`, `battle_slot_id`, `enemy_deck_id`, `reward_plan_id`, `operation_node_id`, `fallback_used`, `broken_ref`, `loadout_source`.
- Mapping rules:
  - AIGC map_instance.node_id must map to existing map_graph_id and remain the only visited/completed identity key.
  - AIGC source pool identifier should map to pool_node_id and may repeat across runs or branches.
  - AIGC visited_node_ids should map to completed_node_ids; available_next_node_ids should map to available_node_ids.
  - AIGC route_state.current_node_id should map to current_node_id; current preview choice should map to selected_node_id.
  - AIGC node_type must be downgraded to existing node_type labels that current UI/bridge already recognizes.
  - Combat-capable AIGC nodes must provide encounter_id and battle_id, or a combat_pool_id fallback that current bridge can resolve.
  - Node materialization should not bypass current battle entry; it must surface through NarrativeBattleContext battle_overrides or a manifest-compatible lookup layer.
  - Operation / event nodes must be converted into non-combat nodes with preview_text/result_text/effects/tags and completed through existing non-combat path.

## Risks
- Current route state lacks explicit battle_count/elite_count/operation_count counters; adapter must add an AIGC-owned state file and only mirror a minimal subset back to strategic_state.
- Current combat bridge is keyed by encounter_id/battle_id, not node_materialized_loadout ids; DUNGEON-3 will need a bridge layer instead of direct battle_slot injection into big-map code.
- Current generated-manifest lookup is active-release scoped; dungeon node materialization must not mutate active_profile/current_release and should use a sidecar resolver in later phases.

## Forbidden Modifications
- Do not rework big-map UI.
- Do not bypass current node selection flow.
- Do not mutate `current_release`, `active_profile`, or `fallback_release`.
- Do not modify `combat_resolver`, `battle_state_machine`, `card_data`, or `fighter_data`.
- Do not modify scenes in DUNGEON-0.

## Acceptance
- `existing_big_map_node_schema_found=true`
- `existing_big_map_selection_hook_found=true`
- `existing_big_map_route_state_found=true`
- `existing_big_map_battle_entry_hook_found=true`
- `aigc_big_map_adapter_plan_ready=true`
- `no_fixed_sequence_assumption=true`
- `no_runtime_modified=true`
- `no_scene_modified=true`
- `probe_pass=true`

## Conclusion
- Existing big-map contract is ready for DUNGEON-1/2 adapter work without assuming a fixed linear sequence.
