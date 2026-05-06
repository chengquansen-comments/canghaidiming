extends RefCounted

# Overlay column builder for the battle deck builder.
#
# Requires owner methods used below and owns no deck state itself.

var c

func _init(controller) -> void:
	c = controller


func show_deck_builder_overlay() -> void:
	if c.overlay_title == null or c.overlay_body == null or c.overlay_actions == null:
		return
	c._set_overlay_deck_builder_size()
	c.overlay_title.text = "牌组"
	c.overlay_body.text = ""
	c.overlay_body.visible = false
	for child in c.overlay_actions.get_children():
		child.queue_free()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.custom_minimum_size = Vector2(1060, 560)
	c.overlay_actions.add_child(root)
	build_deck_library_column(root)
	build_deck_slots_column(root)
	c.overlay_scrim.visible = true
	c.overlay_panel.visible = true
	c.overlay_scrim.move_to_front()
	c.overlay_panel.move_to_front()


func build_deck_library_column(root: HBoxContainer) -> void:
	var read_only: bool = c.battle_active
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(730, 540)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	left.add_child(tabs)
	for filter_label in c.DECK_LIBRARY_FILTERS:
		var tab := Button.new()
		tab.text = str(filter_label)
		tab.toggle_mode = true
		tab.button_pressed = c.deck_builder_filter == str(filter_label)
		tab.pressed.connect(c._set_deck_builder_filter.bind(str(filter_label)))
		tabs.add_child(tab)

	var hint := Label.new()
	hint.text = "左侧牌库：当前战斗中只能查看，不能修改牌组。" if read_only else "左侧牌库：点击加入当前牌组。每个牌组 8 张，同名最多 2 张。"
	left.add_child(hint)

	var pager := HBoxContainer.new()
	pager.custom_minimum_size = Vector2(730, 438)
	pager.add_theme_constant_override("separation", 8)
	left.add_child(pager)

	var cards: Array[CardData] = c._filtered_library_cards()
	var max_page: int = maxi(0, int(ceil(float(cards.size()) / 8.0)) - 1)
	c.deck_builder_library_page = clampi(c.deck_builder_library_page, 0, max_page)
	if c.deck_builder_library_page > 0:
		var prev := c._deck_builder_page_button("◀")
		prev.pressed.connect(c._change_deck_builder_page.bind(-1))
		pager.add_child(prev)
	else:
		pager.add_child(c._deck_builder_page_spacer())

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(640, 438)
	card_panel.add_theme_stylebox_override("panel", c._deck_library_panel_style())
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

	var target_slot: int = c._deck_builder_target_slot()
	var target_deck: Array[CardData] = c.player.get_battle_deck_slot(target_slot)
	var start_index: int = c.deck_builder_library_page * 8
	for i in range(8):
		var library_index: int = start_index + i
		if library_index < cards.size():
			var card: CardData = cards[library_index]
			var button := c._build_deck_library_card_button(card, read_only or not c._can_add_library_card_to_slot(card, target_deck))
			if not read_only:
				button.pressed.connect(c._add_library_card_to_current_deck.bind(card.id))
			grid.add_child(button)
		else:
			grid.add_child(c._empty_deck_library_card_slot())

	if c.deck_builder_library_page < max_page:
		var next := c._deck_builder_page_button("▶")
		next.pressed.connect(c._change_deck_builder_page.bind(1))
		pager.add_child(next)
	else:
		pager.add_child(c._deck_builder_page_spacer())

	var close_row := HBoxContainer.new()
	close_row.custom_minimum_size = Vector2(730, 40)
	left.add_child(close_row)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(120, 38)
	close_button.pressed.connect(c._hide_overlay)
	close_row.add_child(close_button)


func build_deck_slots_column(root: HBoxContainer) -> void:
	var read_only: bool = c.battle_active
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 540)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	if c.deck_builder_selected_slot_index < 0:
		var title := Label.new()
		title.text = "我的套牌"
		title.add_theme_font_size_override("font_size", 18)
		right.add_child(title)
		for i in range(c.PLAYER_DECK_SLOT_COUNT):
			var deck: Array[CardData] = c.player.get_battle_deck_slot(i)
			var button := Button.new()
			var marker := "启用｜" if i == c.player.get_active_battle_deck_index() else ""
			button.text = "%s%s\n%d/%d" % [marker, c._deck_slot_name(i), deck.size(), c.PLAYER_BATTLE_DECK_SIZE]
			button.custom_minimum_size = Vector2(300, 82)
			button.pressed.connect(c._open_deck_slot_detail.bind(i))
			right.add_child(button)
		return

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	right.add_child(header)
	var back := Button.new()
	back.text = "套牌"
	back.custom_minimum_size = Vector2(80, 34)
	back.pressed.connect(c._return_deck_slot_list)
	header.add_child(back)
	var active := Button.new()
	active.text = "设为启用" if c.deck_builder_selected_slot_index != c.player.get_active_battle_deck_index() else "已启用"
	active.disabled = read_only or c.deck_builder_selected_slot_index == c.player.get_active_battle_deck_index()
	active.custom_minimum_size = Vector2(112, 34)
	if not read_only:
		active.pressed.connect(c._set_active_deck_slot.bind(c.deck_builder_selected_slot_index))
	header.add_child(active)

	var deck: Array[CardData] = c.player.get_battle_deck_slot(c.deck_builder_selected_slot_index)
	var title := Label.new()
	title.text = "%s｜%d/%d" % [c._deck_slot_name(c.deck_builder_selected_slot_index), deck.size(), c.PLAYER_BATTLE_DECK_SIZE]
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
				card_button.pressed.connect(c._remove_deck_slot_card.bind(c.deck_builder_selected_slot_index, i))
			list.add_child(card_button)
