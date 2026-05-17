extends RefCounted

# UI overlay helper for the strategic network map.
#
# Owns overlay node creation, dynamic child cleanup, and basic panel rendering.
# It intentionally avoids graph state transitions, battle requests, narrative
# result application, and scene switching.

const StrategicNetworkMapView := preload("res://scripts/strategic_network_map_view.gd")

var owner: Control = null
var layer: Control = null
var panel: PanelContainer = null
var map_container: VBoxContainer = null
var preview_container: VBoxContainer = null
var footer_container: HBoxContainer = null
var map_scroll: ScrollContainer = null
var map_view: Control = null


func _init(owner_node: Control) -> void:
	owner = owner_node


func _make_panel_style(bg_color: Color, border_color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _create_surface_panel(parent: Node, bg_color: Color, border_color: Color, radius: int = 12, padding: int = 14) -> PanelContainer:
	var panel_node := PanelContainer.new()
	panel_node.add_theme_stylebox_override("panel", _make_panel_style(bg_color, border_color, radius, padding))
	parent.add_child(panel_node)
	return panel_node


func _style_action_button(button: Button, kind: String = "secondary") -> void:
	var normal_color := Color(0.20, 0.18, 0.15, 0.98)
	var hover_color := Color(0.29, 0.24, 0.17, 1.0)
	var pressed_color := Color(0.35, 0.26, 0.16, 1.0)
	var border_color := Color(0.55, 0.42, 0.25, 0.76)
	if kind == "primary":
		normal_color = Color(0.50, 0.11, 0.07, 0.98)
		hover_color = Color(0.62, 0.14, 0.08, 1.0)
		pressed_color = Color(0.70, 0.18, 0.10, 1.0)
		border_color = Color(0.78, 0.48, 0.30, 0.92)
	elif kind == "danger":
		normal_color = Color(0.42, 0.18, 0.16, 0.98)
		hover_color = Color(0.53, 0.22, 0.20, 1.0)
		pressed_color = Color(0.62, 0.26, 0.24, 1.0)
		border_color = Color(0.86, 0.56, 0.42, 0.92)
	var disabled_color := Color(0.15, 0.14, 0.13, 0.88)
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_color, border_color, 10, 10))
	button.add_theme_stylebox_override("hover", _make_panel_style(hover_color, border_color.lightened(0.08), 10, 10))
	button.add_theme_stylebox_override("pressed", _make_panel_style(pressed_color, border_color.lightened(0.12), 10, 10))
	button.add_theme_stylebox_override("disabled", _make_panel_style(disabled_color, Color(0.34, 0.32, 0.30, 0.60), 10, 10))
	button.add_theme_color_override("font_color", Color("f6ead2"))
	button.add_theme_color_override("font_hover_color", Color("fff6e6"))
	button.add_theme_color_override("font_pressed_color", Color("fff6e6"))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.54, 0.50, 0.92))


