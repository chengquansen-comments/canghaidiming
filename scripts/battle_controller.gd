extends Control

const BattleStateMachine = preload("res://scripts/battle_state_machine.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const FighterData = preload("res://scripts/fighter_data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const FeintData = preload("res://scripts/feint_data.gd")
const HiddenMoveData = preload("res://scripts/hidden_move_data.gd")

const HAND_SIZE := 4
const ENEMY_SESSION_REALM := 2

enum PlayerSelectionMode {
	NORMAL,
	HIDDEN_PICK_VISIBLE,
	HIDDEN_PICK_REAL
}

var state_machine := BattleStateMachine.new()
var enemy_ai := EnemyAI.new()
var fighter_catalog: Dictionary[String, FighterData] = {}
var reward_pool: Array[CardData] = []

var player: Fighter
var enemy: Fighter
var player_role_id := ""
var battle_active := false
var awaiting_player_input := false
var battle_count := 0
var node_pick_count := 0

var player_intent: IntentData
var enemy_intent: IntentData
var draft_player_intent: IntentData
var declaration_order: PackedStringArray = PackedStringArray()
var declaration_index := 0
var selection_mode: PlayerSelectionMode = PlayerSelectionMode.NORMAL
var pending_visible_card: CardData

var title_label: Label
var subtitle_label: Label
var round_label: Label
var phase_label: Label
var player_label: RichTextLabel
var enemy_label: RichTextLabel
var player_visible_label: RichTextLabel
var enemy_visible_label: RichTextLabel
var status_label: RichTextLabel
var preview_label: RichTextLabel
var hand_flow: HFlowContainer
var log_label: RichTextLabel
var node_buttons_box: HBoxContainer
var normal_button: Button
var hidden_button: Button
var cancel_hidden_button: Button
var confirm_button: Button
var overlay_scrim: ColorRect
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: RichTextLabel
var overlay_actions: VBoxContainer


func _ready() -> void:
	_build_catalog()
	_build_ui()
	state_machine.reset_for_session()
	_show_role_selection()


func _build_catalog() -> void:
	# Phase 1: minimal typed data catalog for the symmetry prototype.
	var spear_mid := CardData.new("spear_mid", "中平枪", "标准枪式", 2, 3, 6, 0, 1)
	var spear_senki := CardData.new("spear_senki", "截势先机", "抢先压枪", 1, 2, 4, 0, 2, PackedStringArray(["先机"]))
	var spear_press := CardData.new("spear_press", "逼步拿势", "贴一步再刺", 1, 2, 5, -1, 1)
	var spear_reset := CardData.new("spear_reset", "撤枪回圆", "拉开再守", 2, 3, 3, 1, 0)

	var blade_dash := CardData.new("blade_dash", "赶步斩", "逼近抢身", 1, 2, 5, -1, 1)
	var blade_senki := CardData.new("blade_senki", "燕返", "刀客快先手", 1, 1, 4, 0, 2, PackedStringArray(["先机"]))
	var blade_sweep := CardData.new("blade_sweep", "掠地反撩", "一步半再撩", 2, 3, 6, 0, 1)
	var blade_backstep := CardData.new("blade_backstep", "藏锋退步", "退一步蓄势", 1, 3, 3, 1, 0)

	var spear_deck: Array[CardData] = [spear_mid, spear_mid, spear_senki, spear_press, spear_reset]
	var blade_deck: Array[CardData] = [blade_dash, blade_dash, blade_senki, blade_sweep, blade_backstep]

	fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 1, PackedInt32Array([2, 3]), spear_deck)
	fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([1, 2]), blade_deck)

	reward_pool = [
		CardData.new("reward_spear_long", "龙脊长拿", "拉远后重击", 2, 3, 7, 1, 2),
		CardData.new("reward_spear_senki", "枪影先机", "枪手先发抢点", 1, 2, 5, 0, 2, PackedStringArray(["先机"])),
		CardData.new("reward_blade_close", "切步贴身", "逼近再斩", 1, 2, 6, -1, 1),
		CardData.new("reward_blade_senki", "追命先机", "刀客快斩", 1, 2, 5, 0, 2, PackedStringArray(["先机"])),
		CardData.new("reward_generic_read", "回身试探", "轻伤并调距", 1, 3, 3, 1, 0)
	]


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("10151d")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	title_label = Label.new()
	title_label.text = "对称性战斗原型"
	title_label.add_theme_font_size_override("font_size", 30)
	root.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "测试武境先后、先机优先、藏招可见意图与识机权轮流。"
	subtitle_label.modulate = Color("b8c0cc")
	root.add_child(subtitle_label)

	var top_info := HBoxContainer.new()
	top_info.add_theme_constant_override("separation", 12)
	root.add_child(top_info)

	round_label = Label.new()
	round_label.text = "尚未开战"
	round_label.add_theme_font_size_override("font_size", 22)
	top_info.add_child(round_label)

	phase_label = Label.new()
	phase_label.text = "待选流派"
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_info.add_child(phase_label)

	node_buttons_box = HBoxContainer.new()
	node_buttons_box.add_theme_constant_override("separation", 10)
	root.add_child(node_buttons_box)

	var battle_panels := HBoxContainer.new()
	battle_panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_panels.add_theme_constant_override("separation", 12)
	root.add_child(battle_panels)

	player_label = _build_rich_panel(battle_panels, "玩家状态")
	status_label = _build_rich_panel(battle_panels, "战斗摘要")
	enemy_label = _build_rich_panel(battle_panels, "敌方状态")

	var intent_panels := HBoxContainer.new()
	intent_panels.add_theme_constant_override("separation", 12)
	root.add_child(intent_panels)
	player_visible_label = _build_rich_panel(intent_panels, "玩家可见意图")
	preview_label = _build_rich_panel(intent_panels, "结果预览")
	enemy_visible_label = _build_rich_panel(intent_panels, "敌方可见意图")

	var control_bar := HBoxContainer.new()
	control_bar.add_theme_constant_override("separation", 10)
	root.add_child(control_bar)

	normal_button = Button.new()
	normal_button.text = "常态出招"
	normal_button.pressed.connect(_set_normal_mode)
	control_bar.add_child(normal_button)

	hidden_button = Button.new()
	hidden_button.text = "藏招模式"
	hidden_button.pressed.connect(_begin_hidden_mode)
	control_bar.add_child(hidden_button)

	cancel_hidden_button = Button.new()
	cancel_hidden_button.text = "取消藏招"
	cancel_hidden_button.pressed.connect(_cancel_hidden_mode)
	control_bar.add_child(cancel_hidden_button)

	confirm_button = Button.new()
	confirm_button.text = "确认出招"
	confirm_button.pressed.connect(_confirm_player_intent)
	control_bar.add_child(confirm_button)

	var hand_panel := PanelContainer.new()
	hand_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("18212a"), Color("52606d")))
	hand_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(hand_panel)

	hand_flow = HFlowContainer.new()
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_flow.add_theme_constant_override("h_separation", 10)
	hand_flow.add_theme_constant_override("v_separation", 10)
	hand_panel.add_child(hand_flow)

	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("18212a"), Color("52606d")))
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(log_panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	log_label.scroll_following = true
	log_panel.add_child(log_label)

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
	overlay_panel.offset_left = -320
	overlay_panel.offset_right = 320
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


func _build_rich_panel(parent: Control, heading: String) -> RichTextLabel:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("18212a"), Color("52606d")))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	box.add_child(rich)
	return rich


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


