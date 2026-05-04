extends "res://scripts/battle_controller_visual_reactive_round_flow.gd"

# Thin final UI glue for reactive settlement mode.
#
# Story encounter selection lives in battle_controller_visual_story_selection.gd.
# Reactive round flow and enemy pre-move animation live in
# battle_controller_visual_reactive_round_flow.gd. This final layer only appends
# settlement-mode status/preview text and keeps actor glows / intent bubbles in
# sync with reactive visibility rules.

const ReactivePreviewFormatter = preload("res://scripts/battle_controller_visual_reactive_preview_formatter.gd")


func _mode_status_suffix() -> String:
	if state_machine == null:
		return ""
	var text: String = "\n剧情遭遇：%s" % story_encounter_id
	text += "\n结算模式：%s（%s）" % [state_machine.settlement_mode_label(), state_machine.settlement_mode_id()]
	text += "\n快捷键：F8 切换结算模式"
	if state_machine.is_reactive_mode():
		text += "\n反应式规则：敌方先移动并亮意图；玩家响应后先结算；若打出崩势，敌方本回合攻击中断。"
	return text


func _reactive_threat_preview_text() -> String:
	return ReactivePreviewFormatter.threat_preview_text(
		state_machine,
		player,
		enemy,
		enemy_intent,
		draft_player_intent,
		draft_player_has_position,
		draft_player_position,
		draft_player_facing,
		BATTLE_SLOT_COUNT
	)


func _reactive_resolution_preview() -> Dictionary:
	return ReactivePreviewFormatter.resolution_preview(
		player,
		enemy,
		enemy_intent,
		draft_player_intent,
		draft_player_has_position,
		draft_player_position,
		draft_player_facing,
		BATTLE_SLOT_COUNT
	)


func _range_text_safe(range_result: String) -> String:
	return ReactivePreviewFormatter.range_text_safe(range_result)


func _refresh_ui() -> void:
	_try_apply_reactive_enemy_pre_move()
	super()
	if confirm_button != null and _reactive_pre_move_animating:
		confirm_button.disabled = true
	if status_label != null and state_machine != null:
		status_label.append_text(_mode_status_suffix())
	if preview_label != null:
		preview_label.append_text(_reactive_threat_preview_text())
	_refresh_reactive_action_glows()


func _refresh_single_intent_bubble(is_player: bool, force: bool = false) -> void:
	if not is_player and not _enemy_intent_reveal_allowed:
		if enemy_intent_bubble != null:
			enemy_intent_bubble.visible = false
		_set_intent_bubble_signature(false, "")
		return
	super._refresh_single_intent_bubble(is_player, force)


func _enemy_preview_intent() -> IntentData:
	if not _enemy_intent_reveal_allowed:
		return null
	return super._enemy_preview_intent()


func _refresh_reactive_action_glows() -> void:
	if _presentation_busy():
		return
	if not battle_active:
		_clear_actor_action_glows()
		return
	if _reactive_pre_move_animating:
		_set_actor_action_glow(true, false)
		_set_actor_action_glow(false, true)
		return
	if awaiting_player_input:
		_set_actor_action_glow(false, false)
		_set_actor_action_glow(true, true)
		return
	_clear_actor_action_glows()
