extends RefCounted

const SAVE_SCHEMA_VERSION := "aigc_dungeon_save_v0_1"
const SAVE_SOURCE := "aigc_dungeon_save_bridge"
const DEFAULT_OUTPUT_DIR := "res://data/aigc_battle/generated/dungeon_save_bridge"
const DEFAULT_SAVE_PAYLOAD_PATH := DEFAULT_OUTPUT_DIR + "/aigc_dungeon_formal_save_payload.json"
const DEFAULT_RESTORED_PAYLOAD_PATH := DEFAULT_OUTPUT_DIR + "/aigc_dungeon_restored_from_save_payload.json"
const DEFAULT_VALIDATION_REPORT_PATH := DEFAULT_OUTPUT_DIR + "/aigc_dungeon_save_bridge_validation_report.json"
const ALLOWED_ENDING_ROUTES := ["normal", "true", "wuzhuangyuan"]


static func build_save_payload(route_state: Dictionary, network_map: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var route_payload := _route_state_payload(route_state)
	var payload := {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"save_source": SAVE_SOURCE,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"map_instance_id": str(metadata.get("map_instance_id", route_state.get("map_instance_id", ""))),
		"content_pool_pack_id": str(metadata.get("content_pool_pack_id", "")),
		"progression_template_id": str(metadata.get("progression_template_id", "")),
		"seed": int(metadata.get("seed", route_state.get("seed", network_map.get("seed", 0)))),
		"route_state": route_payload,
		"route_integrity": _route_integrity(route_payload),
		"compatibility": {
			"compatible_with_network_map": true,
			"no_fixed_sequence": true,
			"map_graph_id_key": true,
			"restored_by": SAVE_SOURCE,
		},
	}
	return payload


static func restore_route_state_from_save(payload: Dictionary, network_map: Dictionary) -> Dictionary:
	var validation := validate_save_payload(payload, network_map)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"errors": validation.get("errors", []),
			"route_state": {},
		}
	var route_state := (payload.get("route_state", {}) as Dictionary).duplicate(true)
	route_state["map_instance_id"] = str(payload.get("map_instance_id", route_state.get("map_instance_id", "")))
	route_state["seed"] = int(payload.get("seed", route_state.get("seed", 0)))
	return {
		"ok": true,
		"route_state": route_state,
	}


static func validate_save_payload(payload: Dictionary, network_map: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if str(payload.get("save_schema_version", "")) != SAVE_SCHEMA_VERSION:
		errors.append("save_schema_version_invalid")
	var route_state: Variant = payload.get("route_state", {})
	if not (route_state is Dictionary):
		errors.append("route_state_missing")
		return {
			"ok": false,
			"errors": errors,
			"no_fixed_sequence": false,
		}
	var route_dict := route_state as Dictionary
	var node_ids := _node_ids(network_map)
	var current_node_id := str(route_dict.get("current_node_id", ""))
	if current_node_id.is_empty() or not node_ids.has(current_node_id):
		errors.append("current_node_missing")
	for field in ["completed_node_ids", "visited_node_ids", "visited_path_order", "available_node_ids"]:
		for node_id in _string_array(route_dict.get(field, [])):
			if not node_ids.has(node_id):
				errors.append("%s_missing:%s" % [field, node_id])
	var selected_ending_route := str(route_dict.get("selected_ending_route", ""))
	if not selected_ending_route.is_empty() and not ALLOWED_ENDING_ROUTES.has(selected_ending_route):
		errors.append("selected_ending_route_invalid")
	if bool(route_dict.get("route_choice_locked", false)) and selected_ending_route.is_empty():
		errors.append("selected_ending_route_required_when_locked")
	for field in ["battle_count_so_far", "elite_count_so_far", "operation_count_so_far"]:
		if int(route_dict.get(field, -1)) < 0:
			errors.append("%s_negative" % field)
	var compatibility: Variant = payload.get("compatibility", {})
	var no_fixed_sequence := bool((compatibility as Dictionary).get("no_fixed_sequence", false)) if compatibility is Dictionary else false
	if not no_fixed_sequence:
		errors.append("no_fixed_sequence_required")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"no_fixed_sequence": no_fixed_sequence,
	}