func _show_role_selection() -> void:
	_show_overlay(
		"选择角色",
		"[b]这版原型只做枪手与刀客。[/b]\n\n当前规则：敌方默认武境 2，玩家初始武境按角色起始值进入。你可以通过【点化】拉到同武境或更高武境，专门测试识机权与先发权。",
		[
			{"text": "枪手开局", "callback": Callable(self, "_start_session").bind("spearman")},
			{"text": "刀客开局", "callback": Callable(self, "_start_session").bind("blademaster")}
		]
	)
	_refresh_ui()


func _start_session(role_id: String) -> void:
	player_role_id = role_id
	var enemy_role_id := "blademaster" if role_id == "spearman" else "spearman"
	player = Fighter.new(_copy_fighter_data(fighter_catalog[role_id]))
	enemy = Fighter.new(_copy_fighter_data(fighter_catalog[enemy_role_id]))
	enemy.set_session_realm(ENEMY_SESSION_REALM)
	battle_count = 0
	node_pick_count = 0
	battle_active = false
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	declaration_order = PackedStringArray()
	selection_mode = PlayerSelectionMode.NORMAL
	pending_visible_card = null
	_hide_overlay()
	_log("[b]新会话开始。[/b] 玩家使用 %s，对手使用 %s。" % [player.data.display_name, enemy.data.display_name])
	_show_node_buttons()
	_refresh_ui()


