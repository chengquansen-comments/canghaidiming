extends "res://scripts/battle_controller_visual_presentation_assets.gd"

# Phase 10/11 presentation wrapper.
# Phase 10 replaces final committed slot settling with clear grid-by-grid movement.
# Phase 11 adds event-driven facing turns. Facing never auto-turns merely because
# the opponent is now on the other side.

const PRESENTATION_STEP_MOVE_DURATION := 0.12
const PRESENTATION_STEP_MOVE_PAUSE := 0.045
const PRESENTATION_STEP_MOVE_BOB_Y := -7.0
const PRESENTATION_STEP_MOVE_MAX_STEPS := 8

const PRESENTATION_TURN_PREP_DURATION := 0.06
const PRESENTATION_TURN_FLIP_DURATION := 0.08
const PRESENTATION_TURN_SETTLE_DURATION := 0.06
const PRESENTATION_TURN_COMPRESS_X := 0.82
const PRESENTATION_TURN_SETTLE_Y := 1.04

const FACING_CTX_OLD_PLAYER_FACING := &"facing_ctx_old_player_facing"
const FACING_CTX_OLD_ENEMY_FACING := &"facing_ctx_old_enemy_facing"
const FACING_CTX_OLD_PLAYER_HP := &"facing_ctx_old_player_hp"
const FACING_CTX_OLD_PLAYER_MOMENTUM := &"facing_ctx_old_player_momentum"
const FACING_CTX_PLAYER_ACTION_TARGET_FACING := &"facing_ctx_player_action_target_facing"
const FACING_CTX_PLAYER_TURN_DURING_ACTION := &"facing_ctx_player_turn_during_action"
const FACING_CTX_ENEMY_TURN_DURING_ACTION := &"facing_ctx_enemy_turn_during_action"

func _confirm_player_intent() -> void:
	_capture_presentation_facing_context()
	super._confirm_player_intent()

