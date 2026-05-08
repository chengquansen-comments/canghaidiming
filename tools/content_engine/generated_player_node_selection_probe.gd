extends SceneTree

const ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const CFG_PATH := "res://data/design/generated_full_battle_slot_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_player_node_selection_report.tsv"
const NON_SLOT := "sample_non_generated_preview_slot"


func _initialize() -> void:
	var adapter = ADAPTER.new()
	var pool: Array[Dictionary] = adapter.build_player_visible_generated_node_pool()
	var rows: Array = []
	var selected_any := false
	var reward_fallback_map := _load_reward_fallback_map()

	for node in pool:
		var node_id := str(node.get("node_id", ""))
		var slot := str(node.get("battle_slot_id", ""))
		var selected_in_probe := false
		if not selected_any:
			selected_in_probe = true
			selected_any = true
		var payload := adapter.get_battle_flow_payload_for_node(node_id)
		var reward_plan_id := str(node.get("reward_plan_id", ""))
		var reward_source := str(node.get("reward_source", "legacy"))
		if bool(reward_fallback_map.get(slot, false)):
			reward_plan_id = ""
			reward_source = "legacy"
		rows.append({
			"node_id": node_id,
			"battle_slot_id": slot,
			"player_visible": str(bool(node.get("player_visible", false))).to_lower(),
			"selectable": str(bool(node.get("selectable", false))).to_lower(),
			"selected_in_probe": str(selected_in_probe).to_lower(),
			"battle_flow_payload_available": str(str(payload.get("battle_slot_source", "legacy")) != "legacy").to_lower(),
			"enemy_deck_id": str(payload.get("enemy_deck_id", "")),
			"card_pool_count": str(int(payload.get("card_pool_count", 0))),
			"reward_plan_id": reward_plan_id,
			"reward_source": reward_source,
			"operation_node_count": str(int(payload.get("operation_node_count", 0))),
			"narrative_key_count": str(int(payload.get("narrative_key_count", 0))),
			"route_gate_count": str(int(payload.get("route_gate_count", 0))),
			"fallback_policy": str(payload.get("fallback_policy", "legacy")),
			"legacy_fallback_available": str(bool(payload.get("legacy_fallback_available", true))).to_lower(),
			"writes_card_data": "false",
			"writes_story_data": "false",
			"writes_battle_state": "false",
			"writes_combat_result": "false",
			"notes": "node_source=%s;payload_source=%s;narrative_key_count=%d;route_gate_count=%d" % [
				str(node.get("node_source", "legacy")),
				str(payload.get("flow_source", "legacy")),
				int(payload.get("narrative_key_count", 0)),
				int(payload.get("route_gate_count", 0)),
			],
		})

	# 非 generated slot 校验（不入池，保持 legacy）
	var fallback = adapter.get_battle_flow_payload_for_node("generated_node_%s" % NON_SLOT)
	rows.append({
		"node_id": "generated_node_%s" % NON_SLOT,
		"battle_slot_id": NON_SLOT,
		"player_visible": "false",
		"selectable": "false",
		"selected_in_probe": "false",
		"battle_flow_payload_available": str(str(fallback.get("battle_slot_source", "legacy")) != "legacy").to_lower(),
		"enemy_deck_id": str(fallback.get("enemy_deck_id", "")),
		"card_pool_count": str(int(fallback.get("card_pool_count", 0))),
		"reward_plan_id": str(fallback.get("reward_plan_id", "")),
		"reward_source": str(fallback.get("reward_source", "legacy")),
		"operation_node_count": str(int(fallback.get("operation_node_count", 0))),
		"narrative_key_count": str(int(fallback.get("narrative_key_count", 0))),
		"route_gate_count": str(int(fallback.get("route_gate_count", 0))),
		"fallback_policy": str(fallback.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(fallback.get("legacy_fallback_available", true))).to_lower(),
		"writes_card_data": "false",
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_generated_preview_slot_legacy",
	})

	_write_tsv(rows)
	print("GENERATED_PLAYER_NODE_SELECTION_PROBE_DONE")
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
	f.store_line("node_id\tbattle_slot_id\tplayer_visible\tselectable\tselected_in_probe\tbattle_flow_payload_available\tenemy_deck_id\tcard_pool_count\treward_plan_id\treward_source\toperation_node_count\tnarrative_key_count\troute_gate_count\tfallback_policy\tlegacy_fallback_available\twrites_card_data\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("node_id", "")),
			str(row.get("battle_slot_id", "")),
			str(row.get("player_visible", "")),
			str(row.get("selectable", "")),
			str(row.get("selected_in_probe", "")),
			str(row.get("battle_flow_payload_available", "")),
			str(row.get("enemy_deck_id", "")),
			str(row.get("card_pool_count", "")),
			str(row.get("reward_plan_id", "")),
			str(row.get("reward_source", "")),
			str(row.get("operation_node_count", "")),
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
