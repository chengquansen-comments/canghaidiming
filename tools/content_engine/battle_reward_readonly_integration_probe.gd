extends SceneTree

const LOADER_SCRIPT := preload("res://scripts/content_engine_runtime_loader.gd")
const RUNTIME_CONFIG_PATH := "res://data/runtime/content_engine/runtime_loader_config.json"
const LEGACY_TSV_PATH := "res://data/design/generated_battle_reward_plan.tsv"
const PROBE_DOMAIN := "battle_reward"


func _initialize() -> void:
	var payload: Dictionary = _run_probe()
	print("BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_BEGIN")
	print(JSON.stringify(payload))
	print("BATTLE_REWARD_READONLY_INTEGRATION_PROBE_JSON_END")
	quit()


func _run_probe() -> Dictionary:
	var errors: Array = []
	var loader: Object = LOADER_SCRIPT.new()

	var manifest_loaded := false
	var manifest_valid := false
	var runtime_loaded := false
	var runtime_record_count := 0
	var runtime_field_count := 0
	var legacy_record_count := 0
	var legacy_field_count := 0
	var missing_in_runtime_count := 0
	var extra_in_runtime_count := 0
	var changed_record_count := 0
	var config_enabled := false
	var integration_mode := "disabled"

	var legacy_ids: Dictionary = {}
	var runtime_ids: Dictionary = {}

	var manifest_result: Dictionary = loader.load_manifest()
	var manifest: Dictionary = {}
	if typeof(manifest_result.get("manifest", {})) == TYPE_DICTIONARY:
		manifest = manifest_result.get("manifest", {})
		manifest_loaded = not manifest.is_empty()
	if typeof(manifest_result.get("errors", [])) == TYPE_ARRAY and not manifest_result.get("errors", []).is_empty():
		errors.append_array(manifest_result.get("errors", []))

	var manifest_check := {"ok": false, "files": [], "errors": ["manifest_not_loaded"]}
	if manifest_loaded:
		manifest_check = loader.validate_manifest(manifest)
		manifest_valid = bool(manifest_check.get("ok", false))
		if typeof(manifest_check.get("errors", [])) == TYPE_ARRAY and not manifest_check.get("errors", []).is_empty():
			errors.append_array(manifest_check.get("errors", []))

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
						var reward_plan_id := str(record.get("reward_plan_id", ""))
						if reward_plan_id != "":
							runtime_ids[reward_plan_id] = true

	var config_result := _load_runtime_config()
	config_enabled = bool(config_result.get("config_enabled", false))
	integration_mode = str(config_result.get("integration_mode", "disabled"))
	if not bool(config_result.get("loaded", false)):
		errors.append("runtime_loader_config_load_failed")
	if str(config_result.get("error", "")) != "":
		errors.append(str(config_result.get("error", "")))

	var legacy_result := _load_legacy_tsv()
	legacy_record_count = int(legacy_result.get("record_count", 0))
	legacy_field_count = int(legacy_result.get("field_count", 0))
	legacy_ids = legacy_result.get("ids", {})
	if not bool(legacy_result.get("loaded", false)):
		errors.append("legacy_source_load_failed")
	if str(legacy_result.get("error", "")) != "":
		errors.append(str(legacy_result.get("error", "")))

	var missing_ids: Dictionary = {}
	for legacy_id in legacy_ids.keys():
		if not runtime_ids.has(legacy_id):
			missing_ids[legacy_id] = true
	var extra_ids: Dictionary = {}
	for runtime_id in runtime_ids.keys():
		if not legacy_ids.has(runtime_id):
			extra_ids[runtime_id] = true

	missing_in_runtime_count = missing_ids.size()
	extra_in_runtime_count = extra_ids.size()
	changed_record_count = 0 if (missing_in_runtime_count == 0 and extra_in_runtime_count == 0) else (missing_in_runtime_count + extra_in_runtime_count)

	var record_count_match_status := "matched" if (runtime_record_count == legacy_record_count and missing_in_runtime_count == 0 and extra_in_runtime_count == 0) else "mismatched"
	var field_count_match_status := "matched" if runtime_field_count == legacy_field_count else "mismatched"

	var dedup_errors: Array = []
	for item in errors:
		var text := str(item)
		if text == "":
			continue
		if not dedup_errors.has(text):
			dedup_errors.append(text)

	var ok := (
		manifest_loaded
		and manifest_valid
		and runtime_loaded
		and record_count_match_status == "matched"
		and field_count_match_status == "matched"
		and not config_enabled
		and integration_mode == "disabled"
		and dedup_errors.is_empty()
	)

	return {
		"ok": ok,
		"runtime_domain": PROBE_DOMAIN,
		"runtime_record_count": runtime_record_count,
		"legacy_record_count": legacy_record_count,
		"record_count_match_status": record_count_match_status,
		"field_count_match_status": field_count_match_status,
		"missing_in_runtime_count": missing_in_runtime_count,
		"extra_in_runtime_count": extra_in_runtime_count,
		"changed_record_count": changed_record_count,
		"manifest_loaded": manifest_loaded,
		"manifest_valid": manifest_valid,
		"runtime_loaded": runtime_loaded,
		"config_enabled": config_enabled,
		"integration_mode": integration_mode,
		"read_only": true,
		"formal_data_source_replaced": false,
		"combat_flow_touched": false,
		"battle_state_touched": false,
		"card_pool_out_of_scope": true,
		"integration_status": "readonly_probe_only",
		"error_count": dedup_errors.size(),
		"errors": dedup_errors,
	}