func _copy_fighter_data(data: FighterData) -> FighterData:
	return FighterData.new(
		data.id,
		data.display_name,
		data.weapon_name,
		data.max_hp,
		data.max_momentum,
		data.starting_momentum,
		data.starting_realm,
		data.preferred_distances,
		data.clone_deck()
	)


func _show_node_buttons() -> void:
	for child in node_buttons_box.get_children():
		child.queue_free()
	for spec in [
		{"label": "得招", "callback": Callable(self, "_open_gain_move")},
		{"label": "点化", "callback": Callable(self, "_apply_enlighten")},
		{"label": "演武", "callback": Callable(self, "_start_battle")}
	]:
		var button := Button.new()
		button.text = spec["label"]
		button.pressed.connect(spec["callback"])
		node_buttons_box.add_child(button)
	node_buttons_box.visible = not battle_active


func _open_gain_move() -> void:
	if player == null:
		return
	node_pick_count += 1
	var picks := _sample_rewards(3)
	var actions := []
	for card in picks:
		actions.append({"text": card.short_summary(), "callback": Callable(self, "_pick_reward_card").bind(card)})
	_show_overlay("得招", "从 3 张招式里选 1 张加入牌池。为了便于测试，允许跨流派混搭。", actions)


func _sample_rewards(count: int) -> Array[CardData]:
	var pool: Array[CardData] = []
	for template in reward_pool:
		pool.append(template.duplicate_card())
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func _pick_reward_card(card: CardData) -> void:
	player.add_card_to_deck(card)
	_log("你通过【得招】获得了 [color=#95e1d3]%s[/color]。" % card.display_name)
	_hide_overlay()
	_refresh_ui()


func _apply_enlighten() -> void:
	if player == null:
		return
	if player.upgrade_realm():
		_log("你通过【点化】将会话武境提升到 %d。" % player.session_realm)
	else:
		_log("你的武境已达当前原型上限 3。")
	_refresh_ui()


func _start_battle() -> void:
	if player == null or enemy == null:
		return
	battle_active = true
	battle_count += 1
	player.reset_for_battle(HAND_SIZE)
	enemy.reset_for_battle(HAND_SIZE)
	state_machine.begin_battle(2)
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	declaration_index = 0
	selection_mode = PlayerSelectionMode.NORMAL
	pending_visible_card = null
	_log("[b]演武开始。[/b] 第 %d 场，对距固定从 2 开始。玩家会话武境 %d，敌方会话武境 %d。" % [battle_count, player.session_realm, enemy.session_realm])
	_show_node_buttons()
	_begin_round()


