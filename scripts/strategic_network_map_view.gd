extends Control

signal node_clicked(map_graph_id: String)

const NODE_RADIUS := 24.0
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
	_draw_edges()
	_draw_nodes()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var clicked_id := _find_node_at(mouse_event.position)
			if not clicked_id.is_empty():
				node_clicked.emit(clicked_id)

func _draw_edges() -> void:
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
			var to_pos := _node_pos(to_node)
			var to_state := str(to_node.get("state", "locked"))
			var line_color := Color(0.50, 0.55, 0.58, 0.45)
			if from_state == "completed" and (to_state == "available" or to_state == "completed"):
				line_color = Color(0.90, 0.72, 0.35, 0.95)
			elif from_state == "unreachable" or to_state == "unreachable":
				line_color = Color(0.20, 0.20, 0.20, 0.35)
			draw_line(from_pos, to_pos, line_color, 3.0, true)

func _draw_nodes() -> void:
	var nodes := _node_array()
	var font := get_theme_default_font()
	var font_size := 24
	for node in nodes:
		var pos := _node_pos(node)
		var node_type := str(node.get("node_type", ""))
		var meta: Dictionary = NODE_TYPE_META.get(node_type, {"mark": "?", "label": node_type, "color": Color(0.42, 0.42, 0.42)}) as Dictionary
		var mark := str((meta as Dictionary).get("mark", "?"))
		var base_color: Color = (meta as Dictionary).get("color", Color(0.42, 0.42, 0.42))
		var state := str(node.get("state", "locked"))
		var is_selected := str(node.get("map_graph_id", "")) == selected_node_id
		var fill_color := _state_fill_color(base_color, state)
		var outline_color := _state_outline_color(state)
		draw_circle(pos, NODE_RADIUS + 5.0, outline_color)
		if is_selected:
			draw_circle(pos, NODE_RADIUS + 10.0, Color(0.92, 0.78, 0.38, 0.90))
		draw_circle(pos, NODE_RADIUS, fill_color)
		if font != null:
			var text_size := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(
				font,
				pos + Vector2(-text_size.x * 0.5, text_size.y * 0.35),
				mark,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color(0.96, 0.94, 0.86)
			)

func _find_node_at(pos: Vector2) -> String:
	for node in _node_array():
		var p := _node_pos(node)
		if p.distance_to(pos) <= NODE_RADIUS + 8.0:
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
	return Vector2(float(node.get("x", 0.0)), float(node.get("y", 0.0)))

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
