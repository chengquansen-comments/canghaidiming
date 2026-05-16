extends RefCounted

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const AigcDungeonRouteBranchEvaluator := preload("res://scripts/aigc_dungeon_route_branch_evaluator.gd")

const BIG_MAP_COMPATIBLE_PATH := "res://data/aigc_battle/generated/dungeon_maps/big_map_compatible_seed_1001.json"
const ROUTE_STATE_PATH := "res://data/aigc_battle/generated/dungeon_maps/route_state_seed_1001_initial.json"
const MAP_INSTANCE_PATH := "res://data/aigc_battle/generated/dungeon_maps/map_seed_1001.json"
const ROUTE_RULES_PATH := "res://data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/route_rules.json"
const LOADOUT_PATH := "res://data/aigc_battle/generated/dungeon_node_materializer/selected_node_materialized_loadout.json"
const BATTLE_ENTRY_REQUEST_PATH := "res://data/aigc_battle/generated/dungeon_node_materializer/selected_node_battle_entry_request.json"
const ACTIVE_PROFILE_PATH := "res://data/aigc_battle/runtime/active_profile.json"
const CURRENT_RELEASE_PATH := "res://data/aigc_battle/release_channels/current_release.json"
const DUNGEON_PROFILE_ID := "dungeon_progression_v1_3"
const DUNGEON_CONTENT_PACK_ID := "dungeon_pool_pack_001"

const ROOT_REQUIRED_FIELDS := [
	"run_id",
	"seed",
	"layer_count",
	"current_layer",
	"current_node_id",
	"selected_node_id",
	"completed_node_ids",
	"available_node_ids",
	"pending_map_node_id",
	"pending_result_text",
	"pending_effects",
	"nodes",
]

const NODE_REQUIRED_FIELDS := [
	"map_graph_id",
	"pool_node_id",
	"layer",
	"lane",
	"x",
	"y",
	"title",
	"node_type",
	"primary_line",
	"secondary_line",
	"preview_text",
	"result_text",
	"effects",
	"tags",
	"combat_pool_id",
	"encounter_id",
	"battle_id",
	"outgoing",
	"incoming",
	"state",
]


static func load_runtime_bundle() -> Dictionary:
	var graph_result := _read_json_dict(BIG_MAP_COMPATIBLE_PATH)
	if not bool(graph_result.get("ok", false)):
		return graph_result
	var route_result := _read_json_dict(ROUTE_STATE_PATH)
	if not bool(route_result.get("ok", false)):
		return route_result
	var graph: Dictionary = (graph_result.get("data", {}) as Dictionary).duplicate(true)
	var route_state: Dictionary = (route_result.get("data", {}) as Dictionary).duplicate(true)
	var map_instance := _optional_json_dict(MAP_INSTANCE_PATH)
	var route_rules := _optional_json_dict(ROUTE_RULES_PATH)
	var loadout := _optional_json_dict(LOADOUT_PATH)
	var battle_entry_request := _optional_json_dict(BATTLE_ENTRY_REQUEST_PATH)
	var validation_errors := _validate_graph(graph)
	if not validation_errors.is_empty():
		return {
			"ok": false,
			"error": "aigc_dungeon_big_map_invalid",
			"details": validation_errors,
		}
	_enrich_graph_nodes(graph, map_instance, loadout, battle_entry_request)
	apply_route_state_to_graph(graph, route_state)
	return {
		"ok": true,
		"network_map": graph,
		"route_state": route_state,
		"map_instance": map_instance,
		"route_rules": route_rules,
		"selected_loadout": loadout,
		"selected_battle_entry_request": battle_entry_request,
	}


