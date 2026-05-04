extends "res://scripts/Main_foundation.gd"

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("0d1218")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var sky_glow := ColorRect.new()
	sky_glow.color = Color(0.24, 0.18, 0.08, 0.22)
	sky_glow.anchor_right = 1.0
	sky_glow.anchor_bottom = 0.42
	add_child(sky_glow)

	var mist := ColorRect.new()
	mist.color = Color(0.65, 0.71, 0.78, 0.06)
	mist.anchor_top = 0.55
	mist.anchor_right = 1.0
	mist.anchor_bottom = 1.0
	add_child(mist)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	root_container = VBoxContainer.new()
	root_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_theme_constant_override("separation", 14)
	margin.add_child(root_container)

	title_label = Label.new()
	title_label.text = "大明之沧海嘀鸣：单局战斗 Demo"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.modulate = Color("f5ebd0")
	root_container.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "围绕争机、势、距的单局原型。"
	subtitle_label.modulate = Color("b8c0cc")
	root_container.add_child(subtitle_label)

	battle_field_panel = _create_panel()
	battle_field_panel.custom_minimum_size = Vector2(0, 280)
	root_container.add_child(battle_field_panel)

	var battle_margin := MarginContainer.new()
	battle_margin.add_theme_constant_override("margin_left", 18)
	battle_margin.add_theme_constant_override("margin_right", 18)
	battle_margin.add_theme_constant_override("margin_top", 16)
	battle_margin.add_theme_constant_override("margin_bottom", 16)
	battle_field_panel.add_child(battle_margin)

	var battle_box := VBoxContainer.new()
	battle_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_box.add_theme_constant_override("separation", 14)
	battle_margin.add_child(battle_box)

	var battle_header := HBoxContainer.new()
	battle_box.add_child(battle_header)

	battle_badge = Label.new()
	battle_badge.text = "演武未开"
	battle_badge.add_theme_font_size_override("font_size", 22)
	battle_badge.modulate = Color("f0d083")
	battle_header.add_child(battle_badge)

	var battle_hint := Label.new()
	battle_hint.text = "削势打断、稳架完格、抓崩塌处决"
	battle_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_hint.modulate = Color("9caab7")
	battle_header.add_child(battle_hint)

	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 18)
	battle_box.add_child(stage)

	player_avatar = _build_avatar(stage, "我方", Color("355d73"))
	var center_column := VBoxContainer.new()
	center_column.custom_minimum_size = Vector2(360, 0)
	center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	center_column.add_theme_constant_override("separation", 8)
	stage.add_child(center_column)

	center_callout = Label.new()
	center_callout.text = "战场"
	center_callout.add_theme_font_size_override("font_size", 20)
	center_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_callout.modulate = Color("d4c6a3")
	center_column.add_child(center_callout)

	var distance_title := Label.new()
	distance_title.text = "距离刻度"
	distance_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_title.modulate = Color("92a0ad")
	center_column.add_child(distance_title)

	distance_track = HBoxContainer.new()
	distance_track.alignment = BoxContainer.ALIGNMENT_CENTER
	distance_track.add_theme_constant_override("separation", 8)
	center_column.add_child(distance_track)
	_build_distance_track()

	enemy_avatar = _build_avatar(stage, "敌方", Color("73423b"))

	var top_split := HBoxContainer.new()
	top_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_split.add_theme_constant_override("separation", 16)
	root_container.add_child(top_split)

	player_label = _build_panel_text(top_split, "玩家军情")
	enemy_label = _build_panel_text(top_split, "敌方军情")
	intent_label = _build_panel_text(top_split, "敌方招式意图")

	hand_label = Label.new()
	hand_label.text = "手牌"
	hand_label.add_theme_font_size_override("font_size", 22)
	hand_label.modulate = Color("f5ebd0")
	root_container.add_child(hand_label)

	var hand_panel := _create_panel()
	hand_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_child(hand_panel)

	hand_flow = HFlowContainer.new()
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_flow.add_theme_constant_override("h_separation", 10)
	hand_flow.add_theme_constant_override("v_separation", 10)
	hand_panel.add_child(hand_flow)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	root_container.add_child(controls)

	action_button = Button.new()
	action_button.text = "结束回合"
	action_button.pressed.connect(_on_end_turn_pressed)
	_style_button(action_button, Color("8f5d2d"))
	controls.add_child(action_button)

	next_button = Button.new()
	next_button.text = "下一场"
	next_button.visible = false
	next_button.pressed.connect(_on_next_pressed)
	_style_button(next_button, Color("4c6d80"))
	controls.add_child(next_button)

	var log_title := Label.new()
	log_title.text = "战斗记录"
	log_title.add_theme_font_size_override("font_size", 22)
	log_title.modulate = Color("f5ebd0")
	root_container.add_child(log_title)

	log_panel = _create_panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_child(log_panel)

	log_label = RichTextLabel.new()
	log_label.fit_content = true
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.scroll_active = true
	log_panel.add_child(log_label)

	overlay_scrim = ColorRect.new()
	overlay_scrim.visible = false
	overlay_scrim.color = Color(0.01, 0.02, 0.03, 0.72)
	overlay_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(overlay_scrim)

	overlay_panel = PanelContainer.new()
	overlay_panel.visible = false
	overlay_panel.custom_minimum_size = Vector2(620, 0)
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.15
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.15
	overlay_panel.offset_left = -310
	overlay_panel.offset_right = 310
	overlay_panel.modulate = Color(1, 1, 1, 0)
	overlay_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("2a2018"), Color("cfb889"), 2, 22))
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
	overlay_body.fit_content = true
	overlay_body.bbcode_enabled = true
	overlay_box.add_child(overlay_body)

	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_box.add_child(overlay_actions)
