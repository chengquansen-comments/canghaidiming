extends Control

signal node_clicked(map_graph_id: String)
signal pan_requested(delta: Vector2)

const StrategicNetworkMapStyle := preload("res://scripts/strategic_network_map_style.gd")

var graph: Dictionary = {}
var selected_node_id: String = ""
var _pan_dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = StrategicNetworkMapStyle.DEFAULT_MINIMUM_SIZE
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func set_graph(new_graph: Dictionary, new_selected_node_id: String) -> void:
	graph = new_graph.duplicate(true)
	selected_node_id = new_selected_node_id
	custom_minimum_size = _desired_canvas_size()
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	_draw_edges(false)
	_draw_edges(true)
	_draw_nodes()
	_draw_legend()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				var clicked_id := _find_node_at(mouse_event.position)
				if not clicked_id.is_empty():
					node_clicked.emit(clicked_id)
					_pan_dragging = false
				else:
					_pan_dragging = true
			else:
				_pan_dragging = false
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_dragging = mouse_event.pressed
	elif event is InputEventMouseMotion and _pan_dragging:
		var motion := event as InputEventMouseMotion
		pan_requested.emit(motion.relative)

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
	var progress_ranges := _compute_progress_ranges(nodes)
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
			if not title.is_empty() and StrategicNetworkMapStyle.should_draw_title(state, is_selected):
				_draw_centered_text(
					font,
					title,
					pos + Vector2(0.0, StrategicNetworkMapStyle.NODE_RADIUS + 19.0),
					StrategicNetworkMapStyle.TITLE_FONT_SIZE,
					StrategicNetworkMapStyle.state_title_color(state)
				)
			if StrategicNetworkMapStyle.should_draw_badge(state, is_selected, node_type):
				_draw_progress_badges(font, node, pos, progress_ranges)

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

func _draw_progress_badges(font: Font, node: Dictionary, pos: Vector2, progress_ranges: Dictionary) -> void:
	var node_id := str(node.get("map_graph_id", ""))
	if node_id.is_empty() or not progress_ranges.has(node_id):
		return
	var progress: Dictionary = progress_ranges[node_id] as Dictionary
	var badges: Array[String] = []
	var node_type := str(node.get("node_type", ""))
	if _is_combat_node(node):
		badges.append(_badge_exact_text("B", int(progress.get("battle_ref", 0))))
		if node_type == "combat_elite":
			badges.append(_badge_exact_text("E", int(progress.get("elite_ref", 0))))
	elif _is_operation_count_node(node):
		badges.append(_badge_exact_text("O", int(progress.get("operation_ref", 0))))
	if badges.is_empty():
		return
	var total_width := 0.0
	var badge_sizes: Array[Vector2] = []
	for badge in badges:
		var size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, StrategicNetworkMapStyle.BADGE_FONT_SIZE)
		var box := Vector2(
			size.x + StrategicNetworkMapStyle.BADGE_PADDING_X * 2.0,
			size.y + StrategicNetworkMapStyle.BADGE_PADDING_Y * 2.0
		)
		badge_sizes.append(box)
		total_width += box.x
	total_width += StrategicNetworkMapStyle.BADGE_SPACING * max(0, badges.size() - 1)
	var cursor_x := pos.x - total_width * 0.5
	var top := pos.y - StrategicNetworkMapStyle.BADGE_OFFSET_Y
	for i in range(badges.size()):
		var badge := badges[i]
		var box: Vector2 = badge_sizes[i]
		var kind := badge.substr(0, 1)
		var rect := Rect2(Vector2(cursor_x, top), box)
		draw_rect(rect, StrategicNetworkMapStyle.badge_fill_color(kind), true)
		draw_rect(rect, Color(0.96, 0.90, 0.78, 0.85), false, 1.5)
		draw_string(
			font,
			Vector2(rect.position.x + StrategicNetworkMapStyle.BADGE_PADDING_X, rect.position.y + box.y - StrategicNetworkMapStyle.BADGE_PADDING_Y),
			badge,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			StrategicNetworkMapStyle.BADGE_FONT_SIZE,
			StrategicNetworkMapStyle.badge_text_color()
		)
		cursor_x += box.x + StrategicNetworkMapStyle.BADGE_SPACING

func _badge_exact_text(prefix: String, value: int) -> String:
	if value <= 0:
		return prefix + "0"
	return "%s%d" % [prefix, value]

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
			if item is Dictionary and not bool((item as Dictionary).get("hidden", false)):
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
	return _layout_pos(node)

