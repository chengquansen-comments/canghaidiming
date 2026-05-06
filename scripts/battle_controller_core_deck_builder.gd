extends "res://scripts/battle_controller_core_combo.gd"

const BattleDeckBuilderCardView := preload("res://scripts/visual/battle_deck_builder_card_view.gd")

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _prepare_player_battle_deck() -> void:
	if player == null:
		return
	player.set_battle_deck_limit(PLAYER_BATTLE_DECK_SIZE)
	_sanitize_player_battle_deck_selection()

func _player_battle_deck_ready() -> bool:
	if player == null:
		return false
	_prepare_player_battle_deck()
	return player.get_battle_deck_size() == PLAYER_BATTLE_DECK_SIZE

func _open_battle_deck_builder() -> void:
	if player == null:
		return
	if not battle_active:
		_prepare_player_battle_deck()
	_show_deck_builder_overlay()

func _show_deck_builder_overlay() -> void:
	if overlay_title == null or overlay_body == null or overlay_actions == null:
		return
	var read_only := battle_active
	_set_overlay_deck_builder_size()
	overlay_title.text = "牌组"
	overlay_body.text = ""
	overlay_body.visible = false
	for child in overlay_actions.get_children():
		child.queue_free()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.custom_minimum_size = Vector2(1060, 560)
	overlay_actions.add_child(root)
	_build_deck_library_column(root)
	_build_deck_slots_column(root)
	overlay_scrim.visible = true
	overlay_panel.visible = true
	overlay_scrim.move_to_front()
	overlay_panel.move_to_front()

func _build_deck_library_column(root: HBoxContainer) -> void:
	var read_only := battle_active
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(730, 540)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	left.add_child(tabs)
	for filter_label in DECK_LIBRARY_FILTERS:
		var tab := Button.new()
		tab.text = str(filter_label)
		tab.toggle_mode = true
		tab.button_pressed = deck_builder_filter == str(filter_label)
		tab.pressed.connect(_set_deck_builder_filter.bind(str(filter_label)))
		tabs.add_child(tab)
	var hint := Label.new()
	hint.text = "左侧牌库：当前战斗中只能查看，不能修改牌组。" if read_only else "左侧牌库：点击加入当前牌组。每个牌组 8 张，同名最多 2 张。"
	left.add_child(hint)
	var pager := HBoxContainer.new()
	pager.custom_minimum_size = Vector2(730, 438)
	pager.add_theme_constant_override("separation", 8)
	left.add_child(pager)
	var cards := _filtered_library_cards()
	var max_page := maxi(0, int(ceil(float(cards.size()) / 8.0)) - 1)
	deck_builder_library_page = clampi(deck_builder_library_page, 0, max_page)
	if deck_builder_library_page > 0:
		var prev := _deck_builder_page_button("◀")
		prev.pressed.connect(_change_deck_builder_page.bind(-1))
		pager.add_child(prev)
	else:
		pager.add_child(_deck_builder_page_spacer())
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(640, 438)
	card_panel.add_theme_stylebox_override("panel", _deck_library_panel_style())
	pager.add_child(card_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card_panel.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)
	var target_slot := _deck_builder_target_slot()
	var target_deck := player.get_battle_deck_slot(target_slot)
	var start_index := deck_builder_library_page * 8
	for i in range(8):
		var library_index := start_index + i
		if library_index < cards.size():
			var card: CardData = cards[library_index]
			var button := _build_deck_library_card_button(card, read_only or not _can_add_library_card_to_slot(card, target_deck))
			if not read_only:
				button.pressed.connect(_add_library_card_to_current_deck.bind(card.id))
			grid.add_child(button)
		else:
			grid.add_child(_empty_deck_library_card_slot())
	if deck_builder_library_page < max_page:
		var next := _deck_builder_page_button("▶")
		next.pressed.connect(_change_deck_builder_page.bind(1))
		pager.add_child(next)
	else:
		pager.add_child(_deck_builder_page_spacer())
	var close_row := HBoxContainer.new()
	close_row.custom_minimum_size = Vector2(730, 40)
	left.add_child(close_row)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(120, 38)
	close_button.pressed.connect(_hide_overlay)
	close_row.add_child(close_button)