func ensure_layer() -> void:
	if layer != null or owner == null:
		return
	layer = Control.new()
	layer.name = "NetworkMapOverlayLayer"
	layer.anchor_left = 0.0
	layer.anchor_top = 0.0
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 180
	layer.z_as_relative = false
	owner.add_child(layer)

	var dim := ColorRect.new()
	dim.name = "NetworkMapOverlayDim"
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.015, 0.014, 0.012, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	panel = PanelContainer.new()
	panel.name = "NetworkMapOverlayPanel"
	panel.anchor_left = 0.04
	panel.anchor_top = 0.06
	panel.anchor_right = 0.96
	panel.anchor_bottom = 0.92
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.095, 0.080, 0.060, 0.96), Color(0.55, 0.42, 0.24, 0.86), 8, 20)
	)

	var root := VBoxContainer.new()
	root.name = "NetworkMapOverlayRoot"
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 4)
	root.add_child(header_box)

	var header := Label.new()
	header.name = "NetworkMapOverlayHeader"
	header.text = "海防舆图"
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color", Color("f0d7a8"))
	header_box.add_child(header)

	var subtitle := Label.new()
	subtitle.text = "武举放榜后启用的军门海防图。左阅汛路，右看塘报、牌票与预计得失。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("d4b98b"))
	header_box.add_child(subtitle)

	var main_row := HBoxContainer.new()
	main_row.name = "NetworkMapOverlayMainRow"
	main_row.add_theme_constant_override("separation", 18)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	var map_panel := _create_surface_panel(
		main_row,
		Color(0.13, 0.105, 0.075, 0.95),
		Color(0.45, 0.34, 0.20, 0.78),
		8
	)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	map_container = VBoxContainer.new()
	map_container.name = "NetworkMapContainer"
	map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_container.add_theme_constant_override("separation", 10)
	map_panel.add_child(map_container)

	var preview_panel := _create_surface_panel(
		main_row,
		Color(0.15, 0.120, 0.085, 0.96),
		Color(0.48, 0.36, 0.20, 0.82),
		8
	)
	preview_panel.custom_minimum_size = Vector2(390, 0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	preview_container = VBoxContainer.new()
	preview_container.name = "NetworkPreviewContainer"
	preview_container.custom_minimum_size = Vector2(360, 0)
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.add_theme_constant_override("separation", 10)
	preview_panel.add_child(preview_container)

	var footer_panel := _create_surface_panel(
		root,
		Color(0.12, 0.098, 0.070, 0.94),
		Color(0.40, 0.30, 0.18, 0.76),
		8
	)
	footer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	footer_container = HBoxContainer.new()
	footer_container.name = "NetworkFooterContainer"
	footer_container.add_theme_constant_override("separation", 12)
	footer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_panel.add_child(footer_container)
	layer.visible = false


func clear_dynamic() -> void:
	_clear_children(map_container)
	_clear_children(preview_container)
	_clear_children(footer_container)
	map_view = null


func set_visible(value: bool) -> void:
	if layer != null:
		layer.visible = value


func sync_visibility(should_show: bool, focus_story_layer: CanvasItem, focus_world_map_layer: CanvasItem) -> void:
	set_visible(should_show)
	if should_show:
		if focus_story_layer != null:
			focus_story_layer.visible = false
		if focus_world_map_layer != null:
			focus_world_map_layer.visible = false


func render_map_view(graph: Dictionary, progress_text: String, selected_node_id: String, node_clicked_callback: Callable) -> void:
	if map_container == null:
		return
	var heading := Label.new()
	heading.text = "沿海汛防图"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("f0d7a8"))
	map_container.add_child(heading)

	var progress := Label.new()
	progress.text = progress_text
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress.add_theme_font_size_override("font_size", 16)
	progress.add_theme_color_override("font_color", Color("d9bd86"))
	map_container.add_child(progress)

	map_scroll = ScrollContainer.new()
	map_scroll.name = "NetworkMapScroll"
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.follow_focus = true
	map_scroll.custom_minimum_size = Vector2(980, 570)
	map_scroll.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.61, 0.54, 0.40, 0.94), Color(0.32, 0.24, 0.15, 0.72), 6, 10)
	)
	map_container.add_child(map_scroll)

	map_view = StrategicNetworkMapView.new()
	map_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	map_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	map_view.set_graph(graph, selected_node_id)
	if node_clicked_callback.is_valid():
		map_view.node_clicked.connect(node_clicked_callback)
	map_view.pan_requested.connect(_on_map_pan_requested)
	map_scroll.add_child(map_view)
	var focus_ids: Array = []
	for item in graph.get("available_node_ids", []):
		var node_id := str(item)
		if not node_id.is_empty():
			focus_ids.append(node_id)
	if focus_ids.is_empty() and not selected_node_id.is_empty():
		focus_ids.append(selected_node_id)
	if focus_ids.is_empty():
		var current_node_id := str(graph.get("current_node_id", ""))
		if not current_node_id.is_empty():
			focus_ids.append(current_node_id)
	call_deferred("_focus_map_on_targets", focus_ids)


func _on_map_pan_requested(delta: Vector2) -> void:
	if map_scroll == null:
		return
	map_scroll.scroll_horizontal = max(0, map_scroll.scroll_horizontal - int(delta.x))
	map_scroll.scroll_vertical = max(0, map_scroll.scroll_vertical - int(delta.y))


func _focus_map_on_targets(target_ids: Array) -> void:
	if map_scroll == null or map_view == null or target_ids.is_empty():
		return
	var min_pos := Vector2(1e9, 1e9)
	var max_pos := Vector2(-1e9, -1e9)
	var found := false
	for item in target_ids:
		var pos: Vector2 = map_view.node_canvas_pos(str(item))
		if pos.x < 0.0 or pos.y < 0.0:
			continue
		found = true
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	if not found:
		return
	var target_center := (min_pos + max_pos) * 0.5
	var viewport := map_scroll.size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		viewport = map_scroll.custom_minimum_size
	var max_scroll_x := maxf(0.0, map_view.custom_minimum_size.x - viewport.x)
	var max_scroll_y := maxf(0.0, map_view.custom_minimum_size.y - viewport.y)
	map_scroll.scroll_horizontal = int(clampf(target_center.x - viewport.x * 0.5, 0.0, max_scroll_x))
	map_scroll.scroll_vertical = int(clampf(target_center.y - viewport.y * 0.5, 0.0, max_scroll_y))


