extends RefCounted

# Pure runtime helpers for strategic network-map state.
# This file intentionally has no UI, scene switching, battle request, or narrative side effects.

static func find_node(graph: Dictionary, map_graph_id: String) -> Dictionary:
	var nodes: Array = graph.get("nodes", [])
	for item in nodes:
		if item is Dictionary:
			var node := item as Dictionary
			if str(node.get("map_graph_id", "")) == map_graph_id:
				return node
	return {}

static func node_by_id(graph: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var nodes: Array = graph.get("nodes", [])
	for item in nodes:
		if item is Dictionary:
			var node := item as Dictionary
			var node_id := str(node.get("map_graph_id", ""))
			if not node_id.is_empty():
				result[node_id] = node
	return result

static func valid_available_ids(graph: Dictionary, candidate_ids: Array) -> Array:
	var result: Array = []
	var completed: Array = graph.get("completed_node_ids", [])
	var by_id := node_by_id(graph)
	for item in candidate_ids:
		var node_id := str(item)
		if node_id.is_empty():
			continue
		if result.has(node_id):
			continue
		if completed.has(node_id):
			continue
		if not by_id.has(node_id):
			push_warning("network_map outgoing points to missing node: %s" % node_id)
			continue
		var node: Dictionary = by_id[node_id] as Dictionary
		var state := str(node.get("state", "locked"))
		if state == "completed" or state == "unreachable":
			continue
		result.append(node_id)
	return result

static func has_available_node(graph: Dictionary) -> bool:
	var available: Array = graph.get("available_node_ids", [])
	return not valid_available_ids(graph, available).is_empty()

static func ensure_selected_node(graph: Dictionary) -> void:
	var available := valid_available_ids(graph, graph.get("available_node_ids", []))
	graph["available_node_ids"] = available
	var selected_id := str(graph.get("selected_node_id", ""))
	if not find_node(graph, selected_id).is_empty() and available.has(selected_id):
		return
	if not available.is_empty():
		graph["selected_node_id"] = str(available[0])
	else:
		graph["selected_node_id"] = str(graph.get("current_node_id", ""))

static func complete_node(graph: Dictionary, node: Dictionary) -> void:
	var node_id := str(node.get("map_graph_id", ""))
	if node_id.is_empty():
		return
	var completed: Array = graph.get("completed_node_ids", [])
	if not completed.has(node_id):
		completed.append(node_id)
	var outgoing: Array = []
	for item in node.get("outgoing", []):
		var out_id := str(item)
		if not out_id.is_empty():
			outgoing.append(out_id)
	graph["completed_node_ids"] = completed
	graph["current_node_id"] = node_id
	graph["current_layer"] = int(node.get("layer", 0)) + 1
	var valid_outgoing := valid_available_ids(graph, outgoing)
	graph["available_node_ids"] = valid_outgoing
	if not valid_outgoing.is_empty():
		graph["selected_node_id"] = str(valid_outgoing[0])
		graph["map_complete"] = false
	else:
		graph["selected_node_id"] = node_id
		graph["map_complete"] = true

static func refresh_node_states(graph: Dictionary) -> void:
	var completed: Array = graph.get("completed_node_ids", [])
	var available: Array = graph.get("available_node_ids", [])
	var current_layer := int(graph.get("current_layer", 0))
	var nodes: Array = graph.get("nodes", [])
	for i in range(nodes.size()):
		if not (nodes[i] is Dictionary):
			continue
		var node := nodes[i] as Dictionary
		var node_id := str(node.get("map_graph_id", ""))
		var layer := int(node.get("layer", 0))
		if completed.has(node_id):
			node["state"] = "completed"
		elif available.has(node_id):
			node["state"] = "available"
		elif layer <= current_layer:
			node["state"] = "unreachable"
		else:
			node["state"] = "locked"
		nodes[i] = node
	graph["nodes"] = nodes

static func clear_pending(graph: Dictionary) -> void:
	graph["pending_map_node_id"] = ""
	graph["pending_result_text"] = ""
	graph["pending_effects"] = {}

static func sync_mirror_fields(strategic_state: Dictionary, graph: Dictionary) -> void:
	strategic_state["network_map"] = graph
	strategic_state["selected_node_id"] = str(graph.get("selected_node_id", ""))
	strategic_state["available_node_ids"] = (graph.get("available_node_ids", []) as Array).duplicate(true)
	strategic_state["completed_node_ids"] = (graph.get("completed_node_ids", []) as Array).duplicate(true)
	strategic_state["current_node_id"] = str(graph.get("current_node_id", ""))
	strategic_state["pending_map_node_id"] = str(graph.get("pending_map_node_id", ""))
	strategic_state["pending_result_text"] = str(graph.get("pending_result_text", ""))
	strategic_state["pending_effects"] = (graph.get("pending_effects", {}) as Dictionary).duplicate(true)