func _compute_progress_ranges(nodes: Array) -> Dictionary:
	var node_by_id := _node_dict(nodes)
	var sorted_nodes := nodes.duplicate()
	sorted_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var la := int(a.get("layer", 0))
		var lb := int(b.get("layer", 0))
		if la != lb:
			return la < lb
		return str(a.get("map_graph_id", "")) < str(b.get("map_graph_id", ""))
	)
	var progress: Dictionary = {}
	for node in sorted_nodes:
		var node_id := str(node.get("map_graph_id", ""))
		if node_id.is_empty():
			continue
		var incoming: Array = node.get("incoming", [])
		var battle_delta := 1 if _is_combat_node(node) else 0
		var elite_delta := 1 if str(node.get("node_type", "")) == "combat_elite" else 0
		var operation_delta := 1 if _is_operation_count_node(node) else 0
		if incoming.is_empty():
			progress[node_id] = {
				"battle_min": battle_delta,
				"battle_max": battle_delta,
				"battle_ref": battle_delta,
				"elite_min": elite_delta,
				"elite_max": elite_delta,
				"elite_ref": elite_delta,
				"operation_min": operation_delta,
				"operation_max": operation_delta,
				"operation_ref": operation_delta,
			}
			continue
		var battle_min := 9999
		var battle_max := -1
		var elite_min := 9999
		var elite_max := -1
		var operation_min := 9999
		var operation_max := -1
		var preferred_incoming_id := _preferred_incoming_id(incoming)
		var preferred_progress: Dictionary = {}
		for incoming_id_variant in incoming:
			var incoming_id := str(incoming_id_variant)
			if incoming_id.is_empty():
				continue
			var prev: Dictionary = {}
			if progress.has(incoming_id):
				prev = progress[incoming_id] as Dictionary
			elif node_by_id.has(incoming_id):
				prev = {
					"battle_min": 0,
					"battle_max": 0,
					"elite_min": 0,
					"elite_max": 0,
					"operation_min": 0,
					"operation_max": 0,
				}
			else:
				continue
			battle_min = mini(battle_min, int(prev.get("battle_min", 0)) + battle_delta)
			battle_max = maxi(battle_max, int(prev.get("battle_max", 0)) + battle_delta)
			elite_min = mini(elite_min, int(prev.get("elite_min", 0)) + elite_delta)
			elite_max = maxi(elite_max, int(prev.get("elite_max", 0)) + elite_delta)
			operation_min = mini(operation_min, int(prev.get("operation_min", 0)) + operation_delta)
			operation_max = maxi(operation_max, int(prev.get("operation_max", 0)) + operation_delta)
			if incoming_id == preferred_incoming_id:
				preferred_progress = prev
		if battle_max < 0:
			battle_min = battle_delta
			battle_max = battle_delta
			elite_min = elite_delta
			elite_max = elite_delta
			operation_min = operation_delta
			operation_max = operation_delta
		var battle_ref := int(preferred_progress.get("battle_ref", preferred_progress.get("battle_max", 0))) + battle_delta
		var elite_ref := int(preferred_progress.get("elite_ref", preferred_progress.get("elite_max", 0))) + elite_delta
		var operation_ref := int(preferred_progress.get("operation_ref", preferred_progress.get("operation_max", 0))) + operation_delta
		if preferred_progress.is_empty():
			battle_ref = battle_max
			elite_ref = elite_max
			operation_ref = operation_max
		progress[node_id] = {
			"battle_min": battle_min,
			"battle_max": battle_max,
			"battle_ref": battle_ref,
			"elite_min": elite_min,
			"elite_max": elite_max,
			"elite_ref": elite_ref,
			"operation_min": operation_min,
			"operation_max": operation_max,
			"operation_ref": operation_ref,
		}
	return progress

func _preferred_incoming_id(incoming: Array) -> String:
	var preferred := ""
	for item in incoming:
		var node_id := str(item)
		if node_id.is_empty():
			continue
		if preferred.is_empty() or node_id < preferred:
			preferred = node_id
	return preferred

func _is_combat_node(node: Dictionary) -> bool:
	return str(node.get("node_type", "")).begins_with("combat_")

func _is_operation_count_node(node: Dictionary) -> bool:
	if _is_combat_node(node):
		return false
	var node_id := str(node.get("map_graph_id", ""))
	if node_id == "node_start" or node_id.begins_with("node_route_"):
		return false
	var tags: Array = node.get("tags", [])
	for item in tags:
		var tag := str(item)
		if tag == "route_branch" or tag == "ending":
			return false
	if str(node.get("node_type", "")) == "military":
		return false
	return true

func _layout_pos(node: Dictionary) -> Vector2:
	var layer := int(node.get("layer", 0))
	var lane := int(node.get("lane", 0))
	var count := _layer_node_count(layer)
	var lane_gap := StrategicNetworkMapStyle.LANE_CLUSTER_HEIGHT / float(max(1, count + 1))
	var x := StrategicNetworkMapStyle.CANVAS_PADDING_X + float(layer) * StrategicNetworkMapStyle.LAYER_GAP
	var y := StrategicNetworkMapStyle.CANVAS_PADDING_Y + float(lane + 1) * lane_gap
	return Vector2(x, y)

func _desired_canvas_size() -> Vector2:
	var max_layer := 0
	var max_count := 1
	for item in _node_array():
		var node := item as Dictionary
		max_layer = maxi(max_layer, int(node.get("layer", 0)))
		max_count = maxi(max_count, _layer_node_count(int(node.get("layer", 0))))
	var width := StrategicNetworkMapStyle.CANVAS_PADDING_X * 2.0 + float(max_layer) * StrategicNetworkMapStyle.LAYER_GAP + StrategicNetworkMapStyle.LAYER_GAP
	var height := StrategicNetworkMapStyle.CANVAS_PADDING_Y * 2.0 + StrategicNetworkMapStyle.LANE_CLUSTER_HEIGHT + StrategicNetworkMapStyle.LEGEND_RESERVED_HEIGHT
	return Vector2(
		maxf(StrategicNetworkMapStyle.DEFAULT_MINIMUM_SIZE.x, width),
		maxf(StrategicNetworkMapStyle.DEFAULT_MINIMUM_SIZE.y, height)
	)

func _layer_node_count(layer: int) -> int:
	var count := 0
	for item in _node_array():
		var node := item as Dictionary
		if int(node.get("layer", -1)) == layer:
			count += 1
	return max(1, count)
