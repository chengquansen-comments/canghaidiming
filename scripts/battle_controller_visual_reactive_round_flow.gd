extends "res://scripts/battle_controller_visual_story_selection.gd"

# Reactive settlement-mode round flow.
#
# This layer owns round-start sequencing, enemy intent reveal timing,
# round-start momentum recovery, reactive enemy pre-move application, and
# pre-move animation. Threat preview text and final UI status decoration stay in
# battle_controller_visual_settlement_mode.gd.

const BattleEffectApplierForSettlement = preload("res://scripts/battle_effect_applier.gd")
const ROUND_START_BANNER_DURATION := 0.75
const ENEMY_INTENT_REVEAL_DELAY_AFTER_ROUND_BANNER := 0.10
const ROUND_START_MOMENTUM_RECOVERY_DELAY := 0.10
const ROUND_START_PRESENTATION_WAIT_TIMEOUT := 8.0
const REACTIVE_PRE_MOVE_STEP_DURATION := 0.26
const REACTIVE_PRE_MOVE_STEP_PAUSE := 0.10

var _reactive_pre_move_round := -1
var _reactive_pre_move_animation_round := -1
var _reactive_pre_move_animating := false
var _round_start_sequence_token := 0
var _enemy_intent_reveal_allowed := true
var _round_start_player_momentum_gain := 0
var _round_start_enemy_momentum_gain := 0
var _round_start_should_recover_momentum := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			if has_method("_on_undo_move_pressed"):
				call("_on_undo_move_pressed")
				get_viewport().set_input_as_handled()
				return
		if event.keycode == KEY_F8:
			toggle_visual_settlement_mode()
			get_viewport().set_input_as_handled()
			return


func _clear_story_battle_reactive_state() -> void:
	_reactive_pre_move_round = -1
	_reactive_pre_move_animation_round = -1
	_reactive_pre_move_animating = false