func _build_deck_slots_column(root: HBoxContainer) -> void:
	var read_only := battle_active
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 540)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	if deck_builder_selected_slot_index < 0:
		var title := Label.new()
		title.text = "我的套牌"
		title.add_theme_font_size_override("font_size", 18)
		right.add_child(title)
		for i in range(PLAYER_DECK_SLOT_COUNT):
			var deck := player.get_battle_deck_slot(i)
			var button := Button.new()
			var marker := "启用｜" if i == player.get_active_battle_deck_index() else ""
			button.text = "%s%s\n%d/%d" % [marker, _deck_slot_name(i), deck.size(), PLAYER_BATTLE_DECK_SIZE]
			button.custom_minimum_size = Vector2(300, 82)
			button.pressed.connect(_open_deck_slot_detail.bind(i))
			right.add_child(button)
		return
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	right.add_child(header)
	var back := Button.new()
	back.text = "套牌"
	back.custom_minimum_size = Vector2(80, 34)
	back.pressed.connect(_return_deck_slot_list)
	header.add_child(back)
	var active := Button.new()
	active.text = "设为启用" if deck_builder_selected_slot_index != player.get_active_battle_deck_index() else "已启用"
	active.disabled = read_only or deck_builder_selected_slot_index == player.get_active_battle_deck_index()
	active.custom_minimum_size = Vector2(112, 34)
	if not read_only:
		active.pressed.connect(_set_active_deck_slot.bind(deck_builder_selected_slot_index))
	header.add_child(active)
	var deck := player.get_battle_deck_slot(deck_builder_selected_slot_index)
	var title := Label.new()
	title.text = "%s｜%d/%d" % [_deck_slot_name(deck_builder_selected_slot_index), deck.size(), PLAYER_BATTLE_DECK_SIZE]
	title.add_theme_font_size_override("font_size", 18)
	right.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, 430)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if deck.is_empty():
		var empty := Label.new()
		empty.text = "空牌组。" if read_only else "空牌组。点击左侧牌库加入招式。"
		list.add_child(empty)
	else:
		for i in range(deck.size()):
			var card: CardData = deck[i]
			var card_button := Button.new()
			card_button.text = "%d. %s" % [i + 1, card.display_name]
			card_button.custom_minimum_size = Vector2(286, 34)
			card_button.disabled = read_only
			if not read_only:
				card_button.pressed.connect(_remove_deck_slot_card.bind(deck_builder_selected_slot_index, i))
			list.add_child(card_button)

func _battle_deck_builder_text(library: Array[CardData], selected: Array[CardData]) -> String:
	var lines: Array[String] = []
	lines.append("[b]入战牌组：%d/%d[/b]" % [selected.size(), PLAYER_BATTLE_DECK_SIZE])
	if selected.is_empty():
		lines.append("尚未选择。")
	else:
		for i in range(selected.size()):
			lines.append("%d. %s" % [i + 1, selected[i].short_summary()])
	lines.append("")
	lines.append("[b]长期牌库：%d 张[/b]" % library.size())
	for i in range(library.size()):
		var card: CardData = library[i]
		var selected_count := _card_count_in_deck(selected, card.id)
		var library_count := _card_count_in_deck(library, card.id)
		lines.append("%d. [%d/%d] %s" % [i + 1, selected_count, library_count, card.short_summary()])
	if selected.size() != PLAYER_BATTLE_DECK_SIZE:
		lines.append("")
		lines.append("[color=#ffd479]需要正好 8 张才能开始战斗。[/color]")
	return "\n".join(lines)

func _deck_library_panel_style() -> StyleBoxFlat:
	return BattleDeckBuilderCardView.deck_library_panel_style()

func _deck_builder_page_button(text: String) -> Button:
	return BattleDeckBuilderCardView.deck_builder_page_button(text)

func _deck_builder_page_spacer() -> Control:
	return BattleDeckBuilderCardView.deck_builder_page_spacer()

func _change_deck_builder_page(delta: int) -> void:
	deck_builder_library_page = maxi(0, deck_builder_library_page + delta)
	_show_deck_builder_overlay()

func _build_deck_library_card_button(card: CardData, disabled: bool) -> Button:
	return BattleDeckBuilderCardView.build_deck_library_card_button(card, disabled, _deck_card_art_glyph(card))

