extends "res://scripts/battle_controller_core_catalog.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shell := Control.new()
	shell.visible = false
	shell.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shell)

	title_label = Label.new()
	shell.add_child(title_label)
	subtitle_label = Label.new()
	shell.add_child(subtitle_label)
	round_label = Label.new()
	shell.add_child(round_label)
	phase_label = Label.new()
	shell.add_child(phase_label)
	player_label = RichTextLabel.new()
	shell.add_child(player_label)
	enemy_label = RichTextLabel.new()
	shell.add_child(enemy_label)
	player_visible_label = RichTextLabel.new()
	shell.add_child(player_visible_label)
	enemy_visible_label = RichTextLabel.new()
	shell.add_child(enemy_visible_label)
	status_label = RichTextLabel.new()
	shell.add_child(status_label)
	preview_label = RichTextLabel.new()
	shell.add_child(preview_label)
	log_label = RichTextLabel.new()
	shell.add_child(log_label)
	deck_button = Button.new()
	shell.add_child(deck_button)
	reset_pick_button = Button.new()
	shell.add_child(reset_pick_button)
	confirm_button = Button.new()
	shell.add_child(confirm_button)
	node_buttons_box = HBoxContainer.new()
	shell.add_child(node_buttons_box)
	hand_flow = HFlowContainer.new()
	shell.add_child(hand_flow)

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.anchor_left = 0.5
	combat_banner.anchor_top = 0.02
	combat_banner.anchor_right = 0.5
	combat_banner.anchor_bottom = 0.02
	combat_banner.offset_left = -240
	combat_banner.offset_right = 240
	combat_banner.offset_top = 0
	combat_banner.offset_bottom = 72
	combat_banner.modulate = Color(1, 1, 1, 0)
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(Color("3a1f14"), Color("ffd479")))
	add_child(combat_banner)
	combat_banner_label = Label.new()
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner.add_child(combat_banner_label)

	screen_flash = ColorRect.new()
	screen_flash.visible = false
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(screen_flash)

	pierce_line = ColorRect.new()
	pierce_line.visible = false
	pierce_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pierce_line.anchor_left = 0.0
	pierce_line.anchor_top = 0.5
	pierce_line.anchor_right = 0.0
	pierce_line.anchor_bottom = 0.5
	pierce_line.offset_left = -120
	pierce_line.offset_top = -4
	pierce_line.offset_right = 120
	pierce_line.offset_bottom = 4
	pierce_line.color = Color(0.7, 0.9, 1.0, 0.0)
	add_child(pierce_line)

	slash_cut = ColorRect.new()
	slash_cut.visible = false
	slash_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash_cut.anchor_left = 0.5
	slash_cut.anchor_top = 0.5
	slash_cut.anchor_right = 0.5
	slash_cut.anchor_bottom = 0.5
	slash_cut.offset_left = -420
	slash_cut.offset_top = -18
	slash_cut.offset_right = 420
	slash_cut.offset_bottom = 18
	slash_cut.rotation_degrees = -18.0
	slash_cut.color = Color(1.0, 0.65, 0.45, 0.0)
	add_child(slash_cut)

	left_hit_mark = ColorRect.new()
	left_hit_mark.visible = false
	left_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_hit_mark.anchor_left = 0.04
	left_hit_mark.anchor_top = 0.25
	left_hit_mark.anchor_right = 0.22
	left_hit_mark.anchor_bottom = 0.74
	left_hit_mark.color = Color(1, 1, 1, 0)
	left_hit_mark.rotation_degrees = -14.0
	add_child(left_hit_mark)

	right_hit_mark = ColorRect.new()
	right_hit_mark.visible = false
	right_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_hit_mark.anchor_left = 0.78
	right_hit_mark.anchor_top = 0.25
	right_hit_mark.anchor_right = 0.96
	right_hit_mark.anchor_bottom = 0.74
	right_hit_mark.color = Color(1, 1, 1, 0)
	right_hit_mark.rotation_degrees = 14.0
	add_child(right_hit_mark)

	overlay_scrim = ColorRect.new()
	overlay_scrim.visible = false
	overlay_scrim.color = Color(0.01, 0.02, 0.03, 0.72)
	overlay_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(overlay_scrim)

	overlay_panel = PanelContainer.new()
	overlay_panel.visible = false
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.12
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("2a2018"), Color("cfb889")))
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
	overlay_box.add_child(overlay_title)
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.fit_content = true
	overlay_box.add_child(overlay_body)
	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_box.add_child(overlay_actions)
	_build_battle_result_layer()

func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _build_battle_result_layer() -> void:
	if battle_result_panel != null:
		return
	battle_result_scrim = ColorRect.new()
	battle_result_scrim.visible = false
	battle_result_scrim.z_as_relative = false
	battle_result_scrim.z_index = 1100
	battle_result_scrim.color = Color(0.01, 0.02, 0.03, 0.76)
	battle_result_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(battle_result_scrim)

	battle_result_panel = PanelContainer.new()
	battle_result_panel.visible = false
	battle_result_panel.z_as_relative = false
	battle_result_panel.z_index = 1101
	battle_result_panel.anchor_left = 0.5
	battle_result_panel.anchor_top = 0.5
	battle_result_panel.anchor_right = 0.5
	battle_result_panel.anchor_bottom = 0.5
	battle_result_panel.offset_left = -240
	battle_result_panel.offset_right = 240
	battle_result_panel.offset_top = -120
	battle_result_panel.offset_bottom = 120
	battle_result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("2a2018"), Color("cfb889")))
	add_child(battle_result_panel)

	var result_margin := MarginContainer.new()
	result_margin.add_theme_constant_override("margin_left", 28)
	result_margin.add_theme_constant_override("margin_right", 28)
	result_margin.add_theme_constant_override("margin_top", 24)
	result_margin.add_theme_constant_override("margin_bottom", 24)
	battle_result_panel.add_child(result_margin)

	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 16)
	result_margin.add_child(result_box)

	battle_result_title = Label.new()
	battle_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result_title.add_theme_font_size_override("font_size", 30)
	battle_result_title.add_theme_color_override("font_color", Color("f4e0b8"))
	result_box.add_child(battle_result_title)

	battle_result_body = Label.new()
	battle_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_body.add_theme_font_size_override("font_size", 20)
	battle_result_body.add_theme_color_override("font_color", Color("e2d2b3"))
	result_box.add_child(battle_result_body)

	battle_result_actions = VBoxContainer.new()
	battle_result_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_result_actions.add_theme_constant_override("separation", 8)
	result_box.add_child(battle_result_actions)
