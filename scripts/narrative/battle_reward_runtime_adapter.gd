extends RefCounted
class_name BattleRewardRuntimeAdapter

const MODE_LEGACY := "legacy"
const MODE_SHADOW := "shadow"
const MODE_RUNTIME_TEST := "runtime_test"
const MODE_RUNTIME_ENABLED := "runtime_enabled"

const CONFIG_PATH := "res://data/runtime/content_engine/runtime_loader_config.json"
const RUNTIME_REWARD_PATH := "res://data/runtime/content_engine/battle_reward.json"


func resolve_reward(source_id: String, legacy_reward: Dictionary, context: Dictionary = {}) -> Dictionary:
	var legacy_copy: Dictionary = _safe_dict(legacy_reward)
	var mode := MODE_LEGACY
	var config_enabled := false
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
		return _build_output(mode, config_enabled, legacy_copy, runtime_candidate, shadow_compare, fallback_used, fallback_reason)

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

	return _build_output(MODE_LEGACY, false, legacy_copy, runtime_candidate, shadow_compare, fallback_used, fallback_reason)


func _build_output(
	mode: String,
	config_enabled: bool,
	legacy_reward: Dictionary,
	runtime_candidate: Dictionary,
	shadow_compare: Dictionary,
	fallback_used: bool,
	fallback_reason: String
) -> Dictionary:
	return {
		"selected_reward": legacy_reward.duplicate(true),
		"selected_source": "legacy",
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