func _empty_deck_library_card_slot() -> Control:
	return BattleDeckBuilderCardView.empty_deck_library_card_slot()

func _apply_deck_library_card_style(button: Button, card: CardData, disabled: bool) -> void:
	BattleDeckBuilderCardView.apply_deck_library_card_style(button, card, disabled)

func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	return BattleDeckBuilderCardView.make_flat_card_style(fill, border, border_width)

func _build_deck_library_card_face(button: Button, card: CardData) -> void:
	BattleDeckBuilderCardView.build_deck_library_card_face(button, card, _deck_card_art_glyph(card))

func _deck_card_badge_style() -> StyleBoxFlat:
	return BattleDeckBuilderCardView.deck_card_badge_style()

func _deck_card_type_style(card: CardData) -> StyleBoxFlat:
	return BattleDeckBuilderCardView.deck_card_type_style(card)

func _deck_card_art_style(card: CardData) -> StyleBoxFlat:
	return BattleDeckBuilderCardView.deck_card_art_style(card)

func _short_card_type_tag_for_builder(card: CardData) -> String:
	return BattleDeckBuilderCardView.short_card_type_tag_for_builder(card)

func _deck_card_art_glyph(card: CardData) -> String:
	return ShoushiComboRules.rank_text(card.shoushi_rank)

func _compact_effect_summary(card: CardData) -> String:
	return BattleDeckBuilderCardView.compact_effect_summary(card)

func _set_deck_builder_filter(filter_label: String) -> void:
	deck_builder_filter = filter_label
	deck_builder_library_page = 0
	_show_deck_builder_overlay()

func _open_deck_slot_detail(slot_index: int) -> void:
	deck_builder_selected_slot_index = clampi(slot_index, 0, PLAYER_DECK_SLOT_COUNT - 1)
	_show_deck_builder_overlay()

func _return_deck_slot_list() -> void:
	deck_builder_selected_slot_index = -1
	_show_deck_builder_overlay()

func _set_active_deck_slot(slot_index: int) -> void:
	if player == null:
		return
	player.set_active_battle_deck_index(slot_index)
	_log("已启用【%s】。" % _deck_slot_name(player.get_active_battle_deck_index()))
	_show_deck_builder_overlay()

func _deck_builder_target_slot() -> int:
	if player == null:
		return 0
	if deck_builder_selected_slot_index >= 0:
		return deck_builder_selected_slot_index
	return player.get_active_battle_deck_index()

func _deck_slot_name(index: int) -> String:
	match index:
		0: return "牌组一"
		1: return "牌组二"
		2: return "牌组三"
		3: return "牌组四"
	return "牌组%d" % (index + 1)

func _filtered_library_cards() -> Array[CardData]:
	var cards := _unique_library_cards()
	if deck_builder_filter == "全部":
		return cards
	var result: Array[CardData] = []
	for card in cards:
		if _card_matches_library_filter(card, deck_builder_filter):
			result.append(card)
	return result

func _unique_library_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}
	if player == null:
		return result
	for card in player.get_session_deck():
		if card == null or seen.has(card.id):
			continue
		seen[card.id] = true
		result.append(card.duplicate_card())
	return result

func _card_matches_library_filter(card: CardData, filter_label: String) -> bool:
	if card == null:
		return false
	match filter_label:
		"攻":
			return card.is_attack_card()
		"守":
			return card.is_guard_card()
		"变":
			return card.is_feint_card()
	return true

func _card_meta_line(card: CardData) -> String:
	var role_label := card.type_label()
	return "耗%d｜%s｜距%d-%d" % [card.momentum_cost, role_label, card.min_distance, card.max_distance]

func _find_library_card(card_id: String) -> CardData:
	for card in player.get_session_deck():
		if card != null and card.id == card_id:
			return card
	return null

func _can_add_library_card_to_slot(card: CardData, deck: Array[CardData]) -> bool:
	if card == null:
		return false
	if deck.size() >= PLAYER_BATTLE_DECK_SIZE:
		return false
	return _card_count_in_deck(deck, card.id) < PLAYER_DECK_CARD_COPY_LIMIT

