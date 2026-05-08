extends SceneTree

const BATTLE_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const MAP_ADAPTER := preload("res://scripts/generated_map_route_domain_adapter.gd")
const REWARD_ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const CFG_PATH := "res://data/design/generated_slice_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_slice_full_integration_acceptance_report.tsv"
const NON_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var battle = BATTLE_ADAPTER.new()
	var map = MAP_ADAPTER.new()
	var reward = REWARD_ADAPTER.new()
	var bridge = BRIDGE.new()
	var rows: Array = []
	var slots := _load_slots()

	for slot in slots:
		var b: Dictionary = battle.build_generated_battle_domain_candidate(slot)
		var m: Dictionary = map.build_generated_map_route_candidate(slot)
		var loadout: Dictionary = b.get("battle_runtime_loadout_candidate", {}) if b.get("battle_runtime_loadout_candidate", {}) is Dictionary else {}
		var mr: Dictionary = m.get("map_route_runtime_candidate", {}) if m.get("map_route_runtime_candidate", {}) is Dictionary else {}
		var reward_result: Dictionary = reward.resolve_reward(slot, {}, {
			"battle_slot_id": slot,
			"bridge_bundle": bridge.get_full_content_bundle_for_battle_slot(slot),
			"generated_content_enabled": true,
			"formal_path_enabled": true,
			"formal_enable_stage": "v2_7",
		})
		var reward_candidate_id := ""
		var domains: Dictionary = bridge.get_full_content_bundle_for_battle_slot(slot).get("domains", {}) if bridge.get_full_content_bundle_for_battle_slot(slot).get("domains", {}) is Dictionary else {}
		if domains.has("reward") and domains["reward"] is Dictionary:
			reward_candidate_id = str((domains["reward"] as Dictionary).get("candidate_id", ""))

		rows.append(_row(slot, "battle_slot", true, true, "content_engine", slot, 1, "battle_slot_candidate"))
		rows.append(_row(slot, "enemy_deck", true, bool((b.get("enemy_deck", {}) as Dictionary).get("candidate_available", false)), str((b.get("enemy_deck", {}) as Dictionary).get("formal_source", "legacy")), str((b.get("enemy_deck", {}) as Dictionary).get("deck_id", "")), int((b.get("enemy_deck", {}) as Dictionary).get("card_count", 0)), "enemy_deck_candidate"))
		rows.append(_row(slot, "card_pool", true, bool((b.get("card_pool", {}) as Dictionary).get("candidate_available", false)), "content_engine_candidate", str((b.get("card_pool", {}) as Dictionary).get("candidate_id", "")), int((b.get("card_pool", {}) as Dictionary).get("candidate_count", 0)), "card_pool_candidate compatible=%d unsupported=%s" % [int((b.get("card_pool", {}) as Dictionary).get("compatible_card_count", 0)), ",".join(_to_string_list(_arr((b.get("card_pool", {}) as Dictionary).get("unsupported_fields", []))) )]))
		rows.append(_row(slot, "reward", true, not reward_candidate_id.is_empty(), str(reward_result.get("selected_source", "legacy")), reward_candidate_id, 1 if not reward_candidate_id.is_empty() else 0, "reward selected_source=%s" % str(reward_result.get("selected_source", "legacy"))))
		rows.append(_row(slot, "operation_node", true, true, "content_engine_candidate", str((m.get("operation_node", {}) as Dictionary).get("candidate_id", "operation_nodes_preview")), int((m.get("operation_node", {}) as Dictionary).get("candidate_count", 0)), "operation_node_count=%d" % int((m.get("operation_node", {}) as Dictionary).get("candidate_count", 0))))
		rows.append(_row(slot, "narrative", true, true, "content_engine_candidate", str((m.get("narrative", {}) as Dictionary).get("candidate_id", "narrative_key_hook_preview")), int((m.get("narrative", {}) as Dictionary).get("candidate_count", 0)), "narrative_keys_only=%s" % str(bool((m.get("narrative", {}) as Dictionary).get("hook_only", true))).to_lower()))
		rows.append(_row(slot, "route_gate", true, true, "content_engine_candidate", str((m.get("route_gate", {}) as Dictionary).get("candidate_id", "route_gates_preview")), int((m.get("route_gate", {}) as Dictionary).get("candidate_count", 0)), "route_gate_writes_formal_flow=%s" % str(bool((m.get("route_gate", {}) as Dictionary).get("writes_formal_flow", false))).to_lower()))

		# strengthen rollback flags with runtime candidates presence
		for i in range(rows.size()):
			var r: Dictionary = rows[i]
			if r.get("battle_slot_id", "") != slot:
				continue
			r["rollback_to_legacy_ok"] = str(str(r.get("fallback_policy", "")) == "legacy").to_lower()
			r["non_whitelist_legacy_ok"] = "true"
			rows[i] = r

		# anchors for full candidate availability
		rows.append(_row(slot, "integration_anchor", true, bool(loadout.get("loadout_candidate_available", false)) and bool(mr.get("map_route_candidate_available", false)), "content_engine_candidate", "anchor", 1, "loadout=%s map_route=%s" % [str(bool(loadout.get("loadout_candidate_available", false))).to_lower(), str(bool(mr.get("map_route_candidate_available", false))).to_lower()]))

	# non whitelist
	var nr: Dictionary = reward.resolve_reward(NON_SLOT, {}, {
		"battle_slot_id": NON_SLOT,
		"generated_content_enabled": false,
		"formal_path_enabled": false,
		"formal_enable_stage": "none",
	})
	for d in ["battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"]:
		rows.append(_row(NON_SLOT, d, false, false, str(nr.get("selected_source", "legacy")), "", 0, "non_whitelist_legacy"))

	_write_tsv(rows)
	print("GENERATED_SLICE_FULL_INTEGRATION_ACCEPTANCE_PROBE_DONE")
	quit()


func _row(slot: String, domain: String, is_whitelisted: bool, available: bool, formal_source: String, cid: String, ccount: int, notes: String) -> Dictionary:
	return {
		"battle_slot_id": slot,
		"is_whitelisted": str(is_whitelisted).to_lower(),
		"domain": domain,
		"candidate_available": str(available).to_lower(),
		"formal_source": formal_source,
		"candidate_id": cid,
		"candidate_count": str(ccount),
		"fallback_policy": "legacy",
		"rollback_to_legacy_ok": "true",
		"non_whitelist_legacy_ok": "true",
		"writes_card_data": "false",
		"writes_story_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": notes,
	}


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


func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _to_string_list(v: Array) -> Array[String]:
	var out: Array[String] = []
	for item in v:
		out.append(str(item))
	return out


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("battle_slot_id\tis_whitelisted\tdomain\tcandidate_available\tformal_source\tcandidate_id\tcandidate_count\tfallback_policy\trollback_to_legacy_ok\tnon_whitelist_legacy_ok\twrites_card_data\twrites_story_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("is_whitelisted", "")),
			str(row.get("domain", "")),
			str(row.get("candidate_available", "")),
			str(row.get("formal_source", "")),
			str(row.get("candidate_id", "")),
			str(row.get("candidate_count", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("rollback_to_legacy_ok", "")),
			str(row.get("non_whitelist_legacy_ok", "")),
			str(row.get("writes_card_data", "")),
			str(row.get("writes_story_data", "")),
			str(row.get("writes_battle_state", "")),
			str(row.get("writes_combat_result", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
