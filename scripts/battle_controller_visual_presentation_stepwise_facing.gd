extends "res://scripts/battle_controller_visual_presentation_stepwise_focus.gd"

# Stepwise facing layer.
#
# Owns presentation facing context, event-driven facing turns, back-hit facing,
# and low-level facing helpers. This layer deliberately avoids auto-facing merely
# because the opponent crosses sides.

const FACING_CTX_OLD_PLAYER_FACING := &"facing_ctx_old_player_facing"
const FACING_CTX_OLD_ENEMY_FACING := &"facing_ctx_old_enemy_facing"
const FACING_CTX_OLD_PLAYER_HP := &"facing_ctx_old_player_hp"
const FACING_CTX_OLD_PLAYER_MOMENTUM := &"facing_ctx_old_player_momentum"
const FACING_CTX_PLAYER_ACTION_TARGET_FACING := &"facing_ctx_player_action_target_facing"
const FACING_CTX_PLAYER_TURN_DURING_ACTION := &"facing_ctx_player_turn_during_action"
const FACING_CTX_ENEMY_TURN_DURING_ACTION := &"facing_ctx_enemy_turn_during_action"

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
	# Kept for compatibility with older flows. Phase 12.5 now performs ordinary
	# target-facing turns before the action, after target-slot movement.
	return

func _maybe_turn_player_after_back_hit(result: Dictionary) -> void:
	if player == null or enemy == null:
		return
	if not bool(result.get("was_back_hit", _is_back_hit_on_player(result))):
		return
	if bool(result.get("will_die", false)) or bool(result.get("will_break", false)):
		return
	if player.hp <= 0:
		return
	var turn_to: String = str(result.get("back_hit_turn_to", ""))
	if not _is_valid_facing(turn_to):
		turn_to = _facing_toward_slot(player.position, enemy.position)
	if not _is_valid_facing(turn_to):
		return
	await _play_facing_turn(true, turn_to, player.facing)

func _is_back_hit_on_player(result: Dictionary) -> bool:
	if player == null or enemy == null:
		return false
	var range_result: String = str(result.get("range", ""))
	if range_result != CombatResolver.RANGE_HIT and not (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE):
		return false
	var damage_value: int = int(result.get("damage", 0))
	var break_value: int = int(result.get("break", 0))
	if damage_value <= 0 and break_value <= 0:
		return false
	return _facing_exposes_back_to_slot(player.facing, player.position, enemy.position)

func _presentation_step_for_side(preview_sim: Dictionary, side: String, phase: String) -> Dictionary:
	var steps_value = preview_sim.get("steps", [])
	if not (steps_value is Array):
		return {}
	for step_value in steps_value:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if str(step.get("side", "")) == side and str(step.get("phase", "")) == phase:
			return step
	return {}

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
	if node is TextureRect:
		await _play_texture_rect_facing_turn(node as TextureRect, safe_from, to_facing)
	elif node is Control:
		await _play_control_facing_turn(node as Control, safe_from, to_facing)
	elif node is Node2D:
		await _play_node2d_facing_turn(node as Node2D, safe_from, to_facing)
	else:
		_set_actor_facing_state(is_player_actor, to_facing)
		return
	_set_actor_facing_state(is_player_actor, to_facing)
	_apply_visual_facing(is_player_actor, to_facing)

func _play_texture_rect_facing_turn(node: TextureRect, from_facing: String, to_facing: String) -> void:
	_apply_texture_rect_facing(node, from_facing)
	node.pivot_offset = node.size * 0.5
	var base_scale := node.scale
	var base_x: float = maxf(absf(base_scale.x), 1.0)
	var base_y: float = maxf(absf(base_scale.y), 1.0)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base_x * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
	tween.tween_callback(Callable(self, "_apply_texture_rect_facing").bind(node, to_facing))
	tween.tween_property(node, "scale", Vector2(base_x, base_y), PRESENTATION_TURN_FLIP_DURATION + PRESENTATION_TURN_SETTLE_DURATION)
	await tween.finished

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
	if node is TextureRect:
		_apply_texture_rect_facing(node as TextureRect, facing_value)
	elif node is Control:
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

func _apply_texture_rect_facing(sprite: TextureRect, facing_value: String) -> void:
	if sprite == null or not _is_valid_facing(facing_value):
		return
	sprite.flip_h = facing_value == "left"
	var sprite_scale := sprite.scale
	sprite.scale = Vector2(maxf(absf(sprite_scale.x), 1.0), maxf(absf(sprite_scale.y), 1.0))
	_sync_actor_action_glows()

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
