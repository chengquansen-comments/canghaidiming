extends "res://scripts/battle_controller_visual_hot_tuning_profile_format.gd"

# Extracted hot tuning profile persistence layer.

func _new_number_config_id() -> String:
	return "profile_%d_%d" % [Time.get_unix_time_from_system(), _number_config_serial]

func _current_tuning_encounter_id() -> String:
	if has_method("_context_debug_text") and HotTuningNarrativeBattleContext.has_request():
		return str(HotTuningNarrativeBattleContext.encounter_id)
	return "current_battle"

func _profile_store_label() -> String:
	return NUMBER_PROFILE_STORE_PATH

func _load_number_configs() -> void:
	if not FileAccess.file_exists(NUMBER_PROFILE_STORE_PATH):
		return
	var file := FileAccess.open(NUMBER_PROFILE_STORE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var profiles: Array = (parsed as Dictionary).get("profiles", [])
	_number_configs.clear()
	for profile_variant in profiles:
		if profile_variant is Dictionary:
			var profile: Dictionary = profile_variant
			_number_configs.append(_normalize_loaded_number_config(profile))
	_number_config_serial = maxi(int((parsed as Dictionary).get("serial", _number_configs.size() + 1)), _number_configs.size() + 1)
	_active_number_config_index = mini(_active_number_config_index, _number_configs.size() - 1)
	_refresh_number_config_select()

func _save_number_configs() -> void:
	var file := FileAccess.open(NUMBER_PROFILE_STORE_PATH, FileAccess.WRITE)
	if file == null:
		_number_config_status = "保存失败：无法写入 %s" % NUMBER_PROFILE_STORE_PATH
		return
	file.store_string(JSON.stringify({
		"schema_version": NUMBER_PROFILE_SCHEMA,
		"serial": _number_config_serial,
		"profiles": _number_configs
	}, "\t"))

func _normalize_loaded_number_config(config: Dictionary) -> Dictionary:
	if not config.has("schema_version"):
		config["schema_version"] = 1
	if not config.has("id"):
		config["id"] = _new_number_config_id()
	if not config.has("player_deck"):
		config["player_deck"] = []
	if not config.has("enemy_deck"):
		config["enemy_deck"] = []
	return config