static func apply_bundle_to_state(strategic_state: Dictionary, bundle: Dictionary) -> bool:
	if not bool(bundle.get("ok", false)):
		return false
	var graph: Dictionary = (bundle.get("network_map", {}) as Dictionary).duplicate(true)
	var route_state: Dictionary = (bundle.get("route_state", {}) as Dictionary).duplicate(true)
	var route_rules: Dictionary = (bundle.get("route_rules", {}) as Dictionary).duplicate(true)
	StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)
	strategic_state["active"] = true
	strategic_state["network_map"] = graph
	strategic_state["dungeon_route_rules"] = route_rules
	strategic_state["visited_node_ids"] = (graph.get("visited_node_ids", route_state.get("visited_node_ids", route_state.get("completed_node_ids", []))) as Array).duplicate(true)
	strategic_state["visited_path_order"] = (graph.get("visited_path_order", route_state.get("visited_path_order", [])) as Array).duplicate(true)
	strategic_state["battle_count_so_far"] = int(graph.get("battle_count_so_far", route_state.get("battle_count_so_far", 0)))
	strategic_state["elite_count_so_far"] = int(graph.get("elite_count_so_far", route_state.get("elite_count_so_far", 0)))
	strategic_state["operation_count_so_far"] = int(graph.get("operation_count_so_far", route_state.get("operation_count_so_far", 0)))
	strategic_state["selected_ending_route"] = str(graph.get("selected_ending_route", route_state.get("selected_ending_route", "")))
	strategic_state["available_ending_routes"] = (graph.get("available_ending_routes", route_state.get("available_ending_routes", [])) as Array).duplicate(true)
	strategic_state["locked_ending_routes"] = (graph.get("locked_ending_routes", route_state.get("locked_ending_routes", [])) as Array).duplicate(true)
	strategic_state["route_lock_reasons"] = (graph.get("route_lock_reasons", route_state.get("route_lock_reasons", {})) as Dictionary).duplicate(true)
	strategic_state["route_branch_pending"] = bool(graph.get("route_branch_pending", route_state.get("route_branch_pending", false)))
	strategic_state["route_branch_node_id"] = str(graph.get("route_branch_node_id", route_state.get("route_branch_node_id", "")))
	strategic_state["route_choice_locked"] = bool(graph.get("route_choice_locked", route_state.get("route_choice_locked", false)))
	strategic_state["route_flags"] = (graph.get("route_flags", route_state.get("route_flags", {})) as Dictionary).duplicate(true)
	strategic_state["lightness_level"] = int(graph.get("lightness_level", route_state.get("lightness_level", strategic_state.get("lightness_level", 1))))
	strategic_state["old_case_progress"] = int(graph.get("old_case_progress", route_state.get("old_case_progress", strategic_state.get("old_case_progress", 0))))
	strategic_state["military_merit"] = int(route_state.get("military_merit", strategic_state.get("military_merit", 0)))
	strategic_state["clean_reputation"] = int(route_state.get("clean_reputation", strategic_state.get("clean_reputation", 0)))
	strategic_state["case_clues"] = int(route_state.get("case_clues", strategic_state.get("case_clues", 0)))
	strategic_state["martial_level"] = int(route_state.get("martial_realm", strategic_state.get("martial_level", 1)))
	return true


static func apply_route_state_to_graph(graph: Dictionary, route_state: Dictionary) -> void:
	graph["current_node_id"] = str(route_state.get("current_node_id", graph.get("current_node_id", "")))
	graph["selected_node_id"] = str(route_state.get("selected_node_id", graph.get("selected_node_id", "")))
	graph["completed_node_ids"] = _string_array(route_state.get("completed_node_ids", graph.get("completed_node_ids", [])))
	graph["visited_node_ids"] = _string_array(route_state.get("visited_node_ids", graph.get("visited_node_ids", route_state.get("completed_node_ids", []))))
	graph["available_node_ids"] = _string_array(route_state.get("available_next_node_ids", graph.get("available_node_ids", [])))
	graph["pending_map_node_id"] = str(route_state.get("pending_map_node_id", graph.get("pending_map_node_id", "")))
	graph["pending_result_text"] = str(route_state.get("pending_result_text", graph.get("pending_result_text", "")))
	graph["pending_effects"] = (route_state.get("pending_effects", graph.get("pending_effects", {})) as Dictionary).duplicate(true)
	graph["visited_path_order"] = _string_array(route_state.get("visited_path_order", graph.get("visited_path_order", [])))
	graph["battle_count_so_far"] = int(route_state.get("battle_count_so_far", graph.get("battle_count_so_far", 0)))
	graph["elite_count_so_far"] = int(route_state.get("elite_count_so_far", graph.get("elite_count_so_far", 0)))
	graph["operation_count_so_far"] = int(route_state.get("operation_count_so_far", graph.get("operation_count_so_far", 0)))
	graph["selected_ending_route"] = str(route_state.get("selected_ending_route", graph.get("selected_ending_route", "")))
	graph["available_ending_routes"] = _string_array(route_state.get("available_ending_routes", graph.get("available_ending_routes", [])))
	graph["locked_ending_routes"] = _string_array(route_state.get("locked_ending_routes", graph.get("locked_ending_routes", [])))
	graph["route_lock_reasons"] = (route_state.get("route_lock_reasons", graph.get("route_lock_reasons", {})) as Dictionary).duplicate(true)
	graph["route_branch_pending"] = bool(route_state.get("route_branch_pending", graph.get("route_branch_pending", false)))
	graph["route_branch_node_id"] = str(route_state.get("route_branch_node_id", graph.get("route_branch_node_id", "")))
	graph["route_choice_locked"] = bool(route_state.get("route_choice_locked", graph.get("route_choice_locked", false)))
	graph["route_flags"] = (route_state.get("route_flags", graph.get("route_flags", {})) as Dictionary).duplicate(true)
	graph["lightness_level"] = int(route_state.get("lightness_level", graph.get("lightness_level", 1)))
	graph["old_case_progress"] = int(route_state.get("old_case_progress", graph.get("old_case_progress", 0)))
	graph["aigc_dungeon_runtime"] = true
	AigcDungeonRouteBranchEvaluator.refresh_route_presentation(graph, route_state)
	StrategicNetworkMapRuntime.ensure_selected_node(graph)
	StrategicNetworkMapRuntime.refresh_node_states(graph)


