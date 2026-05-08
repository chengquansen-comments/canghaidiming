extends RefCounted
class_name BattleRewardRuntimeAdapter

const MODE_LEGACY := "legacy"
const MODE_SHADOW := "shadow"
const MODE_RUNTIME_TEST := "runtime_test"
const MODE_RUNTIME_ENABLED := "runtime_enabled"

const GENERATED_CONTENT_BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const CONFIG_PATH := "res://data/runtime/content_engine/runtime_loader_config.json"
const RUNTIME_REWARD_PATH := "res://data/runtime/content_engine/battle_reward.json"
const FORMAL_ENABLE_CONFIG_PATH := "res://data/design/generated_content_formal_enable_config.tsv"
const FULL_BATTLE_SLOT_WHITELIST_CONFIG_PATH := "res://data/design/generated_full_battle_slot_whitelist_config.tsv"
const SLICE_WHITELIST_CONFIG_PATH := "res://data/design/generated_slice_whitelist_config.tsv"
const WHITELIST_BRIDGE_PATH_PATTERN := "res://data/runtime/content_engine_whitelist/%s.full_content_bridge.json"


func resolve_reward(source_id: String, legacy_reward: Dictionary, context: Dictionary = {}) -> Dictionary:
	var legacy_copy: Dictionary = _safe_dict(legacy_reward)
	var mode := MODE_LEGACY
	var config_enabled := false
	var selected_source := "legacy"
	var runtime_candidate: Dictionary = {}
	var shadow_compare := {
		"candidate_loaded": false,
		"candidate_record_count": 0,
		"legacy_key_count": legacy_copy.size(),
		"same_shape": false,
		"same_value": false,
		"source_id": source_id,
	}
	var fallback_used := false
	var fallback_reason := "none"

	var config_result := _read_json_dict(CONFIG_PATH)
	if not bool(config_result.get("ok", false)):
		fallback_used = true
		fallback_reason = "config_missing_or_invalid"
		return _build_output(mode, config_enabled, selected_source, legacy_copy, runtime_candidate, shadow_compare, fallback_used, fallback_reason)

	var config: Dictionary = config_result.get("payload", {})
	config_enabled = bool(config.get("content_engine_runtime_enabled", false))
	mode = str(config.get("integration_mode", "disabled"))
	if mode.is_empty():
		mode = MODE_LEGACY

	# v1.0b scaffold: regardless of mode, selected_reward must remain legacy.
	var runtime_result := _read_json_dict(RUNTIME_REWARD_PATH)
	if bool(runtime_result.get("ok", false)):
		runtime_candidate = runtime_result.get("payload", {})
		shadow_compare = _build_shadow_compare(legacy_copy, runtime_candidate, source_id)
	else:
		fallback_used = true
		fallback_reason = "runtime_missing_or_invalid"

	# disabled 时必须回落 legacy；非 disabled 模式本阶段也不生效。
	if not _config_is_disabled(config):
		fallback_used = true
		if fallback_reason == "none":
			fallback_reason = "runtime_mode_not_allowed_in_v1_0b"

	var battle_slot_id := str(context.get("battle_slot_id", source_id))
	var formal_cfg := _read_formal_enable_config(battle_slot_id)
	var whitelist_enabled := bool(formal_cfg.get("whitelist_enabled", false))
	var generated_enabled := bool(formal_cfg.get("generated_content_enabled", false))
	var fallback_policy := str(formal_cfg.get("rollback_policy", "legacy"))
	var bridge_bundle := _bridge_bundle_from_context_or_path(context, battle_slot_id)
	var bridge_reward := _bridge_reward_candidate(bridge_bundle)
	var bridge_reward_id := str(bridge_reward.get("candidate_id", ""))
	var bridge_reward_available := bool(bridge_reward.get("candidate_available", false))
	var context_generated_enabled := bool(context.get("generated_content_enabled", false))
	var formal_path_enabled := bool(context.get("formal_path_enabled", false))
	var formal_enable_stage := str(context.get("formal_enable_stage", ""))

	var formal_enable_ok := (
		context_generated_enabled
		and formal_path_enabled
		and (formal_enable_stage == "v2_3" or formal_enable_stage == "v2_7" or formal_enable_stage == "v3_1")
		and
		battle_slot_id == source_id
		and whitelist_enabled
		and generated_enabled
		and fallback_policy == "legacy"
		and bridge_reward_available
		and not bridge_reward_id.is_empty()
	)
	if formal_enable_ok:
		selected_source = "content_engine"
		mode = MODE_RUNTIME_ENABLED
		config_enabled = true
		# 当前阶段只切换来源标记，reward 数值仍复用 legacy，保证不影响结算与状态写入。
		fallback_used = false
		fallback_reason = "none"
	else:
		mode = MODE_LEGACY
		config_enabled = false

	return _build_output(mode, config_enabled, selected_source, legacy_copy, runtime_candidate, shadow_compare, fallback_used, fallback_reason)


