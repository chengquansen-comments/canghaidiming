extends SceneTree

const MAP_ROUTE_ADAPTER := preload("res://scripts/generated_map_route_domain_adapter.gd")
const BATTLE_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const REWARD_ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const OUT_PATH := "res://data/design/generated_map_route_domain_formal_report.tsv"
const SLOT := "prologue_01"
const NON_WHITELIST_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var map_adapter = MAP_ROUTE_ADAPTER.new()
	var battle_adapter = BATTLE_ADAPTER.new()
	var reward_adapter = REWARD_ADAPTER.new()
	var bridge = BRIDGE.new()
	var rows: Array = []

	var bundle: Dictionary = bridge.get_full_content_bundle_for_battle_slot(SLOT)
	var map_candidate: Dictionary = map_adapter.build_generated_map_route_candidate(SLOT)
	var battle_candidate: Dictionary = battle_adapter.build_generated_battle_domain_candidate(SLOT)
	var reward_result: Dictionary = reward_adapter.resolve_reward(SLOT, {}, {
		"battle_slot_id": SLOT,
		"bridge_bundle": bundle,
		"generated_content_enabled": true,
		"formal_path_enabled": true,
		"formal_enable_stage": "v2_3",
	})
	var non_whitelist_map: Dictionary = map_adapter.build_generated_map_route_candidate(NON_WHITELIST_SLOT)

	rows.append(_domain_row(SLOT, "battle_slot", _dict(map_candidate.get("battle_slot", {})), "battle_slot candidate 只读接入。"))
	rows.append(_domain_row(SLOT, "operation_node", _dict(map_candidate.get("operation_node", {})), "operation_node 仅 candidate，不改正式流程。"))
	rows.append(_domain_row(SLOT, "narrative", _dict(map_candidate.get("narrative", {})), "narrative 仅 key/hook，不生成正文。"))
	rows.append(_domain_row(SLOT, "route_gate", _dict(map_candidate.get("route_gate", {})), "route_gate 仅 candidate，不改变正式分流。"))

	var reward_note := "reward_candidate_id=rw_prologue_01 selected_source=%s" % str(reward_result.get("selected_source", "legacy"))
	rows.append({
		"battle_slot_id": SLOT,
		"domain": "reward",
		"generated_content_enabled": "true",
		"candidate_available": "true",
		"candidate_id": "rw_prologue_01",
		"candidate_count": "1",
		"formal_source": str(reward_result.get("selected_source", "legacy")),
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"writes_formal_flow": "false",
		"notes": reward_note,
	})

	var enemy_deck: Dictionary = _dict(battle_candidate.get("enemy_deck", {}))
	rows.append({
		"battle_slot_id": SLOT,
		"domain": "enemy_deck",
		"generated_content_enabled": "true",
		"candidate_available": str(bool(enemy_deck.get("candidate_available", false))).to_lower(),
		"candidate_id": str(enemy_deck.get("deck_id", "")),
		"candidate_count": str(int(enemy_deck.get("card_count", 0))),
		"formal_source": str(enemy_deck.get("formal_source", "legacy")),
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"writes_formal_flow": "false",
		"notes": "enemy_deck candidate 可读，不进入 resolver。",
	})

	var card_pool: Dictionary = _dict(battle_candidate.get("card_pool", {}))
	rows.append({
		"battle_slot_id": SLOT,
		"domain": "card_pool",
		"generated_content_enabled": "true",
		"candidate_available": str(bool(card_pool.get("candidate_available", false))).to_lower(),
		"candidate_id": str(card_pool.get("candidate_id", "")),
		"candidate_count": str(int(card_pool.get("candidate_count", 0))),
		"formal_source": str(card_pool.get("formal_source", "content_engine_candidate")),
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"writes_formal_flow": "false",
		"notes": "card_pool compatibility_checked; unsupported_fields=%s" % ",".join(_to_string_list(_arr(card_pool.get("unsupported_fields", [])))),
	})

	rows.append({
		"battle_slot_id": NON_WHITELIST_SLOT,
		"domain": "battle_slot",
		"generated_content_enabled": "false",
		"candidate_available": str(bool(_dict(non_whitelist_map.get("battle_slot", {})).get("candidate_available", false))).to_lower(),
		"candidate_id": "",
		"candidate_count": "0",
		"formal_source": "legacy",
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"writes_formal_flow": "false",
		"notes": "非白名单仍 legacy。",
	})

	_write_tsv(rows)
	print("GENERATED_MAP_ROUTE_DOMAIN_FORMAL_PROBE_DONE")
	quit()


func _domain_row(battle_slot_id: String, domain: String, data: Dictionary, notes: String) -> Dictionary:
	return {
		"battle_slot_id": battle_slot_id,
		"domain": domain,
		"generated_content_enabled": "true",
		"candidate_available": str(bool(data.get("candidate_available", false))).to_lower(),
		"candidate_id": str(data.get("candidate_id", "")),
		"candidate_count": str(int(data.get("candidate_count", 0))),
		"formal_source": str(data.get("formal_source", "legacy")),
		"fallback_policy": str(data.get("fallback_policy", "legacy")),
		"legacy_fallback_available": "true",
		"writes_formal_flow": str(bool(data.get("writes_formal_flow", false))).to_lower(),
		"notes": notes,
	}


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("battle_slot_id\tdomain\tgenerated_content_enabled\tcandidate_available\tcandidate_id\tcandidate_count\tformal_source\tfallback_policy\tlegacy_fallback_available\twrites_formal_flow\tnotes")
	for row_variant in rows:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("domain", "")),
			str(row.get("generated_content_enabled", "")),
			str(row.get("candidate_available", "")),
			str(row.get("candidate_id", "")),
			str(row.get("candidate_count", "")),
			str(row.get("formal_source", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("writes_formal_flow", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])


func _dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _to_string_list(v: Array) -> Array[String]:
	var out: Array[String] = []
	for item in v:
		out.append(str(item))
	return out
