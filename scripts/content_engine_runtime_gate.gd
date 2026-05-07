extends RefCounted
class_name ContentEngineRuntimeGate

const CONFIG_PATH := "res://data/runtime/content_engine/runtime_loader_config.json"
const MANIFEST_PATH := "res://data/runtime/content_engine/runtime_manifest.json"
const RUNTIME_ROOT := "res://data/runtime/content_engine"
const ALLOWED_RUNTIME_FILES := {
	"card_pool.json": true,
	"battle_reward.json": true,
	"runtime_manifest.json": true,
	"runtime_loader_config.json": true,
}


func evaluate_gate() -> Dictionary:
	var base := {
		"ok": false,
		"gate_status": "failed_closed",
		"integration_status": "not_integrated",
		"runtime_domains": [],
		"blocked_reason": "",
		"notes": "v0.9a read-only gate scaffold. No main-flow integration.",
	}

	var config_result := _read_json_dictionary(CONFIG_PATH)
	if not bool(config_result.get("ok", false)):
		base.blocked_reason = "config_missing_or_invalid"
		base.gate_status = "failed_closed"
		return base

	var config: Dictionary = config_result.get("payload", {})
	if not _config_has_required_keys(config):
		base.blocked_reason = "config_missing_required_key"
		base.gate_status = "blocked"
		return base

	var runtime_enabled := bool(config.get("content_engine_runtime_enabled", false))
	var integration_mode := str(config.get("integration_mode", ""))
	var fallback_mode := str(config.get("fallback_mode", ""))

	if not runtime_enabled:
		base.ok = true
		base.gate_status = "disabled"
		base.blocked_reason = ""
		base.notes = "content_engine_runtime_enabled=false; runtime bundle not loaded."
		return base

	if integration_mode != "disabled":
		base.blocked_reason = "integration_mode_not_disabled"
		base.gate_status = "blocked"
		return base

	if fallback_mode != "existing_data_source":
		base.blocked_reason = "fallback_mode_invalid"
		base.gate_status = "blocked"
		return base

	var runtime_dir_check := _check_runtime_dir_allowlist()
	if not bool(runtime_dir_check.get("ok", false)):
		base.blocked_reason = str(runtime_dir_check.get("blocked_reason", "runtime_dir_invalid"))
		base.gate_status = "failed_closed"
		return base

	var manifest_result := _read_json_dictionary(MANIFEST_PATH)
	if not bool(manifest_result.get("ok", false)):
		base.blocked_reason = "manifest_missing_or_invalid"
		base.gate_status = "failed_closed"
		return base

	var manifest: Dictionary = manifest_result.get("payload", {})
	if not _manifest_looks_valid(manifest):
		base.blocked_reason = "manifest_validation_failed"
		base.gate_status = "failed_closed"
		return base

	# v0.9a gate remains not integrated and read-only by default.
	base.gate_status = "blocked"
	base.blocked_reason = "runtime_enabled_but_not_integrated_in_v0_9a"
	return base


func _config_has_required_keys(config: Dictionary) -> bool:
	return (
		config.has("content_engine_runtime_enabled")
		and config.has("read_only_probe_enabled")
		and config.has("integration_mode")
		and config.has("fallback_mode")
	)


func _manifest_looks_valid(manifest: Dictionary) -> bool:
	var runtime_root := str(manifest.get("runtime_root", ""))
	if runtime_root != "data/runtime/content_engine":
		return false
	var files_value: Variant = manifest.get("files", [])
	if typeof(files_value) != TYPE_ARRAY:
		return false
	return true


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "payload": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "payload": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "payload": {}}
	return {"ok": true, "payload": parsed}


func _check_runtime_dir_allowlist() -> Dictionary:
	var dir := DirAccess.open(RUNTIME_ROOT)
	if dir == null:
		return {"ok": false, "blocked_reason": "runtime_dir_missing"}
	var names: Dictionary = {}
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if not dir.current_is_dir():
			names[item] = true
		item = dir.get_next()
	dir.list_dir_end()

	var expected_count := ALLOWED_RUNTIME_FILES.size()
	if names.size() != expected_count:
		return {"ok": false, "blocked_reason": "runtime_dir_file_count_mismatch"}

	for file_name in names.keys():
		if not ALLOWED_RUNTIME_FILES.has(file_name):
			return {"ok": false, "blocked_reason": "runtime_dir_unallowlisted_file"}

	for required_name in ALLOWED_RUNTIME_FILES.keys():
		if not names.has(required_name):
			return {"ok": false, "blocked_reason": "runtime_dir_missing_allowlisted_file"}

	return {"ok": true, "blocked_reason": ""}
