extends RefCounted
class_name NarrativeStaticMapLayout

const DEFAULT_LAYOUT_PATH := "res://data/narrative/mvp_static_map_layout.json"

var data: Dictionary = {}
var node_to_column: Dictionary = {}
var outgoing_edges: Dictionary = {}
var incoming_edges: Dictionary = {}

func load_from_path(path: String = DEFAULT_LAYOUT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Narrative map layout missing: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open narrative map layout: %s" % path)
		return false
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Narrative map layout is not a Dictionary: %s" % path)
		return false
	data = parsed as Dictionary
	_rebuild_indexes()
	return true

func is_loaded() -> bool:
	return not data.is_empty()

func title() -> String:
	return str(data.get("title", "行军图"))

func columns() -> Array:
	return data.get("columns", [])

func edges() -> Array:
	return data.get("edges", [])

func node_ids() -> Array[String]:
	var result: Array[String] = []
	for column_value in columns():
		if typeof(column_value) != TYPE_DICTIONARY:
			continue
		var column: Dictionary = column_value
		var nodes: Array = column.get("nodes", [])
		for node_value in nodes:
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("node_id", ""))
			if not node_id.is_empty():
				result.append(node_id)
	return result

func column_for_node(node_id: String) -> String:
	return str(node_to_column.get(node_id, ""))

func next_nodes(node_id: String) -> Array[String]:
	return _string_array_from_dict(outgoing_edges, node_id)

func previous_nodes(node_id: String) -> Array[String]:
	return _string_array_from_dict(incoming_edges, node_id)

func _string_array_from_dict(src: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = src.get(key, [])
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			result.append(str(item))
	return result

func _rebuild_indexes() -> void:
	node_to_column.clear()
	outgoing_edges.clear()
	incoming_edges.clear()
	for column_value in columns():
		if typeof(column_value) != TYPE_DICTIONARY:
			continue
		var column: Dictionary = column_value
		var column_id := str(column.get("column_id", ""))
		var nodes: Array = column.get("nodes", [])
		for node_value in nodes:
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("node_id", ""))
			if not node_id.is_empty():
				node_to_column[node_id] = column_id
	for edge_value in edges():
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not outgoing_edges.has(from_id):
			outgoing_edges[from_id] = []
		if not incoming_edges.has(to_id):
			incoming_edges[to_id] = []
		outgoing_edges[from_id].append(to_id)
		incoming_edges[to_id].append(from_id)