static func has_compatible_map_file() -> bool:
	return is_dungeon_profile_active() and FileAccess.file_exists(BIG_MAP_COMPATIBLE_PATH)


static func is_dungeon_profile_active() -> bool:
	var active := _optional_json_dict(ACTIVE_PROFILE_PATH)
	var current := _optional_json_dict(CURRENT_RELEASE_PATH)
	var active_profile_id := str(active.get("active_mechanic_profile_id", active.get("mechanic_profile_id", "")))
	var active_pack_id := str(active.get("active_content_pack_id", active.get("content_pack_id", "")))
	var current_profile_id := str(current.get("mechanic_profile_id", ""))
	var current_pack_id := str(current.get("content_pack_id", ""))
	return active_profile_id == DUNGEON_PROFILE_ID and active_pack_id == DUNGEON_CONTENT_PACK_ID and current_profile_id == DUNGEON_PROFILE_ID and current_pack_id == DUNGEON_CONTENT_PACK_ID


static func _validate_graph(graph: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ROOT_REQUIRED_FIELDS:
		if not graph.has(field):
			errors.append("missing_root_field:%s" % field)
	var nodes: Array = graph.get("nodes", [])
	for item in nodes:
		if not (item is Dictionary):
			errors.append("non_dictionary_node")
			continue
		var node := item as Dictionary
		for field in NODE_REQUIRED_FIELDS:
			if not node.has(field):
				errors.append("missing_node_field:%s:%s" % [str(node.get("map_graph_id", "")), field])
	return errors


static func _enrich_graph_nodes(graph: Dictionary, map_instance: Dictionary, loadout: Dictionary, battle_entry_request: Dictionary) -> void:
	var map_nodes_by_id: Dictionary = {}
	for item in map_instance.get("nodes", []):
		if item is Dictionary:
			var node := item as Dictionary
			map_nodes_by_id[str(node.get("node_id", ""))] = node
	var selected_node_id := str(loadout.get("node_id", ""))
	var nodes: Array = graph.get("nodes", [])
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		var node := (nodes[index] as Dictionary).duplicate(true)
		var graph_id := str(node.get("map_graph_id", ""))
		var aigc_node: Dictionary = map_nodes_by_id.get(graph_id, {}) as Dictionary
		if not aigc_node.is_empty():
			node["battle_slot_id"] = str(aigc_node.get("battle_slot_id", ""))
			node["operation_node_id"] = str(aigc_node.get("operation_node_id", ""))
			node["aigc_node_type"] = str(aigc_node.get("node_type", ""))
			node["route_tags"] = aigc_node.get("route_tags", [])
			node["old_case_tags"] = aigc_node.get("old_case_tags", [])
		if graph_id == selected_node_id:
			node["source_battle_slot_id"] = str(loadout.get("battle_slot_id", node.get("battle_slot_id", "")))
			node["source_enemy_deck_id"] = str(loadout.get("enemy_deck_id", ""))
			node["source_reward_plan_id"] = str(loadout.get("reward_plan_id", ""))
			if str(node.get("encounter_id", "")).is_empty():
				node["encounter_id"] = str(battle_entry_request.get("encounter_id", ""))
			if str(node.get("battle_id", "")).is_empty():
				node["battle_id"] = str(battle_entry_request.get("battle_id", ""))
			if str(node.get("combat_pool_id", "")).is_empty():
				node["combat_pool_id"] = str(battle_entry_request.get("combat_pool_id", ""))
		nodes[index] = node
	graph["nodes"] = nodes


static func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"error": "missing_file",
			"path": path,
		}
	var file := FileAccess.open(path, FileAccess.READ)
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
		"data": parsed as Dictionary,
	}


static func _optional_json_dict(path: String) -> Dictionary:
	var result := _read_json_dict(path)
	if not bool(result.get("ok", false)):
		return {}
	return (result.get("data", {}) as Dictionary).duplicate(true)


static func _string_array(value) -> Array:
	var result: Array = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	return result
