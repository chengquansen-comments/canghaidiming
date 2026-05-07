extends SceneTree

const LOADER_SCRIPT := preload("res://scripts/content_engine_runtime_loader.gd")
const PROBE_DOMAIN := "battle_reward"


func _initialize() -> void:
	var payload: Dictionary = _run_probe()
	print("CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN")
	print(JSON.stringify(payload))
	print("CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_END")
	quit()


func _run_probe() -> Dictionary:
	var errors: Array = []
	var loader: Object = LOADER_SCRIPT.new()

	var manifest_result: Dictionary = loader.load_manifest()
	var manifest: Dictionary = {}
	var manifest_loaded := false
	if typeof(manifest_result.get("manifest", {})) == TYPE_DICTIONARY:
		manifest = manifest_result.get("manifest", {})
		manifest_loaded = not manifest.is_empty()
	if typeof(manifest_result.get("errors", [])) == TYPE_ARRAY and not manifest_result.get("errors", []).is_empty():
		errors.append_array(manifest_result.get("errors", []))

	var manifest_check := {"ok": false, "files": [], "errors": ["manifest_not_loaded"]}
	if manifest_loaded:
		manifest_check = loader.validate_manifest(manifest)
		if typeof(manifest_check.get("errors", [])) == TYPE_ARRAY and not manifest_check.get("errors", []).is_empty():
			errors.append_array(manifest_check.get("errors", []))

	var manifest_valid := bool(manifest_check.get("ok", false))
	var runtime_loaded := false
	var runtime_record_count := 0
	var runtime_field_count := 0
	var loaded_record_ids: Array = []

	if manifest_valid:
		var entries: Array = manifest_check.get("files", [])
		var battle_entries: Array = []
		for entry_variant in entries:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			if str(entry.get("runtime_domain", "")) == PROBE_DOMAIN:
				battle_entries.append(entry)
		if battle_entries.size() != 1:
			errors.append("battle_reward_manifest_entry_count_invalid:%d" % battle_entries.size())
		else:
			var file_result: Dictionary = loader.validate_runtime_file(battle_entries[0])
			runtime_loaded = bool(file_result.get("ok", false))
			if typeof(file_result.get("errors", [])) == TYPE_ARRAY and not file_result.get("errors", []).is_empty():
				errors.append_array(file_result.get("errors", []))
			if runtime_loaded:
				var payload: Dictionary = file_result.get("payload", {})
				runtime_record_count = int(payload.get("record_count", 0))
				runtime_field_count = int(payload.get("field_count", 0))
				var records_value: Variant = payload.get("records", [])
				if typeof(records_value) == TYPE_ARRAY:
					var records: Array = records_value
					for record_variant in records:
						if typeof(record_variant) != TYPE_DICTIONARY:
							continue
						var record: Dictionary = record_variant
						var record_id := str(record.get("reward_plan_id", ""))
						if record_id == "":
							record_id = str(record.get("battle_slot_id", ""))
						if record_id == "":
							record_id = "index_%d" % loaded_record_ids.size()
						loaded_record_ids.append(record_id)
				loaded_record_ids.sort()

	var dedup_errors: Array = []
	for item in errors:
		var text := str(item)
		if not dedup_errors.has(text):
			dedup_errors.append(text)

	var ok := manifest_loaded and manifest_valid and runtime_loaded and dedup_errors.is_empty()
	return {
		"ok": ok,
		"runtime_domain": PROBE_DOMAIN,
		"manifest_loaded": manifest_loaded,
		"manifest_valid": manifest_valid,
		"runtime_loaded": runtime_loaded,
		"runtime_record_count": runtime_record_count,
		"runtime_field_count": runtime_field_count,
		"loaded_record_ids": loaded_record_ids,
		"error_count": dedup_errors.size(),
		"errors": dedup_errors,
		"manifest_first": true,
		"read_only": true,
		"formal_data_source_replaced": false,
		"integration_status": "godot_compare_only",
	}
