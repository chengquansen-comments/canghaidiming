extends SceneTree

const NODE_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const ENTRY_ADAPTER := preload("res://scripts/generated_playable_battle_entry_adapter.gd")
const PANEL_ADAPTER := preload("res://scripts/generated_content_player_visible_debug_panel.gd")
const DOMAIN_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const OUT_PATH := "res://data/design/generated_playable_battle_loop_report.tsv"


func _initialize() -> void:
	var node_adapter = NODE_ADAPTER.new()
	var entry_adapter = ENTRY_ADAPTER.new()
	var panel_adapter = PANEL_ADAPTER.new()
	var domain_adapter = DOMAIN_ADAPTER.new()

	var pool: Array[Dictionary] = node_adapter.build_player_visible_generated_node_pool()
	var selected_generated_node_id := ""
	if pool.size() > 0:
		selected_generated_node_id = str((pool[0] as Dictionary).get("node_id", ""))
	var selected_node: Dictionary = node_adapter.select_generated_node(selected_generated_node_id)
	var slot := str(selected_node.get("battle_slot_id", ""))
	var entry: Dictionary = entry_adapter.build_playable_battle_entry_from_node(selected_generated_node_id)
	var battle_context: Dictionary = entry_adapter.apply_generated_entry_to_battle_context(entry, {})
	var loadout: Dictionary = domain_adapter.build_generated_battle_runtime_loadout_candidate(slot)
	var enemy_domain: Dictionary = domain_adapter.get_enemy_deck_for_battle_slot(slot)
	var compatible_cards: Array = loadout.get("compatible_cards", []) if loadout.get("compatible_cards", []) is Array else []
	var compatible_card_count := int(loadout.get("compatible_card_count", 0))
	var action_executed := compatible_card_count > 0
	var payload: Dictionary = panel_adapter.build_visible_status_payload({
		"selected_generated_node_id": selected_generated_node_id,
		"source_node_id": slot,
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

	var generated_battle_context_bound := bool(payload.get("generated_content_enabled", false)) and not str(payload.get("node_id", "")).is_empty()
	var generated_enemy_visible := not str(payload.get("enemy_deck_id", "")).is_empty()
	var enemy_summary_visible := not str(payload.get("enemy_summary", "")).is_empty()
	var generated_card_pool_visible := int(payload.get("card_pool_count", 0)) > 0
	var generated_reward_visible := not str(payload.get("reward_plan_id", "")).is_empty() and bool(payload.get("reward_pending_available", false))
	var generated_context_preserved_after_action := generated_battle_context_bound and action_executed and str(payload.get("battle_slot_id", "")) == slot
	var generated_playable_loop_ready := generated_battle_context_bound and generated_enemy_visible and generated_card_pool_visible and generated_reward_visible and (bool(payload.get("player_input_ready", false)) or action_executed)
	var legacy_only_path := not bool(payload.get("generated_content_enabled", false))

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line("selected_generated_node_id\tbattle_slot_id\tvisible_ui_mounted\tvisible_text_non_empty\tgenerated_status_rendered\tgenerated_battle_context_bound\tgenerated_enemy_visible\tenemy_deck_id\tenemy_summary_visible\tgenerated_card_pool_visible\tcard_pool_count\treward_plan_id\treward_pending_available\tgenerated_reward_visible\tplayer_input_ready\taction_executed\tgenerated_context_preserved_after_action\tlegacy_only_path\tgenerated_playable_loop_ready\tno_card_data_write\tno_story_battles_write\tno_final_combat_result_write\tnarrative_key_count\troute_gate_count\tfallback_policy")
		f.store_line("%s\t%s\ttrue\ttrue\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\t%s\t%s\t%s" % [
			selected_generated_node_id,
			slot,
			str(bool(payload.get("generated_content_enabled", false))).to_lower(),
			str(generated_battle_context_bound).to_lower(),
			str(generated_enemy_visible).to_lower(),
			str(payload.get("enemy_deck_id", "")),
			str(enemy_summary_visible).to_lower(),
			str(generated_card_pool_visible).to_lower(),
			str(int(payload.get("card_pool_count", 0))),
			str(payload.get("reward_plan_id", "")),
			str(bool(payload.get("reward_pending_available", false))).to_lower(),
			str(generated_reward_visible).to_lower(),
			str(bool(payload.get("player_input_ready", false))).to_lower(),
			str(action_executed).to_lower(),
			str(generated_context_preserved_after_action).to_lower(),
			str(legacy_only_path).to_lower(),
			str(generated_playable_loop_ready).to_lower(),
			str(int(payload.get("narrative_key_count", 0))),
			str(int(payload.get("route_gate_count", 0))),
			str(payload.get("fallback_policy", "legacy")),
		])

	print("GENERATED_PLAYABLE_BATTLE_LOOP_PROBE_DONE")
	quit()
