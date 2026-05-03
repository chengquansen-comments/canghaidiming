extends Control

signal node_clicked(map_graph_id: String)

const NODE_RADIUS := 24.0
const VIEW_PADDING := 46.0
const TITLE_MAX_CHARS := 5
const TITLE_FONT_SIZE := 13
const MARK_FONT_SIZE := 24
const LEGEND_FONT_SIZE := 12
const NODE_TYPE_META := {
	"military": {"mark": "令", "label": "军令", "color": Color(0.35, 0.48, 0.62)},
	"case": {"mark": "案", "label": "旧案", "color": Color(0.66, 0.55, 0.28)},
	"investigation": {"mark": "案", "label": "调查", "color": Color(0.66, 0.55, 0.28)},
	"combat_common": {"mark": "战", "label": "普通战斗", "color": Color(0.62, 0.28, 0.20)},
	"combat_elite": {"mark": "精", "label": "精英战", "color": Color(0.50, 0.10, 0.12)},
	"folk": {"mark": "民", "label": "民间", "color": Color(0.22, 0.50, 0.42)},
	"reputation": {"mark": "民", "label": "清望", "color": Color(0.22, 0.50, 0.42)},
	"rest": {"mark": "息", "label": "休整", "color": Color(0.38, 0.48, 0.55)},
	"master": {"mark": "师", "label": "师父", "color": Color(0.30, 0.26, 0.40)},
	"old_item": {"mark": "物", "label": "旧物", "color": Color(0.58, 0.45, 0.22)},
	"boss": {"mark": "首", "label": "首领", "color": Color(0.46, 0.08, 0.08)},
	"risk": {"mark": "险", "label": "风险", "color": Color(0.42, 0.28, 0.24)},
}

var graph: Dictionary = {}
var selected_node_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(940, 460)

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
			var line_color := _edge_color(from_state, to_state, is_highlight)
			var line_width := 4.0 if is_highlight else 2.5
			draw_line(from_pos, _node_pos(to_node), line_color, line_width, true)

func _draw_nodes() -> void:
	var nodes := _node_array()
	var font := get_theme_default_font()
	for node in nodes:
		var pos := _node_pos(node)
		var node_type := str(node.get("node_type", ""))
		var meta: Dictionary = NODE_TYPE_META.get(node_type, {"mark": "?", "label": node_type, "color": Color(0.42, 0.42, 0.42)}) as Dictionary
		var mark := str(meta.get("mark", "?"))
		var base_color: Color = meta.get("color", Color(0.42, 0.42, 0.42))
		var state := str(node.get("state", "locked"))
		var is_selected := str(node.get("map_graph_id", "")) == selected_node_id
		var fill_color := _state_fill_color(base_color, state)
		var outline_color := _state_outline_color(state)
		if is_selected:
			draw_circle(pos, NODE_RADIUS + 12.0, Color(0.92, 0.78, 0.38, 0.88))
		draw_circle(pos, NODE_RADIUS + 5.0, outline_color)
		draw_circle(pos, NODE_RADIUS, fill_color)
		if font != null:
			_draw_centered_text(font, mark, pos + Vector2(0.0, 8.0), MARK_FONT_SIZE, Color(0.96, 0.94, 0.86))
			var title := _short_title(str(node.get("title", "")))
			if not title.is_empty():
				_draw_centered_text(font, title, pos + Vector2(0.0, NODE_RADIUS + 19.0), TITLE_FONT_SIZE, _state_title_color(state))

func _draw_legend() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var text := "令军令  案旧案  战战斗  精精英  民清望  息休整  师师父  物旧物  首首领"
	draw_string(font, Vector2(VIEW_PADDING, max(20.0, size.y - 12.0)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, Color(0.78, 0.70, 0.56, 0.78))

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
		if p.distance_to(pos) <= NODE_RADIUS + 10.0:
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
	var bounds := _graph_bounds()
	var min_pos: Vector2 = bounds.get("min", Vector2.ZERO)
	var max_pos: Vector2 = bounds.get("max", Vector2.ONE)
	var graph_size := max_pos - min_pos
	graph_size.x = max(1.0, graph_size.x)
	graph_size.y = max(1.0, graph_size.y)
	var view_size := size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = custom_minimum_size
	var usable_width := max(1.0, view_size.x - VIEW_PADDING * 2.0)
	var usable_height := max(1.0, view_size.y - VIEW_PADDING * 2.0 - 34.0)
	var scale_factor: float = min(usable_width / graph_size.x, usable_height / graph_size.y)
	var used_size := graph_size * scale_factor
	var origin := Vector2(
		(view_size.x - used_size.x) * 0.5,
		VIEW_PADDING + (usable_height - used_size.y) * 0.5
	)
	return origin + (graph_pos - min_pos) * scale_factor

func _graph_bounds() -> Dictionary:
	var nodes := _node_array()
	if nodes.is_empty():
		return {"min": Vector2.ZERO, "max": Vector2.ONE}
	var first := nodes[0] as Dictionary
	var min_pos := Vector2(float(first.get("x", 0.0)), float(first.get("y", 0.0)))
	var max_pos := min_pos
	for item in nodes:
		var node := item as Dictionary
		var pos := Vector2(float(node.get("x", 0.0)), float(node.get("y", 0.0)))
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	return {"min": min_pos, "max": max_pos}

func _short_title(title: String) -> String:
	var clean := title.strip_edges()
	if clean.length() <= TITLE_MAX_CHARS:
		return clean
	return clean.substr(0, TITLE_MAX_CHARS) + "…"

func _edge_color(from_state: String, to_state: String, is_highlight: bool) -> Color:
	if is_highlight:
		return Color(0.90, 0.72, 0.35, 0.95)
	if from_state == "unreachable" or to_state == "unreachable":
		return Color(0.20, 0.20, 0.20, 0.35)
	return Color(0.50, 0.55, 0.58, 0.42)

func _state_fill_color(base_color: Color, state: String) -> Color:
	match state:
		"completed":
			return Color(0.35, 0.57, 0.33, 0.98)
		"available", "start":
			return base_color.lightened(0.08)
		"unreachable":
			return Color(0.22, 0.22, 0.22, 0.80)
		"locked":
			return Color(base_color.r * 0.55, base_color.g * 0.55, base_color.b * 0.55, 0.65)
	return base_color

func _state_outline_color(state: String) -> Color:
	match state:
		"completed":
			return Color(0.88, 0.82, 0.45, 0.95)
		"available", "start":
			return Color(0.86, 0.88, 0.90, 0.95)
		"unreachable":
			return Color(0.18, 0.18, 0.18, 0.80)
		"locked":
			return Color(0.45, 0.45, 0.47, 0.70)
	return Color(0.60, 0.60, 0.62, 0.80)

func _state_title_color(state: String) -> Color:
	match state:
		"available", "start":
			return Color(0.95, 0.88, 0.66, 0.96)
		"completed":
			return Color(0.78, 0.92, 0.72, 0.92)
		"unreachable":
			return Color(0.52, 0.52, 0.52, 0.62)
		"locked":
			return Color(0.60, 0.60, 0.62, 0.60)
	return Color(0.86, 0.82, 0.72, 0.82)