func _begin_round() -> void:
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	if state_machine.round_index > 1:
		var player_gain := player.recover_momentum(1)
		var enemy_gain := enemy.recover_momentum(1)
		if player_gain > 0 or enemy_gain > 0:
			_log("[b]回合调息。[/b] 玩家 +%d 势，敌方 +%d 势。" % [player_gain, enemy_gain])
	# Phase 2: refresh declaration order every round so realm changes and tie swaps both take effect.
	declaration_order = state_machine.get_declaration_order(player, enemy)
	declaration_index = 0
	awaiting_player_input = false
	_update_phase_label()
	_advance_declaration()
	_refresh_ui()


func _advance_declaration() -> void:
	while declaration_index < declaration_order.size():
		var actor_id: String = declaration_order[declaration_index]
		if actor_id == player.data.id:
			awaiting_player_input = true
			_refresh_hand_buttons()
			_refresh_ui()
			return
		var seen_intent: IntentData = player_intent if player_intent != null else null
		enemy_intent = enemy_ai.choose_intent(enemy, player, state_machine.current_distance, seen_intent)
		if enemy_intent.actual_card.id != "idle":
			enemy.spend_momentum(enemy_intent.actual_card.momentum_cost)
		_log("敌方定招：%s。" % state_machine.get_visible_intent_text(enemy_intent, player))
		declaration_index += 1
	awaiting_player_input = false
	_resolve_round()


func _set_normal_mode() -> void:
	selection_mode = PlayerSelectionMode.NORMAL
	pending_visible_card = null
	_refresh_ui()


func _begin_hidden_mode() -> void:
	if not awaiting_player_input or player == null or _count_affordable_hand_cards() < 2:
		_log("当前可用势不足，两张不同招式都无法成藏招。")
		return
	selection_mode = PlayerSelectionMode.HIDDEN_PICK_VISIBLE
	pending_visible_card = null
	_refresh_ui()


func _cancel_hidden_mode() -> void:
	selection_mode = PlayerSelectionMode.NORMAL
	pending_visible_card = null
	draft_player_intent = null
	_refresh_ui()


func _refresh_hand_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()
	if player == null:
		return
	for i in range(player.hand.size()):
		var card: CardData = player.hand[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 124)
		button.text = card.short_summary() + "\n" + card.description
		button.disabled = not awaiting_player_input or card.momentum_cost > player.momentum
		button.pressed.connect(_on_player_card_pressed.bind(card))
		if pending_visible_card == card:
			button.text = "[表招] " + button.text
		elif _draft_uses_card(card):
			button.text = "[已选] " + button.text
		hand_flow.add_child(button)

	if awaiting_player_input and selection_mode == PlayerSelectionMode.NORMAL:
		var idle_button := Button.new()
		idle_button.custom_minimum_size = Vector2(220, 124)
		idle_button.text = "观势｜距1-3｜耗势 0\n不主动进击，回 1 势。"
		idle_button.pressed.connect(_on_player_card_pressed.bind(_idle_card()))
		hand_flow.add_child(idle_button)


func _on_player_card_pressed(card: CardData) -> void:
	if not awaiting_player_input:
		return
	if card.id == "idle" and selection_mode != PlayerSelectionMode.NORMAL:
		return
	if card.momentum_cost > player.momentum:
		_log("势不足，无法选用 %s。" % card.display_name)
		return
	match selection_mode:
		PlayerSelectionMode.NORMAL:
			draft_player_intent = IntentData.from_card(player, card)
			_log("已选定常态招式 [color=#95e1d3]%s[/color]，请确认出招。" % card.display_name)
			_refresh_ui()
		PlayerSelectionMode.HIDDEN_PICK_VISIBLE:
			pending_visible_card = card
			draft_player_intent = null
			selection_mode = PlayerSelectionMode.HIDDEN_PICK_REAL
			_log("已选表招 [color=#95e1d3]%s[/color]，请再选里招。" % card.display_name)
			_refresh_ui()
		PlayerSelectionMode.HIDDEN_PICK_REAL:
			if pending_visible_card == null or pending_visible_card == card or pending_visible_card.id == card.id:
				_log("藏招需要两张不同的招式牌。")
				return
			var hidden := HiddenMoveData.new(FeintData.new(pending_visible_card), card)
			draft_player_intent = IntentData.from_hidden_move(player, hidden, [pending_visible_card, card])
			_log("已组好藏招：表招 [color=#95e1d3]%s[/color] / 里招 [color=#95e1d3]%s[/color]，请确认出招。" % [pending_visible_card.display_name, card.display_name])
			_refresh_ui()


