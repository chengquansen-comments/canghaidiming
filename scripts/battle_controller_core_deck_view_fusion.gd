extends "res://scripts/battle_controller_core_deck_builder.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _begin_hidden_fusion() -> void:
	if player == null:
		return
	var deck := player.get_session_deck()
	if deck.size() < 2:
		_log("牌库少于 2 张，无法合成藏招。")
		return
	fusion_first_index = -1
	_show_fusion_pick_overlay()

func _show_fusion_pick_overlay() -> void:
	if player == null:
		return
	var deck := player.get_session_deck()
	var actions := []
	var title := "合成藏招"
	var body := "从当前牌库中选择两张已有招式，合成为一张更强的藏招。合成后原两张移出牌库，新牌加入牌库末尾。"
	if fusion_first_index >= 0 and fusion_first_index < deck.size():
		title = "选择第二张牌"
		body = "已选第一张：[b]%s[/b]\n再选一张不同的牌完成合成。" % deck[fusion_first_index].short_summary()
	for i in range(deck.size()):
		var card: CardData = deck[i]
		var prefix := ""
		if i == fusion_first_index:
			prefix = "[已选] "
		actions.append({"text": "%s%d. %s" % [prefix, i + 1, card.short_summary()], "callback": Callable(self, "_on_fusion_pick").bind(i)})
	if fusion_first_index >= 0:
		actions.append({"text": "取消本次合成", "callback": Callable(self, "_cancel_hidden_fusion")})
	else:
		actions.append({"text": "关闭", "callback": Callable(self, "_hide_overlay")})
	_show_overlay(title, body, actions)

func _on_fusion_pick(index: int) -> void:
	if player == null:
		return
	if fusion_first_index < 0:
		fusion_first_index = index
		_show_fusion_pick_overlay()
		return
	if index == fusion_first_index:
		_log("合成藏招需要两张不同的牌。")
		return
	var deck := player.get_session_deck()
	if fusion_first_index >= deck.size() or index >= deck.size():
		fusion_first_index = -1
		_hide_overlay()
		return
	var first_card: CardData = deck[fusion_first_index]
	var second_card: CardData = deck[index]
	var fused := _build_hidden_fusion_card(first_card, second_card)
	if player.replace_cards_in_session_deck(fusion_first_index, index, fused):
		_log("你将 [color=#95e1d3]%s[/color] 与 [color=#95e1d3]%s[/color] 合成为藏招 [color=#ffd479]%s[/color]。" % [first_card.display_name, second_card.display_name, fused.display_name])
		_auto_fill_player_battle_deck()
	fusion_first_index = -1
	_hide_overlay()
	_refresh_ui()

func _cancel_hidden_fusion() -> void:
	fusion_first_index = -1
	_hide_overlay()

func _build_hidden_fusion_card(first_card: CardData, second_card: CardData) -> CardData:
	var tags := PackedStringArray(["藏招"])
	var fused_cost := first_card.momentum_cost + second_card.momentum_cost
	if first_card.is_feint_card() and second_card.is_feint_card():
		return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双变并行的藏招。", 1, 3, fused_cost, CardData.ROLE_FEINT, first_card.gain_momentum + second_card.gain_momentum, first_card.break_momentum + second_card.break_momentum, 0, 0, tags)
	if first_card.is_guard_card() and second_card.is_guard_card():
		return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双守并立的藏招。", 1, 3, fused_cost, CardData.ROLE_GUARD, 0, 0, 0, first_card.guard + second_card.guard, tags)
	tags.append("终结")
	return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双重杀伤的藏招。", 1, 3, fused_cost, CardData.ROLE_ATTACK, 0, 0, first_card.damage + second_card.damage, 0, tags)

func _open_deck_view() -> void:
	if player == null:
		return
	if not battle_active:
		_open_battle_deck_builder()
		return
	var body := _build_deck_view_text()
	_show_overlay("牌组", body, [{"text": "关闭", "callback": Callable(self, "_hide_overlay")}])

func _build_deck_view_text() -> String:
	if player == null:
		return "尚未初始化。"
	var lines: Array[String] = []
	var deck := player.get_session_deck()
	var battle_deck := player.get_selected_battle_deck()
	if not battle_active:
		lines.append("[b]长期牌库[/b]")
		for i in range(deck.size()):
			lines.append("%d. %s" % [i + 1, deck[i].short_summary()])
		lines.append("")
		lines.append("[b]入战牌组 %d/%d[/b]" % [battle_deck.size(), PLAYER_BATTLE_DECK_SIZE])
		for i in range(battle_deck.size()):
			lines.append("%d. %s" % [i + 1, battle_deck[i].short_summary()])
	else:
		lines.append("[b]本场入战牌组[/b]")
		for i in range(battle_deck.size()):
			lines.append("%d. %s" % [i + 1, battle_deck[i].short_summary()])
		lines.append("")
		lines.append("[b]当前手牌[/b]")
		for i in range(player.hand.size()):
			lines.append("%d. %s" % [i + 1, player.hand[i].short_summary()])
		lines.append("")
		lines.append("[b]抽牌堆[/b]")
		for i in range(player.draw_pile.size()):
			lines.append("%d. %s" % [i + 1, player.draw_pile[i].short_summary()])
		lines.append("")
		lines.append("[b]弃牌堆[/b]")
		for i in range(player.discard_pile.size()):
			lines.append("%d. %s" % [i + 1, player.discard_pile[i].short_summary()])
	lines.append("")
	lines.append("[b]已解锁连招[/b]")
	for combo in _combo_chains_for_profession(player.data.id):
		var missing := _combo_missing_cards(player, combo)
		if missing.is_empty():
			lines.append("- %s：已解锁" % combo.get("display_name", ""))
		else:
			lines.append("- %s：未解锁（缺 %s）" % [combo.get("display_name", ""), ", ".join(missing)])
	return "\n".join(lines)
