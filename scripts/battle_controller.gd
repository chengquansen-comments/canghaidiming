extends Control

const BattleStateMachine = preload("res://scripts/battle_state_machine.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const FighterData = preload("res://scripts/fighter_data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")

const HAND_SIZE := 4
const ENEMY_SESSION_REALM := 2

var state_machine := BattleStateMachine.new()
var enemy_ai := EnemyAI.new()
var fighter_catalog: Dictionary[String, FighterData] = {}
var reward_pool: Array[CardData] = []
var combo_registry: Dictionary[String, Array] = {}

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

var fusion_first_index := -1

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
var deck_button: Button
var reset_pick_button: Button
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


func _ready_card(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_min_distance: int,
	p_max_distance: int,
	p_cost: int,
	p_role: String,
	p_gain_momentum: int,
	p_break_momentum: int,
	p_damage: int,
	p_guard: int,
	p_tags: PackedStringArray = PackedStringArray()
) -> CardData:
	return CardData.new(
		p_id,
		p_name,
		p_desc,
		p_min_distance,
		p_max_distance,
		p_cost,
		p_role,
		p_gain_momentum,
		p_break_momentum,
		p_damage,
		p_guard,
		p_tags
	)


func _build_catalog() -> void:
	var spear_read := _ready_card("spear_read", "探锋", "枪手试探，专注立势。", 2, 3, 1, CardData.ROLE_MOMENTUM, 2, 0, 0, 0)
	var spear_break := _ready_card("spear_break", "压枪", "压住来路，削弱对方势头。", 2, 3, 1, CardData.ROLE_MOMENTUM, 0, 2, 0, 0)
	var spear_senki := _ready_card("spear_senki", "截势先机", "先发争先，只争势不取伤。", 1, 2, 2, CardData.ROLE_MOMENTUM, 2, 2, 0, 0, PackedStringArray(["先机"]))
	var spear_mid := _ready_card("spear_mid", "中平枪", "标准中段枪刺。", 2, 3, 1, CardData.ROLE_DAMAGE, 0, 0, 4, 0, PackedStringArray(["连招起手"]))
	var spear_heavy := _ready_card("spear_heavy", "龙脊重刺", "大开大合的重刺。", 2, 3, 2, CardData.ROLE_DAMAGE, 0, 0, 8, 0)
	var spear_guard := _ready_card("spear_guard", "回圆架", "回枪成圆，以守化险。", 1, 3, 1, CardData.ROLE_GUARD, 0, 0, 0, 4)
	var spear_wall := _ready_card("spear_wall", "封门守", "稳固门户，重守待机。", 1, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8)

	var blade_probe := _ready_card("blade_probe", "探步", "刀客试探，专注抢势。", 1, 2, 1, CardData.ROLE_MOMENTUM, 2, 0, 0, 0)
	var blade_press := _ready_card("blade_press", "逼刀", "压迫敌方，专破其势。", 1, 2, 1, CardData.ROLE_MOMENTUM, 0, 2, 0, 0)
	var blade_senki := _ready_card("blade_senki", "燕返先机", "以快争先，先夺局势。", 1, 1, 2, CardData.ROLE_MOMENTUM, 2, 2, 0, 0, PackedStringArray(["先机"]))
	var blade_cut := _ready_card("blade_cut", "赶步斩", "迅捷标准斩击。", 1, 2, 1, CardData.ROLE_DAMAGE, 0, 0, 4, 0, PackedStringArray(["连招起手"]))
	var blade_heavy := _ready_card("blade_heavy", "断流重斩", "势大力沉的压胜一斩。", 1, 2, 2, CardData.ROLE_DAMAGE, 0, 0, 8, 0)
	var blade_guard := _ready_card("blade_guard", "藏锋格", "低身藏锋，以格挡化险。", 1, 3, 1, CardData.ROLE_GUARD, 0, 0, 0, 4)
	var blade_wall := _ready_card("blade_wall", "锁门架", "以刀封门，强守不退。", 1, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8)

	var spear_deck: Array[CardData] = [spear_read, spear_break, spear_senki, spear_mid, spear_heavy, spear_guard, spear_wall]
	var blade_deck: Array[CardData] = [blade_probe, blade_press, blade_senki, blade_cut, blade_heavy, blade_guard, blade_wall]

	fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 1, PackedInt32Array([2, 3]), spear_deck)
	fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([1, 2]), blade_deck)

	reward_pool = [
		_ready_card("reward_momentum_up", "聚势", "专注提振自身势头。", 1, 3, 1, CardData.ROLE_MOMENTUM, 2, 0, 0, 0),
		_ready_card("reward_momentum_break", "断势", "专注削弱敌方势头。", 1, 3, 1, CardData.ROLE_MOMENTUM, 0, 2, 0, 0),
		_ready_card("reward_senki", "争先", "以先机抢夺势头。", 1, 2, 2, CardData.ROLE_MOMENTUM, 2, 2, 0, 0, PackedStringArray(["先机"])),
		_ready_card("reward_damage", "重手", "纯粹追求压倒性伤害。", 1, 3, 2, CardData.ROLE_DAMAGE, 0, 0, 8, 0),
		_ready_card("reward_guard", "铁壁", "纯粹追求稳固格挡。", 1, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8)
	]

	combo_registry["spearman"] = [
		{
			"id": "spear_combo_001",
			"display_name": "穿云三刺",
			"starter_card_id": "spear_mid",
			"required_card_ids": PackedStringArray(["spear_mid", "spear_heavy"]),
			"followups": [
				{"name": "追喉刺", "base_damage": 2},
				{"name": "龙脊送枪", "base_damage": 4, "is_finisher": true}
			]
		}
	]
	combo_registry["blademaster"] = [
		{
			"id": "blade_combo_001",
			"display_name": "断流三斩",
			"starter_card_id": "blade_cut",
			"required_card_ids": PackedStringArray(["blade_cut", "blade_heavy"]),
			"followups": [
				{"name": "回身快斩", "base_damage": 2},
				{"name": "断流收刀", "base_damage": 5, "is_finisher": true}
			]
		}
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
	subtitle_label.text = "势被打到 0 将在下回合崩势硬直；击崩后打出的下一招，若接上已解锁套路，会自动触发职业连招。"
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
	deck_button = Button.new()
	deck_button.text = "查看牌库"
	deck_button.pressed.connect(_open_deck_view)
	control_bar.add_child(deck_button)
	reset_pick_button = Button.new()
	reset_pick_button.text = "重选招式"
	reset_pick_button.pressed.connect(_reset_draft_intent)
	control_bar.add_child(reset_pick_button)
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


func _combo_chains_for_profession(profession_id: String) -> Array:
	return combo_registry.get(profession_id, [])


func _combo_for_starter(profession_id: String, starter_card_id: String) -> Dictionary:
	for combo in _combo_chains_for_profession(profession_id):
		if combo.get("starter_card_id", "") == starter_card_id:
			return combo
	return {}


func _combo_missing_cards(fighter: Fighter, combo: Dictionary) -> Array[String]:
	var owned := {}
	for card in fighter.get_session_deck():
		owned[card.id] = true
	var missing: Array[String] = []
	for required_id in combo.get("required_card_ids", PackedStringArray()):
		if not owned.has(required_id):
			missing.append(required_id)
	return missing


func _is_combo_unlocked(fighter: Fighter, combo: Dictionary) -> bool:
	return _combo_missing_cards(fighter, combo).is_empty()


func _get_triggerable_combo(fighter: Fighter, card: CardData) -> Dictionary:
	if fighter == null or card == null:
		return {}
	var combo := _combo_for_starter(fighter.data.id, card.id)
	if combo.is_empty():
		return {}
	if not _is_combo_unlocked(fighter, combo):
		return {}
	return combo


func _combo_marker_text(fighter: Fighter, card: CardData) -> String:
	var combo := _combo_for_starter(fighter.data.id, card.id)
	if combo.is_empty():
		return ""
	if fighter.combo_window_active:
		if _is_combo_unlocked(fighter, combo):
			return "【连招起手·可触发】%s" % combo.get("display_name", "")
		return "【连招起手·未解锁】%s" % combo.get("display_name", "")
	return "【连招起手】%s" % combo.get("display_name", "")


func _card_role_prefix(card: CardData) -> String:
	if card.is_momentum_card():
		return "【势牌】"
	if card.is_guard_card():
		return "【格挡牌】"
	return "【伤害牌】"


func _card_restriction_reason(fighter: Fighter, card: CardData) -> String:
	if fighter == null or card.id == "idle":
		return ""
	if fighter.is_broken():
		return "崩势中本回合无法行动"
	return ""


func _can_play_card(fighter: Fighter, card: CardData) -> bool:
	if fighter == null:
		return false
	if card.momentum_cost > fighter.momentum:
		return false
	return _card_restriction_reason(fighter, card) == ""


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
	fusion_first_index = -1
	_hide_overlay()
	_log("[b]新会话开始。[/b] 玩家使用 %s，对手使用 %s。" % [player.data.display_name, enemy.data.display_name])
	_show_node_buttons()
	_refresh_ui()


func _copy_fighter_data(data: FighterData) -> FighterData:
	return FighterData.new(data.id, data.display_name, data.weapon_name, data.max_hp, data.max_momentum, data.starting_momentum, data.starting_realm, data.preferred_distances, data.clone_deck())


func _show_node_buttons() -> void:
	for child in node_buttons_box.get_children():
		child.queue_free()
	if battle_active:
		node_buttons_box.visible = false
		return
	for spec in [
		{"label": "查看牌库", "callback": Callable(self, "_open_deck_view")},
		{"label": "合成藏招", "callback": Callable(self, "_begin_hidden_fusion")},
		{"label": "得招", "callback": Callable(self, "_open_gain_move")},
		{"label": "点化", "callback": Callable(self, "_apply_enlighten")},
		{"label": "演武", "callback": Callable(self, "_start_battle")}
	]:
		var button := Button.new()
		button.text = spec["label"]
		button.pressed.connect(spec["callback"])
		node_buttons_box.add_child(button)
	node_buttons_box.visible = true


func _open_gain_move() -> void:
	if player == null:
		return
	node_pick_count += 1
	var picks := _sample_rewards(3)
	var actions := []
	for card in picks:
		actions.append({"text": card.short_summary(), "callback": Callable(self, "_pick_reward_card").bind(card)})
	actions.append({"text": "取消", "callback": Callable(self, "_hide_overlay")})
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
	fusion_first_index = -1
	_hide_overlay()
	_refresh_ui()


func _cancel_hidden_fusion() -> void:
	fusion_first_index = -1
	_hide_overlay()


func _build_hidden_fusion_card(first_card: CardData, second_card: CardData) -> CardData:
	var tags := PackedStringArray(["藏招"])
	var fused_cost := first_card.momentum_cost + second_card.momentum_cost
	if first_card.is_momentum_card() and second_card.is_momentum_card():
		return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双势并举的藏招。", 1, 3, fused_cost, CardData.ROLE_MOMENTUM, first_card.gain_momentum + second_card.gain_momentum, first_card.break_momentum + second_card.break_momentum, 0, 0, tags)
	if first_card.is_guard_card() and second_card.is_guard_card():
		return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双守并立的藏招。", 1, 3, fused_cost, CardData.ROLE_GUARD, 0, 0, 0, first_card.guard + second_card.guard, tags)
	return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双重杀伤的藏招。", 1, 3, fused_cost, CardData.ROLE_DAMAGE, 0, 0, first_card.damage + second_card.damage, 0, tags)


func _open_deck_view() -> void:
	if player == null:
		return
	var body := _build_deck_view_text()
	_show_overlay("查看牌库", body, [{"text": "关闭", "callback": Callable(self, "_hide_overlay")}])


func _build_deck_view_text() -> String:
	if player == null:
		return "尚未初始化。"
	var lines: Array[String] = []
	var deck := player.get_session_deck()
	if not battle_active:
		lines.append("[b]战前牌库[/b]")
		for i in range(deck.size()):
			lines.append("%d. %s" % [i + 1, deck[i].short_summary()])
	else:
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
	fusion_first_index = -1
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
	if player.control_state != Fighter.CONTROL_NONE or enemy.control_state != Fighter.CONTROL_NONE or player.combo_window_active or enemy.combo_window_active:
		_log("[b]当前势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
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
			if player.is_broken():
				player_intent = IntentData.from_card(player, _stagger_card())
				_log("玩家崩势未稳，本回合无法行动。")
				declaration_index += 1
				continue
			awaiting_player_input = true
			_refresh_hand_buttons()
			_refresh_ui()
			return
		if enemy.is_broken():
			enemy_intent = IntentData.from_card(enemy, _stagger_card())
			_log("敌方崩势未稳，本回合无法行动。")
			declaration_index += 1
			continue
		var seen_intent: IntentData = player_intent if player_intent != null else null
		enemy_intent = enemy_ai.choose_intent(enemy, player, state_machine.current_distance, seen_intent)
		if enemy_intent.actual_card.id != "idle" and enemy_intent.actual_card.id != "staggered":
			enemy.spend_momentum(enemy_intent.actual_card.momentum_cost)
		_log("敌方定招：%s。" % state_machine.get_visible_intent_text(enemy_intent, player))
		declaration_index += 1
	awaiting_player_input = false
	_resolve_round()


func _reset_draft_intent() -> void:
	draft_player_intent = null
	_refresh_ui()


func _refresh_hand_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()
	if player == null:
		return
	for i in range(player.hand.size()):
		var card: CardData = player.hand[i]
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 142)
		button.text = "%s %s\n%s\n%s" % [_card_role_prefix(card), card.display_name, card.short_summary(), card.description]
		if marker != "":
			button.text += "\n%s" % marker
		if reason != "":
			button.text += "\n限制：%s" % reason
		button.disabled = not awaiting_player_input or not _can_play_card(player, card)
		button.pressed.connect(_on_player_card_pressed.bind(card))
		if _draft_uses_card(card):
			button.text = "[已选] " + button.text
		hand_flow.add_child(button)

	if awaiting_player_input:
		var idle_button := Button.new()
		idle_button.custom_minimum_size = Vector2(220, 142)
		idle_button.text = "【势牌】 观势\n观势｜势牌｜距1-3｜耗势 0｜增己势 1\n不主动进击，回 1 势。"
		idle_button.pressed.connect(_on_player_card_pressed.bind(_idle_card()))
		hand_flow.add_child(idle_button)


func _on_player_card_pressed(card: CardData) -> void:
	if not awaiting_player_input:
		return
	var reason := _card_restriction_reason(player, card)
	if reason != "":
		_log(reason)
		return
	if card.momentum_cost > player.momentum:
		_log("势不足，无法选用 %s。" % card.display_name)
		return
	draft_player_intent = IntentData.from_card(player, card)
	var combo_marker := _combo_marker_text(player, card)
	if combo_marker != "":
		_log("已选定%s [color=#95e1d3]%s[/color]。%s" % [_card_role_prefix(card), card.display_name, combo_marker])
	else:
		_log("已选定%s [color=#95e1d3]%s[/color]，请确认出招。" % [_card_role_prefix(card), card.display_name])
	_refresh_ui()


func _confirm_player_intent() -> void:
	if not awaiting_player_input or draft_player_intent == null:
		return
	if draft_player_intent.actual_card.id != "idle" and draft_player_intent.actual_card.id != "staggered" and not player.spend_momentum(draft_player_intent.actual_card.momentum_cost):
		_log("你的势不足，无法确认这招。")
		_refresh_ui()
		return
	player_intent = draft_player_intent
	draft_player_intent = null
	_finish_player_declaration()


func _finish_player_declaration() -> void:
	awaiting_player_input = false
	declaration_index += 1
	_log("玩家定招：%s。" % state_machine.get_visible_intent_text(player_intent, enemy))
	_advance_declaration()
	_refresh_ui()


func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines: Array[String] = []
	if actor == null or intent == null or intent.actual_card == null:
		return lines
	if not actor.combo_window_active:
		return lines
	var card: CardData = intent.actual_card
	if card.id == "staggered":
		return lines
	actor.consume_combo_window()
	var combo := _get_triggerable_combo(actor, card)
	if combo.is_empty():
		lines.append("%s 未衔接到已解锁连招，本次连招窗口消散。" % actor.data.display_name)
		return lines
	lines.append("[b]%s 启动连招：%s！[/b]" % [actor.data.display_name, combo.get("display_name", "")])
	for segment in combo.get("followups", []):
		if target.hp <= 0:
			break
		var segment_name: String = segment.get("name", "追击")
		var effective_damage: int = int(segment.get("base_damage", 0))
		if target.is_broken():
			effective_damage *= 2
			lines.append("%s 处于崩势，%s 伤害翻倍至 %d。" % [target.data.display_name, segment_name, effective_damage])
		var remaining_damage := target.absorb_damage(effective_damage)
		var blocked := effective_damage - remaining_damage
		if blocked > 0:
			lines.append("%s 被格挡化去 %d。" % [segment_name, blocked])
		if remaining_damage > 0:
			target.hp = maxi(target.hp - remaining_damage, 0)
			lines.append("%s 连招命中，造成 %d 伤害。" % [segment_name, remaining_damage])
		else:
			lines.append("%s 被完全格挡。" % segment_name)
		if bool(segment.get("is_finisher", false)):
			lines.append("[b]%s 以 %s 终结收势！[/b]" % [actor.data.display_name, segment_name])
	return lines


func _resolve_round() -> void:
	state_machine.phase = BattleStateMachine.BattlePhase.RESOLUTION
	var order := state_machine.get_resolution_order(player, enemy, player_intent, enemy_intent)
	_log("[b]结算顺序：[/b] %s -> %s" % [order[0].get_actual_name(), order[1].get_actual_name()])
	for intent in order:
		var actor := player if intent.actor_id == player.data.id else enemy
		var target := enemy if intent.actor_id == player.data.id else player
		var lines := state_machine.resolve_intent(intent, actor, target)
		for line in lines:
			_log(line)
		var combo_lines := _resolve_combo_chain_if_any(actor, target, intent)
		for line in combo_lines:
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
	_log("[b]回合势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
	_begin_round()


func _finish_battle() -> void:
	battle_active = false
	awaiting_player_input = false
	state_machine.phase = BattlePhase.RESULT
	var result_text := "玩家落败。"
	if enemy.hp <= 0:
		result_text = "玩家获胜。"
	_log("[b]演武结束。[/b] %s" % result_text)
	_show_node_buttons()
	_refresh_ui()


func _update_phase_label() -> void:
	if not battle_active:
		phase_label.text = "节点阶段：查看牌库 / 合成藏招 / 得招 / 点化 / 演武"
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
	deck_button.disabled = player == null
	reset_pick_button.disabled = not awaiting_player_input or draft_player_intent == null
	confirm_button.disabled = not awaiting_player_input or draft_player_intent == null


func _fighter_status_text(fighter: Fighter) -> String:
	if fighter == null:
		return "未初始化。"
	var session_deck_size := fighter.get_session_deck().size()
	return "[b]%s[/b]｜%s\n生命：%d/%d\n势：%d/%d\n护值：%d\n状态：%s\n连招窗口：%s\n当前武境：%d\n会话武境：%d\n优势距离：%s\n会话牌库：%d\n抽牌堆：%d｜手牌：%d｜弃牌堆：%d" % [fighter.data.display_name, fighter.data.weapon_name, fighter.hp, fighter.data.max_hp, fighter.momentum, fighter.data.max_momentum, fighter.guard_points, fighter.control_label(), fighter.combo_window_label(), fighter.realm, fighter.session_realm, fighter.preferred_text(), session_deck_size, fighter.draw_pile.size(), fighter.hand.size(), fighter.discard_pile.size()]


func _intent_panel_text(intent: IntentData, viewer: Fighter, is_player: bool) -> String:
	var owner := "玩家" if is_player else "敌方"
	if is_player and awaiting_player_input and draft_player_intent != null:
		intent = draft_player_intent
		owner = "玩家草稿"
	if intent == null:
		return "尚未定招。"
	var visible := state_machine.get_visible_intent_text(intent, viewer)
	var actual := intent.get_actual_name()
	return "[b]%s[/b]\n可见：%s\n实际：%s" % [owner, visible, actual]


func _status_text() -> String:
	if player == null or enemy == null:
		return "等待选择角色。"
	var lines: Array[String] = []
	lines.append("[b]规则测试点[/b]")
	lines.append("- 招式严格区分为势牌、伤害牌、格挡牌")
	lines.append("- 本回合势被削到 0：下回合崩势，无法行动且受击伤害翻倍")
	lines.append("- 打崩对手的一方获得连招窗口：下一招若为已解锁套路起手，则自动连段")
	lines.append("- Demo 连招：枪手【穿云三刺】；刀客【断流三斩】")
	lines.append("- 招式数值统一遵循：增己势*2 + 削敌势*2 + 伤害 + 格挡 = 耗势*4")
	lines.append("- %s" % state_machine.tie_rule_text(player, enemy))
	lines.append("- %s" % state_machine.pressure_state_text(player, enemy))
	if awaiting_player_input:
		lines.append("")
		lines.append("[b]当前操作[/b]")
		if draft_player_intent != null:
			lines.append("已选好招式，点击【确认出招】锁定动作。")
		else:
			lines.append("请选择一张手牌。若当前有连招窗口，带【连招起手】的牌会给出是否可触发的标记。")
	return "\n".join(lines)


func _preview_text() -> String:
	if not battle_active:
		return "战前可查看牌库、合成藏招，并检查职业连招是否解锁。"
	if awaiting_player_input and draft_player_intent == null:
		return "选择招式后，这里会显示双方出招后的结果预览。"
	if draft_player_intent == null or enemy_intent == null:
		return "等待双方意图。"
	return _simulate_preview(draft_player_intent, enemy_intent)


func _simulate_preview(player_preview_intent: IntentData, enemy_preview_intent: IntentData) -> String:
	var player_hp := player.hp
	var enemy_hp := enemy.hp
	var player_momentum := player.momentum
	var enemy_momentum := enemy.momentum
	var lines: Array[String] = []
	var order := state_machine.get_resolution_order(player, enemy, player_preview_intent, enemy_preview_intent)
	lines.append("[b]确认后预览[/b]")
	lines.append("结算顺序：%s -> %s" % [order[0].get_actual_name(), order[1].get_actual_name()])
	if player_preview_intent.actual_card.id != "idle" and player_preview_intent.actual_card.id != "staggered":
		player_momentum = maxi(player_momentum - player_preview_intent.actual_card.momentum_cost, 0)
		lines.append("玩家确认后将耗 %d 势，剩余 %d。" % [player_preview_intent.actual_card.momentum_cost, player_momentum])
	for intent in order:
		var actor_name := "玩家" if intent.actor_id == player.data.id else "敌方"
		var actor_ref := player if intent.actor_id == player.data.id else enemy
		var target_ref := enemy if intent.actor_id == player.data.id else player
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
		if card.id == "staggered":
			lines.append("%s 崩势硬直，无法行动。" % actor_name)
			continue
		if card.is_momentum_card():
			if card.gain_momentum > 0:
				if intent.actor_id == player.data.id:
					player_momentum = mini(player_momentum + card.gain_momentum, player.data.max_momentum)
					lines.append("玩家增己势 %d，势将变为 %d。" % [card.gain_momentum, player_momentum])
				else:
					enemy_momentum = mini(enemy_momentum + card.gain_momentum, enemy.data.max_momentum)
					lines.append("敌方增己势 %d，势将变为 %d。" % [card.gain_momentum, enemy_momentum])
			if card.break_momentum > 0:
				if intent.actor_id == player.data.id:
					enemy_momentum = maxi(enemy_momentum - card.break_momentum, 0)
					lines.append("玩家削敌势 %d，敌方势将变为 %d。" % [card.break_momentum, enemy_momentum])
					if enemy_momentum == 0:
						lines.append("敌方本回合势归零，下回合将崩势。")
				else:
					player_momentum = maxi(player_momentum - card.break_momentum, 0)
					lines.append("敌方削敌势 %d，玩家势将变为 %d。" % [card.break_momentum, player_momentum])
					if player_momentum == 0:
						lines.append("玩家本回合势归零，下回合将崩势。")
		elif card.is_damage_card() and card.damage > 0:
			if card.is_usable_at(state_machine.current_distance):
				var effective_damage := card.damage
				if intent.actor_id == player.data.id and enemy.is_broken():
					effective_damage *= 2
					lines.append("敌方处于崩势，所受伤害翻倍至 %d。" % effective_damage)
				if intent.actor_id == enemy.data.id and player.is_broken():
					effective_damage *= 2
					lines.append("玩家处于崩势，所受伤害翻倍至 %d。" % effective_damage)
				if intent.actor_id == player.data.id:
					enemy_hp = maxi(enemy_hp - effective_damage, 0)
					lines.append("命中敌方，敌方生命将变为 %d。" % enemy_hp)
				else:
					player_hp = maxi(player_hp - effective_damage, 0)
					lines.append("命中玩家，玩家生命将变为 %d。" % player_hp)
				if actor_ref.combo_window_active:
					var preview_combo := _get_triggerable_combo(actor_ref, card)
					if preview_combo.is_empty():
						lines.append("当前若出此招，连招窗口将消散。")
					else:
						lines.append("将触发连招：%s。" % preview_combo.get("display_name", ""))
						for segment in preview_combo.get("followups", []):
							var seg_damage: int = int(segment.get("base_damage", 0))
							if target_ref.is_broken():
								seg_damage *= 2
							if intent.actor_id == player.data.id:
								enemy_hp = maxi(enemy_hp - seg_damage, 0)
							else:
								player_hp = maxi(player_hp - seg_damage, 0)
							lines.append("连招段 %s 预计造成 %d。" % [segment.get("name", "追击"), seg_damage])
			else:
				lines.append("因距离 %d 不合式，将落空。" % state_machine.current_distance)
		elif card.is_guard_card() and card.guard > 0:
			lines.append("本回合作为格挡牌，提供 %d 格挡。" % card.guard)
	lines.append("最终预览：玩家 %d 血 %d 势 / 敌方 %d 血 %d 势" % [player_hp, player_momentum, enemy_hp, enemy_momentum])
	return "\n".join(lines)


func _draft_uses_card(card: CardData) -> bool:
	if draft_player_intent == null:
		return false
	for used_card in draft_player_intent.get_consumed_cards():
		if used_card == card:
			return true
	return false


func _idle_card() -> CardData:
	return _ready_card("idle", "观势", "不主动进击，收束架势并回 1 势", 1, 3, 0, CardData.ROLE_MOMENTUM, 1, 0, 0, 0)


func _stagger_card() -> CardData:
	return _ready_card("staggered", "崩势硬直", "势被打崩，下一回合无法行动。", 1, 3, 0, CardData.ROLE_MOMENTUM, 0, 0, 0, 0)


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
