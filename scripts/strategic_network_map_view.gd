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

func node_canvas_pos(map_graph_id: String) -> Vector2:
	if map_graph_id.is_empty():
		return Vector2(-1.0, -1.0)
	for node in _node_array():
		if str(node.get("map_graph_id", "")) == map_graph_id:
			return _node_pos(node)
	return Vector2(-1.0, -1.0)

func set_graph(new_graph: Dictionary, new_selected_node_id: String) -> void:
	graph = new_graph.duplicate(true)
	selected_node_id = new_selected_node_id
	custom_minimum_size = _desired_canvas_size()
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	_draw_canvas_background()
	_draw_layer_guides()
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
	var current_node_id := str(graph.get("current_node_id", ""))
	for node in nodes:
		var pos := _node_pos(node)
		var node_type := str(node.get("node_type", ""))
		var meta: Dictionary = StrategicNetworkMapStyle.node_type_meta(node_type)
		var mark := str(meta.get("mark", "?"))
		var base_color: Color = meta.get("color", Color(0.42, 0.42, 0.42))
		var state := str(node.get("state", "locked"))
		var node_id := str(node.get("map_graph_id", ""))
		var is_selected := node_id == selected_node_id
		var is_current := node_id == current_node_id
		var fill_color := StrategicNetworkMapStyle.state_fill_color(base_color, state)
		var outline_color := StrategicNetworkMapStyle.state_outline_color(state)
		if state == "available" or state == "start":
			draw_circle(
				pos,
				StrategicNetworkMapStyle.NODE_RADIUS + StrategicNetworkMapStyle.AVAILABLE_AURA_EXTRA_RADIUS,
				StrategicNetworkMapStyle.available_aura_color()
			)
		if is_selected:
			draw_circle(
				pos,
				StrategicNetworkMapStyle.NODE_RADIUS + StrategicNetworkMapStyle.SELECTED_RING_EXTRA_RADIUS,
				StrategicNetworkMapStyle.selected_ring_color()
			)
		draw_circle(pos, StrategicNetworkMapStyle.NODE_RADIUS + StrategicNetworkMapStyle.OUTLINE_EXTRA_RADIUS, outline_color)
		draw_circle(pos, StrategicNetworkMapStyle.NODE_RADIUS, fill_color)
		if is_current:
			draw_circle(
				pos + Vector2(0.0, -StrategicNetworkMapStyle.NODE_RADIUS - 13.0),
				4.0,
				StrategicNetworkMapStyle.current_node_dot_color()
			)
		if font != null:
			_draw_centered_text(
				font,
				mark,
				pos,
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
	var legend_lines := [
		StrategicNetworkMapStyle.LEGEND_TEXT,
		"朱线为已通塘报，朱圈为当前批选，淡朱外晕为可发牌前往。",
		"角标：战=累计接战  倭=累计强敌  营=累计经营。拖动画布可平移，点击汛口查看右侧批注。",
	]
	var line_height := StrategicNetworkMapStyle.LEGEND_FONT_SIZE + 6.0
	var panel_height := line_height * float(legend_lines.size()) + 18.0
	var rect := Rect2(
		Vector2(StrategicNetworkMapStyle.VIEW_PADDING - 14.0, size.y - panel_height - 12.0),
		Vector2(size.x - (StrategicNetworkMapStyle.VIEW_PADDING - 14.0) * 2.0, panel_height)
	)
	draw_rect(rect, StrategicNetworkMapStyle.legend_panel_fill_color(), true)
	draw_rect(rect, StrategicNetworkMapStyle.legend_panel_border_color(), false, 1.5)
	var text_x := rect.position.x + 14.0
	var text_y := rect.position.y + 22.0
	for line in legend_lines:
		draw_string(
			font,
			Vector2(text_x, text_y),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			StrategicNetworkMapStyle.LEGEND_FONT_SIZE,
			StrategicNetworkMapStyle.legend_color()
		)
		text_y += line_height

func _draw_centered_text(font: Font, text: String, center_pos: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	draw_string(
		font,
		center_pos + Vector2(-text_size.x * 0.5, (ascent - descent) * 0.5),
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
		badges.append(_badge_exact_text("战", int(progress.get("battle_ref", 0))))
		if node_type == "combat_elite":
			badges.append(_badge_exact_text("倭", int(progress.get("elite_ref", 0))))
	elif _is_operation_count_node(node):
		badges.append(_badge_exact_text("营", int(progress.get("operation_ref", 0))))
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

func _draw_canvas_background() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, StrategicNetworkMapStyle.background_fill_color(), true)
	_draw_map_grid()
	_draw_coast_wash()
	_draw_sea_lines()
	_draw_compass_rose()
	_draw_map_seal()
	draw_rect(rect, StrategicNetworkMapStyle.background_border_color(), false, 2.0)

func _draw_layer_guides() -> void:
	var font := get_theme_default_font()
	var max_layer := _max_layer()
	var top: float = maxf(12.0, StrategicNetworkMapStyle.CANVAS_PADDING_Y - StrategicNetworkMapStyle.HEADER_RESERVED_HEIGHT)
	var bottom: float = size.y - StrategicNetworkMapStyle.LEGEND_RESERVED_HEIGHT - 18.0
	var current_layer := int(graph.get("current_layer", 0))
	for layer in range(max_layer + 1):
		var x := StrategicNetworkMapStyle.CANVAS_PADDING_X + float(layer) * StrategicNetworkMapStyle.LAYER_GAP
		var half_band := StrategicNetworkMapStyle.LAYER_GAP * 0.42
		var left := x - half_band
		var band_rect := Rect2(Vector2(left, top), Vector2(half_band * 2.0, bottom - top))
		if layer == current_layer:
			draw_rect(band_rect, StrategicNetworkMapStyle.current_layer_band_color(), true)
			draw_rect(band_rect, StrategicNetworkMapStyle.current_layer_border_color(), false, 1.0)
		else:
			draw_line(
				Vector2(x, top + 18.0),
				Vector2(x, bottom),
				StrategicNetworkMapStyle.layer_divider_color(),
				1.0,
				true
			)
		if font != null:
			_draw_centered_text(
				font,
				StrategicNetworkMapStyle.layer_label(layer),
				Vector2(x, top + 10.0),
				StrategicNetworkMapStyle.LAYER_HEADER_FONT_SIZE,
				StrategicNetworkMapStyle.layer_header_color(layer == current_layer)
			)

func _draw_map_grid() -> void:
	var step := 72.0
	var x := StrategicNetworkMapStyle.VIEW_PADDING
	while x < size.x - StrategicNetworkMapStyle.VIEW_PADDING:
		draw_line(
			Vector2(x, StrategicNetworkMapStyle.VIEW_PADDING),
			Vector2(x, size.y - StrategicNetworkMapStyle.LEGEND_RESERVED_HEIGHT),
			StrategicNetworkMapStyle.grid_line_color(),
			1.0,
			true
		)
		x += step
	var y := StrategicNetworkMapStyle.VIEW_PADDING
	while y < size.y - StrategicNetworkMapStyle.LEGEND_RESERVED_HEIGHT:
		draw_line(
			Vector2(StrategicNetworkMapStyle.VIEW_PADDING, y),
			Vector2(size.x - StrategicNetworkMapStyle.VIEW_PADDING, y),
			StrategicNetworkMapStyle.grid_line_color(),
			1.0,
			true
		)
		y += step

func _draw_coast_wash() -> void:
	var coast: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, size.y * 0.25),
		Vector2(size.x * 0.09, size.y * 0.30),
		Vector2(size.x * 0.06, size.y * 0.42),
		Vector2(size.x * 0.16, size.y * 0.54),
		Vector2(size.x * 0.11, size.y * 0.68),
		Vector2(size.x * 0.23, size.y * 0.80),
		Vector2(size.x * 0.18, size.y),
		Vector2(0.0, size.y),
	])
	draw_colored_polygon(coast, StrategicNetworkMapStyle.coast_fill_color())
	for i in range(coast.size() - 2):
		draw_line(
			coast[i],
			coast[i + 1],
			StrategicNetworkMapStyle.coast_line_color(),
			2.0,
			true
		)