func _confirm_player_intent() -> void:
	if not awaiting_player_input or draft_player_intent == null:
		return
	if draft_player_intent.actual_card.id != "idle" and not player.spend_momentum(draft_player_intent.actual_card.momentum_cost):
		_log("你的势不足，无法确认这招。")
		_refresh_ui()
		return
	player_intent = draft_player_intent
	draft_player_intent = null
	_finish_player_declaration()


func _finish_player_declaration() -> void:
	awaiting_player_input = false
	selection_mode = PlayerSelectionMode.NORMAL
	pending_visible_card = null
	declaration_index += 1
	_log("玩家定招：%s。" % state_machine.get_visible_intent_text(player_intent, enemy))
	_advance_declaration()
	_refresh_ui()


func _resolve_round() -> void:
	state_machine.phase = BattleStateMachine.BattlePhase.RESOLUTION
	# Phase 3: resolve after both intents are locked, preserving senki and realm priority rules.
	var order := state_machine.get_resolution_order(player, enemy, player_intent, enemy_intent)
	_log("[b]结算顺序：[/b] %s -> %s" % [order[0].get_actual_name(), order[1].get_actual_name()])
	for intent in order:
		var actor := player if intent.actor_id == player.data.id else enemy
		var target := enemy if intent.actor_id == player.data.id else player
		var lines := state_machine.resolve_intent(intent, actor, target)
		for line in lines:
			_log(line)
		_refresh_ui()
		if target.hp <= 0:
			break

	player.discard_cards(player_intent.get_consumed_cards())
	enemy.discard_cards(enemy_intent.get_consumed_cards())
	player.draw_to(HAND_SIZE)
	enemy.draw_to(HAND_SIZE)

	if player.hp <= 0 or enemy.hp <= 0:
		_finish_battle()
		return

	state_machine.finish_round(player, enemy)
	_begin_round()


func _finish_battle() -> void:
	battle_active = false
	awaiting_player_input = false
	state_machine.phase = BattleStateMachine.BattlePhase.RESULT
	var result_text := "玩家落败。"
	if enemy.hp <= 0:
		result_text = "玩家获胜。"
	_log("[b]演武结束。[/b] %s" % result_text)
	_show_node_buttons()
	_refresh_ui()


func _update_phase_label() -> void:
	if not battle_active:
		phase_label.text = "节点阶段：得招 / 点化 / 演武"
		return
	var declare_names: Array[String] = []
	for actor_id in declaration_order:
		if player != null and actor_id == player.data.id:
			declare_names.append(player.data.display_name)
		elif enemy != null and actor_id == enemy.data.id:
			declare_names.append(enemy.data.display_name)
		else:
			declare_names.append(actor_id)
	var declare_text := " -> ".join(declare_names)
	phase_label.text = "回合 %d｜定招顺序：%s" % [state_machine.round_index, declare_text]


func _refresh_ui() -> void:
	round_label.text = "演武 %d｜距离 %d" % [battle_count, state_machine.current_distance]
	_update_phase_label()
	player_label.text = _fighter_status_text(player)
	enemy_label.text = _fighter_status_text(enemy)
	player_visible_label.text = _intent_panel_text(player_intent, enemy, true)
	enemy_visible_label.text = _intent_panel_text(enemy_intent, player, false)
	preview_label.text = _preview_text()
	status_label.text = _status_text()
	_refresh_hand_buttons()
	_refresh_log()
	_show_node_buttons()
	normal_button.disabled = not awaiting_player_input
	hidden_button.disabled = not awaiting_player_input or _count_affordable_hand_cards() < 2
	cancel_hidden_button.disabled = not awaiting_player_input or selection_mode == PlayerSelectionMode.NORMAL
	confirm_button.disabled = not awaiting_player_input or draft_player_intent == null


