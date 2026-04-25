extends "res://scripts/narrative/narrative_demo_controller.gd"
class_name NarrativeDemoControllerClickableMap

const NarrativeMapClickRouterScript := preload("res://scripts/narrative/narrative_map_click_router.gd")

func _build_static_map_node_card(node_entry: Dictionary) -> Control:
	var node_id := str(node_entry.get("node_id", ""))
	var node := narrative.node_by_id(node_id)
	var node_type := str(node.get("type", ""))
	var is_current := node_id == narrative.current_node_id and narrative.current_ending_id.is_empty() and not showing_prologue
	var is_visited := narrative.visited_node_ids.has(node_id) and not showing_prologue
	var is_available := _is_static_map_node_available(node_id)
	var hint := NarrativeMapClickRouterScript.click_hint(narrative, node_id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(156, 30)
	button.text = "%s %s %s" % [_static_map_marker(is_current, is_visited, is_available), _node_type_icon(node_type), str(node.get("title", node_id))]
	button.clip_text = true
	button.tooltip_text = hint
	button.pressed.connect(_on_static_map_node_pressed.bind(node_id))

	var normal_style := _make_map_button_style(is_current, is_visited, is_available, false)
	var hover_style := _make_map_button_style(is_current, is_visited, true, true)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_font_size_override("font_size", 12)
	return button

func _make_map_button_style(is_current: bool, is_visited: bool, is_available: bool, is_hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.bg_color = Color("202936")
	style.border_color = Color("536171")
	if is_available:
		style.bg_color = Color("203240")
		style.border_color = Color("6f8899")
	if is_visited:
		style.bg_color = Color("263548")
		style.border_color = Color("7d8fa6")
	if is_current:
		style.bg_color = Color("3a2c18")
		style.border_color = Color("d8b26e")
	if is_hover:
		style.border_color = Color("e0c27a")
	return style

func _on_static_map_node_pressed(node_id: String) -> void:
	var hint := NarrativeMapClickRouterScript.click_hint(narrative, node_id)
	if hint != "可前往":
		result_label.text = "地图节点：%s。" % hint
		_force_cjk_font()
		return
	var result := NarrativeMapClickRouterScript.click_node(narrative, node_id)
	if not bool(result.get("ok", false)):
		result_label.text = str(result.get("result", "无法前往该节点。"))
		_force_cjk_font()
		return
	waiting_result = false
	_render_node()
	_force_cjk_font()