func _begin_round() -> void:
	if not _presentation_busy():
		_clear_actor_action_glows()
	_enemy_intent_reveal_allowed = false
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	state_machine.update_distance_from_positions(player, enemy)
	_round_start_player_momentum_gain = 0
	_round_start_enemy_momentum_gain = 0
	_round_start_should_recover_momentum = state_machine.round_index > 1
	if player.control_state != Fighter.CONTROL_NONE or enemy.control_state != Fighter.CONTROL_NONE or player.combo_window_active or enemy.combo_window_active:
		_log("[b]当前势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
	declaration_order = state_machine.get_declaration_order(player, enemy)
	declaration_index = 0
	awaiting_player_input = false
	_update_phase_label()
	_refresh_ui()
	_round_start_sequence_token += 1
	call_deferred("_begin_round_after_round_banner", _round_start_sequence_token, state_machine.round_index)


func _begin_round_after_round_banner(token: int, round_value: int) -> void:
	if token != _round_start_sequence_token or not battle_active:
		return
	var busy_wait_elapsed: float = 0.0
	while _presentation_busy():
		await get_tree().create_timer(0.05).timeout
		busy_wait_elapsed += 0.05
		if token != _round_start_sequence_token or not battle_active:
			return
		if busy_wait_elapsed >= ROUND_START_PRESENTATION_WAIT_TIMEOUT:
			_finish_presentation_exchange("round-start-wait-timeout")
			break
	_clear_actor_action_glows()
	await _play_round_start_banner(round_value)
	if token != _round_start_sequence_token or not battle_active:
		return
	await _play_round_start_momentum_gain_presentation()
	if token != _round_start_sequence_token or not battle_active:
		return
	if ENEMY_INTENT_REVEAL_DELAY_AFTER_ROUND_BANNER > 0.0:
		await get_tree().create_timer(ENEMY_INTENT_REVEAL_DELAY_AFTER_ROUND_BANNER).timeout
		if token != _round_start_sequence_token or not battle_active:
			return
	_enemy_intent_reveal_allowed = true
	_advance_declaration()
	_refresh_ui()


func _play_round_start_banner(round_value: int) -> void:
	if combat_banner == null or combat_banner_label == null:
		await get_tree().create_timer(ROUND_START_BANNER_DURATION).timeout
		return
	combat_banner.visible = true
	combat_banner_label.text = "第 %d 回合" % round_value
	combat_banner_label.modulate = Color.WHITE
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(Color("1a2935"), Color("8fd3ff")))
	combat_banner.scale = Vector2(0.90, 0.90)
	combat_banner.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.tween_property(combat_banner, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.parallel().tween_property(combat_banner, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(maxf(ROUND_START_BANNER_DURATION - 0.18, 0.12))
	tween.tween_property(combat_banner, "modulate", Color(1, 1, 1, 0), 0.10)
	await tween.finished
	combat_banner.visible = false


func _play_round_start_momentum_gain_presentation() -> void:
	if not _round_start_should_recover_momentum:
		return
	_round_start_should_recover_momentum = false
	if ROUND_START_MOMENTUM_RECOVERY_DELAY > 0.0:
		await get_tree().create_timer(ROUND_START_MOMENTUM_RECOVERY_DELAY).timeout
	var player_before: int = player.momentum if player != null else 0
	var enemy_before: int = enemy.momentum if enemy != null else 0
	_round_start_player_momentum_gain = player.recover_momentum(ROUND_MOMENTUM_RECOVERY) if player != null else 0
	_round_start_enemy_momentum_gain = enemy.recover_momentum(ROUND_MOMENTUM_RECOVERY) if enemy != null else 0
	if _round_start_player_momentum_gain > 0 or _round_start_enemy_momentum_gain > 0:
		_log("[b]回合调息。[/b] 玩家 +%d 势，敌方 +%d 势。" % [_round_start_player_momentum_gain, _round_start_enemy_momentum_gain])
	if _round_start_player_momentum_gain <= 0 and _round_start_enemy_momentum_gain <= 0:
		return
	if _round_start_player_momentum_gain > 0 and player != null:
		await _animate_momentum_dots_between(true, player_before, player.momentum, true)
	if _round_start_enemy_momentum_gain > 0 and enemy != null:
		await _animate_momentum_dots_between(false, enemy_before, enemy.momentum, true)
	_round_start_player_momentum_gain = 0
	_round_start_enemy_momentum_gain = 0


func _try_apply_reactive_enemy_pre_move() -> void:
	if not _enemy_intent_reveal_allowed:
		return
	if not battle_active or not awaiting_player_input:
		return
	var result: Dictionary = BattleEffectApplierForSettlement.apply_reactive_enemy_pre_move(state_machine, player, enemy, enemy_intent, _reactive_pre_move_round)
	_reactive_pre_move_round = int(result.get("round", _reactive_pre_move_round))
	if not bool(result.get("applied", false)):
		return
	if log_label != null and bool(result.get("changed", false)):
		log_label.append_text("\n[color=#8fd3ff]反应式：敌方先移动 %s → %s，并亮出攻击意图。[/color]" % [_slot_label_safe(int(result.get("from_position", 0))), _slot_label_safe(int(result.get("to_position", 0)))])
		_show_combat_banner("敌方先移动，亮出威胁", Color("1c2a36"), Color("8fd3ff"))
	if bool(result.get("changed", false)):
		_reactive_pre_move_animating = true
		awaiting_player_input = false
		_hand_buttons_signature = ""
		_invalidate_stage_preview()
		var from_slot: int = int(result.get("from_position", -1))
		var to_slot: int = int(result.get("to_position", -1))
		if _is_valid_presentation_slot(from_slot) and _is_valid_presentation_slot(to_slot) and from_slot != to_slot:
			_set_enemy_presentation_offset(_slot_offset_between(false, from_slot, to_slot))
		call_deferred("_play_reactive_enemy_pre_move_animation", result)


func _play_reactive_enemy_pre_move_animation(result: Dictionary) -> void:
	var round_value: int = int(result.get("round", -1))
	if round_value < 0 or _reactive_pre_move_animation_round == round_value:
		_reactive_pre_move_animating = false
		return
	if not bool(result.get("changed", false)):
		_reactive_pre_move_animating = false
		return
	var from_slot: int = int(result.get("from_position", -1))
	var to_slot: int = int(result.get("to_position", -1))
	if not _is_valid_presentation_slot(from_slot) or not _is_valid_presentation_slot(to_slot):
		_reactive_pre_move_animating = false
		return
	if from_slot == to_slot:
		_reactive_pre_move_animating = false
		return
	_reactive_pre_move_animation_round = round_value
	_set_actor_action_glow(true, false)
	_set_actor_action_glow(false, true)
	await _play_phase_focus_cue("敌方预移", ACTOR_GLOW_ENEMY_COLOR)
	_set_enemy_presentation_offset(_slot_offset_between(false, from_slot, to_slot))
	await _animate_reactive_enemy_pre_move_slots(from_slot, to_slot)
	_set_enemy_presentation_offset(Vector2.ZERO)
	_set_actor_action_glow(false, false)
	await get_tree().create_timer(0.24).timeout
	_set_actor_action_glow(true, true)
	await _play_phase_focus_cue("我方行动", ACTOR_GLOW_PLAYER_COLOR, 0.45)
	_reactive_pre_move_animating = false
	awaiting_player_input = true
	_hand_buttons_signature = ""
	_invalidate_stage_preview()
	_refresh_hand_buttons()
	_refresh_ui()


func _animate_reactive_enemy_pre_move_slots(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot:
		return
	var step_dir: int = 1 if to_slot > from_slot else -1
	var current_slot: int = from_slot
	while current_slot != to_slot:
		var next_slot: int = current_slot + step_dir
		if not _is_valid_presentation_slot(next_slot):
			break
		var from_offset: Vector2 = _slot_offset_between(false, current_slot, to_slot)
		var to_offset: Vector2 = _slot_offset_between(false, next_slot, to_slot)
		await _tween_reactive_enemy_pre_move_step(from_offset, to_offset)
		current_slot = next_slot
		if current_slot != to_slot:
			await get_tree().create_timer(REACTIVE_PRE_MOVE_STEP_PAUSE).timeout


func _tween_reactive_enemy_pre_move_step(from_offset: Vector2, to_offset: Vector2) -> void:
	var mid_offset: Vector2 = from_offset.lerp(to_offset, 0.55) + Vector2(0.0, PRESENTATION_STEP_MOVE_BOB_Y)
	var tween: Tween = create_tween()
	tween.tween_method(Callable(self, "_set_enemy_presentation_offset"), from_offset, mid_offset, REACTIVE_PRE_MOVE_STEP_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(self, "_set_enemy_presentation_offset"), mid_offset, to_offset, REACTIVE_PRE_MOVE_STEP_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


func _confirm_player_intent() -> void:
	if _reactive_pre_move_animating:
		return
	super._confirm_player_intent()


func _on_stage_grid_slot_pressed(slot: int) -> void:
	if _reactive_pre_move_animating:
		return
	super._on_stage_grid_slot_pressed(slot)


func _slot_label_safe(slot: int) -> String:
	var labels: Array[String] = ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot
