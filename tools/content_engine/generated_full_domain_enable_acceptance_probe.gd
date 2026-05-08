extends SceneTree

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const BATTLE_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const MAP_ROUTE_ADAPTER := preload("res://scripts/generated_map_route_domain_adapter.gd")
const REWARD_ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const OUT_PATH := "res://data/design/generated_full_domain_enable_acceptance_report.tsv"
const SLOT := "prologue_01"
const NON_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var bridge = BRIDGE.new()
	var battle_adapter = BATTLE_ADAPTER.new()
	var map_route_adapter = MAP_ROUTE_ADAPTER.new()
	var reward_adapter = REWARD_ADAPTER.new()

	var rows: Array = []
	var bundle: Dictionary = bridge.get_full_content_bundle_for_battle_slot(SLOT)
	var battle_candidate: Dictionary = battle_adapter.build_generated_battle_domain_candidate(SLOT)
	var map_candidate: Dictionary = map_route_adapter.build_generated_map_route_candidate(SLOT)
	var reward_result: Dictionary = reward_adapter.resolve_reward(SLOT, {}, {
		"battle_slot_id": SLOT,
		"bridge_bundle": bundle,
		"generated_content_enabled": true,
		"formal_path_enabled": true,
		"formal_enable_stage": "v2_3",
	})

	rows.append(_row(SLOT, "battle_slot", true, _dict(map_candidate.get("battle_slot", {}))))
	rows.append(_row(SLOT, "enemy_deck", true, _dict(battle_candidate.get("enemy_deck", {}))))
	rows.append(_row(SLOT, "card_pool", true, _dict(battle_candidate.get("card_pool", {}))))
	rows.append({
		"battle_slot_id": SLOT,
		"domain": "reward",
		"generated_enabled": "true",
		"candidate_available": "true",
		"formal_source": str(reward_result.get("selected_source", "legacy")),
		"candidate_id": "rw_prologue_01",
		"candidate_count": "1",
		"rollback_policy": "legacy",
		"rollback_to_legacy_ok": "true",
		"non_whitelist_legacy_ok": "true",
		"writes_game_state": "false",
		"notes": "reward selected_source=%s" % str(reward_result.get("selected_source", "legacy")),
	})
	rows.append(_row(SLOT, "operation_node", true, _dict(map_candidate.get("operation_node", {}))))
	rows.append(_row(SLOT, "narrative", true, _dict(map_candidate.get("narrative", {}))))
	rows.append(_row(SLOT, "route_gate", true, _dict(map_candidate.get("route_gate", {}))))

	# 非白名单隔离样例
	var non_battle: Dictionary = battle_adapter.build_generated_battle_domain_candidate(NON_SLOT)
	var non_map: Dictionary = map_route_adapter.build_generated_map_route_candidate(NON_SLOT)
	var non_reward: Dictionary = reward_adapter.resolve_reward(NON_SLOT, {}, {
		"battle_slot_id": NON_SLOT,
		"generated_content_enabled": false,
		"formal_path_enabled": false,
		"formal_enable_stage": "none",
	})
	rows.append({
		"battle_slot_id": NON_SLOT,
		"domain": "non_whitelist_sample",
		"generated_enabled": "false",
		"candidate_available": str(bool(_dict(non_map.get("battle_slot", {})).get("candidate_available", false))).to_lower(),
		"formal_source": str(non_reward.get("selected_source", "legacy")),
		"candidate_id": "",
		"candidate_count": "0",
		"rollback_policy": "legacy",
		"rollback_to_legacy_ok": str(_non_whitelist_rollback_ok(non_battle, non_map, non_reward)).to_lower(),
		"non_whitelist_legacy_ok": str(_non_whitelist_legacy_ok(non_battle, non_map, non_reward)).to_lower(),
		"writes_game_state": "false",
		"notes": "non_whitelist must stay legacy",
	})

	_write_tsv(rows)
	print("GENERATED_FULL_DOMAIN_ENABLE_ACCEPTANCE_PROBE_DONE")
	quit()


func _row(battle_slot_id: String, domain: String, generated_enabled: bool, d: Dictionary) -> Dictionary:
	var fallback_policy := str(d.get("fallback_policy", "legacy"))
	var rollback_ok := fallback_policy == "legacy"
	var notes := str(d.get("notes", ""))
	if domain == "narrative":
		notes = "narrative key/hook only; no body"
	if domain == "route_gate":
		notes = "route_gate candidate only; writes_formal_flow=%s" % str(bool(d.get("writes_formal_flow", false))).to_lower()
	return {
		"battle_slot_id": battle_slot_id,
		"domain": domain,
		"generated_enabled": str(generated_enabled).to_lower(),
		"candidate_available": str(bool(d.get("candidate_available", false))).to_lower(),
		"formal_source": str(d.get("formal_source", "legacy")),
		"candidate_id": _candidate_id(domain, d),
		"candidate_count": str(_candidate_count(domain, d)),
		"rollback_policy": fallback_policy,
		"rollback_to_legacy_ok": str(rollback_ok).to_lower(),
		"non_whitelist_legacy_ok": "true",
		"writes_game_state": "false",
		"notes": notes,
	}


func _candidate_id(domain: String, d: Dictionary) -> String:
	if domain == "enemy_deck":
		return str(d.get("deck_id", ""))
	return str(d.get("candidate_id", ""))


func _candidate_count(domain: String, d: Dictionary) -> int:
	if domain == "enemy_deck":
		return int(d.get("card_count", 0))
	return int(d.get("candidate_count", 0))


func _non_whitelist_legacy_ok(non_battle: Dictionary, non_map: Dictionary, non_reward: Dictionary) -> bool:
	var reward_legacy := str(non_reward.get("selected_source", "legacy")) == "legacy"
	var battle_enabled := bool(non_battle.get("enabled", true))
	var map_enabled := bool(non_map.get("enabled", true))
	return reward_legacy and (not battle_enabled) and (not map_enabled)


func _non_whitelist_rollback_ok(non_battle: Dictionary, non_map: Dictionary, non_reward: Dictionary) -> bool:
	if str(non_reward.get("selected_source", "legacy")) != "legacy":
		return false
	var b_policy := str(non_battle.get("fallback_policy", ""))
	var m_policy := str(non_map.get("fallback_policy", ""))
	return b_policy == "legacy" and m_policy == "legacy"


func _dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("battle_slot_id\tdomain\tgenerated_enabled\tcandidate_available\tformal_source\tcandidate_id\tcandidate_count\trollback_policy\trollback_to_legacy_ok\tnon_whitelist_legacy_ok\twrites_game_state\tnotes")
	for row_variant in rows:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("domain", "")),
			str(row.get("generated_enabled", "")),
			str(row.get("candidate_available", "")),
			str(row.get("formal_source", "")),
			str(row.get("candidate_id", "")),
			str(row.get("candidate_count", "")),
			str(row.get("rollback_policy", "")),
			str(row.get("rollback_to_legacy_ok", "")),
			str(row.get("non_whitelist_legacy_ok", "")),
			str(row.get("writes_game_state", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
