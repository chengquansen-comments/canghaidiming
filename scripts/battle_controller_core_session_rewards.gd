extends "res://scripts/battle_controller_core_stance.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _show_role_selection() -> void:
	_show_overlay(
		"选择角色",
		"[b]这版原型只做枪手与刀客。[/b]\n\n当前规则：当一方的势在本回合被削到 0 时，其将在下一回合崩势：无法行动，且受击伤害翻倍。打崩对手的一方，会在该回合获得一次连招窗口；若其打出的下一招接上已解锁的职业连招起手，则会自动连段。",
		[
			{"text": "枪手开局", "callback": Callable(self, "_start_session").bind("spearman")},
			{"text": "刀客开局", "callback": Callable(self, "_start_session").bind("blademaster")}
		]
	)
	_refresh_ui()

func _start_session(role_id: String) -> void:
	player_role_id = role_id
	var enemy_role_id := "blademaster" if role_id == "spearman" or role_id == "master_veteran" else "spearman"
	player = Fighter.new(_copy_fighter_data(fighter_catalog[role_id]))
	_prepare_player_battle_deck()
	enemy = Fighter.new(_copy_fighter_data(fighter_catalog[enemy_role_id]))
	enemy.set_session_realm(ENEMY_SESSION_REALM)
	battle_count = 0
	node_pick_count = 0
	battle_active = false
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	declaration_order = PackedStringArray()
	fusion_first_index = -1
	_hide_overlay()
	_log("[b]新会话开始。[/b] 玩家使用 %s，对手使用 %s。" % [player.data.display_name, enemy.data.display_name])
	_show_node_buttons()
	_refresh_ui()

func _copy_fighter_data(data: FighterData) -> FighterData:
	return FighterData.new(data.id, data.display_name, data.weapon_name, data.max_hp, data.max_momentum, data.starting_momentum, data.starting_realm, data.preferred_distances, data.clone_deck(), data.qinggong, data.starting_position, data.starting_facing)

func _show_node_buttons() -> void:
	if node_buttons_box == null:
		return
	for child in node_buttons_box.get_children():
		child.queue_free()
	if player == null:
		deck_button = null
		node_buttons_box.visible = false
		return
	var summary_button := Button.new()
	summary_button.text = "战斗摘要"
	summary_button.pressed.connect(_open_battle_summary)
	node_buttons_box.add_child(summary_button)
	deck_button = Button.new()
	deck_button.text = "牌组"
	deck_button.pressed.connect(_open_battle_deck_builder)
	deck_button.disabled = player == null
	node_buttons_box.add_child(deck_button)
	if battle_active:
		node_buttons_box.visible = true
		return
	for spec in [
			{"label": "开始战斗", "callback": Callable(self, "_request_start_battle")}
		]:
		var button := Button.new()
		button.text = spec["label"]
		button.pressed.connect(spec["callback"])
		node_buttons_box.add_child(button)
	node_buttons_box.visible = true

func _request_start_battle() -> void:
	if has_method("_start_battle"):
		call("_start_battle")


func _open_battle_summary() -> void:
	_show_overlay("战斗摘要", _status_text(), [{"text": "关闭", "callback": Callable(self, "_hide_overlay")}])

func _open_gain_move() -> void:
	if player == null:
		return
	node_pick_count += 1
	var picks := _sample_rewards(3)
	var actions := []
	for card in picks:
		actions.append({"text": card.short_summary(), "callback": Callable(self, "_pick_reward_card").bind(card)})
	actions.append({"text": "取消", "callback": Callable(self, "_hide_overlay")})
	_show_overlay("得招", "从 3 张招式里选 1 张加入长期牌库。入战仍需在【牌组】中选满 8 张。", actions)

func _sample_rewards(count: int) -> Array[CardData]:
	var pool: Array[CardData] = []
	for template in reward_pool:
		pool.append(template.duplicate_card())
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func _pick_reward_card(card: CardData, source_label: String = "得招") -> void:
	player.add_card_to_deck(card)
	_log("你通过【%s】获得了 [color=#95e1d3]%s[/color]，已加入长期牌库。" % [source_label, card.display_name])
	_hide_overlay()
	_refresh_ui()

func _apply_enlighten() -> void:
	if player == null:
		return
	if player.upgrade_realm():
		_log("你通过【点化】将会话武境提升到 %d。" % player.session_realm)
		_open_realm_move_reward()
	else:
		_log("你的武境已达当前原型上限 3。")
		_refresh_ui()

func _open_realm_move_reward() -> void:
	var picks := _sample_rewards(3)
	var actions := []
	for card in picks:
		actions.append({"text": card.short_summary(), "callback": Callable(self, "_pick_reward_card").bind(card, "武境突破")})
	actions.append({"text": "稍后再说", "callback": Callable(self, "_hide_overlay")})
	_show_overlay("武境突破", "从 3 张招式里选 1 张加入长期牌库。新招不会自动进入当前入战 8 张。", actions)
