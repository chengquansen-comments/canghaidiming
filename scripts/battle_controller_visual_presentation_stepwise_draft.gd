extends "res://scripts/battle_controller_visual_presentation_stepwise_facing.gd"

# Stepwise player draft-move layer.
#
# Owns the pre-confirm grid click flow, draft stance target, undo button,
# player draft movement animation, and confirm-time draft freeze.

var undo_move_button: Button
var _player_draft_visual_active := false
var _player_draft_visual_origin_slot := -1
var _player_draft_visual_origin_facing := ""
var _player_draft_visual_slot := -1
var _player_draft_visual_facing := ""
var _player_draft_move_token := 0
var _player_draft_move_tween: Tween
var _player_draft_turn_tween: Tween


func _build_ui() -> void:
	super._build_ui()
	_ensure_undo_move_button()


func _refresh_ui() -> void:
	super._refresh_ui()
	_refresh_undo_move_button()


func _ensure_undo_move_button() -> void:
	if undo_move_button != null:
		return
	if confirm_button == null or confirm_button.get_parent() == null:
		return
	var parent := confirm_button.get_parent()
	undo_move_button = Button.new()
	undo_move_button.name = "UndoMoveButton"
	undo_move_button.text = "撤销移动(Z)"
	undo_move_button.focus_mode = Control.FOCUS_NONE
	undo_move_button.disabled = true
	undo_move_button.pressed.connect(_on_undo_move_pressed)
	parent.add_child(undo_move_button)
	parent.move_child(undo_move_button, confirm_button.get_index() + 1)
	if has_method("_style_plain_button_once"):
		call("_style_plain_button_once", undo_move_button)

func _refresh_undo_move_button() -> void:
	_ensure_undo_move_button()
	if undo_move_button == null:
		return
	var can_undo := battle_active and awaiting_player_input and draft_player_has_position and _player_draft_visual_active
	undo_move_button.visible = battle_active
	undo_move_button.disabled = not can_undo

func _on_undo_move_pressed() -> void:
	_cancel_player_draft_visual_move()
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false
	if draft_player_intent != null and player != null:
		draft_player_intent.set_stance(player.position, player.facing)
	_refresh_ui()

func _ensure_player_draft_visual_origin() -> void:
	if player == null:
		return
	if _player_draft_visual_active:
		return
	_player_draft_visual_active = true
	_player_draft_visual_origin_slot = player.position
	_player_draft_visual_origin_facing = player.facing
	_player_draft_visual_slot = player.position
	_player_draft_visual_facing = player.facing

func _play_player_draft_visual_to(target_slot: int, target_facing: String) -> void:
	if player == null or not _player_draft_visual_active:
		return
	_player_draft_move_token += 1
	var token := _player_draft_move_token
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	var start_slot: int = _player_draft_visual_slot if _is_valid_presentation_slot(_player_draft_visual_slot) else _player_draft_visual_origin_slot
	var safe_target_slot: int = clampi(target_slot, 0, GRID_SLOT_COUNT - 1)
	var safe_target_facing: String = target_facing if _is_valid_facing(target_facing) else _player_draft_visual_origin_facing
	call_deferred("_run_player_draft_visual_to", token, start_slot, safe_target_slot, safe_target_facing)

func _run_player_draft_visual_to(token: int, start_slot: int, target_slot: int, target_facing: String) -> void:
	if not _player_draft_visual_active or token != _player_draft_move_token:
		return
	_apply_visual_facing(true, _player_draft_visual_facing)
	var current_slot: int = start_slot
	while current_slot != target_slot and token == _player_draft_move_token:
		var next_slot: int = current_slot + (1 if target_slot > current_slot else -1)
		var from_offset := _slot_offset_between(true, current_slot, _player_draft_visual_origin_slot)
		var to_offset := _slot_offset_between(true, next_slot, _player_draft_visual_origin_slot)
		await _tween_player_draft_one_grid_step(token, from_offset, to_offset)
		current_slot = next_slot
		_player_draft_visual_slot = current_slot
	if token != _player_draft_move_token:
		return
	_player_draft_visual_slot = target_slot
	var final_offset := _slot_offset_between(true, target_slot, _player_draft_visual_origin_slot)
	_set_player_presentation_offset(final_offset)
	if _is_valid_facing(target_facing) and target_facing != _player_draft_visual_facing:
		await _play_player_draft_visual_turn(token, _player_draft_visual_facing, target_facing)
	if token != _player_draft_move_token:
		return
	_player_draft_visual_facing = target_facing

