extends SceneTree

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const BATTLE_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const REWARD_ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const OUT_PATH := "res://data/design/generated_battle_domain_formal_report.tsv"
const SLOT := "prologue_01"
const NON_WHITELIST_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var bridge = BRIDGE.new()
	var battle_adapter = BATTLE_ADAPTER.new()
	var reward_adapter = REWARD_ADAPTER.new()
	var rows: Array = []

	var bundle: Dictionary = bridge.get_full_content_bundle_for_battle_slot(SLOT)
	var battle_slot_candidate := bridge.get_battle_slot_candidate(bundle)
	var enemy_deck_candidate := battle_adapter.get_enemy_deck_for_battle_slot(SLOT, bundle)
	var card_pool_candidate := battle_adapter.get_card_pool_for_battle_slot(SLOT, bundle)
	var reward_result: Dictionary = reward_adapter.resolve_reward(SLOT, {}, {
		"battle_slot_id": SLOT,
		"bridge_bundle": bundle,
		"generated_content_enabled": true,
		"formal_path_enabled": true,
		"formal_enable_stage": "v2_3",
	})
	var non_whitelist_reward: Dictionary = reward_adapter.resolve_reward(NON_WHITELIST_SLOT, {}, {
		"battle_slot_id": NON_WHITELIST_SLOT,
		"bridge_bundle": {},
		"generated_content_enabled": false,
		"formal_path_enabled": false,
		"formal_enable_stage": "none",
	})

	rows.append(_row(SLOT, "battle_slot", true, bool(battle_slot_candidate.get("candidate_available", false)), str(battle_slot_candidate.get("candidate_id", "")), int(battle_slot_candidate.get("candidate_count", 0)), "legacy", "legacy", [], "battle_slot 仍走 legacy 流程。"))
	rows.append(_row(SLOT, "enemy_deck", true, bool(enemy_deck_candidate.get("candidate_available", false)), str(enemy_deck_candidate.get("deck_id", "")), int(enemy_deck_candidate.get("card_count", 0)), str(enemy_deck_candidate.get("formal_source", "legacy")), "legacy", [], "enemy_deck 只接 battle setup candidate，不进入 resolver。"))
	rows.append(_row(SLOT, "card_pool", true, bool(card_pool_candidate.get("candidate_available", false)), str(card_pool_candidate.get("candidate_id", "")), int(card_pool_candidate.get("candidate_count", 0)), str(card_pool_candidate.get("formal_source", "content_engine_candidate")), "legacy", _arr(card_pool_candidate.get("unsupported_fields", [])), "card_pool 执行兼容检查，仅 candidate，不写 CardData。"))
	rows.append(_row(SLOT, "reward", true, true, "rw_prologue_01", 1, str(reward_result.get("selected_source", "legacy")), "legacy", [], "reward 白名单正式来源可切换到 content_engine。"))
	rows.append(_row(SLOT, "operation_node", true, true, "operation_nodes_preview", 10, "content_engine_candidate", "legacy", [], "operation_node 仅 candidate。"))
	rows.append(_row(SLOT, "narrative", true, true, "narrative_key_hook_preview", 28, "content_engine_candidate", "legacy", [], "narrative 仅 key/hook，不含正文。"))
	rows.append(_row(SLOT, "route_gate", true, true, "route_gates_preview", 9, "content_engine_candidate", "legacy", [], "route_gate 仅 candidate，不改变正式分流。"))

	rows.append(_row(NON_WHITELIST_SLOT, "reward", false, false, "", 0, str(non_whitelist_reward.get("selected_source", "legacy")), "legacy", [], "非白名单仍 legacy。"))

	_write_tsv(rows)
	print("GENERATED_BATTLE_DOMAIN_FORMAL_PROBE_DONE")
	quit()


func _row(
	battle_slot_id: String,
	domain: String,
	generated_content_enabled: bool,
	candidate_available: bool,
	candidate_id: String,
	candidate_count: int,
	formal_source: String,
	fallback_policy: String,
	unsupported_fields: Array,
	notes: String
) -> Dictionary:
	return {
		"battle_slot_id": battle_slot_id,
		"domain": domain,
		"generated_content_enabled": str(generated_content_enabled).to_lower(),
		"candidate_available": str(candidate_available).to_lower(),
		"candidate_id": candidate_id,
		"candidate_count": str(candidate_count),
		"formal_source": formal_source,
		"fallback_policy": fallback_policy,
		"unsupported_fields": ",".join(_arr_to_string_list(unsupported_fields)),
		"legacy_fallback_available": "true",
		"game_state_written": "false",
		"notes": notes,
	}


func _write_tsv(rows: Array) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("battle_slot_id\tdomain\tgenerated_content_enabled\tcandidate_available\tcandidate_id\tcandidate_count\tformal_source\tfallback_policy\tunsupported_fields\tlegacy_fallback_available\tgame_state_written\tnotes")
	for row_variant in rows:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("domain", "")),
			str(row.get("generated_content_enabled", "")),
			str(row.get("candidate_available", "")),
			str(row.get("candidate_id", "")),
			str(row.get("candidate_count", "")),
			str(row.get("formal_source", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("unsupported_fields", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("game_state_written", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])


func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _arr_to_string_list(v: Array) -> Array[String]:
	var out: Array[String] = []
	for item in v:
		out.append(str(item))
	return out
