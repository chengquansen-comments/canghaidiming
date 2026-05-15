extends RefCounted

const ROUTE_NORMAL := "normal"
const ROUTE_TRUE := "true"
const ROUTE_WUZHUANGYUAN := "wuzhuangyuan"

const TRUE_OLD_CASE_THRESHOLD := 3
const TRUE_CASE_CLUE_THRESHOLD := 2
const WUZHUANGYUAN_MILITARY_HIGH_THRESHOLD := 9


static func evaluate_route_branch(route_state: Dictionary, route_rules: Dictionary, current_node: Dictionary = {}, graph: Dictionary = {}) -> Dictionary:
	var branch_node_id := str(current_node.get("map_graph_id", current_node.get("node_id", route_state.get("route_branch_node_id", route_state.get("current_node_id", "")))))
	var route_flags: Dictionary = (route_state.get("route_flags", {}) as Dictionary).duplicate(true)
	var selected_ending_route := str(route_state.get("selected_ending_route", route_flags.get("selected_ending_route", "")))
	var available_route_options: Array[String] = [ROUTE_NORMAL]
	var locked_route_options: Array[String] = []
	var lock_reasons := {
		ROUTE_TRUE: [],
		ROUTE_WUZHUANGYUAN: [],
	}

	var normal_route_available := true
	var true_route_available := _true_route_available(route_state, route_flags, lock_reasons)
	var wuzhuangyuan_route_available := _wuzhuangyuan_route_available(route_state, route_flags, lock_reasons)
	if true_route_available:
		available_route_options.append(ROUTE_TRUE)
	else:
		locked_route_options.append(ROUTE_TRUE)
	if wuzhuangyuan_route_available:
		available_route_options.append(ROUTE_WUZHUANGYUAN)
	else:
		locked_route_options.append(ROUTE_WUZHUANGYUAN)

	var multiple_route_choice_supported := bool(route_rules.get("multiple_route_choice_supported", true))
	var player_choice_required := multiple_route_choice_supported and available_route_options.size() > 1
	var recommended_default_route := ROUTE_NORMAL
	if available_route_options.size() == 1 and selected_ending_route.is_empty():
		selected_ending_route = str(available_route_options[0])
	if selected_ending_route.is_empty() and available_route_options.has(ROUTE_TRUE):
		recommended_default_route = ROUTE_TRUE
	elif selected_ending_route.is_empty() and available_route_options.has(ROUTE_WUZHUANGYUAN):
		recommended_default_route = ROUTE_WUZHUANGYUAN

	var route_flags_after_eval := route_flags.duplicate(true)
	route_flags_after_eval["normal_route_available"] = normal_route_available
	route_flags_after_eval["true_route_unlocked"] = true_route_available
	route_flags_after_eval["wuzhuangyuan_route_unlocked"] = wuzhuangyuan_route_available
	route_flags_after_eval["multiple_route_choice_supported"] = multiple_route_choice_supported
	route_flags_after_eval["player_choice_required"] = player_choice_required
	route_flags_after_eval["selected_ending_route"] = selected_ending_route
	return {
		"route_branch_ready": true,
		"current_node_id": str(route_state.get("current_node_id", "")),
		"branch_node_id": branch_node_id,
		"normal_route_available": normal_route_available,
		"true_route_available": true_route_available,
		"wuzhuangyuan_route_available": wuzhuangyuan_route_available,
		"multiple_route_choice_supported": multiple_route_choice_supported,
		"player_choice_required": player_choice_required,
		"available_route_options": available_route_options,
		"locked_route_options": locked_route_options,
		"lock_reasons": lock_reasons,
		"recommended_default_route": recommended_default_route,
		"selected_ending_route": selected_ending_route,
		"route_flags_after_eval": route_flags_after_eval,
	}


static func apply_branch_result(graph: Dictionary, strategic_state: Dictionary, branch_result: Dictionary, branch_node: Dictionary = {}) -> void:
	var branch_node_id := str(branch_result.get("branch_node_id", branch_node.get("map_graph_id", "")))
	var available_route_options := _string_array(branch_result.get("available_route_options", []))
	var available_node_ids := _route_nodes_for_options(graph, branch_node, available_route_options)
	var route_flags: Dictionary = (branch_result.get("route_flags_after_eval", {}) as Dictionary).duplicate(true)
	graph["available_node_ids"] = available_node_ids
	graph["selected_node_id"] = str(available_node_ids[0]) if not available_node_ids.is_empty() else str(graph.get("current_node_id", ""))
	graph["available_ending_routes"] = available_route_options
	graph["locked_ending_routes"] = _string_array(branch_result.get("locked_route_options", []))
	graph["route_lock_reasons"] = (branch_result.get("lock_reasons", {}) as Dictionary).duplicate(true)
	graph["route_branch_node_id"] = branch_node_id
	graph["route_branch_pending"] = bool(branch_result.get("player_choice_required", false))
	graph["selected_ending_route"] = str(branch_result.get("selected_ending_route", ""))
	graph["route_choice_locked"] = not bool(branch_result.get("player_choice_required", false))
	graph["route_flags"] = route_flags
	strategic_state["available_ending_routes"] = available_node_ids_to_route_keys(graph, available_node_ids)
	strategic_state["locked_ending_routes"] = (graph.get("locked_ending_routes", []) as Array).duplicate(true)
	strategic_state["route_lock_reasons"] = (graph.get("route_lock_reasons", {}) as Dictionary).duplicate(true)
	strategic_state["route_branch_node_id"] = branch_node_id
	strategic_state["route_branch_pending"] = bool(graph.get("route_branch_pending", false))
	strategic_state["selected_ending_route"] = str(graph.get("selected_ending_route", ""))
	strategic_state["route_choice_locked"] = bool(graph.get("route_choice_locked", false))
	strategic_state["route_flags"] = route_flags.duplicate(true)


