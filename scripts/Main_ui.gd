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

func _build_panel_text(parent: Control, heading: String) -> RichTextLabel:
	var panel := _create_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("f2dfbd")
	box.add_child(label)

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = false
	rich.modulate = Color("dbe4eb")
	box.add_child(rich)
	return rich

func _build_avatar(parent: Control, title: String, accent: Color) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(260, 144)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _make_panel_style(accent.darkened(0.65), accent.lightened(0.1), 2, 24))
	parent.add_child(shell)

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	shell.add_child(box)

	var title_label_local := Label.new()
	title_label_local.text = title
	title_label_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label_local.modulate = Color("d8dce3")
	box.add_child(title_label_local)

	var figure := Label.new()
	figure.text = "●"
	figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	figure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	figure.add_theme_font_size_override("font_size", 56)
	figure.modulate = accent.lightened(0.3)
	box.add_child(figure)

	var fx := Label.new()
	fx.text = ""
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.add_theme_font_size_override("font_size", 18)
	fx.modulate = Color(1, 1, 1, 0)
	box.add_child(fx)

	if title == "我方":
		player_avatar_label = figure
		player_fx_label = fx
	else:
		enemy_avatar_label = figure
		enemy_fx_label = fx
	return shell

func _build_distance_track() -> void:
	distance_nodes.clear()
	distance_labels.clear()
	for child in distance_track.get_children():
		child.queue_free()
	for value in range(map_length):
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(56, 54)
		node.add_theme_stylebox_override("panel", _make_panel_style(Color("151d24"), Color("4f5a65"), 1, 16))
		distance_track.add_child(node)
		distance_nodes.append(node)

		var marker := Label.new()
		marker.text = str(value)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 16)
		node.add_child(marker)
		distance_labels.append(marker)

func _refresh_ui() -> void:
	player_label.text = _player_status_text()
	enemy_label.text = _enemy_status_text()
	intent_label.text = _intent_status_text()
	hand_label.text = "手牌（%d）" % hand.size()
	if player_class_id == "":
		battle_badge.text = "演武未开"
	elif current_node_id == "":
		battle_badge.text = "军旅待发"
	else:
		var node_title := ""
		if route_nodes.has(current_node_id):
			node_title = route_nodes[current_node_id]["title"]
		battle_badge.text = "%s｜%s" % [_battle_name() if not enemy.is_empty() else "路线推进", node_title]
	center_callout.text = "地图长度：%d｜当前距离：%d" % [map_length, distance]
	_refresh_battlefield_visuals()
	_refresh_distance_track()
	_refresh_hand_buttons()
	_refresh_log()

func _player_status_text() -> String:
	if player.is_empty():
		return "等待开局。"
	return "[b]%s[/b]｜%s\n生命：%d/%d\n势：%d/%d\n格挡：%d\n优势距离：%s\n当前位置：%d/%d\n当前距离：[color=#95e1d3]%d[/color]\n被动：%s" % [
		player["name"], player["weapon"], player["hp"], player["max_hp"], player["momentum"], player["max_momentum"],
		player["guard"], _ranges_text(player["preferred_ranges"]), player_position, map_length - 1, distance, player["passive"]
	]

func _enemy_status_text() -> String:
	if enemy.is_empty():
		return "尚未遭遇敌人。"
	var collapse_text := "\n[color=#ff8a7a]状态：崩塌，下次受击必暴击。[/color]" if enemy["collapsed"] else ""
	return "[b]%s[/b]｜%s\n生命：%d/%d\n势：%d/%d\n格挡：%d\n优势距离：%s\n当前位置：%d/%d\n被动：%s%s" % [
		enemy["name"], enemy["title"], enemy["hp"], enemy["max_hp"], enemy["momentum"], enemy["max_momentum"],
		enemy["guard"], _ranges_text(enemy["preferred_ranges"]), enemy_position, map_length - 1, enemy["passive"], collapse_text
	]

func _intent_status_text() -> String:
	if enemy.is_empty() or enemy["current_intent"].is_empty():
		return "暂无意图。"
	var intent: Dictionary = enemy["current_intent"]
	var move_text := "不改距"
	if intent.has("move_to"):
		move_text = "调整到距离 %d" % intent["move_to"]
	elif intent.has("move_delta"):
		move_text = "距离 %+d" % intent["move_delta"]
	var extras := []
	if intent.has("guard"):
		extras.append("获得 %d 格挡" % intent["guard"])
	if intent.has("tags"):
		extras.append("标签：" + " / ".join(intent["tags"]))
	return "[b]%s[/b]\n预计耗势：%d\n行动：%s\n预计伤害：%d\n预计削势：%d\n%s" % [
		intent["name"],
		intent["cost"],
		move_text,
		intent.get("damage", 0),
		intent.get("momentum_damage", 0),
		"｜".join(extras)
	]

func _refresh_hand_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()
	for i in range(hand.size()):
		var card_id: String = hand[i]
		var def: Dictionary = card_defs[card_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 138)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s｜耗势 %d\n%s" % [def["name"], def["category"], _card_cost(card_id), def["text"]]
		button.disabled = battle_over or reward_pending or _card_cost(card_id) > player["momentum"]
		_style_card_button(button, def["category"])
		button.pressed.connect(_on_card_pressed.bind(i))
		hand_flow.add_child(button)

func _refresh_log() -> void:
	log_label.text = "\n".join(battle_log.slice(maxi(battle_log.size() - 18, 0), battle_log.size()))

func _refresh_battlefield_visuals() -> void:
	if player.is_empty():
		player_avatar_label.text = "●"
		enemy_avatar_label.text = "●"
		return
	player_avatar_label.text = "枪" if player_class_id == "spear" else "刀"
	enemy_avatar_label.text = _enemy_glyph()
	player_avatar.modulate = Color("ffffff")
	enemy_avatar.modulate = Color("ffffff") if not enemy.get("collapsed", false) else Color("ffb1a8")

func _refresh_distance_track() -> void:
	for i in range(distance_nodes.size()):
		var node := distance_nodes[i]
		var label := distance_labels[i]
		var marker_text := str(i)
		var occupied := false
		if i == player_position and i == enemy_position:
			marker_text += "\n我·敌"
			occupied = true
		elif i == player_position:
			marker_text += "\n我"
			occupied = true
		elif i == enemy_position:
			marker_text += "\n敌"
			occupied = true
		label.text = marker_text
		if occupied:
			node.add_theme_stylebox_override("panel", _make_panel_style(Color("324b5d"), Color("9ad5ff"), 2, 16))
			label.modulate = Color("f6f9fb")
		else:
			node.add_theme_stylebox_override("panel", _make_panel_style(Color("151d24"), Color("4f5a65"), 1, 16))
			label.modulate = Color("95a5b1")

func _style_card_button(button: Button, category: String) -> void:
	var accent: Color = CATEGORY_COLORS.get(category, Color("718093"))
	button.add_theme_font_size_override("font_size", 17)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_color", Color("f7f2e8"))
	button.add_theme_color_override("font_disabled_color", Color("8c9096"))
	button.add_theme_stylebox_override("normal", _make_panel_style(accent.darkened(0.72), accent, 2, 16))
	button.add_theme_stylebox_override("hover", _make_panel_style(accent.darkened(0.58), accent.lightened(0.25), 2, 16))
	button.add_theme_stylebox_override("pressed", _make_panel_style(accent.darkened(0.82), accent.lightened(0.1), 2, 16))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color("1a2128"), Color("3c454f"), 1, 16))

