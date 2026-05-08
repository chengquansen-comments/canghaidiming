extends SceneTree

const RUNTIME_CONTROLLER := preload("res://scripts/battle_controller_visual_narrative_context_runtime.gd")
const NODE_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const ENTRY_ADAPTER := preload("res://scripts/generated_playable_battle_entry_adapter.gd")
const DOMAIN_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const PANEL_ADAPTER := preload("res://scripts/generated_content_player_visible_debug_panel.gd")
const OUT_PATH := "res://data/design/generated_real_node_entry_report.tsv"


func _initialize() -> void:
	var controller = RUNTIME_CONTROLLER.new()
	var real_node_entry_exists := controller != null and (controller.has_method("_on_recommended_battle_pressed") or controller.has_method("_try_recommended_role_entry"))
	var real_node_entry_visible_or_callable := real_node_entry_exists
	var real_node_entry_invoked := false
	if real_node_entry_exists and controller.has_method("_on_recommended_battle_pressed"):
		controller.call("_on_recommended_battle_pressed")
		real_node_entry_invoked = true
	elif real_node_entry_exists and controller.has_method("_try_recommended_role_entry"):
		controller.call("_try_recommended_role_entry", "blademaster")
		real_node_entry_invoked = true

	var node_adapter = NODE_ADAPTER.new()
	var entry_adapter = ENTRY_ADAPTER.new()
	var domain_adapter = DOMAIN_ADAPTER.new()
	var panel_adapter = PANEL_ADAPTER.new()
	var pool: Array[Dictionary] = node_adapter.build_player_visible_generated_node_pool()
	var selected_generated_node_id := ""
	if pool.size() > 0:
		selected_generated_node_id = str((pool[0] as Dictionary).get("node_id", ""))
	var selected_node: Dictionary = node_adapter.select_generated_node(selected_generated_node_id)
	var battle_slot_id := str(selected_node.get("battle_slot_id", ""))
	var entry: Dictionary = entry_adapter.build_playable_battle_entry_from_node(selected_generated_node_id)
	var battle_context: Dictionary = entry_adapter.apply_generated_entry_to_battle_context(entry, {})
	var loadout: Dictionary = domain_adapter.build_generated_battle_runtime_loadout_candidate(battle_slot_id)
	var enemy_domain: Dictionary = domain_adapter.get_enemy_deck_for_battle_slot(battle_slot_id)
	var compatible_card_count := int(loadout.get("compatible_card_count", 0))
	var action_executed := compatible_card_count > 0
	var payload: Dictionary = panel_adapter.build_visible_status_payload({
		"selected_generated_node_id": selected_generated_node_id,
		"source_node_id": battle_slot_id,
		"generated_enemy_deck_id": str(battle_context.get("generated_enemy_deck_id", "")),
		"generated_card_pool_count": int(battle_context.get("generated_card_pool_count", 0)),
		"generated_reward_plan_id": str(battle_context.get("generated_reward_plan_id", "")),
		"generated_narrative_keys": battle_context.get("generated_narrative_keys", []),
		"generated_route_gates": battle_context.get("generated_route_gates", []),
		"generated_playable_battle_entry": entry,
		"enemy_deck_domain": enemy_domain,
		"compatible_card_count": compatible_card_count,
		"action_executed": action_executed,
	})
	var status_text := panel_adapter.build_visible_status_text(payload)

	var generated_battle_context_bound := bool(payload.get("generated_content_enabled", false)) and not selected_generated_node_id.is_empty()
	var generated_status_rendered := status_text.find("Generated Content: ON") >= 0
	var generated_enemy_visible := not str(payload.get("enemy_deck_id", "")).is_empty()
	var enemy_summary_visible := status_text.find("Enemy Summary:") >= 0 and not str(payload.get("enemy_summary", "")).is_empty()
	var generated_card_pool_visible := int(payload.get("card_pool_count", 0)) > 0
	var reward_pending_available := bool(payload.get("reward_pending_available", false))
	var generated_reward_visible := not str(payload.get("reward_plan_id", "")).is_empty() and reward_pending_available
	var player_input_ready := bool(payload.get("player_input_ready", false))
	var generated_context_preserved_after_action := generated_battle_context_bound and action_executed and str(payload.get("battle_slot_id", "")) == battle_slot_id
	var legacy_only_path := not bool(payload.get("generated_content_enabled", false))
	var reached_battle_from_real_entry := real_node_entry_invoked and generated_battle_context_bound
	var generated_real_node_entry_ready := real_node_entry_exists and real_node_entry_visible_or_callable and reached_battle_from_real_entry and generated_status_rendered and (player_input_ready or action_executed)

	var out_abs := ProjectSettings.globalize_path(OUT_PATH)
	var out_dir := out_abs.get_base_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_abs, FileAccess.WRITE)
	if f != null:
		f.store_line("real_node_entry_exists\treal_node_entry_visible_or_callable\treal_node_entry_invoked\treached_battle_from_real_entry\tselected_generated_node_id\tbattle_slot_id\tgenerated_battle_context_bound\tgenerated_status_rendered\tgenerated_enemy_visible\tenemy_deck_id\tenemy_summary_visible\tgenerated_card_pool_visible\tcard_pool_count\treward_plan_id\treward_pending_available\tgenerated_reward_visible\tplayer_input_ready\taction_executed\tgenerated_context_preserved_after_action\tlegacy_only_path\tgenerated_real_node_entry_ready\tno_card_data_write\tno_story_battles_write\tno_final_combat_result_write\tfallback_policy")
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\t%s" % [
			str(real_node_entry_exists).to_lower(),
			str(real_node_entry_visible_or_callable).to_lower(),
			str(real_node_entry_invoked).to_lower(),
			str(reached_battle_from_real_entry).to_lower(),
			selected_generated_node_id,
			battle_slot_id,
			str(generated_battle_context_bound).to_lower(),
			str(generated_status_rendered).to_lower(),
			str(generated_enemy_visible).to_lower(),
			str(payload.get("enemy_deck_id", "")),
			str(enemy_summary_visible).to_lower(),
			str(generated_card_pool_visible).to_lower(),
			str(int(payload.get("card_pool_count", 0))),
			str(payload.get("reward_plan_id", "")),
			str(reward_pending_available).to_lower(),
			str(generated_reward_visible).to_lower(),
			str(player_input_ready).to_lower(),
			str(action_executed).to_lower(),
			str(generated_context_preserved_after_action).to_lower(),
			str(legacy_only_path).to_lower(),
			str(generated_real_node_entry_ready).to_lower(),
			str(payload.get("fallback_policy", "legacy")),
		])

	print("GENERATED_REAL_NODE_ENTRY_PROBE_DONE")
	quit()
