extends Control

signal node_clicked(map_graph_id: String)

const StrategicNetworkMapStyle := preload("res://scripts/strategic_network_map_style.gd")

var graph: Dictionary = {}
var selected_node_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = StrategicNetworkMapStyle.DEFAULT_MINIMUM_SIZE

func set_graph(new_graph: Dictionary, new_selected_node_id: String) -> void:
	graph = new_graph.duplicate(true)
	selected_node_id = new_selected_node_id
	queue_redraw()

func _draw() -> void:
	_draw_edges(false)
	_draw_edges(true)
	_draw_nodes()
	_draw_legend()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var clicked_id := _find_node_at(mouse_event.position)
			if not clicked_id.is_empty():
				node_clicked.emit(clicked_id)

func _draw_edges(highlight_only: bool) -> void:
	var nodes := _node_array()
	var node_by_id := _node_dict(nodes)
	for node in nodes:
		var from_pos := _node_pos(node)
		var from_state := str(node.get("state", "locked"))
		var outgoing: Array = node.get("outgoing", [])
		for to_id_variant in outgoing:
			var to_id := str(to_id_variant)
			if not node_by_id.has(to_id):
				continue
			var to_node := node_by_id[to_id] as Dictionary
			var to_state := str(to_node.get("state", "locked"))
			var is_highlight := from_state == "completed" and (to_state == "available" or to_state == "completed")
			if highlight_only != is_highlight:
				continue
			var line_color := StrategicNetworkMapStyle.edge_color(from_state, to_state, is_highlight)
			var line_width := 4.0 if is_highlight else 2.5
			draw_line(from_pos, _node_pos(to_node), line_color, line_width, true)

func _draw_nodes() -> void:
	var nodes := _node_array()
	var font := get_theme_default_font()
	for node in nodes:
		var pos := _node_pos(node)
		var node_type := str(node.get("node_type", ""))
		var meta: Dictionary = StrategicNetworkMapStyle.node_type_meta(node_type)
		var mark := str(meta.get("mark", "?"))
		var base_color: Color = meta.get("color", Color(0.42, 0.42, 0.42))
		var state := str(node.get("state", "locked"))
		var is_selected := str(node.get("map_graph_id", "")) == selected_node_id
		var fill_color := StrategicNetworkMapStyle.state_fill_color(base_color, state)
		var outline_color := StrategicNetworkMapStyle.state_outline_color(state)
		if is_selected:
			draw_circle(
				pos,
				StrategicNetworkMapStyle.NODE_RADIUS + StrategicNetworkMapStyle.SELECTED_RING_EXTRA_RADIUS,
				StrategicNetworkMapStyle.selected_ring_color()
			)
		draw_circle(pos, StrategicNetworkMapStyle.NODE_RADIUS + StrategicNetworkMapStyle.OUTLINE_EXTRA_RADIUS, outline_color)
		draw_circle(pos, StrategicNetworkMapStyle.NODE_RADIUS, fill_color)
		if font != null:
			_draw_centered_text(
				font,
				mark,
				pos + Vector2(0.0, 8.0),
				StrategicNetworkMapStyle.MARK_FONT_SIZE,
				StrategicNetworkMapStyle.mark_color()
			)
			var title := StrategicNetworkMapStyle.short_title(str(node.get("title", "")))
			if not title.is_empty():
				_draw_centered_text(
					font,
					title,
					pos + Vector2(0.0, StrategicNetworkMapStyle.NODE_RADIUS + 19.0),
					StrategicNetworkMapStyle.TITLE_FONT_SIZE,
					StrategicNetworkMapStyle.state_title_color(state)
				)

func _draw_legend() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(
		font,
		Vector2(StrategicNetworkMapStyle.VIEW_PADDING, maxf(20.0, size.y - 12.0)),
		StrategicNetworkMapStyle.LEGEND_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		StrategicNetworkMapStyle.LEGEND_FONT_SIZE,
		StrategicNetworkMapStyle.legend_color()
	)

func _draw_centered_text(font: Font, text: String, center_pos: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		center_pos + Vector2(-text_size.x * 0.5, text_size.y * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)

func _find_node_at(pos: Vector2) -> String:
	for node in _node_array():
		var p := _node_pos(node)
		if p.distance_to(pos) <= StrategicNetworkMapStyle.NODE_RADIUS + StrategicNetworkMapStyle.CLICK_EXTRA_RADIUS:
			return str(node.get("map_graph_id", ""))
	return ""

func _node_array() -> Array:
	var result: Array = []
	var nodes_variant = graph.get("nodes", [])
	if nodes_variant is Array:
		for item in nodes_variant:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result

func _node_dict(nodes: Array) -> Dictionary:
	var node_by_id: Dictionary = {}
	for node_variant in nodes:
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			node_by_id[str(node.get("map_graph_id", ""))] = node
	return node_by_id

func _node_pos(node: Dictionary) -> Vector2:
	return _graph_to_view(Vector2(float(node.get("x", 0.0)), float(node.get("y", 0.0))))

func _graph_to_view(graph_pos: Vector2) -> Vector2:
	var bounds: Dictionary = _graph_bounds()
	var min_pos: Vector2 = bounds.get("min", Vector2.ZERO)
	var max_pos: Vector2 = bounds.get("max", Vector2.ONE)
	var graph_size: Vector2 = max_pos - min_pos
	graph_size.x = maxf(1.0, graph_size.x)
	graph_size.y = maxf(1.0, graph_size.y)
	var view_size: Vector2 = size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = custom_minimum_size
	var usable_width: float = maxf(1.0, view_size.x - StrategicNetworkMapStyle.VIEW_PADDING * 2.0)
	var usable_height: float = maxf(1.0, view_size.y - StrategicNetworkMapStyle.VIEW_PADDING * 2.0 - StrategicNetworkMapStyle.LEGEND_RESERVED_HEIGHT)
	var scale_factor: float = minf(usable_width / graph_size.x, usable_height / graph_size.y)
	var used_size: Vector2 = graph_size * scale_factor
	var origin: Vector2 = Vector2(
		(view_size.x - used_size.x) * 0.5,
		StrategicNetworkMapStyle.VIEW_PADDING + (usable_height - used_size.y) * 0.5
	)
	return origin + (graph_pos - min_pos) * scale_factor

func _graph_bounds() -> Dictionary:
	var nodes: Array = _node_array()
	if nodes.is_empty():
		return {"min": Vector2.ZERO, "max": Vector2.ONE}
	var first: Dictionary = nodes[0] as Dictionary
	var min_pos: Vector2 = Vector2(float(first.get("x", 0.0)), float(first.get("y", 0.0)))
	var max_pos: Vector2 = min_pos
	for item in nodes:
		var node := item as Dictionary
		var pos: Vector2 = Vector2(float(node.get("x", 0.0)), float(node.get("y", 0.0)))
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	return {"min": min_pos, "max": max_pos}
