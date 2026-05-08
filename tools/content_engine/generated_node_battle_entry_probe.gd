extends SceneTree

const ENTRY_ADAPTER := preload("res://scripts/generated_node_battle_entry_adapter.gd")
const NODE_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const CFG_PATH := "res://data/design/generated_full_battle_slot_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_node_battle_entry_report.tsv"
const NON_NODE_ID := "generated_node_sample_non_generated_preview_slot"


func _initialize() -> void:
	var entry_adapter = ENTRY_ADAPTER.new()
	var node_adapter = NODE_ADAPTER.new()
	var rows: Array = []
	var pool: Array[Dictionary] = node_adapter.build_player_visible_generated_node_pool()
	var selected_any := false
	var reward_fallback_map := _load_reward_fallback_map()

	for node in pool:
		var node_id := str(node.get("node_id", ""))
		var slot := str(node.get("battle_slot_id", ""))
		var selected_in_probe := false
		if not selected_any:
			selected_in_probe = true
			selected_any = true
		var entry: Dictionary = entry_adapter.build_battle_entry_from_generated_node(node_id)
		var reward_plan_id := str(entry.get("reward_plan_id", ""))
		var reward_source := str(entry.get("reward_source", "legacy"))
		if bool(reward_fallback_map.get(slot, false)):
			reward_plan_id = ""
			reward_source = "legacy"
		rows.append({
			"node_id": node_id,
			"battle_slot_id": slot,
			"selected_in_probe": str(selected_in_probe).to_lower(),
			"battle_entry_available": str(str(entry.get("entry_source", "legacy")) != "legacy").to_lower(),
			"can_enter_battle": str(bool(entry.get("can_enter_battle", false))).to_lower(),
			"entry_source": str(entry.get("entry_source", "legacy")),
			"enemy_deck_id": str(entry.get("enemy_deck_id", "")),
			"enemy_deck_source": str(entry.get("enemy_deck_source", "legacy")),
			"card_pool_count": str(int(entry.get("card_pool_count", 0))),
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
			"notes": "entry_from_generated_node",
		})

	var non_entry: Dictionary = entry_adapter.build_battle_entry_from_generated_node(NON_NODE_ID)
	rows.append({
		"node_id": NON_NODE_ID,
		"battle_slot_id": "sample_non_generated_preview_slot",
		"selected_in_probe": "false",
		"battle_entry_available": str(str(non_entry.get("entry_source", "legacy")) != "legacy").to_lower(),
		"can_enter_battle": str(bool(non_entry.get("can_enter_battle", false))).to_lower(),
		"entry_source": str(non_entry.get("entry_source", "legacy")),
		"enemy_deck_id": str(non_entry.get("enemy_deck_id", "")),
		"enemy_deck_source": str(non_entry.get("enemy_deck_source", "legacy")),
		"card_pool_count": str(int(non_entry.get("card_pool_count", 0))),
		"reward_plan_id": str(non_entry.get("reward_plan_id", "")),
		"reward_source": str(non_entry.get("reward_source", "legacy")),
		"narrative_key_count": str(int(non_entry.get("narrative_key_count", 0))),
		"route_gate_count": str(int(non_entry.get("route_gate_count", 0))),
		"fallback_policy": str(non_entry.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(non_entry.get("legacy_fallback_available", true))).to_lower(),
		"writes_card_data": "false",
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_generated_node_legacy",
	})

	_write_tsv(rows)
	print("GENERATED_NODE_BATTLE_ENTRY_PROBE_DONE")
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
	f.store_line("node_id\tbattle_slot_id\tselected_in_probe\tbattle_entry_available\tcan_enter_battle\tentry_source\tenemy_deck_id\tenemy_deck_source\tcard_pool_count\treward_plan_id\treward_source\tnarrative_key_count\troute_gate_count\tfallback_policy\tlegacy_fallback_available\twrites_card_data\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("node_id", "")),
			str(row.get("battle_slot_id", "")),
			str(row.get("selected_in_probe", "")),
			str(row.get("battle_entry_available", "")),
			str(row.get("can_enter_battle", "")),
			str(row.get("entry_source", "")),
			str(row.get("enemy_deck_id", "")),
			str(row.get("enemy_deck_source", "")),
			str(row.get("card_pool_count", "")),
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
