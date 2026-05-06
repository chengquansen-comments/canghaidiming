extends RefCounted

const CanonicalMapRuntime := preload("res://scripts/narrative/canonical_map_runtime.gd")


static func make_world_map_line(index: int, current_index: int) -> Label:
	var line := Label.new()
	line.text = "━━"
	line.custom_minimum_size = Vector2(24, 34)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Color("c9a35b") if index <= current_index else Color(0.60, 0.55, 0.46, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func make_world_map_node_button(index: int, node: Dictionary, current_index: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = "%s\n%s" % [
		CanonicalMapRuntime.map_marker_for_index(index, current_index),
		str(node.get("title", ""))
	]
	btn.custom_minimum_size = Vector2(116, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = index > current_index + 1
	btn.pressed.connect(callback.bind(index))
	return btn


static func add_safe_map_buttons(
	target_box: VBoxContainer,
	columns: Array,
	nodes: Array,
	current_index: int,
	callback: Callable
) -> void:
	var column_row := HBoxContainer.new()
	column_row.add_theme_constant_override("separation", 8)
	target_box.add_child(column_row)

	for column_name in columns:
		var column_box := VBoxContainer.new()
		column_box.custom_minimum_size = Vector2(142, 0)
		column_box.add_theme_constant_override("separation", 4)
		column_row.add_child(column_box)

		var title := Label.new()
		title.text = str(column_name)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 13)
		column_box.add_child(title)

		for i in range(nodes.size()):
			var node: Dictionary = nodes[i] if nodes[i] is Dictionary else {}
			if str(node.get("column", "")) == str(column_name):
				var btn := Button.new()
				btn.text = "%s %s" % [
					CanonicalMapRuntime.map_marker_for_index(i, current_index),
					str(node.get("title", ""))
				]
				btn.custom_minimum_size = Vector2(136, 38)
				btn.pressed.connect(callback.bind(i))
				column_box.add_child(btn)