func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_reset_presentation_offsets()
	_apply_pre_resolution_slot_offsets(old_player_slot, old_enemy_slot)
	for side: String in order:
		if side == "player" and player_card != null:
			await _play_one_presentation_action(true, player_card, _presentation_result_for_side(preview_sim, "player"))
		elif side == "enemy" and enemy_card != null:
			await _play_one_presentation_action(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"))
	await _settle_committed_slot_offsets_stepwise(old_player_slot, old_enemy_slot)
	await _maybe_turn_player_after_action_target()
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_reset_presentation_offsets()
	_set_presentation_busy(false)

func _play_one_presentation_action(is_player_actor: bool, card: CardData, result: Dictionary) -> void:
	if card == null:
		return
	if _card_has_turn_during_action(card):
		var turn_to: String = _turn_during_action_target_facing(is_player_actor, card)
		if _is_valid_facing(turn_to):
			await _play_facing_turn(is_player_actor, turn_to, _actor_old_or_current_facing(is_player_actor))
	await super._play_one_presentation_action(is_player_actor, card, result)
	if not is_player_actor:
		await _maybe_turn_player_after_back_hit(result)

func _settle_committed_slot_offsets_stepwise(old_player_slot: int, old_enemy_slot: int) -> void:
	var did_stepwise_settle := false
	if player != null and _is_valid_presentation_slot(old_player_slot) and _is_valid_presentation_slot(player.position) and old_player_slot != player.position:
		did_stepwise_settle = true
		await _animate_actor_committed_slots_stepwise(true, old_player_slot, player.position)
	if enemy != null and _is_valid_presentation_slot(old_enemy_slot) and _is_valid_presentation_slot(enemy.position) and old_enemy_slot != enemy.position:
		did_stepwise_settle = true
		await _animate_actor_committed_slots_stepwise(false, old_enemy_slot, enemy.position)
	if not did_stepwise_settle:
		await _settle_committed_slot_offsets()

func _animate_actor_committed_slots_stepwise(is_player_actor: bool, from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot:
		return
	var step_dir := 1 if to_slot > from_slot else -1
	var current_slot := from_slot
	var step_count := 0
	while current_slot != to_slot and step_count < PRESENTATION_STEP_MOVE_MAX_STEPS:
		var next_slot := current_slot + step_dir
		if not _is_valid_presentation_slot(next_slot):
			break
		var from_offset := _slot_offset_between(is_player_actor, current_slot, to_slot)
		var to_offset := _slot_offset_between(is_player_actor, next_slot, to_slot)
		await _tween_actor_one_grid_step(is_player_actor, from_offset, to_offset)
		current_slot = next_slot
		step_count += 1
		if current_slot != to_slot:
			await get_tree().create_timer(PRESENTATION_STEP_MOVE_PAUSE).timeout
	if current_slot != to_slot:
		var current_offset: Vector2 = _presentation_offset(is_player_actor)
		_tween_actor_offset(is_player_actor, current_offset, Vector2.ZERO, PRESENTATION_SLOT_SETTLE_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
		await get_tree().create_timer(PRESENTATION_SLOT_SETTLE_DURATION + 0.02).timeout
	else:
		var final_offset: Vector2 = _presentation_offset(is_player_actor)
		if final_offset.length() > 0.5:
			_tween_actor_offset(is_player_actor, final_offset, Vector2.ZERO, 0.04, Tween.TRANS_QUAD, Tween.EASE_OUT)
			await get_tree().create_timer(0.05).timeout

func _tween_actor_one_grid_step(is_player_actor: bool, from_offset: Vector2, to_offset: Vector2) -> void:
	var setter: Callable = Callable(self, "_set_player_presentation_offset") if is_player_actor else Callable(self, "_set_enemy_presentation_offset")
	var mid_offset := from_offset.lerp(to_offset, 0.55) + Vector2(0.0, PRESENTATION_STEP_MOVE_BOB_Y)
	var tween := create_tween()
	tween.tween_method(setter, from_offset, mid_offset, PRESENTATION_STEP_MOVE_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(setter, mid_offset, to_offset, PRESENTATION_STEP_MOVE_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

func _capture_presentation_facing_context() -> void:
	var old_player_slot: int = player.position if player != null else -1
	var old_player_facing: String = player.facing if player != null else ""
	var old_enemy_facing: String = enemy.facing if enemy != null else ""
	var old_player_hp: int = player.hp if player != null else 0
	var old_player_momentum: int = player.momentum if player != null else 0
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = _intent_card(p_intent)
	var e_card: CardData = _intent_card(e_intent)
	set_meta(FACING_CTX_OLD_PLAYER_FACING, old_player_facing)
	set_meta(FACING_CTX_OLD_ENEMY_FACING, old_enemy_facing)
	set_meta(FACING_CTX_OLD_PLAYER_HP, old_player_hp)
	set_meta(FACING_CTX_OLD_PLAYER_MOMENTUM, old_player_momentum)
	set_meta(FACING_CTX_PLAYER_ACTION_TARGET_FACING, _action_target_facing(p_intent, old_player_slot))
	set_meta(FACING_CTX_PLAYER_TURN_DURING_ACTION, _card_has_turn_during_action(p_card))
	set_meta(FACING_CTX_ENEMY_TURN_DURING_ACTION, _card_has_turn_during_action(e_card))
	# No automatic turn is derived from relative position.

func _maybe_turn_player_after_action_target() -> void:
	if player == null or player.hp <= 0:
		return
	if bool(get_meta(FACING_CTX_PLAYER_TURN_DURING_ACTION, false)):
		return
	var old_facing: String = str(get_meta(FACING_CTX_OLD_PLAYER_FACING, ""))
	var target_facing: String = str(get_meta(FACING_CTX_PLAYER_ACTION_TARGET_FACING, ""))
	if not _is_valid_facing(old_facing) or not _is_valid_facing(target_facing):
		return
	if old_facing == target_facing:
		return
	await _play_facing_turn(true, target_facing, old_facing)

func _maybe_turn_player_after_back_hit(result: Dictionary) -> void:
	if player == null or enemy == null:
		return
	if not _is_back_hit_on_player(result):
		return
	var old_hp: int = int(get_meta(FACING_CTX_OLD_PLAYER_HP, player.hp))
	var old_momentum: int = int(get_meta(FACING_CTX_OLD_PLAYER_MOMENTUM, player.momentum))
	var damage_value: int = int(result.get("damage", 0))
	var break_value: int = int(result.get("break", 0))
	if old_hp > 0 and old_hp - damage_value <= 0:
		return
	if old_momentum > 0 and old_momentum - break_value <= 0:
		return
	if player.hp <= 0:
		return
	var turn_to := _facing_toward_slot(player.position, enemy.position)
	if not _is_valid_facing(turn_to):
		return
	await _play_facing_turn(true, turn_to, player.facing)

func _is_back_hit_on_player(result: Dictionary) -> bool:
	if player == null or enemy == null:
		return false
	var range_result: String = str(result.get("range", ""))
	if range_result != "hit" and range_result != "graze":
		return false
	var damage_value: int = int(result.get("damage", 0))
	var break_value: int = int(result.get("break", 0))
	if damage_value <= 0 and break_value <= 0:
		return false
	return _facing_exposes_back_to_slot(player.facing, player.position, enemy.position)

func _action_target_facing(intent: IntentData, old_slot: int) -> String:
	if intent == null:
		return ""
	if _is_valid_facing(intent.target_facing):
		return intent.target_facing
	if intent.target_position >= 0 and old_slot >= 0:
		if intent.target_position > old_slot:
			return "right"
		if intent.target_position < old_slot:
			return "left"
	return ""

func _card_has_turn_during_action(card: CardData) -> bool:
	if card == null:
		return false
	if _card_has_tag(card, "转身") or _card_has_tag(card, "回身") or _card_has_tag(card, "反身") or _card_has_tag(card, "翻身") or _card_has_tag(card, "回马"):
		return true
	var id_text: String = str(card.id)
	var name_text: String = str(card.display_name)
	return id_text.findn("turn") >= 0 or id_text.findn("reverse") >= 0 or id_text.findn("backturn") >= 0 or name_text.find("转身") >= 0 or name_text.find("回身") >= 0 or name_text.find("反身") >= 0 or name_text.find("翻身") >= 0 or name_text.find("回马") >= 0

func _turn_during_action_target_facing(is_player_actor: bool, _card: CardData) -> String:
	var intent: IntentData = (draft_player_intent if draft_player_intent != null else player_intent) if is_player_actor else enemy_intent
	var actor: Fighter = player if is_player_actor else enemy
	var old_facing: String = _actor_old_or_current_facing(is_player_actor)
	if intent != null and _is_valid_facing(intent.target_facing):
		return intent.target_facing
	if intent != null and actor != null and intent.target_position >= 0:
		var target_facing := _action_target_facing(intent, actor.position)
		if _is_valid_facing(target_facing):
			return target_facing
	return _opposite_facing(old_facing)

func _play_facing_turn(is_player_actor: bool, to_facing: String, from_facing: String = "") -> void:
	if not _is_valid_facing(to_facing):
		return
	var actor: Fighter = player if is_player_actor else enemy
	if actor == null or actor.hp <= 0:
		return
	var safe_from := from_facing if _is_valid_facing(from_facing) else actor.facing
	if safe_from == to_facing:
		_set_actor_facing_state(is_player_actor, to_facing)
		_apply_visual_facing(is_player_actor, to_facing)
		return
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null:
		_set_actor_facing_state(is_player_actor, to_facing)
		return
	_apply_visual_facing(is_player_actor, safe_from)
	if node is Control:
		await _play_control_facing_turn(node as Control, safe_from, to_facing)
	elif node is Node2D:
		await _play_node2d_facing_turn(node as Node2D, safe_from, to_facing)
	else:
		_set_actor_facing_state(is_player_actor, to_facing)
		return
	_set_actor_facing_state(is_player_actor, to_facing)
	_apply_visual_facing(is_player_actor, to_facing)

func _play_control_facing_turn(node: Control, from_facing: String, to_facing: String) -> void:
	node.pivot_offset = node.size * 0.5
	var base_scale := node.scale
	var base_x: float = maxf(absf(base_scale.x), 1.0)
	var base_y: float = maxf(absf(base_scale.y), 1.0)
	var from_sign: float = _facing_sign(from_facing)
	var to_sign: float = _facing_sign(to_facing)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base_x * from_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign, base_y), PRESENTATION_TURN_SETTLE_DURATION)
	await tween.finished

func _play_node2d_facing_turn(node: Node2D, from_facing: String, to_facing: String) -> void:
	var base_scale := node.scale
	var base_x: float = maxf(absf(base_scale.x), 1.0)
	var base_y: float = maxf(absf(base_scale.y), 1.0)
	var from_sign: float = _facing_sign(from_facing)
	var to_sign: float = _facing_sign(to_facing)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base_x * from_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign, base_y), PRESENTATION_TURN_SETTLE_DURATION)
	await tween.finished

func _apply_visual_facing(is_player_actor: bool, facing_value: String) -> void:
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null or not _is_valid_facing(facing_value):
		return
	if node is Control:
		var control := node as Control
		control.pivot_offset = control.size * 0.5
		var control_scale := control.scale
		var control_base_x: float = maxf(absf(control_scale.x), 1.0)
		var control_base_y: float = maxf(absf(control_scale.y), 1.0)
		control.scale = Vector2(control_base_x * _facing_sign(facing_value), control_base_y)
	elif node is Node2D:
		var node2d := node as Node2D
		var node2d_scale := node2d.scale
		var node2d_base_x: float = maxf(absf(node2d_scale.x), 1.0)
		var node2d_base_y: float = maxf(absf(node2d_scale.y), 1.0)
		node2d.scale = Vector2(node2d_base_x * _facing_sign(facing_value), node2d_base_y)

func _set_actor_facing_state(is_player_actor: bool, facing_value: String) -> void:
	if not _is_valid_facing(facing_value):
		return
	if is_player_actor and player != null:
		player.facing = facing_value
	elif not is_player_actor and enemy != null:
		enemy.facing = facing_value

func _actor_old_or_current_facing(is_player_actor: bool) -> String:
	if is_player_actor:
		var old_player_facing: String = str(get_meta(FACING_CTX_OLD_PLAYER_FACING, ""))
		if _is_valid_facing(old_player_facing):
			return old_player_facing
		return player.facing if player != null else ""
	var old_enemy_facing: String = str(get_meta(FACING_CTX_OLD_ENEMY_FACING, ""))
	if _is_valid_facing(old_enemy_facing):
		return old_enemy_facing
	return enemy.facing if enemy != null else ""

func _facing_exposes_back_to_slot(facing_value: String, actor_slot: int, attacker_slot: int) -> bool:
	if not _is_valid_facing(facing_value):
		return false
	if attacker_slot > actor_slot:
		return facing_value == "left"
	if attacker_slot < actor_slot:
		return facing_value == "right"
	return false

func _facing_toward_slot(actor_slot: int, target_slot: int) -> String:
	if target_slot > actor_slot:
		return "right"
	if target_slot < actor_slot:
		return "left"
	return ""

func _opposite_facing(facing_value: String) -> String:
	if facing_value == "left":
		return "right"
	if facing_value == "right":
		return "left"
	return ""

func _facing_sign(facing_value: String) -> float:
	return -1.0 if facing_value == "left" else 1.0

func _is_valid_facing(facing_value: String) -> bool:
	return facing_value == "left" or facing_value == "right"

func _is_valid_presentation_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < GRID_SLOT_COUNT