static func apply_selected_route_choice(graph: Dictionary, strategic_state: Dictionary, route_node: Dictionary) -> void:
	var route_key := route_key_for_node(route_node)
	if route_key.is_empty():
		return
	var route_flags: Dictionary = (graph.get("route_flags", strategic_state.get("route_flags", {})) as Dictionary).duplicate(true)
	route_flags["selected_ending_route"] = route_key
	route_flags["player_choice_required"] = false
	graph["selected_ending_route"] = route_key
	graph["route_branch_pending"] = false
	graph["route_choice_locked"] = true
	graph["available_ending_routes"] = [route_key]
	graph["locked_ending_routes"] = []
	graph["route_flags"] = route_flags
	strategic_state["selected_ending_route"] = route_key
	strategic_state["available_ending_routes"] = [route_key]
	strategic_state["locked_ending_routes"] = []
	strategic_state["route_branch_pending"] = false
	strategic_state["route_choice_locked"] = true
	strategic_state["route_flags"] = route_flags


static func route_key_for_node(node: Dictionary) -> String:
	for tag in _string_array(node.get("route_tags", [])):
		if tag == ROUTE_NORMAL or tag == ROUTE_TRUE or tag == ROUTE_WUZHUANGYUAN:
			return tag
	var node_id := str(node.get("map_graph_id", node.get("node_id", "")))
	if node_id.find("wuzhuangyuan") >= 0:
		return ROUTE_WUZHUANGYUAN
	if node_id.find("true") >= 0:
		return ROUTE_TRUE
	if node_id.find("normal") >= 0:
		return ROUTE_NORMAL
	return ""


static func is_branch_gate_node(node: Dictionary) -> bool:
	var aigc_node_type := str(node.get("aigc_node_type", ""))
	if aigc_node_type == "boss_gate":
		return true
	return str(node.get("map_graph_id", "")) == "node_boss_gate"


static func is_route_branch_node(node: Dictionary) -> bool:
	var aigc_node_type := str(node.get("aigc_node_type", ""))
	if aigc_node_type == "route_branch":
		return true
	return not route_key_for_node(node).is_empty() and str(node.get("map_graph_id", "")).begins_with("node_route_")


static func available_node_ids_to_route_keys(graph: Dictionary, available_node_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for node_id_variant in available_node_ids:
		var node_id := str(node_id_variant)
		if node_id.is_empty():
			continue
		var node := _find_node(graph, node_id)
		var route_key := route_key_for_node(node)
		if route_key.is_empty():
			continue
		if not result.has(route_key):
			result.append(route_key)
	return result


static func _true_route_available(route_state: Dictionary, route_flags: Dictionary, lock_reasons: Dictionary) -> bool:
	if bool(route_flags.get("true_route_unlocked", false)):
		return true
	var old_case_progress: int = int(route_state.get("old_case_progress", 0))
	var case_clues: int = int(route_state.get("case_clues", 0))
	var available: bool = old_case_progress >= TRUE_OLD_CASE_THRESHOLD and case_clues >= TRUE_CASE_CLUE_THRESHOLD
	if not available:
		if old_case_progress < TRUE_OLD_CASE_THRESHOLD:
			(lock_reasons.get(ROUTE_TRUE, []) as Array).append("old_case_progress_not_enough")
		if case_clues < TRUE_CASE_CLUE_THRESHOLD:
			(lock_reasons.get(ROUTE_TRUE, []) as Array).append("case_clues_not_enough")
	return available


static func _wuzhuangyuan_route_available(route_state: Dictionary, route_flags: Dictionary, lock_reasons: Dictionary) -> bool:
	if bool(route_flags.get("wuzhuangyuan_route_unlocked", false)):
		return true
	var martial_realm: int = max(int(route_state.get("martial_realm", route_state.get("martial_level", 0))), int(route_state.get("martial_level", route_state.get("martial_realm", 0))))
	var military_merit: int = int(route_state.get("military_merit", 0))
	var available: bool = martial_realm >= 10 and military_merit >= WUZHUANGYUAN_MILITARY_HIGH_THRESHOLD
	if not available:
		if martial_realm < 10:
			(lock_reasons.get(ROUTE_WUZHUANGYUAN, []) as Array).append("martial_realm_below_10")
		if military_merit < WUZHUANGYUAN_MILITARY_HIGH_THRESHOLD:
			(lock_reasons.get(ROUTE_WUZHUANGYUAN, []) as Array).append("military_merit_not_high")
	return available


static func _route_nodes_for_options(graph: Dictionary, branch_node: Dictionary, available_route_options: Array[String]) -> Array:
	var result: Array = []
	for outgoing_id_variant in branch_node.get("outgoing", []):
		var outgoing_id := str(outgoing_id_variant)
		if outgoing_id.is_empty():
			continue
		var next_node := _find_node(graph, outgoing_id)
		var route_key := route_key_for_node(next_node)
		if available_route_options.has(route_key):
			result.append(outgoing_id)
	return result


static func _find_node(graph: Dictionary, node_id: String) -> Dictionary:
	for item in graph.get("nodes", []):
		if item is Dictionary and str((item as Dictionary).get("map_graph_id", "")) == node_id:
			return item as Dictionary
	return {}


static func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	return result
