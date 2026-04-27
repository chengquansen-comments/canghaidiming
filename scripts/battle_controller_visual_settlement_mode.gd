extends "res://scripts/battle_controller_visual_presentation_assets.gd"

# Thin runtime wrapper for switching battle settlement mode without touching the
# existing visual presentation chain.
#
# Default remains "symmetric" to preserve current main behavior.
# The opening overlay now lets the player choose symmetric/reactive before role selection.

@export_enum("symmetric", "reactive") var settlement_mode_id: String = "symmetric"

var _settlement_mode_selected := false


func _ready() -> void:
	super()
	_apply_visual_settlement_mode()


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
		overlay_body.text = "对称式：敌我同时拆招，按先机/崩势/武境决定顺序。\n反应式：敌方先亮出威胁，玩家后行动并尝试破解。"
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
	_apply_visual_settlement_mode()
	super._show_role_selection()


func set_visual_settlement_mode(value: String) -> void:
	settlement_mode_id = value
	_apply_visual_settlement_mode()
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


func _mode_status_suffix() -> String:
	if state_machine == null:
		return ""
	return "\n结算模式：%s（%s）" % [state_machine.settlement_mode_label(), state_machine.settlement_mode_id()]


func _refresh_ui() -> void:
	super()
	if status_label != null and state_machine != null:
		status_label.append_text(_mode_status_suffix())
