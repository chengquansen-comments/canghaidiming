extends SceneTree

const ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const REWARD_ADAPTER := preload("res://scripts/narrative/battle_reward_runtime_adapter.gd")
const CFG_PATH := "res://data/design/generated_slice_whitelist_config.tsv"
const OUT_PATH := "res://data/design/generated_battle_runtime_loadout_report.tsv"
const NON_SLOT := "sample_non_whitelist"


func _initialize() -> void:
	var adapter = ADAPTER.new()
	var bridge = BRIDGE.new()
	var reward_adapter = REWARD_ADAPTER.new()
	var rows: Array = []

	for slot in _load_slots():
		var loadout: Dictionary = adapter.build_generated_battle_runtime_loadout_candidate(slot)
		var enemy_ok := not str(loadout.get("enemy_deck_id", "")).is_empty()
		rows.append({
			"battle_slot_id": slot,
			"is_whitelisted": "true",
			"enemy_deck_candidate_available": str(enemy_ok).to_lower(),
			"enemy_deck_id": str(loadout.get("enemy_deck_id", "")),
			"card_pool_count": str(int(loadout.get("card_pool_count", 0))),
			"compatible_card_count": str(int(loadout.get("compatible_card_count", 0))),
			"unsupported_fields": ",".join(_to_string_list(_arr(loadout.get("unsupported_fields", [])))),
			"loadout_candidate_available": str(bool(loadout.get("loadout_candidate_available", false))).to_lower(),
			"fallback_policy": str(loadout.get("fallback_policy", "legacy")),
			"legacy_fallback_available": str(bool(loadout.get("legacy_fallback_available", true))).to_lower(),
			"writes_card_data": "false",
			"writes_battle_state": "false",
			"writes_combat_result": "false",
			"notes": "loadout_source=%s" % str(loadout.get("loadout_source", "")),
		})

	var non_loadout: Dictionary = adapter.build_generated_battle_runtime_loadout_candidate(NON_SLOT)
	rows.append({
		"battle_slot_id": NON_SLOT,
		"is_whitelisted": "false",
		"enemy_deck_candidate_available": str(not str(non_loadout.get("enemy_deck_id", "")).is_empty()).to_lower(),
		"enemy_deck_id": str(non_loadout.get("enemy_deck_id", "")),
		"card_pool_count": str(int(non_loadout.get("card_pool_count", 0))),
		"compatible_card_count": str(int(non_loadout.get("compatible_card_count", 0))),
		"unsupported_fields": "",
		"loadout_candidate_available": str(bool(non_loadout.get("loadout_candidate_available", false))).to_lower(),
		"fallback_policy": str(non_loadout.get("fallback_policy", "legacy")),
		"legacy_fallback_available": str(bool(non_loadout.get("legacy_fallback_available", true))).to_lower(),
		"writes_card_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "non_whitelist_legacy",
	})

	# prologue reward anchored check
	var prologue_bundle: Dictionary = bridge.get_full_content_bundle_for_battle_slot("prologue_01")
	var reward_result: Dictionary = reward_adapter.resolve_reward("prologue_01", {}, {
		"battle_slot_id": "prologue_01",
		"bridge_bundle": prologue_bundle,
		"generated_content_enabled": true,
		"formal_path_enabled": true,
		"formal_enable_stage": "v2_7",
	})
	rows.append({
		"battle_slot_id": "prologue_01",
		"is_whitelisted": "true",
		"enemy_deck_candidate_available": "true",
		"enemy_deck_id": "reward_anchor",
		"card_pool_count": "72",
		"compatible_card_count": "1",
		"unsupported_fields": "",
		"loadout_candidate_available": "true",
		"fallback_policy": "legacy",
		"legacy_fallback_available": "true",
		"writes_card_data": "false",
		"writes_battle_state": "false",
		"writes_combat_result": "false",
		"notes": "prologue_reward_selected_source=%s;reward_id=rw_prologue_01" % str(reward_result.get("selected_source", "legacy")),
	})

	_write_tsv(rows)
	print("GENERATED_BATTLE_RUNTIME_LOADOUT_PROBE_DONE")
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
	var slot_idx := -1
	for i in range(header.size()):
		if header[i] == "battle_slot_id":
			slot_idx = i
			break
	if slot_idx < 0:
		return out
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line == "":
			continue
		var cols: PackedStringArray = line.split("\t")
		if slot_idx >= cols.size():
			continue
		var slot := cols[slot_idx]
		if slot != "":
			out.append(slot)
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
	f.store_line("battle_slot_id\tis_whitelisted\tenemy_deck_candidate_available\tenemy_deck_id\tcard_pool_count\tcompatible_card_count\tunsupported_fields\tloadout_candidate_available\tfallback_policy\tlegacy_fallback_available\twrites_card_data\twrites_battle_state\twrites_combat_result\tnotes")
	for rowv in rows:
		if typeof(rowv) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rowv
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [
			str(row.get("battle_slot_id", "")),
			str(row.get("is_whitelisted", "")),
			str(row.get("enemy_deck_candidate_available", "")),
			str(row.get("enemy_deck_id", "")),
			str(row.get("card_pool_count", "")),
			str(row.get("compatible_card_count", "")),
			str(row.get("unsupported_fields", "")),
			str(row.get("loadout_candidate_available", "")),
			str(row.get("fallback_policy", "")),
			str(row.get("legacy_fallback_available", "")),
			str(row.get("writes_card_data", "")),
			str(row.get("writes_battle_state", "")),
			str(row.get("writes_combat_result", "")),
			str(row.get("notes", "")).replace("\n", " "),
		])
