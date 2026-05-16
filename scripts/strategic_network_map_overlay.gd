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

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.039, 0.030, 0.96)
	style.border_color = Color(0.78, 0.62, 0.36, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.name = "NetworkMapOverlayRoot"
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root)

	var header := Label.new()
	header.name = "NetworkMapOverlayHeader"
	header.text = "海疆大势图"
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color", Color("f3dfb8"))
	root.add_child(header)

	var main_row := HBoxContainer.new()
	main_row.name = "NetworkMapOverlayMainRow"
	main_row.add_theme_constant_override("separation", 16)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	map_container = VBoxContainer.new()
	map_container.name = "NetworkMapContainer"
	map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(map_container)

	preview_container = VBoxContainer.new()
	preview_container.name = "NetworkPreviewContainer"
	preview_container.custom_minimum_size = Vector2(360, 0)
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.add_theme_constant_override("separation", 10)
	main_row.add_child(preview_container)

	footer_container = HBoxContainer.new()
	footer_container.name = "NetworkFooterContainer"
	footer_container.add_theme_constant_override("separation", 10)
	footer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(footer_container)
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
	var progress := Label.new()
	progress.text = progress_text
	progress.add_theme_font_size_override("font_size", 16)
	progress.add_theme_color_override("font_color", Color("d9c08c"))
	map_container.add_child(progress)

	map_scroll = ScrollContainer.new()
	map_scroll.name = "NetworkMapScroll"
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	map_scroll.follow_focus = true
	map_scroll.custom_minimum_size = Vector2(980, 540)
	map_container.add_child(map_scroll)

	map_view = StrategicNetworkMapView.new()
	map_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	map_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	map_view.set_graph(graph, selected_node_id)
	if node_clicked_callback.is_valid():
		map_view.node_clicked.connect(node_clicked_callback)
	map_view.pan_requested.connect(_on_map_pan_requested)
	map_scroll.add_child(map_view)


func _on_map_pan_requested(delta: Vector2) -> void:
	if map_scroll == null:
		return
	map_scroll.scroll_horizontal = max(0, map_scroll.scroll_horizontal - int(delta.x))
	map_scroll.scroll_vertical = max(0, map_scroll.scroll_vertical - int(delta.y))


func render_preview_panel(preview_text: String, confirm_enabled: bool, confirm_callback: Callable) -> void:
	if preview_container == null:
		return
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = false
	preview.scroll_active = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(340, 420)
	preview.add_theme_font_size_override("normal_font_size", 18)
	preview.add_theme_font_size_override("bold_font_size", 20)
	preview.add_theme_color_override("default_color", Color("f0dfb8"))
	preview.text = preview_text
	preview_container.add_child(preview)

	var confirm := Button.new()
	confirm.text = "确认前往"
	confirm.disabled = not confirm_enabled
	confirm.custom_minimum_size = Vector2(0, 58)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(confirm_callback)
	preview_container.add_child(confirm)


func render_dungeon_storage_panel(save_slot_callback: Callable, restore_slot_callback: Callable) -> void:
	if preview_container == null:
		return
	var panel_box := VBoxContainer.new()
	panel_box.name = "DungeonSaveSlotPanel"
	panel_box.add_theme_constant_override("separation", 8)
	preview_container.add_child(panel_box)

	var title := Label.new()
	title.text = "副本存档"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f3dfb8"))
	panel_box.add_child(title)

	var hint := Label.new()
	hint.text = "保存当前路线，或从正式 slot 继续本局。"
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
		save_slot.pressed.connect(save_slot_callback)
		actions.add_child(save_slot)

	if restore_slot_callback.is_valid():
		var restore_slot := Button.new()
		restore_slot.name = "DungeonRestoreSlotButton"
		restore_slot.text = "读取路线"
		restore_slot.custom_minimum_size = Vector2(0, 46)
		restore_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	state_label.add_theme_font_size_override("font_size", 16)
	state_label.add_theme_color_override("font_color", Color("d9c08c"))
	footer_container.add_child(state_label)

	var fallback := Button.new()
	fallback.text = "继续旧线性流程"
	fallback.custom_minimum_size = Vector2(220, 52)
	fallback.pressed.connect(fallback_callback)
	footer_container.add_child(fallback)



func render_complete_panel(summary_text: String, boss_callback: Callable) -> void:
	if preview_container == null:
		return
	var summary := RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.fit_content = false
	summary.scroll_active = true
	summary.custom_minimum_size = Vector2(340, 420)
	summary.add_theme_font_size_override("normal_font_size", 18)
	summary.add_theme_font_size_override("bold_font_size", 22)
	summary.add_theme_color_override("default_color", Color("f0dfb8"))
	summary.text = summary_text
	preview_container.add_child(summary)

	var boss_btn := Button.new()
	boss_btn.text = "进入临时终局战"
	boss_btn.custom_minimum_size = Vector2(0, 58)
	boss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_btn.pressed.connect(boss_callback)
	preview_container.add_child(boss_btn)


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
