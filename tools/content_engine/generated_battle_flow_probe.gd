extends SceneTree

const FLOW_ADAPTER := preload("res://scripts/generated_battle_flow_adapter.gd")
const CFG_PATH := "res://data/design/generated_full_battle_slot_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_battle_flow_report.tsv"
const NON_SLOT := "sample_non_generated_preview_slot"


func _initialize() -> void:
	var adapter = FLOW_ADAPTER.new()
	var rows: Array = []
	var slots := _load_slots()
	var reward_fallback_map := _load_reward_fallback_map()

	for slot in slots:
		var payload: Dictionary = adapter.build_generated_battle_flow_payload(slot)
		var available := not str(payload.get("enemy_deck_id", "")).is_empty()
		var reward_source := str(payload.get("reward_source", "legacy"))
		var reward_plan_id := str(payload.get("reward_plan_id", ""))
		var reward_fallback_required := bool(reward_fallback_map.get(slot, false))
		if reward_fallback_required and reward_source == "content_engine":
			reward_source = "legacy"
			reward_plan_id = ""
		rows.append({
			"battle_slot_id": slot,
			"is_generated_preview_slot": "true",
			"battle_flow_payload_available": str(available).to_lower(),
			"battle_slot_source": str(payload.get("battle_slot_source", "legacy")),
			"enemy_deck_id": str(payload.get("enemy_deck_id", "")),
			"enemy_deck_source": str(payload.get("enemy_deck_source", "legacy")),
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
			"notes": "flow_source=%s" % str(payload.get("flow_source", "legacy")),
		})

	var non_payload: Dictionary = adapter.build_generated_battle_flow_payload(NON_SLOT)
	rows.append({
		"battle_slot_id": NON_SLOT,
		"is_generated_preview_slot": "false",
		"battle_flow_payload_available": str(not str(non_payload.get("enemy_deck_id", "")).is_empty()).to_lower(),
		"battle_slot_source": str(non_payload.get("battle_slot_source", "legacy")),
		"enemy_deck_id": str(non_payload.get("enemy_deck_id", "")),
		"enemy_deck_source": str(non_payload.get("enemy_deck_source", "legacy")),
		"card_pool_count": str(int(non_payload.get("card_pool_count", 0))),
		"reward_plan_id": str(non_payload.get("reward_plan_id", "")),
		"reward_source": str(non_payload.get("reward_source", "legacy")),
		"operation_node_count": str(int(non_payload.get("operation_node_count", 0))),
		"narrative_key_count": str(int(non_payload.get("narrative_key_count", 0))),
		"route_gate_count": str(int(non_payload.get("route_gate_count", 0))),
		"fallback_policy": str(non_payload.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(non_payload.get("legacy_fallback_available", true))).to_lower(),
		"writes_card_data": "false",
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_generated_preview_slot_legacy",
	})

	_write_tsv(rows)
	print("GENERATED_BATTLE_FLOW_PROBE_DONE")
	quit()


func _load_slots() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(CFG_PATH):
		return out
	var f := FileAccess.open(CFG_PATH, FileAccess.READ)
	if f == null:
		return out
	var lines := f.get_as_text().split("\n")
	if lines.size() <= 1:
		return out
	var header: PackedStringArray = lines[0].strip_edges().split("\t")
	var idx := -1
	for i in range(header.size()):
		if header[i] == "battle_slot_id":
			idx = i
			break
	if idx < 0:
		return out
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line == "":
			continue
		var cols: PackedStringArray = line.split("\t")
		if idx >= cols.size():
			continue
		var slot := cols[idx]
		if slot != "":
			out.append(slot)
	return out


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
	f.store_line("battle_slot_id\tis_generated_preview_slot\tbattle_flow_payload_available\tbattle_slot_source\tenemy_deck_id\tenemy_deck_source\tcard_pool_count\treward_plan_id\treward_source\toperation_node_count\tnarrative_key_count\troute_gate_count\tfallback_policy\tlegacy_fallback_available\twrites_card_data\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("is_generated_preview_slot", "")),
			str(row.get("battle_flow_payload_available", "")),
			str(row.get("battle_slot_source", "")),
			str(row.get("enemy_deck_id", "")),
			str(row.get("enemy_deck_source", "")),
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
