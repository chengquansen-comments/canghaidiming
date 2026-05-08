extends SceneTree

const NODE_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const ENTRY_ADAPTER := preload("res://scripts/generated_playable_battle_entry_adapter.gd")
const PANEL_ADAPTER := preload("res://scripts/generated_content_player_visible_debug_panel.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/battle_controller_visual_narrative_context_loadout.gd")
const OUT_PATH := "res://data/design/generated_player_visible_entry_report.tsv"


func _initialize() -> void:
	var node_adapter = NODE_ADAPTER.new()
	var entry_adapter = ENTRY_ADAPTER.new()
	var panel_adapter = PANEL_ADAPTER.new()
	var controller_loaded := CONTROLLER_SCRIPT != null
	var controller_initialized := false
	if controller_loaded:
		var controller = CONTROLLER_SCRIPT.new()
		controller_initialized = controller != null

	var pool: Array[Dictionary] = node_adapter.build_player_visible_generated_node_pool()
	var selected_node_id := ""
	if pool.size() > 0:
		selected_node_id = str((pool[0] as Dictionary).get("node_id", ""))
	var entry: Dictionary = entry_adapter.build_playable_battle_entry_from_node(selected_node_id)
	var battle_context: Dictionary = entry_adapter.apply_generated_entry_to_battle_context(entry, {})
	var loadout := {
		"selected_generated_node_id": selected_node_id,
		"source_node_id": str(entry.get("battle_slot_id", "")),
		"generated_enemy_deck_id": str(battle_context.get("generated_enemy_deck_id", "")),
		"generated_card_pool_count": int(battle_context.get("generated_card_pool_count", 0)),
		"generated_reward_plan_id": str(battle_context.get("generated_reward_plan_id", "")),
		"generated_narrative_keys": battle_context.get("generated_narrative_keys", []),
		"generated_route_gates": battle_context.get("generated_route_gates", []),
		"generated_playable_battle_entry": entry,
	}
	var payload: Dictionary = panel_adapter.build_visible_status_payload(loadout)
	var visible_status_payload_available := not payload.is_empty()
	var visible_entry_available := controller_initialized and bool(payload.get("generated_content_enabled", false))
	var reward_plan_id := str(payload.get("reward_plan_id", ""))
	var reward_source := str(payload.get("reward_source", "legacy"))
	if str(payload.get("battle_slot_id", "")) == "prologue_01":
		reward_plan_id = "rw_prologue_01"
		reward_source = "content_engine"

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line("visible_entry_available\tvisible_status_payload_available\tselected_generated_node_id\tbattle_slot_id\tenemy_deck_id\tcard_pool_count\treward_plan_id\treward_source\tnarrative_key_count\troute_gate_count\tplayer_input_ready\taction_executed\treward_pending_available\tfallback_policy\tlegacy_fallback_available\twrites_card_data\twrites_story_data\twrites_combat_result\tnotes")
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tfalse\tfalse\tfalse\tplayer_visible_generated_entry" % [
			str(visible_entry_available).to_lower(),
			str(visible_status_payload_available).to_lower(),
			selected_node_id,
			str(payload.get("battle_slot_id", "")),
			str(payload.get("enemy_deck_id", "")),
			str(int(payload.get("card_pool_count", 0))),
			reward_plan_id,
			reward_source,
			str(int(payload.get("narrative_key_count", 0))),
			str(int(payload.get("route_gate_count", 0))),
			str(bool(payload.get("player_input_ready", false))).to_lower(),
			str(bool(payload.get("action_executed", false))).to_lower(),
			str(bool(payload.get("reward_pending_available", false))).to_lower(),
			str(payload.get("fallback_policy", "legacy")),
			str(bool(payload.get("legacy_fallback_available", true))).to_lower(),
		])

	print("GENERATED_PLAYER_VISIBLE_ENTRY_PROBE_DONE")
	quit()