func render_preview_panel(preview_text: String, confirm_enabled: bool, confirm_callback: Callable) -> void:
	if preview_container == null:
		return
	var heading := Label.new()
	heading.text = "军门批注"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("f0d7a8"))
	preview_container.add_child(heading)

	var hint := Label.new()
	hint.text = "发牌后即行本汛；若遇倭警海汛，会切入正式战斗场景。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("d4b98b"))
	preview_container.add_child(hint)

	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = false
	preview.scroll_active = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(340, 450)
	preview.add_theme_font_size_override("normal_font_size", 18)
	preview.add_theme_font_size_override("bold_font_size", 20)
	preview.add_theme_color_override("default_color", Color("2d2115"))
	preview.add_theme_stylebox_override(
		"normal",
		_make_panel_style(Color(0.66, 0.58, 0.42, 0.96), Color(0.34, 0.25, 0.15, 0.74), 6, 14)
	)
	preview.text = preview_text
	preview_container.add_child(preview)

	var confirm := Button.new()
	confirm.text = "发牌前往"
	confirm.disabled = not confirm_enabled
	confirm.custom_minimum_size = Vector2(0, 58)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(confirm, "primary")
	confirm.pressed.connect(confirm_callback)
	preview_container.add_child(confirm)


func render_dungeon_storage_panel(save_slot_callback: Callable, restore_slot_callback: Callable) -> void:
	if preview_container == null:
		return
	var panel_box := VBoxContainer.new()
	panel_box.name = "DungeonSaveSlotPanel"
	panel_box.add_theme_constant_override("separation", 8)
	var surface := _create_surface_panel(
		preview_container,
		Color(0.09, 0.078, 0.064, 0.96),
		Color(0.38, 0.33, 0.26, 0.76),
		10,
		12
	)
	surface.add_child(panel_box)

	var title := Label.new()
	title.text = "路线勘合"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f3dfb8"))
	panel_box.add_child(title)

	var hint := Label.new()
	hint.text = "存下当前牌路，或按旧勘合续行本局。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("d9c08c"))
	panel_box.add_child(hint)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	panel_box.add_child(actions)

	if save_slot_callback.is_valid():
		var save_slot := Button.new()
		save_slot.name = "DungeonSaveSlotButton"
		save_slot.text = "保存路线"
		save_slot.custom_minimum_size = Vector2(0, 46)
		save_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(save_slot, "secondary")
		save_slot.pressed.connect(save_slot_callback)
		actions.add_child(save_slot)

	if restore_slot_callback.is_valid():
		var restore_slot := Button.new()
		restore_slot.name = "DungeonRestoreSlotButton"
		restore_slot.text = "读取路线"
		restore_slot.custom_minimum_size = Vector2(0, 46)
		restore_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(restore_slot, "secondary")
		restore_slot.pressed.connect(restore_slot_callback)
		actions.add_child(restore_slot)


func render_footer(
	state_text: String,
	fallback_callback: Callable,
	save_slot_callback: Callable = Callable(),
	restore_slot_callback: Callable = Callable()
) -> void:
	if footer_container == null:
		return
	var state_label := Label.new()
	state_label.text = state_text
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 16)
	state_label.add_theme_color_override("font_color", Color("d9c08c"))
	footer_container.add_child(state_label)

	var fallback := Button.new()
	fallback.text = "转入旧线本纪"
	fallback.custom_minimum_size = Vector2(220, 52)
	_style_action_button(fallback, "secondary")
	fallback.pressed.connect(fallback_callback)
	footer_container.add_child(fallback)



func render_complete_panel(summary_text: String, boss_callback: Callable) -> void:
	if preview_container == null:
		return
	var heading := Label.new()
	heading.text = "会剿牌票"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("f0ddb6"))
	preview_container.add_child(heading)

	var summary := RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.fit_content = false
	summary.scroll_active = true
	summary.custom_minimum_size = Vector2(340, 450)
	summary.add_theme_font_size_override("normal_font_size", 18)
	summary.add_theme_font_size_override("bold_font_size", 22)
	summary.add_theme_color_override("default_color", Color("2d2115"))
	summary.add_theme_stylebox_override(
		"normal",
		_make_panel_style(Color(0.66, 0.58, 0.42, 0.96), Color(0.34, 0.25, 0.15, 0.74), 6, 14)
	)
	summary.text = summary_text
	preview_container.add_child(summary)

	var boss_btn := Button.new()
	boss_btn.text = "发会剿牌"
	boss_btn.custom_minimum_size = Vector2(0, 58)
	boss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(boss_btn, "danger")
	boss_btn.pressed.connect(boss_callback)
	preview_container.add_child(boss_btn)


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
