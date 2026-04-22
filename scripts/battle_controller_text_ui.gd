extends "res://scripts/battle_controller_core.gd"

# Dedicated pure-text battle controller entry.
# Uses the legacy rich-text debug layout and owns the text-first UI shell.

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
	title_label.text = "对称性战斗原型（字符版）"
	title_label.add_theme_font_size_override("font_size", 30)
	root.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "文本模式优先保证规则验证、预览可读性与日志完整性。"
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

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.anchor_left = 0.5
	combat_banner.anchor_top = 0.02
	combat_banner.anchor_right = 0.5
	combat_banner.anchor_bottom = 0.02
	combat_banner.offset_left = -240
	combat_banner.offset_right = 240
	combat_banner.offset_top = 0
	combat_banner.offset_bottom = 72
	combat_banner.modulate = Color(1, 1, 1, 0)
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(Color("3a1f14"), Color("ffd479")))
	add_child(combat_banner)

	combat_banner_label = Label.new()
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner_label.add_theme_font_size_override("font_size", 28)
	combat_banner.add_child(combat_banner_label)

	screen_flash = ColorRect.new()
	screen_flash.visible = false
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(screen_flash)

	pierce_line = ColorRect.new()
	pierce_line.visible = false
	pierce_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pierce_line.anchor_left = 0.0
	pierce_line.anchor_top = 0.5
	pierce_line.anchor_right = 0.0
	pierce_line.anchor_bottom = 0.5
	pierce_line.offset_left = -120
	pierce_line.offset_top = -4
	pierce_line.offset_right = 120
	pierce_line.offset_bottom = 4
	pierce_line.color = Color(0.7, 0.9, 1.0, 0.0)
	add_child(pierce_line)

	slash_cut = ColorRect.new()
	slash_cut.visible = false
	slash_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash_cut.anchor_left = 0.5
	slash_cut.anchor_top = 0.5
	slash_cut.anchor_right = 0.5
	slash_cut.anchor_bottom = 0.5
	slash_cut.offset_left = -420
	slash_cut.offset_top = -18
	slash_cut.offset_right = 420
	slash_cut.offset_bottom = 18
	slash_cut.rotation_degrees = -18.0
	slash_cut.color = Color(1.0, 0.65, 0.45, 0.0)
	add_child(slash_cut)

	left_hit_mark = ColorRect.new()
	left_hit_mark.visible = false
	left_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_hit_mark.anchor_left = 0.04
	left_hit_mark.anchor_top = 0.25
	left_hit_mark.anchor_right = 0.22
	left_hit_mark.anchor_bottom = 0.74
	left_hit_mark.color = Color(1, 1, 1, 0)
	left_hit_mark.rotation_degrees = -14.0
	add_child(left_hit_mark)

	right_hit_mark = ColorRect.new()
	right_hit_mark.visible = false
	right_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_hit_mark.anchor_left = 0.78
	right_hit_mark.anchor_top = 0.25
	right_hit_mark.anchor_right = 0.96
	right_hit_mark.anchor_bottom = 0.74
	right_hit_mark.color = Color(1, 1, 1, 0)
	right_hit_mark.rotation_degrees = 14.0
	add_child(right_hit_mark)

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
		button.custom_minimum_size = Vector2(220, 150)
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
		idle_button.custom_minimum_size = Vector2(220, 150)
		idle_button.text = "【势牌】 观势\n观势｜势牌｜距1-3｜耗势 0｜增己势 1\n不主动进击，回 1 势。"
		idle_button.pressed.connect(_on_player_card_pressed.bind(_idle_card()))
		hand_flow.add_child(idle_button)

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
	lines.append("- 伤害牌进一步区分为：起手 / 追击 / 终结")
	lines.append("- 本回合势被削到 0：下回合崩势，无法行动且受击伤害翻倍")
	lines.append("- 打崩对手的一方获得连招窗口：下一招若为已解锁套路起手，则自动连段")
	lines.append("- Demo 连招：枪手【穿云三刺】；刀客【断流三斩】")
	lines.append("- 招式数值统一遵循：增己势*2 + 削敌势*2 + 伤害 + 格挡 = 耗势*4")
	lines.append("- %s" % state_machine.tie_rule_text(player, enemy))
	lines.append("- %s" % state_machine.pressure_state_text(player, enemy))
	lines.append("- 枪手连招偏短停顿穿刺；刀客连招偏多段斩切后重落")
	lines.append("- 枪手命中带穿刺线；刀客命中带斩切带")
	lines.append("- 受击侧会出现专属受创标记：枪刺偏贯穿，刀斩偏斜切")
	lines.append("- 受击状态层：枪刺偏钉住一下，刀斩偏失衡一下")
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
							lines.append("连招段 [%s]%s 预计造成 %d。" % [segment.get("segment_type", "追击"), segment.get("name", "追击"), seg_damage])
			else:
				lines.append("因距离 %d 不合式，将落空。" % state_machine.current_distance)
		elif card.is_guard_card() and card.guard > 0:
			lines.append("本回合作为格挡牌，提供 %d 格挡。" % card.guard)
	lines.append("最终预览：玩家 %d 血 %d 势 / 敌方 %d 血 %d 势" % [player_hp, player_momentum, enemy_hp, enemy_momentum])
	return "\n".join(lines)
