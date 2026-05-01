extends SceneTree

const HotTuningController = preload("res://scripts/battle_controller_visual_hot_tuning.gd")
const PROFILE_STORE_PATH := "user://battle_number_profiles.json"

func _init() -> void:
	var errors: Array[String] = []
	var demo: Node = HotTuningController.new()
	root.add_child(demo)
	await process_frame
	if demo.has_method("_start_session"):
		demo.call("_start_session", "spearman")
	await process_frame
	if demo.get("player") == null or demo.get("enemy") == null:
		errors.append("battle fighters were not initialized")
	else:
		_run_profile_checks(demo, errors)
	root.remove_child(demo)
	demo.free()
	if errors.is_empty():
		print("[battle-number-profiles] OK: save/apply/delete/sample deck profiles")
		quit(0)
	else:
		_fail(errors)

func _run_profile_checks(demo: Node, errors: Array[String]) -> void:
	var config: Dictionary = demo.call("_snapshot_number_config", "smoke profile")
	var player_deck: Array = config.get("player_deck", [])
	var enemy_deck: Array = config.get("enemy_deck", [])
	if player_deck.is_empty() or enemy_deck.is_empty():
		errors.append("profile did not capture both decks")
		return
	var original_enemy_size := enemy_deck.size()
	if original_enemy_size > 1:
		enemy_deck.remove_at(0)
	enemy_deck.append(player_deck[0].duplicate(true))
	config["enemy_deck"] = enemy_deck
	var enemy_numbers: Dictionary = config.get("enemy", {})
	enemy_numbers["qinggong"] = 0
	config["enemy"] = enemy_numbers
	demo.call("_apply_number_config", config)
	var enemy = demo.get("enemy")
	if enemy == null:
		errors.append("enemy missing after apply")
		return
	if enemy.data.starting_deck.size() != original_enemy_size:
		errors.append("enemy deck size did not rebuild through profile")
	if enemy.qinggong < 1 or enemy.data.qinggong < 1:
		errors.append("qinggong minimum 1 was not enforced")
	var sample: Dictionary = demo.call("_sample_number_config", config, 12, 12345)
	if int(sample.get("sample_count", 0)) != 12:
		errors.append("sample did not use requested profile sample count")
	if sample.get("player_label", "") == "" or sample.get("enemy_label", "") == "":
		errors.append("sample labels missing")
	var profiles: Array[Dictionary] = [config]
	demo.set("_number_configs", profiles)
	demo.set("_active_number_config_index", 0)
	demo.call("_save_number_configs")
	if not FileAccess.file_exists(PROFILE_STORE_PATH):
		errors.append("profile store was not written")
	else:
		var file := FileAccess.open(PROFILE_STORE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else {}
		if not (parsed is Dictionary) or int((parsed as Dictionary).get("schema_version", 0)) < 2:
			errors.append("profile store schema missing")
	demo.call("_duplicate_selected_number_config")
	var duplicated: Array = demo.get("_number_configs")
	if duplicated.size() != 2:
		errors.append("duplicate selected profile did not append a copy")
	demo.call("_delete_selected_number_config")
	demo.set("_active_number_config_index", 0)
	demo.call("_delete_selected_number_config")
	var remaining: Array = demo.get("_number_configs")
	if not remaining.is_empty():
		errors.append("delete selected profile did not remove profiles")

func _fail(errors: Array[String]) -> void:
	for error in errors:
		push_error("[battle-number-profiles] %s" % error)
	quit(1)