func _add_library_card_to_current_deck(card_id: String) -> void:
	if player == null:
		return
	var card := _find_library_card(card_id)
	if card == null:
		return
	var slot_index := _deck_builder_target_slot()
	var deck := player.get_battle_deck_slot(slot_index)
	if deck.size() >= PLAYER_BATTLE_DECK_SIZE:
		_log("【%s】已满 8 张，不能继续加入。" % _deck_slot_name(slot_index))
	elif _card_count_in_deck(deck, card.id) >= PLAYER_DECK_CARD_COPY_LIMIT:
		_log("每个牌组中同一张牌最多 %d 张。" % PLAYER_DECK_CARD_COPY_LIMIT)
	else:
		player.add_card_to_battle_deck(card, slot_index)
		_log("已将【%s】加入【%s】。" % [card.display_name, _deck_slot_name(slot_index)])
	_refresh_ui()
	_show_deck_builder_overlay()

func _remove_deck_slot_card(slot_index: int, card_index: int) -> void:
	if player == null:
		return
	if player.remove_battle_deck_card(card_index, slot_index):
		_log("已从【%s】移出 1 张招式。" % _deck_slot_name(slot_index))
	_refresh_ui()
	_show_deck_builder_overlay()

func _add_battle_deck_card(library_index: int) -> void:
	if player == null:
		return
	var library := player.get_session_deck()
	var selected := player.get_selected_battle_deck()
	if library_index < 0 or library_index >= library.size():
		_open_battle_deck_builder()
		return
	var card: CardData = library[library_index]
	if not _can_add_library_card_to_battle_deck(card, selected, library):
		_log("这张招式在当前牌组中已达到上限，或牌组已满。")
	else:
		player.add_card_to_battle_deck(card)
	_refresh_ui()
	_open_battle_deck_builder()

func _remove_battle_deck_card(index: int) -> void:
	if player == null:
		return
	player.remove_battle_deck_card(index)
	_refresh_ui()
	_open_battle_deck_builder()

func _auto_fill_battle_deck_and_reopen() -> void:
	_auto_fill_player_battle_deck()
	_refresh_ui()
	_open_battle_deck_builder()

func _confirm_battle_deck_builder() -> void:
	if _player_battle_deck_ready():
		_log("入战牌组已确认：8 张。")
		_hide_overlay()
		_refresh_ui()
		return
	_log("入战牌组需要正好 8 张。")
	_open_battle_deck_builder()

func _auto_fill_player_battle_deck() -> void:
	if player == null:
		return
	_prepare_player_battle_deck()
	var library := _unique_library_cards()
	var selected := player.get_selected_battle_deck()
	while selected.size() < PLAYER_BATTLE_DECK_SIZE:
		var added := false
		for card in library:
			if selected.size() >= PLAYER_BATTLE_DECK_SIZE:
				break
			if _can_add_library_card_to_battle_deck(card, selected, library):
				selected.append(card.duplicate_card())
				added = true
		if not added:
			break
	player.set_selected_battle_deck(selected)

func _sanitize_player_battle_deck_selection() -> void:
	if player == null:
		return
	var library := player.get_session_deck()
	var selected := player.get_selected_battle_deck()
	var sanitized: Array[CardData] = []
	for card in selected:
		if card == null:
			continue
		if sanitized.size() >= PLAYER_BATTLE_DECK_SIZE:
			break
		if _library_has_card(library, card.id) and _card_count_in_deck(sanitized, card.id) < PLAYER_DECK_CARD_COPY_LIMIT:
			sanitized.append(card.duplicate_card())
	player.set_selected_battle_deck(sanitized)

func _can_add_library_card_to_battle_deck(card: CardData, selected: Array[CardData], library: Array[CardData]) -> bool:
	if card == null:
		return false
	if selected.size() >= PLAYER_BATTLE_DECK_SIZE:
		return false
	return _library_has_card(library, card.id) and _card_count_in_deck(selected, card.id) < PLAYER_DECK_CARD_COPY_LIMIT

func _card_count_in_deck(cards: Array[CardData], card_id: String) -> int:
	var count := 0
	for card in cards:
		if card != null and card.id == card_id:
			count += 1
	return count

func _library_has_card(library: Array[CardData], card_id: String) -> bool:
	for card in library:
		if card != null and card.id == card_id:
			return true
	return false
