extends RefCounted

const DEFAULT_SNAPSHOT_PATH := "res://data/aigc_battle/generated/dungeon_route_persistence/route_state_runtime_snapshot.json"
const SNAPSHOT_VERSION := "dungeon_route_state_snapshot_v1"
const SNAPSHOT_SOURCE := "aigc_dungeon_route_state_store"
const ALLOWED_ENDING_ROUTES := ["normal", "true", "wuzhuangyuan"]


static func save_route_state_snapshot(state: Dictionary, path: String = DEFAULT_SNAPSHOT_PATH) -> Dictionary:
	var snapshot := _snapshot_from_state(state)
	var target_path := _resolve_path(path)
	var dir_path := target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_result := DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_result != OK:
			return {
				"ok": false,
				"error": "mkdir_failed",
				"path": path,
			}
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "open_failed",
			"path": path,
		}
	file.store_string(JSON.stringify(snapshot, "\t"))
	return {
		"ok": true,
		"path": path,
		"snapshot": snapshot,
	}


static func load_route_state_snapshot(path: String = DEFAULT_SNAPSHOT_PATH) -> Dictionary:
	var target_path := _resolve_path(path)
	if not FileAccess.file_exists(target_path):
		return {
			"ok": false,
			"error": "missing_file",
			"path": path,
		}
	var file := FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": "open_failed",
			"path": path,
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"error": "invalid_json",
			"path": path,
		}
	return {
		"ok": true,
		"path": path,
		"snapshot": (parsed as Dictionary).duplicate(true),
	}


static func validate_route_state_snapshot(snapshot: Dictionary, network_map: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var node_ids := _node_ids(network_map)
	var current_node_id := str(snapshot.get("current_node_id", ""))
	if current_node_id.is_empty() or not node_ids.has(current_node_id):
		errors.append("current_node_missing")
	for field in ["completed_node_ids", "visited_node_ids", "visited_path_order", "available_node_ids"]:
		for node_id in _string_array(snapshot.get(field, [])):
			if not node_ids.has(node_id):
				errors.append("%s_missing:%s" % [field, node_id])
	var selected_ending_route := str(snapshot.get("selected_ending_route", ""))
	if not selected_ending_route.is_empty() and not ALLOWED_ENDING_ROUTES.has(selected_ending_route):
		errors.append("selected_ending_route_invalid")
	if bool(snapshot.get("route_branch_pending", false)) and str(snapshot.get("route_branch_node_id", "")).is_empty():
		errors.append("route_branch_node_missing")
	for field in ["battle_count_so_far", "elite_count_so_far", "operation_count_so_far"]:
		if int(snapshot.get(field, -1)) < 0:
			errors.append("%s_negative" % field)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}


static func clear_route_state_snapshot(path: String = DEFAULT_SNAPSHOT_PATH) -> Dictionary:
	var target_path := _resolve_path(path)
	if not FileAccess.file_exists(target_path):
		return {
			"ok": true,
			"path": path,
			"deleted": false,
		}
	var remove_result := DirAccess.remove_absolute(target_path)
	return {
		"ok": remove_result == OK,
		"path": path,
		"deleted": remove_result == OK,
	}


static func _snapshot_from_state(state: Dictionary) -> Dictionary:
	var martial_level := int(state.get("martial_level", state.get("martial_realm", 1)))
	var available_node_ids := _string_array(state.get("available_node_ids", []))
	var visited_node_ids := _string_array(state.get("visited_node_ids", state.get("completed_node_ids", [])))
	return {
		"run_id": str(state.get("run_id", "dungeon_run_seed_1001")),
		"map_instance_id": str(state.get("map_instance_id", "dungeon_map_seed_1001")),
		"current_node_id": str(state.get("current_node_id", "")),
		"selected_node_id": str(state.get("selected_node_id", "")),
		"completed_node_ids": _string_array(state.get("completed_node_ids", [])),
		"visited_node_ids": visited_node_ids,
		"visited_path_order": _string_array(state.get("visited_path_order", [])),
		"available_node_ids": available_node_ids,
		"available_next_node_ids": _string_array(state.get("available_next_node_ids", available_node_ids)),
		"battle_count_so_far": int(state.get("battle_count_so_far", 0)),
		"elite_count_so_far": int(state.get("elite_count_so_far", 0)),
		"operation_count_so_far": int(state.get("operation_count_so_far", 0)),
		"selected_ending_route": str(state.get("selected_ending_route", "")),
		"available_ending_routes": _string_array(state.get("available_ending_routes", [])),
		"locked_ending_routes": _string_array(state.get("locked_ending_routes", [])),
		"route_lock_reasons": (state.get("route_lock_reasons", {}) as Dictionary).duplicate(true),
		"route_branch_pending": bool(state.get("route_branch_pending", false)),
		"route_branch_node_id": str(state.get("route_branch_node_id", "")),
		"route_choice_locked": bool(state.get("route_choice_locked", false)),
		"route_flags": (state.get("route_flags", {}) as Dictionary).duplicate(true),
		"martial_level": martial_level,
		"martial_realm": int(state.get("martial_realm", martial_level)),
		"lightness_level": int(state.get("lightness_level", 0)),
		"military_merit": int(state.get("military_merit", 0)),
		"clean_reputation": int(state.get("clean_reputation", 0)),
		"old_case_progress": int(state.get("old_case_progress", 0)),
		"case_clues": int(state.get("case_clues", 0)),
		"snapshot_version": SNAPSHOT_VERSION,
		"snapshot_source": SNAPSHOT_SOURCE,
	}


static func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _node_ids(network_map: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item in network_map.get("nodes", []):
		if item is Dictionary:
			var node_id := str((item as Dictionary).get("map_graph_id", ""))
			if not node_id.is_empty() and not result.has(node_id):
				result.append(node_id)
	return result


static func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	return result
