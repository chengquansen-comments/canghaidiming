extends RefCounted

const WUKE_ID_FIELDS := [
	"node_id",
	"map_graph_id",
	"pool_node_id",
	"encounter_id",
	"battle_id",
	"formal_encounter_id",
	"formal_battle_id",
	"compatible_encounter_id",
	"compatible_battle_id",
	"story_arc",
	"story_stage",
	"story_role",
	"story_beat_id",
	"source_battle_slot_id",
]


static func is_wuke_map_node(node: Dictionary) -> bool:
	for field in WUKE_ID_FIELDS:
		if _is_wuke_text(node.get(field, "")):
			return true
	if _value_has_wuke_marker(node.get("tags", [])):
		return true
	if _value_has_wuke_marker(node.get("route_tags", [])):
		return true
	return false


static func sanitize_network_graph(graph: Dictionary) -> int:
	var nodes: Array = graph.get("nodes", [])
	var by_id: Dictionary = {}
	var removed_ids: Dictionary = {}
	for item in nodes:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		var node_id := str(node.get("map_graph_id", ""))
		if node_id.is_empty():
			continue
		by_id[node_id] = node
		if is_wuke_map_node(node):
			removed_ids[node_id] = true
	if removed_ids.is_empty():
		_compact_visible_layers(graph)
		return 0

	var kept_nodes: Array = []
	var kept_by_id: Dictionary = {}
	for item in nodes:
		if not (item is Dictionary):
			continue
		var node := (item as Dictionary).duplicate(true)
		var node_id := str(node.get("map_graph_id", ""))
		if node_id.is_empty() or removed_ids.has(node_id):
			continue
		kept_nodes.append(node)
		kept_by_id[node_id] = node

	for index in range(kept_nodes.size()):
		var node := kept_nodes[index] as Dictionary
		var sanitized_outgoing: Array = []
		for outgoing_variant in node.get("outgoing", []):
			var outgoing_id := str(outgoing_variant)
			if outgoing_id.is_empty():
				continue
			var bridged_ids := _visible_targets_for_outgoing(outgoing_id, by_id, removed_ids, {})
			for bridged_id in bridged_ids:
				if kept_by_id.has(bridged_id):
					_append_unique_string(sanitized_outgoing, bridged_id)
		node["outgoing"] = sanitized_outgoing
		node["incoming"] = []
		kept_nodes[index] = node

	var incoming_by_id: Dictionary = {}
	for node_id in kept_by_id.keys():
		incoming_by_id[node_id] = []
	for item in kept_nodes:
		var node := item as Dictionary
		var from_id := str(node.get("map_graph_id", ""))
		for outgoing_variant in node.get("outgoing", []):
			var to_id := str(outgoing_variant)
			if incoming_by_id.has(to_id):
				_append_unique_string(incoming_by_id[to_id], from_id)
	for index in range(kept_nodes.size()):
		var node := kept_nodes[index] as Dictionary
		var node_id := str(node.get("map_graph_id", ""))
		node["incoming"] = incoming_by_id.get(node_id, [])
		kept_nodes[index] = node

	graph["nodes"] = kept_nodes
	_compact_visible_layers(graph)
	_filter_graph_id_list(graph, "completed_node_ids", kept_by_id)
	_filter_graph_id_list(graph, "visited_node_ids", kept_by_id)
	_filter_graph_id_list(graph, "visited_path_order", kept_by_id)
	_filter_graph_id_list(graph, "available_node_ids", kept_by_id)
	_repair_runtime_selection(graph, kept_by_id)
	graph["removed_wuke_node_count"] = int(graph.get("removed_wuke_node_count", 0)) + removed_ids.size()
	return removed_ids.size()


