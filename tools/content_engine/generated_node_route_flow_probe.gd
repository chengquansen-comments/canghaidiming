extends SceneTree

const ADAPTER := preload("res://scripts/generated_node_route_flow_adapter.gd")
const CFG_PATH := "res://data/design/generated_full_battle_slot_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_node_route_flow_report.tsv"
const NON_SLOT := "sample_non_generated_preview_slot"


func _initialize() -> void:
	var adapter = ADAPTER.new()
	var rows: Array = []
	var slots := _load_slots()
	var reward_fallback_map := _load_reward_fallback_map()

	for slot in slots:
		var candidate: Dictionary = adapter.build_generated_node_candidate(slot)
		var fallback_required := bool(reward_fallback_map.get(slot, false))
		var reward_plan_id := str(candidate.get("reward_plan_id", ""))
		var reward_source := str(candidate.get("reward_source", "legacy"))
		if fallback_required:
			reward_plan_id = ""
			reward_source = "legacy"
		rows.append({
			"battle_slot_id": slot,
			"is_generated_preview_slot": "true",
			"node_candidate_available": str(str(candidate.get("node_source", "legacy")) != "legacy").to_lower(),
			"battle_flow_payload_available": str(bool(candidate.get("battle_flow_payload_available", false))).to_lower(),
			"enemy_deck_id": str(candidate.get("enemy_deck_id", "")),
			"card_pool_count": str(int(candidate.get("card_pool_count", 0))),
			"reward_plan_id": reward_plan_id,
			"reward_source": reward_source,
			"operation_node_count": str(int(candidate.get("operation_node_count", 0))),
			"narrative_key_count": str(int(candidate.get("narrative_key_count", 0))),
			"narrative_keys_only": str(bool(candidate.get("narrative_keys_only", true))).to_lower(),
			"route_gate_count": str(int(candidate.get("route_gate_count", 0))),
			"route_gate_writes_formal_flow": str(bool(candidate.get("route_gate_writes_formal_flow", false))).to_lower(),
			"fallback_policy": str(candidate.get("fallback_policy", "legacy")),
			"legacy_fallback_available": str(bool(candidate.get("legacy_fallback_available", true))).to_lower(),
			"writes_story_data": "false",
			"writes_battle_state": "false",
			"writes_combat_result": "false",
			"notes": "node_source=%s" % str(candidate.get("node_source", "legacy")),
		})

	var non_candidate: Dictionary = adapter.build_generated_node_candidate(NON_SLOT)
	rows.append({
		"battle_slot_id": NON_SLOT,
		"is_generated_preview_slot": "false",
		"node_candidate_available": str(str(non_candidate.get("node_source", "legacy")) != "legacy").to_lower(),
		"battle_flow_payload_available": str(bool(non_candidate.get("battle_flow_payload_available", false))).to_lower(),
		"enemy_deck_id": str(non_candidate.get("enemy_deck_id", "")),
		"card_pool_count": str(int(non_candidate.get("card_pool_count", 0))),
		"reward_plan_id": str(non_candidate.get("reward_plan_id", "")),
		"reward_source": str(non_candidate.get("reward_source", "legacy")),
		"operation_node_count": str(int(non_candidate.get("operation_node_count", 0))),
		"narrative_key_count": str(int(non_candidate.get("narrative_key_count", 0))),
		"narrative_keys_only": str(bool(non_candidate.get("narrative_keys_only", true))).to_lower(),
		"route_gate_count": str(int(non_candidate.get("route_gate_count", 0))),
		"route_gate_writes_formal_flow": str(bool(non_candidate.get("route_gate_writes_formal_flow", false))).to_lower(),
		"fallback_policy": str(non_candidate.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(non_candidate.get("legacy_fallback_available", true))).to_lower(),
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_generated_preview_slot_legacy",
	})

	_write_tsv(rows)
	print("GENERATED_NODE_ROUTE_FLOW_PROBE_DONE")
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
		if idx < cols.size() and cols[idx] != "":
			out.append(cols[idx])
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
	f.store_line("battle_slot_id\tis_generated_preview_slot\tnode_candidate_available\tbattle_flow_payload_available\tenemy_deck_id\tcard_pool_count\treward_plan_id\treward_source\toperation_node_count\tnarrative_key_count\tnarrative_keys_only\troute_gate_count\troute_gate_writes_formal_flow\tfallback_policy\tlegacy_fallback_available\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("is_generated_preview_slot", "")),
			str(row.get("node_candidate_available", "")),
			str(row.get("battle_flow_payload_available", "")),
			str(row.get("enemy_deck_id", "")),
			str(row.get("card_pool_count", "")),
			str(row.get("reward_plan_id", "")),
			str(row.get("reward_source", "")),
			str(row.get("operation_node_count", "")),
			str(row.get("narrative_key_count", "")),
			str(row.get("narrative_keys_only", "")),
			str(row.get("route_gate_count", "")),
			str(row.get("route_gate_writes_formal_flow", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("writes_story_data", "")),
			str(row.get("writes_battle_state", "")),
			str(row.get("writes_combat_result", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
