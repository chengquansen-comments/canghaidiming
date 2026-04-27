extends "res://scripts/battle_controller_visual_presentation_assets.gd"

# Thin runtime wrapper for switching battle settlement mode without touching the
# existing visual presentation chain.
#
# Default remains "symmetric" to preserve current main behavior.
# The opening overlay now lets the player choose symmetric/reactive before role selection.
# F8 toggles the mode during local testing.

@export_enum("symmetric", "reactive") var settlement_mode_id: String = "symmetric"

var _settlement_mode_selected := false
var _reactive_pre_move_round := -1


func _ready() -> void:
	super()
	_apply_visual_settlement_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			toggle_visual_settlement_mode()
			get_viewport().set_input_as_handled()
			return


func _show_role_selection() -> void:
	if not _settlement_mode_selected:
		_show_settlement_mode_selection()
		return
	super._show_role_selection()


func _show_settlement_mode_selection() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	if overlay_scrim != null:
		overlay_scrim.visible = true
	if overlay_panel != null:
		overlay_panel.visible = true
	if overlay_title != null:
		overlay_title.text = "选择结算模式"
	if overlay_body != null:
		overlay_body.text = "对称式：敌我同时拆招，按先机/崩势/武境决定顺序。\n反应式：敌方先移动并亮出威胁，玩家后行动并尝试破解。\n\n测试快捷键：战斗中按 F8 可切换模式。"
	_clear_overlay_actions()
	_add_settlement_mode_button(BattleStateMachine.MODE_SYMMETRIC_ID, "对称式：双向拆招")
	_add_settlement_mode_button(BattleStateMachine.MODE_REACTIVE_ID, "反应式：看招破解")


func _clear_overlay_actions() -> void:
	if overlay_actions == null:
		return
	for child in overlay_actions.get_children():
		child.queue_free()


func _add_settlement_mode_button(mode_id: String, title: String) -> void:
	if overlay_actions == null:
		return
	var selected_mode_id: String = mode_id
	var button := Button.new()
	button.text = title
	button.pressed.connect(func() -> void:
		_select_settlement_mode_and_continue(selected_mode_id)
	)
	overlay_actions.add_child(button)


func _select_settlement_mode_and_continue(mode_id: String) -> void:
	settlement_mode_id = mode_id
	_settlement_mode_selected = true
	_reactive_pre_move_round = -1
	_apply_visual_settlement_mode()
	super._show_role_selection()


func set_visual_settlement_mode(value: String) -> void:
	settlement_mode_id = value
	_reactive_pre_move_round = -1
	_apply_visual_settlement_mode()
	_show_combat_banner("结算模式：%s" % ("反应式" if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else "对称式"), Color("1c2a36") if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else Color("2a2018"), Color("8fd3ff") if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID else Color("ffd479"))
	_refresh_ui()


func toggle_visual_settlement_mode() -> void:
	if settlement_mode_id == BattleStateMachine.MODE_REACTIVE_ID:
		set_visual_settlement_mode(BattleStateMachine.MODE_SYMMETRIC_ID)
	else:
		set_visual_settlement_mode(BattleStateMachine.MODE_REACTIVE_ID)


func _apply_visual_settlement_mode() -> void:
	if state_machine == null:
		return
	state_machine.set_settlement_mode_id(settlement_mode_id)
	print("[settlement-mode] ", state_machine.settlement_mode_id())


func _try_apply_reactive_enemy_pre_move() -> void:
	if state_machine == null or not state_machine.is_reactive_mode():
		return
	if not battle_active or not awaiting_player_input:
		return
	if enemy == null or enemy_intent == null:
		return
	if _reactive_pre_move_round == state_machine.round_index:
		return
	if enemy_intent.target_position < 0:
		return
	var from_position: int = enemy.position
	var from_facing: String = enemy.facing
	var to_position: int = clampi(enemy_intent.target_position, 0, BATTLE_SLOT_COUNT - 1)
	var to_facing: String = enemy_intent.target_facing if enemy_intent.target_facing != "" else enemy.facing
	enemy.position = to_position
	enemy.facing = "left" if to_facing == "left" else "right"
	enemy_intent.set_stance(enemy.position, enemy.facing)
	state_machine.update_distance_from_positions(player, enemy)
	_reactive_pre_move_round = state_machine.round_index
	if log_label != null and (from_position != enemy.position or from_facing != enemy.facing):
		log_label.append_text("\n[color=#8fd3ff]反应式：敌方先移动 %s → %s，并亮出攻击意图。[/color]" % [_slot_label_safe(from_position), _slot_label_safe(enemy.position)])
	_show_combat_banner("敌方先移动，亮出威胁", Color("1c2a36"), Color("8fd3ff"))


func _slot_label_safe(slot: int) -> String:
	var labels := ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot


func _mode_status_suffix() -> String:
	if state_machine == null:
		return ""
	var text := "\n结算模式：%s（%s）" % [state_machine.settlement_mode_label(), state_machine.settlement_mode_id()]
	text += "\n快捷键：F8 切换结算模式"
	if state_machine.is_reactive_mode():
		text += "\n反应式规则：敌方先移动并亮意图；玩家响应后先结算；若打出崩势，敌方本回合攻击中断。"
	return text


func _refresh_ui() -> void:
	_try_apply_reactive_enemy_pre_move()
	super()
	if status_label != null and state_machine != null:
		status_label.append_text(_mode_status_suffix())