static func _compact_visible_layers(graph: Dictionary) -> void:
	var nodes: Array = graph.get("nodes", [])
	var old_layers: Array[int] = []
	for item in nodes:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		if bool(node.get("hidden", false)):
			continue
		var layer := int(node.get("layer", 0))
		if not old_layers.has(layer):
			old_layers.append(layer)
	old_layers.sort()
	if old_layers.is_empty():
		graph["layer_count"] = 0
		return
	var layer_remap: Dictionary = {}
	for index in range(old_layers.size()):
		layer_remap[int(old_layers[index])] = index

	var by_id: Dictionary = {}
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		var node := nodes[index] as Dictionary
		var old_layer := int(node.get("layer", 0))
		var new_layer := int(layer_remap.get(old_layer, old_layer))
		if not node.has("source_layer"):
			node["source_layer"] = old_layer
		node["layer"] = new_layer
		var node_id := str(node.get("map_graph_id", ""))
		if not node_id.is_empty():
			by_id[node_id] = node
		nodes[index] = node
	graph["nodes"] = nodes
	graph["layer_count"] = old_layers.size()

	var current_id := str(graph.get("current_node_id", ""))
	if by_id.has(current_id):
		var current_node := by_id[current_id] as Dictionary
		graph["current_layer"] = int(current_node.get("layer", 0)) + 1
	else:
		var current_layer := int(graph.get("current_layer", 0))
		graph["current_layer"] = int(layer_remap.get(current_layer, current_layer))


static func _visible_targets_for_outgoing(target_id: String, by_id: Dictionary, removed_ids: Dictionary, visiting: Dictionary) -> Array:
	if not removed_ids.has(target_id):
		return [target_id]
	if visiting.has(target_id):
		return []
	visiting[target_id] = true
	var node: Dictionary = by_id.get(target_id, {}) as Dictionary
	var result: Array = []
	for next_variant in node.get("outgoing", []):
		var next_id := str(next_variant)
		if next_id.is_empty():
			continue
		for bridged_id in _visible_targets_for_outgoing(next_id, by_id, removed_ids, visiting.duplicate()):
			_append_unique_string(result, str(bridged_id))
	return result


static func _repair_runtime_selection(graph: Dictionary, kept_by_id: Dictionary) -> void:
	var completed: Array = graph.get("completed_node_ids", [])
	var current_id := str(graph.get("current_node_id", ""))
	if not current_id.is_empty() and not kept_by_id.has(current_id):
		graph["current_node_id"] = str(completed[completed.size() - 1]) if not completed.is_empty() else ""
	current_id = str(graph.get("current_node_id", ""))

	var available: Array = graph.get("available_node_ids", [])
	if available.is_empty() and kept_by_id.has(current_id):
		var current_node := kept_by_id[current_id] as Dictionary
		for outgoing_variant in current_node.get("outgoing", []):
			var outgoing_id := str(outgoing_variant)
			if not completed.has(outgoing_id):
				_append_unique_string(available, outgoing_id)
		graph["available_node_ids"] = available

	var selected_id := str(graph.get("selected_node_id", ""))
	if selected_id.is_empty() or not kept_by_id.has(selected_id):
		graph["selected_node_id"] = str(available[0]) if not available.is_empty() else current_id
	var pending_id := str(graph.get("pending_map_node_id", ""))
	if not pending_id.is_empty() and not kept_by_id.has(pending_id):
		graph["pending_map_node_id"] = ""
		graph["pending_result_text"] = ""
		graph["pending_effects"] = {}


static func _filter_graph_id_list(graph: Dictionary, field: String, kept_by_id: Dictionary) -> void:
	var result: Array = []
	for item in graph.get(field, []):
		var node_id := str(item)
		if not node_id.is_empty() and kept_by_id.has(node_id):
			_append_unique_string(result, node_id)
	graph[field] = result


static func _append_unique_string(items: Array, value: String) -> void:
	if value.is_empty() or items.has(value):
		return
	items.append(value)


static func _value_has_wuke_marker(value) -> bool:
	if value is Array or value is PackedStringArray:
		for item in value:
			if _value_has_wuke_marker(item):
				return true
		return false
	return _is_wuke_text(value)


static func _is_wuke_text(value) -> bool:
	var text := str(value)
	if text.is_empty():
		return false
	var lowered := text.to_lower()
	return lowered.contains("wuke") or lowered.contains("wuju") or text.contains("武举")