func _fighter_status_text(fighter: Fighter) -> String:
	if fighter == null:
		return "未初始化。"
	return "[b]%s[/b]｜%s\n生命：%d/%d\n势：%d/%d\n当前武境：%d\n会话武境：%d\n优势距离：%s\n牌库：%d｜手牌：%d" % [
		fighter.data.display_name,
		fighter.data.weapon_name,
		fighter.hp,
		fighter.data.max_hp,
		fighter.momentum,
		fighter.data.max_momentum,
		fighter.realm,
		fighter.session_realm,
		fighter.preferred_text(),
		fighter.draw_pile.size(),
		fighter.hand.size()
	]


func _intent_panel_text(intent: IntentData, viewer: Fighter, is_player: bool) -> String:
	var owner := "玩家" if is_player else "敌方"
	if is_player and awaiting_player_input and draft_player_intent != null:
		intent = draft_player_intent
		owner = "玩家草稿"
	if intent == null:
		return "尚未定招。"
	var visible := state_machine.get_visible_intent_text(intent, viewer)
	var actual := intent.get_actual_name() if not intent.is_hidden() else "（里招隐藏）"
	if intent.is_hidden() and viewer != null and intent.source_fighter == viewer:
		actual = intent.get_actual_name()
	return "[b]%s[/b]\n可见：%s\n实际：%s" % [owner, visible, actual]


func _status_text() -> String:
	if player == null or enemy == null:
		return "等待选择角色。"
	var lines: Array[String] = []
	lines.append("[b]规则测试点[/b]")
	lines.append("- 高武境后定招，并通常先结算")
	lines.append("- 带【先机】标签的招式先于武境顺序")
	lines.append("- 藏招只暴露表招，里招仍然隐藏")
	lines.append("- 招式会耗势，每回合开始自动回 1 势")
	lines.append("- %s" % state_machine.tie_rule_text(player, enemy))
	if awaiting_player_input:
		lines.append("")
		lines.append("[b]当前操作[/b]")
		if selection_mode == PlayerSelectionMode.HIDDEN_PICK_VISIBLE:
			lines.append("请选择一张表招。")
		elif selection_mode == PlayerSelectionMode.HIDDEN_PICK_REAL:
			lines.append("请选择一张不同的里招。")
		elif draft_player_intent != null:
			lines.append("已选好招式，点击【确认出招】锁定动作。")
		else:
			lines.append("请选择常态出招，或切到藏招模式。")
	return "\n".join(lines)


func _preview_text() -> String:
	if not battle_active:
		return "进入演武后，这里会显示可见意图下的结果预览。"
	if awaiting_player_input and draft_player_intent == null:
		return "选择招式后，若敌方真意图可见，这里会显示双方出招后的结果预览。"
	if draft_player_intent == null or enemy_intent == null:
		return "等待双方意图。"
	if enemy_intent.is_hidden() and not enemy_intent.can_hidden_be_read(player):
		return "敌方当前只暴露表招，尚不能预览完整结果。"
	return _simulate_preview(draft_player_intent, enemy_intent)


