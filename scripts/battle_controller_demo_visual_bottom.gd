extends "res://scripts/battle_controller_demo_visual_hud.gd"

# Demo visual bottom hand and detail panel construction layer.

func _build_bottom_hand_area() -> void:
	bottom_backdrop = PanelContainer.new()
	bottom_backdrop.z_as_relative = false
	bottom_backdrop.z_index = 110
	bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_backdrop.anchor_left = 0.0
	bottom_backdrop.anchor_right = 1.0
	bottom_backdrop.anchor_top = 0.0
	bottom_backdrop.anchor_bottom = 1.0
	bottom_backdrop.offset_left = 0.0
	bottom_backdrop.offset_right = 0.0
	bottom_backdrop.offset_top = BOTTOM_AREA_TOP - 12.0
	bottom_backdrop.offset_bottom = 0.0
	bottom_backdrop.add_theme_stylebox_override("panel", _make_bottom_backdrop_style())
	add_child(bottom_backdrop)

	bottom_root = VBoxContainer.new()
	bottom_root.z_as_relative = false
	bottom_root.z_index = 120
	bottom_root.anchor_left = 0.0
	bottom_root.anchor_right = 1.0
	bottom_root.anchor_top = 0.0
	bottom_root.anchor_bottom = 1.0
	bottom_root.offset_left = 24
	bottom_root.offset_right = -24
	bottom_root.offset_top = BOTTOM_AREA_TOP
	bottom_root.offset_bottom = -BOTTOM_AREA_BOTTOM_MARGIN
	bottom_root.add_theme_constant_override("separation", 12)
	add_child(bottom_root)

	var control_bar := HBoxContainer.new()
	control_bar.name = "ControlBar"
	control_bar.custom_minimum_size = Vector2(0, 44)
	control_bar.add_theme_constant_override("separation", 10)
	bottom_root.add_child(control_bar)

	node_buttons_box = HBoxContainer.new()
	node_buttons_box.add_theme_constant_override("separation", 10)
	node_buttons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_bar.add_child(node_buttons_box)

	var bottom_panels := HBoxContainer.new()
	bottom_panels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_panels.add_theme_constant_override("separation", 14)
	bottom_root.add_child(bottom_panels)

	var hand_panel := PanelContainer.new()
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_panel.size_flags_stretch_ratio = 2.0
	hand_panel.clip_contents = true
	hand_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("090d13"), Color("8a774f")))
	bottom_panels.add_child(hand_panel)

	var hand_margin := MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_left", 16)
	hand_margin.add_theme_constant_override("margin_right", 16)
	hand_margin.add_theme_constant_override("margin_top", 12)
	hand_margin.add_theme_constant_override("margin_bottom", 12)
	hand_panel.add_child(hand_margin)

	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	hand_margin.add_child(hand_box)

	var hand_title_row := HBoxContainer.new()
	hand_title_row.add_theme_constant_override("separation", 10)
	hand_title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.add_child(hand_title_row)

	var hand_title := Label.new()
	hand_title.text = "招式牌"
	hand_title.add_theme_font_size_override("font_size", 20)
	hand_title.add_theme_color_override("font_color", Color("e0c789"))
	hand_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	hand_title.add_theme_constant_override("shadow_offset_x", 1)
	hand_title.add_theme_constant_override("shadow_offset_y", 2)
	hand_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hand_title_row.add_child(hand_title)

	reset_pick_button = Button.new()
	reset_pick_button.text = "重选招式"
	reset_pick_button.custom_minimum_size = Vector2(104, 32)
	reset_pick_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset_pick_button.visible = false
	reset_pick_button.pressed.connect(_reset_draft_intent)
	hand_title_row.add_child(reset_pick_button)

	confirm_button = Button.new()
	confirm_button.text = "确认出招"
	confirm_button.custom_minimum_size = Vector2(104, 32)
	confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_button.visible = false
	confirm_button.pressed.connect(_confirm_player_intent)
	hand_title_row.add_child(confirm_button)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_box.add_child(hand_scroll)

	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 14)
	hand_scroll.add_child(hand_row)
	hand_flow = hand_row

	card_detail_panel = PanelContainer.new()
	card_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_detail_panel.size_flags_stretch_ratio = 1.0
	card_detail_panel.clip_contents = true
	card_detail_panel.add_theme_stylebox_override("panel", _make_detail_panel_style())
	bottom_panels.add_child(card_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 22)
	detail_margin.add_theme_constant_override("margin_right", 22)
	detail_margin.add_theme_constant_override("margin_top", 20)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	card_detail_panel.add_child(detail_margin)

	card_detail_label = RichTextLabel.new()
	card_detail_label.bbcode_enabled = true
	card_detail_label.fit_content = false
	card_detail_label.scroll_active = true
	card_detail_label.scroll_following = false
	card_detail_label.custom_minimum_size = Vector2(0, 0)
	card_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_detail_label.add_theme_color_override("default_color", Color("2f2821"))
	detail_margin.add_child(card_detail_label)

	effect_preview_panel = PanelContainer.new()
	effect_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_preview_panel.size_flags_stretch_ratio = 1.0
	effect_preview_panel.clip_contents = true
	effect_preview_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("11151a"), Color("8a774f")))
	bottom_panels.add_child(effect_preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 16)
	preview_margin.add_theme_constant_override("margin_right", 16)
	preview_margin.add_theme_constant_override("margin_top", 12)
	preview_margin.add_theme_constant_override("margin_bottom", 12)
	effect_preview_panel.add_child(preview_margin)

	effect_preview_label = RichTextLabel.new()
	effect_preview_label.bbcode_enabled = true
	effect_preview_label.fit_content = false
	effect_preview_label.scroll_active = true
	effect_preview_label.scroll_following = false
	effect_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_preview_label.add_theme_color_override("default_color", Color("d8c8a4"))
	preview_margin.add_child(effect_preview_label)

	battle_log_strip = Label.new()
	battle_log_strip.text = "日志待命"
	battle_log_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_wrapped_label(battle_log_strip, 2)
	battle_log_strip.add_theme_color_override("font_color", Color("e1d4b5"))
	battle_log_strip.visible = false
	bottom_root.add_child(battle_log_strip)

	log_label = RichTextLabel.new()
	log_label.visible = false
	status_label = RichTextLabel.new()
	status_label.visible = false
	preview_label = RichTextLabel.new()
	preview_label.visible = false
	player_visible_label = RichTextLabel.new()
	player_visible_label.visible = false
	enemy_visible_label = RichTextLabel.new()
	enemy_visible_label.visible = false
	player_label = RichTextLabel.new()
	player_label.visible = false
	enemy_label = RichTextLabel.new()
	enemy_label.visible = false