static func write_save_payload(payload: Dictionary, path: String) -> Dictionary:
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
	file.store_string(JSON.stringify(payload, "\t"))
	return {
		"ok": true,
		"path": path,
	}


static func read_save_payload(path: String) -> Dictionary:
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
		"payload": (parsed as Dictionary).duplicate(true),
	}


static func _route_state_payload(route_state: Dictionary) -> Dictionary:
	var martial_level := int(route_state.get("martial_level", route_state.get("martial_realm", 1)))
	var available_node_ids := _string_array(route_state.get("available_node_ids", []))
	return {
		"run_id": str(route_state.get("run_id", "")),
		"current_node_id": str(route_state.get("current_node_id", "")),
		"selected_node_id": str(route_state.get("selected_node_id", "")),
		"completed_node_ids": _string_array(route_state.get("completed_node_ids", [])),
		"visited_node_ids": _string_array(route_state.get("visited_node_ids", route_state.get("completed_node_ids", []))),
		"visited_path_order": _string_array(route_state.get("visited_path_order", [])),
		"available_node_ids": available_node_ids,
		"available_next_node_ids": _string_array(route_state.get("available_next_node_ids", available_node_ids)),
		"battle_count_so_far": int(route_state.get("battle_count_so_far", 0)),
		"elite_count_so_far": int(route_state.get("elite_count_so_far", 0)),
		"operation_count_so_far": int(route_state.get("operation_count_so_far", 0)),
		"selected_ending_route": str(route_state.get("selected_ending_route", "")),
		"available_ending_routes": _string_array(route_state.get("available_ending_routes", [])),
		"locked_ending_routes": _string_array(route_state.get("locked_ending_routes", [])),
		"route_lock_reasons": (route_state.get("route_lock_reasons", {}) as Dictionary).duplicate(true),
		"route_branch_pending": bool(route_state.get("route_branch_pending", false)),
		"route_branch_node_id": str(route_state.get("route_branch_node_id", "")),
		"route_choice_locked": bool(route_state.get("route_choice_locked", false)),
		"route_flags": (route_state.get("route_flags", {}) as Dictionary).duplicate(true),
		"martial_level": martial_level,
		"martial_realm": int(route_state.get("martial_realm", martial_level)),
		"lightness_level": int(route_state.get("lightness_level", 0)),
		"military_merit": int(route_state.get("military_merit", 0)),
		"clean_reputation": int(route_state.get("clean_reputation", 0)),
		"old_case_progress": int(route_state.get("old_case_progress", 0)),
		"case_clues": int(route_state.get("case_clues", 0)),
	}


static func _route_integrity(route_state: Dictionary) -> Dictionary:
	var visited_path_order := _string_array(route_state.get("visited_path_order", []))
	return {
		"completed_count": _string_array(route_state.get("completed_node_ids", [])).size(),
		"visited_count": _string_array(route_state.get("visited_node_ids", [])).size(),
		"available_count": _string_array(route_state.get("available_node_ids", [])).size(),
		"path_last_node_id": visited_path_order[-1] if not visited_path_order.is_empty() else "",
		"route_choice_locked": bool(route_state.get("route_choice_locked", false)),
		"selected_ending_route": str(route_state.get("selected_ending_route", "")),
		"battle_count_so_far": int(route_state.get("battle_count_so_far", 0)),
		"elite_count_so_far": int(route_state.get("elite_count_so_far", 0)),
		"operation_count_so_far": int(route_state.get("operation_count_so_far", 0)),
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
	elif value is String:
		var text := str(value)
		if not text.is_empty():
			result.append(text)
	return result
