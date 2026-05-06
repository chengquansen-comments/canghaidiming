extends RefCounted

# Top world-map strip for the focused narrative UI.
#
# Requires owner:
# - focus_world_map_layer / panel / status_label / nodes_row fields
# - in_prologue, jun_gong, qing_wang, clues, node_index
# - _prologue_map_title(), _node_data_at(), _world_map_total_count(), _world_map_current_index()
# - _on_world_map_node_pressed(index)

var c

func _init(controller) -> void:
	c = controller


func add_world_map_layer() -> void:
	if c.focus_world_map_layer != null:
		return
	c.focus_world_map_layer = Control.new()
	c.focus_world_map_layer.name = "FocusWorldMapLayer"
	c.focus_world_map_layer.anchor_left = 0.0
	c.focus_world_map_layer.anchor_top = 0.0
	c.focus_world_map_layer.anchor_right = 1.0
	c.focus_world_map_layer.anchor_bottom = 0.33
	c.focus_world_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_world_map_layer.z_index = 60
	c.focus_world_map_layer.z_as_relative = false
	c.add_child(c.focus_world_map_layer)

	c.focus_world_map_panel = PanelContainer.new()
	c.focus_world_map_panel.name = "FocusWorldMapPanel"
	c.focus_world_map_panel.anchor_left = 0.055
	c.focus_world_map_panel.anchor_top = 0.035
	c.focus_world_map_panel.anchor_right = 0.945
	c.focus_world_map_panel.anchor_bottom = 0.205
	c.focus_world_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_world_map_panel.z_index = 61
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.030, 0.024, 0.66)
	style.border_color = Color(0.74, 0.60, 0.38, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	c.focus_world_map_panel.add_theme_stylebox_override("panel", style)
	c.focus_world_map_layer.add_child(c.focus_world_map_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_world_map_panel.add_child(root)

	c.focus_world_map_status_label = Label.new()
	c.focus_world_map_status_label.name = "FocusWorldMapStatusLabel"
	c.focus_world_map_status_label.add_theme_font_size_override("font_size", 14)
	c.focus_world_map_status_label.add_theme_color_override("font_color", Color("f0dfb8"))
	c.focus_world_map_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	c.focus_world_map_status_label.add_theme_constant_override("shadow_offset_x", 1)
	c.focus_world_map_status_label.add_theme_constant_override("shadow_offset_y", 1)
	c.focus_world_map_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c.focus_world_map_status_label)

	c.focus_world_map_nodes_row = HBoxContainer.new()
	c.focus_world_map_nodes_row.name = "FocusWorldMapNodesRow"
	c.focus_world_map_nodes_row.add_theme_constant_override("separation", 5)
	c.focus_world_map_nodes_row.mouse_filter = Control.MOUSE_FILTER_PASS
	c.focus_world_map_nodes_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(c.focus_world_map_nodes_row)
	refresh_world_map()


func refresh_world_map() -> void:
	if c.focus_world_map_layer == null or c.focus_world_map_panel == null or c.focus_world_map_nodes_row == null:
		return
	var should_show: bool = not c.in_prologue
	c.focus_world_map_layer.visible = should_show
	c.focus_world_map_panel.visible = should_show
	if not should_show:
		return
	if c.focus_world_map_status_label != null:
		c.focus_world_map_status_label.text = "海疆行军图｜当前：%s｜军功 %d｜清望 %d｜旧案 %d" % [current_world_map_title(), c.jun_gong, c.qing_wang, c.clues]
	for child in c.focus_world_map_nodes_row.get_children():
		child.queue_free()
	for i in range(c._world_map_total_count()):
		if i > 0:
			c.focus_world_map_nodes_row.add_child(make_world_map_line(i))
		c.focus_world_map_nodes_row.add_child(make_world_map_node_button(i))


func show_world_map_ui() -> void:
	refresh_world_map()


func current_world_map_title() -> String:
	if c.in_prologue:
		return c._prologue_map_title()
	var node: Dictionary = c._node_data_at(c.node_index)
	return str(node.get("title", ""))


func world_map_title_at(map_index: int) -> String:
	if map_index == 0:
		return c._prologue_map_title()
	var node: Dictionary = c._node_data_at(map_index - 1)
	return str(node.get("title", ""))


func world_map_marker_for_index(index: int) -> String:
	var current: int = c._world_map_current_index()
	if index == current:
		return "◆ 当前"
	if index < current:
		return "● 已过"
	if index == current + 1:
		return "◎ 可前往"
	return "○ 未开放"


func make_world_map_line(index: int) -> Label:
	var line := Label.new()
	line.text = "━━"
	line.custom_minimum_size = Vector2(24, 34)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Color("c9a35b") if index <= c._world_map_current_index() else Color(0.60, 0.55, 0.46, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func make_world_map_node_button(index: int) -> Button:
	var btn := Button.new()
	btn.text = "%s\n%s" % [world_map_marker_for_index(index), world_map_title_at(index)]
	btn.custom_minimum_size = Vector2(116, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = index > c._world_map_current_index() + 1
	btn.pressed.connect(c._on_world_map_node_pressed.bind(index))
	return btn
