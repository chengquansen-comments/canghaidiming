extends "res://scripts/battle_controller_core_overlay_log.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _update_phase_label() -> void:
	if phase_label == null:
		return
	if not battle_active:
		phase_label.text = "节点阶段：战斗摘要 / 牌组 / 演武"
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
	if player != null and player.combo_window_active:
		phase_label.text += "｜玩家连招窗口开启"
	elif enemy != null and enemy.combo_window_active:
		phase_label.text += "｜敌方连招窗口开启"

func _refresh_ui() -> void:
	if round_label != null:
		round_label.text = "演武 %d｜距离 %d" % [battle_count, state_machine.current_distance]
	_update_phase_label()
	if deck_button != null:
		deck_button.disabled = player == null
	if reset_pick_button != null:
		reset_pick_button.disabled = not awaiting_player_input or draft_player_intent == null
	if confirm_button != null:
		confirm_button.disabled = not awaiting_player_input or draft_player_intent == null
	_refresh_log()
	if has_method("_show_node_buttons"):
		call("_show_node_buttons")

func _fighter_status_text(fighter: Fighter) -> String:
	if fighter == null:
		return ""
	return fighter.data.display_name

func _intent_panel_text(intent: IntentData, viewer: Fighter, is_player: bool) -> String:
	if intent == null:
		return ""
	return intent.get_actual_name()

func _status_text() -> String:
	if player == null or enemy == null:
		return "等待选择角色。"
	var lines: Array[String] = []
	lines.append("[b]当前概况[/b]")
	lines.append("演武 %d｜距离 %d｜回合 %d" % [battle_count, state_machine.current_distance, state_machine.round_index])
	lines.append("玩家：%s｜生命 %d/%d｜势 %d/%d｜护值 %d｜位 %d｜朝%s" % [player.data.display_name, player.hp, player.data.max_hp, player.momentum, player.data.max_momentum, player.guard_points, player.position, "左" if player.facing == "left" else "右"])
	lines.append("敌方：%s｜生命 %d/%d｜势 %d/%d｜护值 %d｜位 %d｜朝%s" % [enemy.data.display_name, enemy.hp, enemy.data.max_hp, enemy.momentum, enemy.data.max_momentum, enemy.guard_points, enemy.position, "左" if enemy.facing == "left" else "右"])
	lines.append("")
	lines.append("[b]当前规则状态[/b]")
	lines.append("- %s" % state_machine.tie_rule_text(player, enemy))
	lines.append("- %s" % state_machine.pressure_state_text(player, enemy))
	return "\n".join(lines)

func _preview_text() -> String:
	return ""

func _simulate_preview(player_preview_intent: IntentData, enemy_preview_intent: IntentData) -> String:
	return ""

func _draft_uses_card(card: CardData) -> bool:
	if draft_player_intent == null:
		return false
	for used_card in draft_player_intent.get_consumed_cards():
		if used_card == card:
			return true
	return false

func _idle_card() -> CardData:
	return _ready_card("idle", "不动", "本回合不出招，不产生额外效果。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0, PackedStringArray(), "", false)

func _preview_wait_card() -> CardData:
	return _ready_card("preview_wait", "待机", "仅用于预览：尚未选招时按什么都不做处理。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0, PackedStringArray(), "", false)

func _stagger_card() -> CardData:
	return _ready_card("staggered", "崩势硬直", "势被打崩，下一回合无法行动。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0, PackedStringArray(), "", false)