func _tween_player_draft_one_grid_step(token: int, from_offset: Vector2, to_offset: Vector2) -> void:
	var mid_offset := from_offset.lerp(to_offset, 0.55) + Vector2(0.0, PRESENTATION_STEP_MOVE_BOB_Y)
	_player_draft_move_tween = create_tween()
	_player_draft_move_tween.tween_method(Callable(self, "_set_player_presentation_offset"), from_offset, mid_offset, PRESENTATION_STEP_MOVE_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_player_draft_move_tween.tween_method(Callable(self, "_set_player_presentation_offset"), mid_offset, to_offset, PRESENTATION_STEP_MOVE_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _player_draft_move_tween.finished
	if token != _player_draft_move_token:
		return

func _play_player_draft_visual_turn(token: int, from_facing: String, to_facing: String) -> void:
	var node: CanvasItem = _presentation_visual_node(true)
	if node == null:
		_apply_visual_facing(true, to_facing)
		return
	_apply_visual_facing(true, from_facing)
	if node is TextureRect:
		var sprite := node as TextureRect
		sprite.pivot_offset = sprite.size * 0.5
		var sprite_scale := sprite.scale
		var sprite_base_x: float = maxf(absf(sprite_scale.x), 1.0)
		var sprite_base_y: float = maxf(absf(sprite_scale.y), 1.0)
		_player_draft_turn_tween = create_tween()
		_player_draft_turn_tween.tween_property(sprite, "scale", Vector2(sprite_base_x * PRESENTATION_TURN_COMPRESS_X, sprite_base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
		_player_draft_turn_tween.tween_callback(Callable(self, "_apply_texture_rect_facing").bind(sprite, to_facing))
		_player_draft_turn_tween.tween_property(sprite, "scale", Vector2(sprite_base_x, sprite_base_y), PRESENTATION_TURN_FLIP_DURATION + PRESENTATION_TURN_SETTLE_DURATION)
		await _player_draft_turn_tween.finished
	elif node is Control:
		var control := node as Control
		control.pivot_offset = control.size * 0.5
		var base_scale := control.scale
		var base_x: float = maxf(absf(base_scale.x), 1.0)
		var base_y: float = maxf(absf(base_scale.y), 1.0)
		_player_draft_turn_tween = create_tween()
		_player_draft_turn_tween.tween_property(control, "scale", Vector2(base_x * _facing_sign(from_facing) * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
		_player_draft_turn_tween.tween_property(control, "scale", Vector2(base_x * _facing_sign(to_facing) * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
		_player_draft_turn_tween.tween_property(control, "scale", Vector2(base_x * _facing_sign(to_facing), base_y), PRESENTATION_TURN_SETTLE_DURATION)
		await _player_draft_turn_tween.finished
	elif node is Node2D:
		var node2d := node as Node2D
		var base_scale2 := node2d.scale
		var base_x2: float = maxf(absf(base_scale2.x), 1.0)
		var base_y2: float = maxf(absf(base_scale2.y), 1.0)
		_player_draft_turn_tween = create_tween()
		_player_draft_turn_tween.tween_property(node2d, "scale", Vector2(base_x2 * _facing_sign(from_facing) * PRESENTATION_TURN_COMPRESS_X, base_y2 * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
		_player_draft_turn_tween.tween_property(node2d, "scale", Vector2(base_x2 * _facing_sign(to_facing) * PRESENTATION_TURN_COMPRESS_X, base_y2 * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
		_player_draft_turn_tween.tween_property(node2d, "scale", Vector2(base_x2 * _facing_sign(to_facing), base_y2), PRESENTATION_TURN_SETTLE_DURATION)
		await _player_draft_turn_tween.finished
	if token != _player_draft_move_token:
		return
	_apply_visual_facing(true, to_facing)
	_set_actor_facing_state(true, to_facing)

func _cancel_player_draft_visual_move() -> void:
	_player_draft_move_token += 1
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	_player_draft_move_tween = null
	if _player_draft_turn_tween != null and _player_draft_turn_tween.is_valid():
		_player_draft_turn_tween.kill()
	_player_draft_turn_tween = null
	_player_draft_visual_active = false
	_player_draft_visual_slot = -1
	_player_draft_visual_facing = ""
	_set_player_presentation_offset(Vector2.ZERO)
	if _is_valid_facing(_player_draft_visual_origin_facing):
		_apply_visual_facing(true, _player_draft_visual_origin_facing)
		_set_actor_facing_state(true, _player_draft_visual_origin_facing)
	_player_draft_visual_origin_slot = -1
	_player_draft_visual_origin_facing = ""

func _finish_player_draft_visual_instant() -> void:
	if not _player_draft_visual_active:
		return
	_player_draft_move_token += 1
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	_player_draft_move_tween = null
	if _player_draft_turn_tween != null and _player_draft_turn_tween.is_valid():
		_player_draft_turn_tween.kill()
	_player_draft_turn_tween = null
	var target_slot: int = draft_player_position if draft_player_has_position else _player_draft_visual_origin_slot
	var target_facing: String = draft_player_facing if _is_valid_facing(draft_player_facing) else _player_draft_visual_origin_facing
	if _is_valid_presentation_slot(target_slot) and _is_valid_presentation_slot(_player_draft_visual_origin_slot):
		_set_player_presentation_offset(_slot_offset_between(true, target_slot, _player_draft_visual_origin_slot))
	if _is_valid_facing(target_facing):
		_apply_visual_facing(true, target_facing)
		_set_actor_facing_state(true, target_facing)
	_player_draft_visual_slot = target_slot
	_player_draft_visual_facing = target_facing

func _freeze_player_draft_visual_for_confirm() -> void:
	if not _player_draft_visual_active:
		return
	_player_draft_move_token += 1
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	_player_draft_move_tween = null
	if _player_draft_turn_tween != null and _player_draft_turn_tween.is_valid():
		_player_draft_turn_tween.kill()
	_player_draft_turn_tween = null
	if _is_valid_presentation_slot(_player_draft_visual_slot) and _is_valid_presentation_slot(_player_draft_visual_origin_slot):
		_set_player_presentation_offset(_slot_offset_between(true, _player_draft_visual_slot, _player_draft_visual_origin_slot))
	if _is_valid_facing(_player_draft_visual_facing):
		_apply_visual_facing(true, _player_draft_visual_facing)

func _consume_player_draft_visual_start_slot(default_slot: int) -> int:
	if not _player_draft_visual_active:
		return default_slot
	var slot_value: int = _player_draft_visual_slot
	if not _is_valid_presentation_slot(slot_value) and draft_player_has_position:
		slot_value = draft_player_position
	_player_draft_visual_active = false
	_player_draft_visual_origin_slot = -1
	_player_draft_visual_origin_facing = ""
	_player_draft_visual_slot = -1
	_player_draft_visual_facing = ""
	return slot_value if _is_valid_presentation_slot(slot_value) else default_slot

func _should_hide_player_preview_ghost() -> bool:
	return _player_draft_visual_active

func _on_stage_grid_slot_pressed(slot: int) -> void:
	if player == null or not battle_active or not awaiting_player_input:
		return
	var clicked_slot: int = clampi(slot, 0, GRID_SLOT_COUNT - 1)
	var current_target_slot: int = _current_player_target_slot()
	var current_target_facing: String = _current_player_target_facing()
	var next_facing: String = current_target_facing
	if clicked_slot == current_target_slot:
		next_facing = _opposite_facing(current_target_facing)
	else:
		if not _is_legal_player_target_slot(clicked_slot):
			_show_illegal_target_feedback(clicked_slot)
			return
		next_facing = player.facing
	_ensure_player_draft_visual_origin()
	_set_player_draft_target(clicked_slot, next_facing)
	_play_player_draft_visual_to(clicked_slot, next_facing)
	_refresh_ui()

func _is_legal_player_target_slot(slot: int) -> bool:
	if player == null:
		return false
	if not _is_valid_presentation_slot(slot):
		return false
	if enemy != null and enemy.hp > 0 and slot == enemy.position:
		return false
	var max_steps: int = maxi(player.qinggong, 0)
	var origin_slot: int = _player_draft_visual_origin_slot if _player_draft_visual_active and _is_valid_presentation_slot(_player_draft_visual_origin_slot) else player.position
	return absi(slot - origin_slot) <= max_steps

func _show_illegal_target_feedback(slot: int) -> void:
	if has_method("_show_combat_banner"):
		_show_combat_banner("无法移动到%s" % _slot_label_safe_local(slot), Color("2a2018"), Color("ffd479"))

func _slot_label_safe_local(slot: int) -> String:
	var labels := ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot

func _current_player_target_slot() -> int:
	if player == null:
		return 0
	if draft_player_has_position:
		return clampi(draft_player_position, 0, GRID_SLOT_COUNT - 1)
	if draft_player_intent != null and draft_player_intent.target_position >= 0:
		return clampi(draft_player_intent.target_position, 0, GRID_SLOT_COUNT - 1)
	return clampi(player.position, 0, GRID_SLOT_COUNT - 1)

func _current_player_target_facing() -> String:
	if player == null:
		return "right"
	if draft_player_has_position and _is_valid_facing(draft_player_facing):
		return draft_player_facing
	if draft_player_intent != null and _is_valid_facing(draft_player_intent.target_facing):
		return draft_player_intent.target_facing
	return player.facing if _is_valid_facing(player.facing) else "right"

func _set_player_draft_target(slot: int, facing_value: String) -> void:
	draft_player_position = clampi(slot, 0, GRID_SLOT_COUNT - 1)
	draft_player_facing = facing_value if _is_valid_facing(facing_value) else (player.facing if player != null and _is_valid_facing(player.facing) else "right")
	draft_player_has_position = true
	_sync_draft_intent_to_target()

func _reset_draft_intent() -> void:
	_cancel_player_draft_visual_move()
	super._reset_draft_intent()

func _sync_draft_intent_to_target() -> void:
	if not draft_player_has_position:
		return
	if draft_player_intent == null:
		return
	draft_player_intent.set_stance(draft_player_position, draft_player_facing)

func _confirm_player_intent() -> void:
	_freeze_player_draft_visual_for_confirm()
	_sync_draft_intent_to_target()
	_capture_presentation_facing_context()
	super._confirm_player_intent()