func _draw_sea_lines() -> void:
	var wash := Rect2(Vector2(size.x * 0.22, 62.0), Vector2(size.x * 0.72, size.y - 170.0))
	draw_rect(wash, StrategicNetworkMapStyle.sea_wash_color(), true)
	for i in range(7):
		var y := 115.0 + float(i) * 58.0
		var start_x := size.x * 0.24 + float(i % 2) * 18.0
		var end_x := size.x - StrategicNetworkMapStyle.VIEW_PADDING
		var cursor := start_x
		while cursor < end_x:
			draw_arc(
				Vector2(cursor + 20.0, y),
				20.0,
				0.05,
				PI - 0.05,
				16,
				StrategicNetworkMapStyle.sea_line_color(),
				1.2,
				true
			)
			cursor += 52.0

func _draw_compass_rose() -> void:
	var font := get_theme_default_font()
	var center := Vector2(size.x - 105.0, 92.0)
	var color := StrategicNetworkMapStyle.compass_color()
	draw_circle(center, 32.0, Color(color.r, color.g, color.b, 0.08))
	draw_arc(center, 32.0, 0.0, TAU, 48, color, 1.5, true)
	draw_line(center + Vector2(0.0, -38.0), center + Vector2(0.0, 38.0), color, 1.4, true)
	draw_line(center + Vector2(-38.0, 0.0), center + Vector2(38.0, 0.0), color, 1.4, true)
	draw_line(center + Vector2(-25.0, -25.0), center + Vector2(25.0, 25.0), color, 1.0, true)
	draw_line(center + Vector2(25.0, -25.0), center + Vector2(-25.0, 25.0), color, 1.0, true)
	if font != null:
		_draw_centered_text(font, "北", center + Vector2(0.0, -50.0), 16, color)
		_draw_centered_text(font, "海", center + Vector2(0.0, 4.0), 14, color)

func _draw_map_seal() -> void:
	var font := get_theme_default_font()
	var rect := Rect2(Vector2(64.0, size.y - 148.0), Vector2(68.0, 68.0))
	var color := StrategicNetworkMapStyle.seal_color()
	draw_rect(rect, Color(color.r, color.g, color.b, 0.10), true)
	draw_rect(rect, color, false, 2.0)
	if font != null:
		_draw_centered_text(font, "海防", rect.position + Vector2(34.0, 25.0), 15, color)
		_draw_centered_text(font, "勘合", rect.position + Vector2(34.0, 49.0), 15, color)

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

func _max_layer() -> int:
	var max_layer := 0
	for item in _node_array():
		var node := item as Dictionary
		max_layer = maxi(max_layer, int(node.get("layer", 0)))
	return max_layer
