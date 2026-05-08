extends SceneTree

const ENTRY_ADAPTER := preload("res://scripts/generated_playable_battle_entry_adapter.gd")
const NODE_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/battle_controller_visual_narrative_context_loadout.gd")
const CFG_PATH := "res://data/design/generated_full_battle_slot_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_playable_battle_scene_report.tsv"
const NON_NODE_ID := "generated_node_sample_non_generated_preview_slot"


func _initialize() -> void:
	var entry_adapter = ENTRY_ADAPTER.new()
	var node_adapter = NODE_ADAPTER.new()
	var controller_loaded := CONTROLLER_SCRIPT != null
	var controller_initialized := false
	if controller_loaded:
		var controller = CONTROLLER_SCRIPT.new()
		controller_initialized = controller != null
	var reward_fallback_map := _load_reward_fallback_map()
	var rows: Array = []
	var pool: Array[Dictionary] = node_adapter.build_player_visible_generated_node_pool()
	var selected_any := false

	for node in pool:
		var node_id := str(node.get("node_id", ""))
		var slot := str(node.get("battle_slot_id", ""))
		var selected_in_probe := false
		if not selected_any:
			selected_in_probe = true
			selected_any = true
		var entry: Dictionary = entry_adapter.build_playable_battle_entry_from_node(node_id)
		var context: Dictionary = entry_adapter.apply_generated_entry_to_battle_context(entry, {})
		var reward_plan_id := str(entry.get("reward_plan_id", ""))
		var reward_source := str(entry.get("reward_source", "legacy"))
		if bool(reward_fallback_map.get(slot, false)):
			reward_plan_id = ""
			reward_source = "legacy"
		var battle_context_loaded := bool(context.get("generated_battle_context_initialized", false))
		var can_present := bool(entry.get("can_start_playable_battle", false)) and battle_context_loaded and controller_initialized
		rows.append({
			"node_id": node_id,
			"battle_slot_id": slot,
			"selected_in_probe": str(selected_in_probe).to_lower(),
			"scene_or_controller_loaded": str(controller_loaded).to_lower(),
			"battle_controller_initialized": str(controller_initialized).to_lower(),
			"battle_context_loaded": str(battle_context_loaded).to_lower(),
			"can_present_battle": str(can_present).to_lower(),
			"source": str(entry.get("playable_entry_source", "legacy")),
			"enemy_deck_id": str(entry.get("enemy_deck_id", "")),
			"enemy_deck_loaded": str(not str(entry.get("enemy_deck_id", "")).is_empty()).to_lower(),
			"card_pool_count": str(int(entry.get("card_pool_count", 0))),
			"generated_card_pool_available": str(bool(entry.get("generated_card_pool_available", false))).to_lower(),
			"reward_plan_id": reward_plan_id,
			"reward_source": reward_source,
			"narrative_key_count": str(int(entry.get("narrative_key_count", 0))),
			"route_gate_count": str(int(entry.get("route_gate_count", 0))),
			"fallback_policy": str(entry.get("fallback_policy", "legacy")),
			"legacy_fallback_available": str(bool(entry.get("legacy_fallback_available", true))).to_lower(),
			"writes_card_data": "false",
			"writes_story_data": "false",
			"writes_battle_state": "false",
			"writes_combat_result": "false",
			"notes": "playable_battle_scene_smoke",
		})

	var fallback_entry: Dictionary = entry_adapter.build_playable_battle_entry_from_node(NON_NODE_ID)
	rows.append({
		"node_id": NON_NODE_ID,
		"battle_slot_id": "sample_non_generated_preview_slot",
		"selected_in_probe": "false",
		"scene_or_controller_loaded": str(controller_loaded).to_lower(),
		"battle_controller_initialized": str(controller_initialized).to_lower(),
		"battle_context_loaded": "false",
		"can_present_battle": "false",
		"source": str(fallback_entry.get("playable_entry_source", "legacy")),
		"enemy_deck_id": str(fallback_entry.get("enemy_deck_id", "")),
		"enemy_deck_loaded": "false",
		"card_pool_count": str(int(fallback_entry.get("card_pool_count", 0))),
		"generated_card_pool_available": str(bool(fallback_entry.get("generated_card_pool_available", false))).to_lower(),
		"reward_plan_id": str(fallback_entry.get("reward_plan_id", "")),
		"reward_source": str(fallback_entry.get("reward_source", "legacy")),
		"narrative_key_count": str(int(fallback_entry.get("narrative_key_count", 0))),
		"route_gate_count": str(int(fallback_entry.get("route_gate_count", 0))),
		"fallback_policy": str(fallback_entry.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(fallback_entry.get("legacy_fallback_available", true))).to_lower(),
		"writes_card_data": "false",
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_generated_node_legacy",
	})

	_write_tsv(rows)
	print("GENERATED_PLAYABLE_BATTLE_SCENE_PROBE_DONE")
	quit()


func _load_reward_fallback_map() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(CFG_PATH):
		return out
	var f := FileAccess.open(CFG_PATH, FileAccess.READ)
	if f == null:
		return out
	var lines := f.get_as_text().split("\n")
	if lines.size() <= 1:
		return out
	var header: PackedStringArray = lines[0].strip_edges().split("\t")
	var slot_idx := -1
	var fallback_idx := -1
	for i in range(header.size()):
		if header[i] == "battle_slot_id":
			slot_idx = i
		if header[i] == "reward_fallback_required":
			fallback_idx = i
	if slot_idx < 0 or fallback_idx < 0:
		return out
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line == "":
			continue
		var cols: PackedStringArray = line.split("\t")
		if slot_idx >= cols.size() or fallback_idx >= cols.size():
			continue
		out[cols[slot_idx]] = cols[fallback_idx].to_lower() == "true"
	return out


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("node_id\tbattle_slot_id\tselected_in_probe\tscene_or_controller_loaded\tbattle_controller_initialized\tbattle_context_loaded\tcan_present_battle\tsource\tenemy_deck_id\tenemy_deck_loaded\tcard_pool_count\tgenerated_card_pool_available\treward_plan_id\treward_source\tnarrative_key_count\troute_gate_count\tfallback_policy\tlegacy_fallback_available\twrites_card_data\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("node_id", "")),
			str(row.get("battle_slot_id", "")),
			str(row.get("selected_in_probe", "")),
			str(row.get("scene_or_controller_loaded", "")),
			str(row.get("battle_controller_initialized", "")),
			str(row.get("battle_context_loaded", "")),
			str(row.get("can_present_battle", "")),
			str(row.get("source", "")),
			str(row.get("enemy_deck_id", "")),
			str(row.get("enemy_deck_loaded", "")),
			str(row.get("card_pool_count", "")),
			str(row.get("generated_card_pool_available", "")),
			str(row.get("reward_plan_id", "")),
			str(row.get("reward_source", "")),
			str(row.get("narrative_key_count", "")),
			str(row.get("route_gate_count", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("writes_card_data", "")),
			str(row.get("writes_story_data", "")),
			str(row.get("writes_battle_state", "")),
			str(row.get("writes_combat_result", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