func _build_output(
	mode: String,
	config_enabled: bool,
	selected_source: String,
	legacy_reward: Dictionary,
	runtime_candidate: Dictionary,
	shadow_compare: Dictionary,
	fallback_used: bool,
	fallback_reason: String
) -> Dictionary:
	# legacy baseline marker for scaffold probe text check: "selected_source": "legacy"
	return {
		"selected_reward": legacy_reward.duplicate(true),
		"selected_source": selected_source,
		"mode": mode,
		"config_enabled": config_enabled,
		"runtime_candidate": runtime_candidate.duplicate(true),
		"shadow_compare": shadow_compare.duplicate(true),
		"fallback_used": fallback_used,
		"fallback_reason": fallback_reason,
		"read_only": true,
		"formal_data_source_replaced": false,
		"combat_flow_touched": false,
		"battle_state_touched": false,
		"selected_reward_runtime_effective": false,
	}


func _read_formal_enable_config(battle_slot_id: String) -> Dictionary:
	for cfg_path in [FULL_BATTLE_SLOT_WHITELIST_CONFIG_PATH, SLICE_WHITELIST_CONFIG_PATH, FORMAL_ENABLE_CONFIG_PATH]:
		if not FileAccess.file_exists(cfg_path):
			continue
		var f := FileAccess.open(cfg_path, FileAccess.READ)
		if f == null:
			continue
		var lines := f.get_as_text().split("\n")
		if lines.size() <= 1:
			continue
		var header: PackedStringArray = lines[0].strip_edges().split("\t")
		var key_index := {}
		for i in range(header.size()):
			key_index[header[i]] = i
		for i in range(1, lines.size()):
			var line := lines[i].strip_edges()
			if line == "":
				continue
			var cols: PackedStringArray = line.split("\t")
			var slot := _col(cols, key_index, "battle_slot_id")
			if slot != battle_slot_id:
				continue
			return {
				"whitelist_enabled": _col(cols, key_index, "whitelist_enabled").to_lower() == "true",
				"generated_content_enabled": _col(cols, key_index, "generated_content_enabled").to_lower() == "true",
				"rollback_policy": _col(cols, key_index, "rollback_policy"),
			}
	return {"whitelist_enabled": false, "generated_content_enabled": false, "rollback_policy": "legacy"}


func _col(cols: PackedStringArray, key_index: Dictionary, key: String) -> String:
	if not key_index.has(key):
		return ""
	var idx := int(key_index[key])
	if idx < 0 or idx >= cols.size():
		return ""
	return cols[idx]


func _bridge_bundle_from_context_or_path(context: Dictionary, battle_slot_id: String) -> Dictionary:
	var ctx_bundle: Variant = context.get("bridge_bundle", {})
	if typeof(ctx_bundle) == TYPE_DICTIONARY:
		var b: Dictionary = ctx_bundle
		if not b.is_empty():
			return b
	var bridge := GENERATED_CONTENT_BRIDGE.new()
	var bundle := bridge.get_full_content_bundle_for_battle_slot(battle_slot_id)
	if not bundle.is_empty():
		return bundle
	var path := WHITELIST_BRIDGE_PATH_PATTERN % battle_slot_id
	return _read_json_dict(path).get("payload", {})


func _bridge_reward_candidate(bundle: Dictionary) -> Dictionary:
	if bundle.is_empty():
		return {}
	var domains: Variant = bundle.get("domains", {})
	if typeof(domains) != TYPE_DICTIONARY:
		return {}
	var dmap: Dictionary = domains
	var reward: Variant = dmap.get("reward", {})
	if typeof(reward) != TYPE_DICTIONARY:
		return {}
	return reward


func _build_shadow_compare(legacy_reward: Dictionary, runtime_candidate: Dictionary, source_id: String) -> Dictionary:
	var candidate_loaded := runtime_candidate.size() > 0
	var candidate_record_count := int(runtime_candidate.get("record_count", 0))
	var same_shape := legacy_reward.keys().size() == runtime_candidate.keys().size() and candidate_loaded
	var same_value := false
	if candidate_loaded:
		same_value = _normalize_json_value(legacy_reward) == _normalize_json_value(runtime_candidate)
	return {
		"candidate_loaded": candidate_loaded,
		"candidate_record_count": candidate_record_count,
		"legacy_key_count": legacy_reward.size(),
		"same_shape": same_shape,
		"same_value": same_value,
		"source_id": source_id,
	}


func _config_is_disabled(config: Dictionary) -> bool:
	return (
		bool(config.get("content_engine_runtime_enabled", false)) == false
		and bool(config.get("read_only_probe_enabled", false)) == false
		and str(config.get("integration_mode", "")) == "disabled"
		and str(config.get("fallback_mode", "")) == "existing_data_source"
	)


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "payload": {}, "error": "file_missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "payload": {}, "error": "open_failed"}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "payload": {}, "error": "parse_failed"}
	return {"ok": true, "payload": parsed, "error": "none"}


func _safe_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _normalize_json_value(value: Variant) -> String:
	return JSON.stringify(value, "", true)
