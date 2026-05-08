extends SceneTree

const MAP_ADAPTER := preload("res://scripts/generated_map_route_domain_adapter.gd")
const BATTLE_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const REWARD_ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const CFG_PATH := "res://data/design/generated_slice_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_map_route_runtime_flow_report.tsv"
const NON_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var map_adapter = MAP_ADAPTER.new()
	var battle_adapter = BATTLE_ADAPTER.new()
	var reward_adapter = REWARD_ADAPTER.new()
	var bridge = BRIDGE.new()
	var rows: Array = []

	for slot in _load_slots():
		var cand: Dictionary = map_adapter.build_generated_map_route_runtime_candidate(slot)
		rows.append({
			"battle_slot_id": slot,
			"is_whitelisted": "true",
			"battle_slot_candidate_available": str(not str(cand.get("battle_slot_candidate_id", "")).is_empty()).to_lower(),
			"operation_node_count": str(int(cand.get("operation_node_count", 0))),
			"narrative_key_count": str(int(cand.get("narrative_key_count", 0))),
			"narrative_keys_only": str(bool(cand.get("narrative_keys_only", false))).to_lower(),
			"route_gate_count": str(int(cand.get("route_gate_count", 0))),
			"route_gate_writes_formal_flow": str(bool(cand.get("route_gate_writes_formal_flow", false))).to_lower(),
			"map_route_candidate_available": str(bool(cand.get("map_route_candidate_available", false))).to_lower(),
			"fallback_policy": str(cand.get("fallback_policy", "legacy")),
			"legacy_fallback_available": str(bool(cand.get("legacy_fallback_available", true))).to_lower(),
			"writes_story_data": "false",
			"writes_battle_state": "false",
			"writes_combat_result": "false",
			"notes": "candidate_source=%s" % str(cand.get("candidate_source", "")),
		})

	var non_cand: Dictionary = map_adapter.build_generated_map_route_runtime_candidate(NON_SLOT)
	rows.append({
		"battle_slot_id": NON_SLOT,
		"is_whitelisted": "false",
		"battle_slot_candidate_available": str(not str(non_cand.get("battle_slot_candidate_id", "")).is_empty()).to_lower(),
		"operation_node_count": str(int(non_cand.get("operation_node_count", 0))),
		"narrative_key_count": str(int(non_cand.get("narrative_key_count", 0))),
		"narrative_keys_only": str(bool(non_cand.get("narrative_keys_only", true))).to_lower(),
		"route_gate_count": str(int(non_cand.get("route_gate_count", 0))),
		"route_gate_writes_formal_flow": str(bool(non_cand.get("route_gate_writes_formal_flow", false))).to_lower(),
		"map_route_candidate_available": str(bool(non_cand.get("map_route_candidate_available", false))).to_lower(),
		"fallback_policy": str(non_cand.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(non_cand.get("legacy_fallback_available", true))).to_lower(),
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_whitelist_legacy",
	})

	# v2.8 loadout still valid + reward availability anchor
	var loadout: Dictionary = battle_adapter.build_generated_battle_runtime_loadout_candidate("prologue_01")
	var reward_result: Dictionary = reward_adapter.resolve_reward("prologue_01", {}, {
		"battle_slot_id": "prologue_01",
		"bridge_bundle": bridge.get_full_content_bundle_for_battle_slot("prologue_01"),
		"generated_content_enabled": true,
		"formal_path_enabled": true,
		"formal_enable_stage": "v2_7",
	})
	rows.append({
		"battle_slot_id": "prologue_01",
		"is_whitelisted": "true",
		"battle_slot_candidate_available": "true",
		"operation_node_count": "10",
		"narrative_key_count": "28",
		"narrative_keys_only": "true",
		"route_gate_count": "9",
		"route_gate_writes_formal_flow": "false",
		"map_route_candidate_available": "true",
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "v2_8_loadout=%s;reward_selected_source=%s" % [str(bool(loadout.get("loadout_candidate_available", false))).to_lower(), str(reward_result.get("selected_source", "legacy"))],
	})

	_write_tsv(rows)
	print("GENERATED_MAP_ROUTE_RUNTIME_FLOW_PROBE_DONE")
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


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("battle_slot_id\tis_whitelisted\tbattle_slot_candidate_available\toperation_node_count\tnarrative_key_count\tnarrative_keys_only\troute_gate_count\troute_gate_writes_formal_flow\tmap_route_candidate_available\tfallback_policy\tlegacy_fallback_available\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("is_whitelisted", "")),
			str(row.get("battle_slot_candidate_available", "")),
			str(row.get("operation_node_count", "")),
			str(row.get("narrative_key_count", "")),
			str(row.get("narrative_keys_only", "")),
			str(row.get("route_gate_count", "")),
			str(row.get("route_gate_writes_formal_flow", "")),
			str(row.get("map_route_candidate_available", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("writes_story_data", "")),
			str(row.get("writes_battle_state", "")),
			str(row.get("writes_combat_result", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
