extends SceneTree

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const OUT_PATH := "res://data/design/generated_content_formal_enable_report.tsv"
const SLOT := "prologue_01"
const NON_WHITELIST_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var bridge = BRIDGE.new()
	var adapter = ADAPTER.new()
	var rows: Array = []

	var bundle: Dictionary = bridge.get_full_content_bundle_for_battle_slot(SLOT)
	var domains: Dictionary = bundle.get("domains", {}) if typeof(bundle.get("domains", {})) == TYPE_DICTIONARY else {}

	var reward_result: Dictionary = adapter.resolve_reward(SLOT, {}, {
		"battle_slot_id": SLOT,
		"bridge_bundle": bundle,
		"generated_content_enabled": true,
		"formal_path_enabled": true,
		"formal_enable_stage": "v2_3",
	})
	var non_whitelist_result: Dictionary = adapter.resolve_reward(NON_WHITELIST_SLOT, {}, {
		"battle_slot_id": NON_WHITELIST_SLOT,
		"bridge_bundle": {},
		"generated_content_enabled": false,
		"formal_path_enabled": false,
		"formal_enable_stage": "none",
	})

	rows.append(_domain_row(SLOT, "battle_slot", _domain(domains, "battle_slot"), true, "legacy", "battle_slot candidate 可读，仅白名单。"))
	rows.append(_domain_row(SLOT, "enemy_deck", _domain(domains, "enemy_deck"), true, "legacy", "enemy_deck 仅 candidate，不进入 resolver。"))
	rows.append(_domain_row(SLOT, "card_pool", _domain(domains, "card_pool"), true, "legacy", "card_pool 仅 candidate，不写 CardData。"))
	rows.append(_domain_row(SLOT, "reward", _domain(domains, "reward"), true, str(reward_result.get("selected_source", "legacy")), "reward 白名单正式来源切换验证。"))
	rows.append(_domain_row(SLOT, "operation_node", _domain(domains, "operation_node"), true, "legacy", "operation_node 仅 candidate。"))
	rows.append(_domain_row(SLOT, "narrative", _domain(domains, "narrative"), true, "legacy", "narrative 仅 key/hook，不生成正文。"))
	rows.append(_domain_row(SLOT, "route_gate", _domain(domains, "route_gate"), true, "legacy", "route_gate 仅 candidate，不改变正式分流。"))

	rows.append({
		"battle_slot_id": NON_WHITELIST_SLOT,
		"domain": "reward",
		"generated_content_enabled": "false",
		"candidate_available": "false",
		"candidate_id": "",
		"formal_use_allowed": "false",
		"formal_selected_source": str(non_whitelist_result.get("selected_source", "legacy")),
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"game_state_written": "false",
		"notes": "非白名单样例必须 legacy。",
	})

	_write_tsv(rows)
	print("GENERATED_CONTENT_FORMAL_ENABLE_PROBE_DONE")
	quit()


func _domain(domains: Dictionary, name: String) -> Dictionary:
	var v: Variant = domains.get(name, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _domain_row(battle_slot_id: String, domain: String, candidate: Dictionary, formal_use_allowed: bool, selected_source: String, notes: String) -> Dictionary:
	return {
		"battle_slot_id": battle_slot_id,
		"domain": domain,
		"generated_content_enabled": "true",
		"candidate_available": str(bool(candidate.get("candidate_available", false))).to_lower(),
		"candidate_id": str(candidate.get("candidate_id", "")),
		"formal_use_allowed": "true" if formal_use_allowed else "false",
		"formal_selected_source": selected_source,
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"game_state_written": "false",
		"notes": notes,
	}


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("battle_slot_id\tdomain\tgenerated_content_enabled\tcandidate_available\tcandidate_id\tformal_use_allowed\tformal_selected_source\tfallback_policy\tlegacy_fallback_available\tgame_state_written\tnotes")
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
			str(row.get("formal_use_allowed", "")),
			str(row.get("formal_selected_source", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("game_state_written", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
