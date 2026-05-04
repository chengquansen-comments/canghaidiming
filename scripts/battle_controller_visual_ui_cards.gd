extends "res://scripts/battle_controller_visual_ui_preview.gd"

func _refresh_hand_buttons() -> void:
	if hand_flow == null:
		return
	var signature := _hand_buttons_state_signature()
	if signature == _hand_buttons_signature:
		return
	_hand_buttons_signature = signature
	for child in hand_flow.get_children():
		child.queue_free()
	if player == null:
		return
	if player.hand.is_empty():
		var empty_label := Label.new()
		empty_label.custom_minimum_size = Vector2(420, 180)
		empty_label.text = "暂无招式牌\n进入演武后会在这里显示本回合招式。"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", Color("9f9277"))
		hand_flow.add_child(empty_label)
		return
	for i in range(player.hand.size()):
		var card: CardData = player.hand[i]
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var button := Button.new()
		button.custom_minimum_size = Vector2(176, 204)
		button.text = ""
		button.tooltip_text = _compact_button_text(card, marker, reason)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = not awaiting_player_input or not _can_play_card(player, card)
		_apply_card_button_style(button, card, _draft_uses_card(card), button.disabled)
		_build_card_button_face(button, card, marker, reason)
		button.pressed.connect(_on_player_card_pressed.bind(card))
		hand_flow.add_child(button)

func _hand_buttons_state_signature() -> String:
	if player == null:
		return "no-player"
	if player.hand.is_empty():
		return "empty|%s|%d|%d" % [str(awaiting_player_input), int(round(hand_flow.size.x)) if hand_flow != null else 0, int(round(hand_flow.size.y)) if hand_flow != null else 0]
	var parts: Array[String] = []
	parts.append(str(awaiting_player_input))
	parts.append(str(player.momentum))
	parts.append(str(player.guard_points))
	parts.append(str(state_machine.current_distance if state_machine != null else 0))
	parts.append(str(state_machine.phase if state_machine != null else -1))
	parts.append(_intent_card_id(draft_player_intent))
	parts.append(_intent_card_id(player_intent))
	parts.append(str(draft_player_position))
	parts.append(draft_player_facing)
	parts.append(str(draft_player_has_position))
	parts.append(str(player.combo_window_active))
	parts.append(str(player.control_state))
	parts.append(str(int(round(hand_flow.size.x)) if hand_flow != null else 0))
	for card in player.hand:
		if card == null:
			parts.append("<null>")
			continue
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var disabled := not awaiting_player_input or not _can_play_card(player, card)
		var selected := _draft_uses_card(card)
		parts.append("%s:%d:%s:%s:%s:%s" % [card.id, card.momentum_cost, str(disabled), str(selected), reason, marker])
	return "|".join(parts)

func _intent_card_id(intent: IntentData) -> String:
	if intent == null or intent.actual_card == null:
		return "-"
	return intent.actual_card.id

func _apply_card_button_style(button: Button, card: CardData, selected: bool, disabled: bool) -> void:
	var base := Color("141a20")
	var border := Color("8a7856")
	if card.is_guard_card():
		border = Color("637d91")
	elif card.is_feint_card():
		border = Color("6f8d76")
	if selected:
		border = Color("e2c066")
	var normal := _make_flat_card_style(base, border, 2 if not selected else 3)
	var hover := _make_flat_card_style(base.lightened(0.08), border.lightened(0.15), 3)
	var pressed := _make_flat_card_style(base.lightened(0.14), Color("e6c36a"), 3)
	var disabled_style := _make_flat_card_style(Color("111418"), Color("4d4a42"), 1)
	button.add_theme_stylebox_override("normal", disabled_style if disabled else normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _make_flat_card_style(base.lightened(0.04), Color("efd382"), 3))
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0))

func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _build_card_button_face(button: Button, card: CardData, marker: String, reason: String) -> void:
	var face := MarginContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_constant_override("margin_left", 10)
	face.add_theme_constant_override("margin_right", 10)
	face.add_theme_constant_override("margin_top", 10)
	face.add_theme_constant_override("margin_bottom", 10)
	button.add_child(face)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	face.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)

	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(34, 34)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_theme_stylebox_override("panel", _make_badge_style(true))
	title_row.add_child(cost_badge)
	var cost_label := Label.new()
	cost_label.text = str(card.momentum_cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color("f5efe1"))
	cost_badge.add_child(cost_label)

	var title_label := Label.new()
	title_label.text = card.display_name
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("f0e4c4"))
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title_label)

	var tag := Label.new()
	tag.text = _short_card_type_tag(card)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(28, 28)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color("f7ead0"))
	tag.add_theme_stylebox_override("normal", _make_type_tag_style(card))
	title_row.add_child(tag)

	var art_box := PanelContainer.new()
	art_box.custom_minimum_size = Vector2(0, 54)
	art_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.add_theme_stylebox_override("panel", _make_card_art_style(card))
	box.add_child(art_box)
	var art_label := Label.new()
	art_label.text = _card_art_glyph(card)
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.add_theme_font_size_override("font_size", 22)
	art_label.add_theme_color_override("font_color", Color("ced8dd"))
	art_box.add_child(art_label)

	var summary := Label.new()
	summary.text = _compact_effect_summary(card)
	if marker != "":
		summary.text += "\n%s" % marker
	if reason != "":
		summary.text += "\n限制：%s" % reason
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.clip_text = true
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color("d9d2bf") if reason == "" else Color("a79881"))
	box.add_child(summary)

func _short_card_type_tag(card: CardData) -> String:
	if card.is_guard_card():
		return "守"
	if card.is_feint_card():
		return "变"
	return "攻"

func _make_type_tag_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6f2824")
	if card.is_guard_card():
		style.bg_color = Color("29495f")
	elif card.is_feint_card():
		style.bg_color = Color("355d46")
	style.border_color = Color("c7b181")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _make_card_art_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202934")
	if card.is_guard_card():
		style.bg_color = Color("243443")
	elif card.is_feint_card():
		style.bg_color = Color("24382e")
	style.border_color = Color("403b31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _card_art_glyph(card: CardData) -> String:
	if card.is_guard_card():
		return "守"
	if card.is_feint_card():
		return "行"
	if card.max_distance >= 3:
		return "气"
	return "斩"
