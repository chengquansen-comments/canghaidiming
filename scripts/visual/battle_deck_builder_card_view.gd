extends RefCounted

# Card-face and small control helpers for the battle deck builder overlay.
#
# Pure UI helper. It creates controls/styles only and does not modify deck state,
# player state, overlay visibility, or battle flow.


static func deck_library_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("261f18")
	style.border_color = Color("c8a464")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


static func deck_builder_page_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 438)
	button.add_theme_font_size_override("font_size", 28)
	return button


static func deck_builder_page_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(36, 438)
	return spacer


static func build_deck_library_card_button(card: CardData, disabled: bool, art_glyph: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(148, 200)
	button.text = ""
	button.tooltip_text = card.short_summary()
	button.disabled = disabled
	apply_deck_library_card_style(button, card, disabled)
	build_deck_library_card_face(button, card, art_glyph)
	return button


static func empty_deck_library_card_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(148, 200)
	panel.add_theme_stylebox_override("panel", make_flat_card_style(Color("15120f"), Color("3b332a"), 1))
	return panel


static func apply_deck_library_card_style(button: Button, card: CardData, disabled: bool) -> void:
	var base := Color("141a20")
	var border := Color("8a7856")
	if card.is_guard_card():
		border = Color("637d91")
	elif card.is_feint_card():
		border = Color("6f8d76")
	var normal := make_flat_card_style(base, border, 2)
	var hover := make_flat_card_style(base.lightened(0.08), border.lightened(0.15), 3)
	var pressed := make_flat_card_style(base.lightened(0.14), Color("e6c36a"), 3)
	var disabled_style := make_flat_card_style(Color("111418"), Color("4d4a42"), 1)
	button.add_theme_stylebox_override("normal", disabled_style if disabled else normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", make_flat_card_style(base.lightened(0.04), Color("efd382"), 3))
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0))


static func make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
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


static func build_deck_library_card_face(button: Button, card: CardData, art_glyph: String) -> void:
	var face := MarginContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_constant_override("margin_left", 9)
	face.add_theme_constant_override("margin_right", 9)
	face.add_theme_constant_override("margin_top", 9)
	face.add_theme_constant_override("margin_bottom", 9)
	button.add_child(face)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	face.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)

	var cost := Label.new()
	cost.text = str(card.momentum_cost)
	cost.custom_minimum_size = Vector2(28, 28)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 17)
	cost.add_theme_color_override("font_color", Color("f5efe1"))
	cost.add_theme_stylebox_override("normal", deck_card_badge_style())
	title_row.add_child(cost)

	var name := Label.new()
	name.text = card.display_name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color("f0e4c4"))
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(name)

	var tag := Label.new()
	tag.text = short_card_type_tag_for_builder(card)
	tag.custom_minimum_size = Vector2(24, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color("f7ead0"))
	tag.add_theme_stylebox_override("normal", deck_card_type_style(card))
	title_row.add_child(tag)

	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(0, 50)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_theme_stylebox_override("panel", deck_card_art_style(card))
	box.add_child(art)

	var art_label := Label.new()
	art_label.text = art_glyph
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.add_theme_font_size_override("font_size", 20)
	art_label.add_theme_color_override("font_color", Color("ced8dd"))
	art.add_child(art_label)

	var summary := Label.new()
	summary.text = compact_effect_summary(card)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.clip_text = true
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color("d9d2bf"))
	box.add_child(summary)


static func deck_card_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("244b73")
	style.border_color = Color("d7e4f5")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style


static func deck_card_type_style(card: CardData) -> StyleBoxFlat:
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


static func deck_card_art_style(card: CardData) -> StyleBoxFlat:
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


static func short_card_type_tag_for_builder(card: CardData) -> String:
	return card.type_label()


static func compact_effect_summary(card: CardData) -> String:
	if card == null:
		return ""
	return card.short_summary()
