extends RefCounted

static func ensure_focus_story_caption(c) -> void:
	if c.focus_story_layer != null:
		return
	c.focus_story_layer = Control.new()
	c.focus_story_layer.name = "NarrativePerformanceCaptionLayer"
	c.focus_story_layer.anchor_left = 0.0
	c.focus_story_layer.anchor_top = 0.0
	c.focus_story_layer.anchor_right = 1.0
	c.focus_story_layer.anchor_bottom = 1.0
	c.focus_story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_story_layer.z_index = 90
	c.focus_story_layer.z_as_relative = false
	c.add_child(c.focus_story_layer)

	c.focus_story_panel = PanelContainer.new()
	c.focus_story_panel.name = "NarrativePerformanceCaptionPanel"
	c.focus_story_panel.anchor_left = 0.06
	c.focus_story_panel.anchor_top = c.PERFORMANCE_CAPTION_TOP
	c.focus_story_panel.anchor_right = 0.94
	c.focus_story_panel.anchor_bottom = c.PERFORMANCE_CAPTION_BOTTOM
	c.focus_story_panel.offset_top = c.TUNED_CAPTION_OFFSET_Y
	c.focus_story_panel.offset_bottom = c.TUNED_CAPTION_OFFSET_Y
	c.focus_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_story_panel.z_index = 91
	c.focus_story_panel.add_theme_stylebox_override("panel", transparent_panel_style())
	c.focus_story_layer.add_child(c.focus_story_panel)

	c.focus_story_label = RichTextLabel.new()
	c.focus_story_label.name = "NarrativePerformanceCaptionText"
	c.focus_story_label.bbcode_enabled = true
	c.focus_story_label.fit_content = false
	c.focus_story_label.scroll_active = false
	c.focus_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_story_label.add_theme_font_size_override("normal_font_size", c.TUNED_STORY_FONT_SIZE)
	c.focus_story_label.add_theme_font_size_override("bold_font_size", c.TUNED_STORY_FONT_SIZE)
	c.focus_story_label.add_theme_font_size_override("italics_font_size", c.TUNED_STORY_FONT_SIZE)
	c.focus_story_label.add_theme_color_override("default_color", Color("f6ead2"))
	c.focus_story_panel.add_child(c.focus_story_label)

static func style_button_box(c, box: VBoxContainer) -> void:
	if box == null:
		return
	box.visible = true
	box.add_theme_constant_override("separation", 16)
	for child in box.get_children():
		if child is Button:
			var btn := child as Button
			btn.visible = true
			btn.custom_minimum_size = Vector2(0, 92)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", c.TUNED_OPTION_FONT_SIZE)
		elif child is Label:
			c._hide_control(child as Control)

static func apply_tuned_scene_art_view(c) -> void:
	pin_cinematic_background(c)
	make_operation_panel_floating(c)
	hide_scene_art_overlay_ui(c)

static func pin_cinematic_background(c) -> void:
	if c.cinematic_bg == null:
		return
	c.cinematic_bg.visible = true
	c.cinematic_bg.scale = Vector2.ONE
	c.cinematic_bg.position = Vector2.ZERO
	c.cinematic_bg.rotation = 0.0
	c.cinematic_bg.pivot_offset = Vector2.ZERO
	c.cinematic_bg.modulate = Color.WHITE
	c.cinematic_bg.self_modulate = Color.WHITE
	c.cinematic_bg.material = null
	c.cinematic_bg.offset_left = 0.0
	c.cinematic_bg.offset_top = 0.0
	c.cinematic_bg.offset_right = 0.0
	c.cinematic_bg.offset_bottom = 0.0

static func make_operation_panel_floating(c) -> void:
	var operation_panel: Control = c._find_operation_panel()
	if operation_panel == null:
		return
	operation_panel.add_theme_stylebox_override("panel", transparent_panel_style())
	operation_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin: Node = operation_panel.get_child(0) if operation_panel.get_child_count() > 0 else null
	if margin is MarginContainer:
		var margin_container := margin as MarginContainer
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_right", 0)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_bottom", 0)

static func hide_scene_art_overlay_ui(c) -> void:
	hide_canvas_item(c.cinematic_mist)
	hide_canvas_item(c.cinematic_fire)
	hide_canvas_item(c.cinematic_dim)
	hide_canvas_item(c.cinematic_focus)
	hide_canvas_item(c.cinematic_master)
	hide_canvas_item(c.cinematic_hero)
	hide_canvas_item(c.world_map_layer)
	hide_canvas_item(c.world_map_panel)
	hide_canvas_item(c.focus_world_map_layer)
	hide_canvas_item(c.focus_world_map_panel)
	hide_canvas_item(c.focus_debug_layer)
	hide_canvas_item(c.focus_debug_panel)
	if c.visual_debug_label != null:
		c.visual_debug_label.visible = false
		c.visual_debug_label.custom_minimum_size = Vector2.ZERO

static func hide_canvas_item(node: CanvasItem) -> void:
	if node == null:
		return
	node.visible = false
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.material = null
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.custom_minimum_size = Vector2.ZERO

static func transparent_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style
