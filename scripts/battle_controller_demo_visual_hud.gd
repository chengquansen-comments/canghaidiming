extends "res://scripts/battle_controller_demo_visual_stage.gd"

# Demo visual HUD construction layer.

func _build_top_hud() -> void:
	top_hud = HBoxContainer.new()
	top_hud.z_as_relative = false
	top_hud.z_index = 100
	top_hud.anchor_left = 0.0
	top_hud.anchor_right = 1.0
	top_hud.anchor_top = 0.0
	top_hud.anchor_bottom = 0.0
	top_hud.offset_left = 20
	top_hud.offset_top = 18
	top_hud.offset_right = -20
	top_hud.offset_bottom = 150
	top_hud.add_theme_constant_override("separation", 20)
	add_child(top_hud)

	player_hud = _build_actor_hud(true)
	top_hud.add_child(player_hud)

	center_hud = VBoxContainer.new()
	center_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	center_hud.add_theme_constant_override("separation", 8)
	top_hud.add_child(center_hud)

	enemy_hud = _build_actor_hud(false)
	top_hud.add_child(enemy_hud)

func _build_actor_hud(is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 130)
	panel.clip_contents = false
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(96, 96)
	avatar_wrap.clip_contents = false

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.size = Vector2(96, 96)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	avatar_wrap.add_child(avatar)

	var avatar_fallback := ColorRect.new()
	avatar_fallback.custom_minimum_size = Vector2(96, 96)
	avatar_fallback.color = Color("3e5875") if is_player else Color("7a4d45")
	avatar_wrap.add_child(avatar_fallback)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	if is_player:
		row.add_child(avatar_wrap)
		row.add_child(box)
	else:
		row.add_child(box)
		row.add_child(avatar_wrap)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("f5e8c8"))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	_set_single_line_ellipsis(name_label)
	box.add_child(name_label)

	var school_label := Label.new()
	school_label.add_theme_font_size_override("font_size", 15)
	school_label.add_theme_color_override("font_color", Color("bba98a"))
	school_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	school_label.add_theme_constant_override("shadow_offset_x", 1)
	school_label.add_theme_constant_override("shadow_offset_y", 1)
	school_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	_set_single_line_ellipsis(school_label)
	box.add_child(school_label)

	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(HUD_BAR_WIDTH + 40, 16)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.clip_contents = true
	hp_bg.color = Color(0.14, 0.06, 0.06, 0.66)
	box.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.size = Vector2(HUD_BAR_WIDTH + 40, 16)
	hp_fill.color = Color("c44a3f")
	hp_bg.add_child(hp_fill)

	var hp_value := Label.new()
	hp_value.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_value.add_theme_font_size_override("font_size", 14)
	hp_value.add_theme_color_override("font_color", Color("f6ead4"))
	_set_single_line_ellipsis(hp_value)
	hp_bg.add_child(hp_value)

	var momentum_row := HBoxContainer.new()
	momentum_row.add_theme_constant_override("separation", 8)
	momentum_row.alignment = BoxContainer.ALIGNMENT_BEGIN if is_player else BoxContainer.ALIGNMENT_END
	box.add_child(momentum_row)

	var momentum_title := Label.new()
	momentum_title.text = "势"
	momentum_title.add_theme_font_size_override("font_size", 18)
	momentum_title.add_theme_color_override("font_color", Color("f0e2bf"))
	momentum_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	momentum_title.add_theme_constant_override("shadow_offset_x", 1)
	momentum_title.add_theme_constant_override("shadow_offset_y", 2)
	momentum_row.add_child(momentum_title)

	var momentum_dots := HBoxContainer.new()
	momentum_dots.add_theme_constant_override("separation", 5)
	momentum_dots.alignment = BoxContainer.ALIGNMENT_BEGIN if is_player else BoxContainer.ALIGNMENT_END
	momentum_row.add_child(momentum_dots)

	if is_player:
		player_avatar = avatar
		player_avatar_fallback = avatar_fallback
		player_hp_bg = hp_bg
		player_hp_fill = hp_fill
		player_hp_value_label = hp_value
		player_name_label = name_label
		player_school_label = school_label
		player_momentum_dots = momentum_dots
	else:
		enemy_avatar = avatar
		enemy_avatar_fallback = avatar_fallback
		enemy_hp_bg = hp_bg
		enemy_hp_fill = hp_fill
		enemy_hp_value_label = hp_value
		enemy_name_label = name_label
		enemy_school_label = school_label
		enemy_momentum_dots = momentum_dots

	return panel

func _build_center_info() -> void:
	if center_hud == null:
		return
	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 34)
	round_label.add_theme_color_override("font_color", Color("f2e2bf"))
	round_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	round_label.add_theme_constant_override("shadow_offset_x", 2)
	round_label.add_theme_constant_override("shadow_offset_y", 3)
	round_label.text = ""
	center_hud.add_child(round_label)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", Color("d6c3a0"))
	phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	phase_label.add_theme_constant_override("shadow_offset_x", 1)
	phase_label.add_theme_constant_override("shadow_offset_y", 2)
	_set_single_line_ellipsis(phase_label)
	phase_label.custom_minimum_size = Vector2(420, 28)
	center_hud.add_child(phase_label)

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.custom_minimum_size = Vector2(420, 60)
	combat_banner.clip_contents = true
	combat_banner.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("332418"), Color("e1b86c")))
	center_hud.add_child(combat_banner)
	combat_banner_label = Label.new()
	combat_banner_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner_label.add_theme_font_size_override("font_size", 24)
	combat_banner_label.add_theme_color_override("font_color", Color("f4e1b1"))
	_set_single_line_ellipsis(combat_banner_label)
	combat_banner.add_child(combat_banner_label)