func _load_runtime_config() -> Dictionary:
	if not FileAccess.file_exists(RUNTIME_CONFIG_PATH):
		return {"loaded": false, "error": "runtime_loader_config_missing", "config_enabled": false, "integration_mode": "disabled"}
	var file := FileAccess.open(RUNTIME_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {"loaded": false, "error": "runtime_loader_config_open_failed", "config_enabled": false, "integration_mode": "disabled"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"loaded": false, "error": "runtime_loader_config_parse_failed", "config_enabled": false, "integration_mode": "disabled"}
	var cfg: Dictionary = parsed
	return {
		"loaded": true,
		"error": "",
		"config_enabled": bool(cfg.get("content_engine_runtime_enabled", false)),
		"integration_mode": str(cfg.get("integration_mode", "disabled")),
	}


func _load_legacy_tsv() -> Dictionary:
	if not FileAccess.file_exists(LEGACY_TSV_PATH):
		return {"loaded": false, "error": "legacy_source_missing", "record_count": 0, "field_count": 0, "ids": {}}
	var file := FileAccess.open(LEGACY_TSV_PATH, FileAccess.READ)
	if file == null:
		return {"loaded": false, "error": "legacy_source_open_failed", "record_count": 0, "field_count": 0, "ids": {}}

	var lines: PackedStringArray = file.get_as_text().split("\n")
	var record_count := 0
	var field_count := 0
	var ids: Dictionary = {}
	var header_ready := false
	var reward_plan_index := -1

	for raw_line in lines:
		var line := raw_line.strip_edges()
		if line == "":
			continue
		var cols: PackedStringArray = line.split("\t")
		if not header_ready:
			field_count = cols.size()
			header_ready = true
			for idx in range(cols.size()):
				if cols[idx] == "reward_plan_id":
					reward_plan_index = idx
					break
			if reward_plan_index < 0:
				return {"loaded": false, "error": "legacy_source_missing_reward_plan_id", "record_count": 0, "field_count": field_count, "ids": {}}
			continue
		record_count += 1
		if reward_plan_index < cols.size():
			var plan_id := cols[reward_plan_index]
			if plan_id != "":
				ids[plan_id] = true

	return {
		"loaded": true,
		"error": "",
		"record_count": record_count,
		"field_count": field_count,
		"ids": ids,
	}
