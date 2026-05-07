extends RefCounted
class_name ContentEngineRuntimeLoader

const MANIFEST_PATH := "res://data/runtime/content_engine/runtime_manifest.json"
const RUNTIME_PREFIX := "data/runtime/content_engine/"
const ALLOWED_RUNTIME_FILES := {
	"card_pool.json": true,
	"battle_reward.json": true,
}

var _loaded_domains: Dictionary = {}
var _errors: Array = []


func load_manifest() -> Dictionary:
	var result := {
		"ok": false,
		"manifest": {},
		"errors": [],
	}
	if not FileAccess.file_exists(MANIFEST_PATH):
		result.errors.append("manifest_missing")
		_errors = result.errors.duplicate()
		return result
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		result.errors.append("manifest_open_failed")
		_errors = result.errors.duplicate()
		return result
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		result.errors.append("manifest_parse_failed")
		_errors = result.errors.duplicate()
		return result
	result.manifest = parsed
	var validation := validate_manifest(result.manifest)
	result.ok = bool(validation.get("ok", false))
	result.errors = validation.get("errors", [])
	_errors = result.errors.duplicate()
	return result


func validate_manifest(manifest: Dictionary) -> Dictionary:
	var errors: Array = []
	var runtime_root := str(manifest.get("runtime_root", ""))
	if runtime_root != "data/runtime/content_engine":
		errors.append("runtime_root_invalid")
	var files_value: Variant = manifest.get("files", [])
	if typeof(files_value) != TYPE_ARRAY:
		errors.append("files_not_array")
		return {"ok": false, "errors": errors, "files": []}
	var entries: Array = files_value
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			errors.append("file_entry_not_dictionary")
			continue
		var entry: Dictionary = entry_variant
		var file_name := str(entry.get("file_name", ""))
		if not ALLOWED_RUNTIME_FILES.has(file_name):
			errors.append("file_name_not_allowlisted:%s" % file_name)
		var runtime_path := str(entry.get("runtime_path", ""))
		if not runtime_path.begins_with(RUNTIME_PREFIX):
			errors.append("runtime_path_not_in_runtime_root:%s" % runtime_path)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"files": entries,
	}


func validate_runtime_file(entry: Dictionary) -> Dictionary:
	var errors: Array = []
	var runtime_path := str(entry.get("runtime_path", ""))
	var file_name := str(entry.get("file_name", ""))
	if not ALLOWED_RUNTIME_FILES.has(file_name):
		errors.append("runtime_file_not_allowlisted:%s" % file_name)
	if not runtime_path.begins_with(RUNTIME_PREFIX):
		errors.append("runtime_path_invalid:%s" % runtime_path)
	var resource_path := "res://%s" % runtime_path
	if not FileAccess.file_exists(resource_path):
		errors.append("runtime_file_missing:%s" % runtime_path)
		return {"ok": false, "errors": errors, "domain": "", "payload": {}}
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		errors.append("runtime_file_open_failed:%s" % runtime_path)
		return {"ok": false, "errors": errors, "domain": "", "payload": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("runtime_file_parse_failed:%s" % runtime_path)
		return {"ok": false, "errors": errors, "domain": "", "payload": {}}
	var payload: Dictionary = parsed
	var runtime_domain := str(payload.get("runtime_domain", ""))
	if runtime_domain != str(entry.get("runtime_domain", "")):
		errors.append("runtime_domain_mismatch:%s" % runtime_path)
	if str(payload.get("artifact_id", "")) != str(entry.get("artifact_id", "")):
		errors.append("artifact_id_mismatch:%s" % runtime_path)
	if str(payload.get("schema_fingerprint", "")) != str(entry.get("schema_fingerprint", "")):
		errors.append("schema_fingerprint_mismatch:%s" % runtime_path)
	if str(payload.get("content_fingerprint", "")) != str(entry.get("content_fingerprint", "")):
		errors.append("content_fingerprint_mismatch:%s" % runtime_path)
	if int(payload.get("record_count", -1)) != int(entry.get("record_count", -2)):
		errors.append("record_count_mismatch:%s" % runtime_path)
	if int(payload.get("field_count", -1)) != int(entry.get("field_count", -2)):
		errors.append("field_count_mismatch:%s" % runtime_path)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"domain": runtime_domain,
		"payload": payload,
	}


func load_runtime_bundle() -> Dictionary:
	_loaded_domains = {}
	_errors = []
	var manifest_result := load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return {"ok": false, "domains": {}, "errors": _errors.duplicate()}
	var manifest: Dictionary = manifest_result.get("manifest", {})
	var manifest_check := validate_manifest(manifest)
	if not bool(manifest_check.get("ok", false)):
		_errors = manifest_check.get("errors", [])
		return {"ok": false, "domains": {}, "errors": _errors.duplicate()}
	var entries: Array = manifest_check.get("files", [])
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			_errors.append("manifest_entry_invalid")
			return {"ok": false, "domains": {}, "errors": _errors.duplicate()}
		var entry: Dictionary = entry_variant
		var file_check := validate_runtime_file(entry)
		if not bool(file_check.get("ok", false)):
			_errors.append_array(file_check.get("errors", []))
			return {"ok": false, "domains": {}, "errors": _errors.duplicate()}
		var domain := str(file_check.get("domain", ""))
		_loaded_domains[domain] = file_check.get("payload", {})
	return {"ok": true, "domains": _loaded_domains.duplicate(true), "errors": []}


func get_loaded_domains() -> Array:
	return _loaded_domains.keys()


func get_errors() -> Array:
	return _errors.duplicate()