func _simulate_preview(player_preview_intent: IntentData, enemy_preview_intent: IntentData) -> String:
	var player_hp := player.hp
	var enemy_hp := enemy.hp
	var player_momentum := player.momentum
	var enemy_momentum := enemy.momentum
	var preview_distance := state_machine.current_distance
	var lines: Array[String] = []
	var order := state_machine.get_resolution_order(player, enemy, player_preview_intent, enemy_preview_intent)
	lines.append("[b]确认后预览[/b]")
	lines.append("结算顺序：%s -> %s" % [order[0].get_actual_name(), order[1].get_actual_name()])
	if player_preview_intent.actual_card.id != "idle":
		player_momentum = maxi(player_momentum - player_preview_intent.actual_card.momentum_cost, 0)
		lines.append("玩家确认后将耗 %d 势，剩余 %d。" % [player_preview_intent.actual_card.momentum_cost, player_momentum])
	for intent in order:
		var actor_name := "玩家" if intent.actor_id == player.data.id else "敌方"
		var card: CardData = intent.actual_card
		if intent.actor_id == player.data.id and player_hp <= 0:
			continue
		if intent.actor_id == enemy.data.id and enemy_hp <= 0:
			continue
		lines.append("%s使用 %s。" % [actor_name, card.display_name])
		if card.id == "idle":
			if intent.actor_id == player.data.id:
				player_momentum = mini(player_momentum + 1, player.data.max_momentum)
				lines.append("玩家回观收势，势将恢复到 %d。" % player_momentum)
			else:
				enemy_momentum = mini(enemy_momentum + 1, enemy.data.max_momentum)
				lines.append("敌方回观收势，势将恢复到 %d。" % enemy_momentum)
			continue
		if card.distance_delta != 0:
			var old_distance := preview_distance
			preview_distance = clampi(preview_distance + card.distance_delta, 1, 3)
			if old_distance == preview_distance:
				lines.append("距离到边界，位移未生效。")
			else:
				lines.append("距离 %+d，变为 %d。" % [card.distance_delta, preview_distance])
		if card.damage > 0:
			if card.is_usable_at(preview_distance):
				if intent.actor_id == player.data.id:
					enemy_hp = maxi(enemy_hp - card.damage, 0)
					lines.append("命中敌方，敌方生命将变为 %d。" % enemy_hp)
				else:
					player_hp = maxi(player_hp - card.damage, 0)
					lines.append("命中玩家，玩家生命将变为 %d。" % player_hp)
			else:
				lines.append("因距离 %d 不合式，将落空。" % preview_distance)
	lines.append("最终预览：玩家 %d 血 %d 势 / 敌方 %d 血 %d 势 / 距离 %d" % [player_hp, player_momentum, enemy_hp, enemy_momentum, preview_distance])
	return "\n".join(lines)


func _draft_uses_card(card: CardData) -> bool:
	if draft_player_intent == null:
		return false
	for used_card in draft_player_intent.get_consumed_cards():
		if used_card == card:
			return true
	return false


func _idle_card() -> CardData:
	return CardData.new("idle", "观势", "不主动进击，收束架势并回 1 势", 1, 3, 0, 0, 0)


func _count_affordable_hand_cards() -> int:
	if player == null:
		return 0
	var count := 0
	for card in player.hand:
		if card.momentum_cost <= player.momentum:
			count += 1
	return count


func _refresh_log() -> void:
	log_label.text = "\n".join(_recent_logs())


func _recent_logs() -> Array[String]:
	var logs: Array[String] = []
	for line in get_meta("battle_logs", []):
		logs.append(line)
	return logs.slice(maxi(logs.size() - 20, 0), logs.size())


func _log(message: String) -> void:
	var logs: Array[String] = []
	if has_meta("battle_logs"):
		logs = get_meta("battle_logs")
	logs.append(message)
	set_meta("battle_logs", logs)
	_refresh_log()


func _show_overlay(title: String, body: String, actions: Array) -> void:
	overlay_title.text = title
	overlay_body.text = body
	for child in overlay_actions.get_children():
		child.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = action["text"]
		button.pressed.connect(action["callback"])
		overlay_actions.add_child(button)
	overlay_scrim.visible = true
	overlay_panel.visible = true


func _hide_overlay() -> void:
	overlay_scrim.visible = false
	overlay_panel.visible = false
