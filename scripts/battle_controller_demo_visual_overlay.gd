extends "res://scripts/battle_controller_demo_visual_bottom.gd"

# Demo visual overlay construction layer.

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_stage_layer()
	_build_top_hud()
	_build_center_info()
	_build_bottom_hand_area()
	_build_overlay_layer()
	set_process(true)
	_refresh_visual_ui()

func _build_overlay_layer() -> void:
	screen_flash = ColorRect.new()
	screen_flash.visible = false
	screen_flash.z_as_relative = false
	screen_flash.z_index = 900
	screen_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.color = Color(1, 1, 1, 0)
	add_child(screen_flash)

	overlay_scrim = ColorRect.new()
	overlay_scrim.visible = false
	overlay_scrim.z_as_relative = false
	overlay_scrim.z_index = 1000
	overlay_scrim.color = Color(0.01, 0.02, 0.03, 0.72)
	overlay_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(overlay_scrim)

	overlay_panel = PanelContainer.new()
	overlay_panel.visible = false
	overlay_panel.z_as_relative = false
	overlay_panel.z_index = 1001
	overlay_panel.clip_contents = true
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.08
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.92
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.offset_top = 0
	overlay_panel.offset_bottom = 0
	overlay_panel.add_theme_stylebox_override("panel", _make_overlay_panel_style())
	add_child(overlay_panel)

	var overlay_margin := MarginContainer.new()
	overlay_margin.add_theme_constant_override("margin_left", 20)
	overlay_margin.add_theme_constant_override("margin_right", 20)
	overlay_margin.add_theme_constant_override("margin_top", 18)
	overlay_margin.add_theme_constant_override("margin_bottom", 18)
	overlay_panel.add_child(overlay_margin)
	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	overlay_margin.add_child(overlay_box)
	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 24)
	overlay_title.add_theme_color_override("font_color", Color("251b11"))
	_set_single_line_ellipsis(overlay_title)
	overlay_box.add_child(overlay_title)
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.fit_content = false
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.scroll_active = false
	overlay_body.custom_minimum_size = Vector2(0, 92)
	overlay_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	overlay_body.add_theme_color_override("default_color", Color("2d2419"))
	overlay_box.add_child(overlay_body)
	var overlay_action_scroll := ScrollContainer.new()
	overlay_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay_action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	overlay_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_action_scroll.custom_minimum_size = Vector2(0, 280)
	overlay_box.add_child(overlay_action_scroll)
	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_action_scroll.add_child(overlay_actions)
	_build_battle_result_layer()
