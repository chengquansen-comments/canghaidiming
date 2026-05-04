extends "res://scripts/battle_controller_visual_presentation_stepwise_draft.gd"

# Stepwise exchange flow layer.
#
# Owns stance move -> stance facing -> action -> effect move sequencing,
# grid-by-grid movement, committed-slot settling, action gate timing,
# presentation death, and result enrichment from ordered preview steps.

const PRESENTATION_EFFECT_MOVE_DELAY_AFTER_ACTION_START := 0.10
const PRESENTATION_PLAYER_EFFECT_MOVE_DELAY_AFTER_ACTION_START := 0.10
const PRESENTATION_ATTACK_BOUND_EFFECT_MOVE_MIN_DURATION := 0.28

var _presentation_player_action_completed_this_exchange := false
var _pending_presentation_effect_move: Dictionary = {}
var _pending_presentation_effect_move_started := false
var _pending_presentation_effect_move_running := false
var _pending_presentation_effect_move_completed := false

func _mark_player_presentation_action_completed() -> void:
	_presentation_player_action_completed_this_exchange = true

func _reset_player_presentation_action_gate() -> void:
	_presentation_player_action_completed_this_exchange = false

func _wait_for_enemy_attack_start_after_player() -> void:
	if not _presentation_player_action_completed_this_exchange:
		return
	if PRESENTATION_ENEMY_ATTACK_START_DELAY_AFTER_PLAYER <= 0.0:
		return
	await get_tree().create_timer(PRESENTATION_ENEMY_ATTACK_START_DELAY_AFTER_PLAYER).timeout

func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_begin_presentation_watchdog("stepwise-exchange")
	_reset_presentation_offsets()
	_reset_player_presentation_action_gate()
	var visual_player_slot: int = _consume_player_draft_visual_start_slot(old_player_slot)
	_apply_pre_resolution_slot_offsets(visual_player_slot, old_enemy_slot)
	var visual_enemy_slot: int = old_enemy_slot
	for side: String in order:
		if _presentation_actor_is_defeated(side == "player"):
			break
		if side == "player" and player_card != null:
			var player_move_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "move")
			visual_player_slot = await _apply_presentation_stance_step(true, visual_player_slot, player.position, player_card, player_move_step)
			var player_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "effect_move")
			var player_action_result: Dictionary = await _play_presentation_action_with_effect_move(true, player_card, _presentation_result_for_side(preview_sim, "player"), player_effect_step, visual_player_slot, player.position, visual_enemy_slot, enemy.position)
			visual_player_slot = int(player_action_result.get("actor_slot", visual_player_slot))
			visual_enemy_slot = int(player_action_result.get("target_slot", visual_enemy_slot))
			_mark_player_presentation_action_completed()
			if _presentation_actor_is_defeated(false):
				await _finish_presentation_after_lethal_action(visual_player_slot, visual_enemy_slot)
				return
		elif side == "enemy" and enemy_card != null:
			var enemy_move_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "move")
			visual_enemy_slot = await _apply_presentation_stance_step(false, visual_enemy_slot, enemy.position, enemy_card, enemy_move_step)
			await _wait_for_enemy_attack_start_after_player()
			if _presentation_actor_is_defeated(false):
				await _finish_presentation_after_lethal_action(visual_player_slot, visual_enemy_slot)
				return
			var enemy_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "effect_move")
			var enemy_action_result: Dictionary = await _play_presentation_action_with_effect_move(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"), enemy_effect_step, visual_enemy_slot, enemy.position, visual_player_slot, player.position)
			visual_enemy_slot = int(enemy_action_result.get("actor_slot", visual_enemy_slot))
			visual_player_slot = int(enemy_action_result.get("target_slot", visual_player_slot))
			if _presentation_actor_is_defeated(true):
				await _finish_presentation_after_lethal_action(visual_player_slot, visual_enemy_slot)
				return
	await _settle_visual_slots_to_committed_positions(visual_player_slot, visual_enemy_slot)
	await _play_pending_presentation_deaths()
	_finish_presentation_exchange()

func _play_presentation_action_with_effect_move(is_player_actor: bool, card: CardData, result: Dictionary, effect_step: Dictionary, actor_visual_slot: int, actor_committed_slot: int, target_visual_slot: int, target_committed_slot: int) -> Dictionary:
	_begin_pending_presentation_effect_move(is_player_actor, card, result, effect_step, actor_visual_slot, actor_committed_slot, target_visual_slot, target_committed_slot)
	_schedule_pending_presentation_effect_move_after_delay(_presentation_effect_move_delay_for_actor(is_player_actor))
	await _play_one_presentation_action(is_player_actor, card, result)
	if _pending_presentation_effect_move_started:
		await _wait_pending_presentation_effect_move_completed()
	elif not _pending_presentation_effect_move_completed:
		await _apply_pending_presentation_effect_move()
	var actor_after: int = int(_pending_presentation_effect_move.get("actor_after", actor_visual_slot))
	var target_after: int = int(_pending_presentation_effect_move.get("target_after", target_visual_slot))
	_clear_pending_presentation_effect_move()
	return {
		"actor_slot": actor_after,
		"target_slot": target_after,
	}

func _presentation_effect_move_delay_for_actor(is_player_actor: bool) -> float:
	return PRESENTATION_PLAYER_EFFECT_MOVE_DELAY_AFTER_ACTION_START if is_player_actor else PRESENTATION_EFFECT_MOVE_DELAY_AFTER_ACTION_START

func _begin_pending_presentation_effect_move(is_player_actor: bool, card: CardData, result: Dictionary, effect_step: Dictionary, actor_visual_slot: int, actor_committed_slot: int, target_visual_slot: int, target_committed_slot: int) -> void:
	_pending_presentation_effect_move_started = false
	_pending_presentation_effect_move_running = false
	_pending_presentation_effect_move_completed = false
	var attack_bound := _card_uses_attack_bound_effect_move(card)
	_pending_presentation_effect_move = {
		"is_player_actor": is_player_actor,
		"effect_step": effect_step,
		"actor_visual_slot": actor_visual_slot,
		"actor_committed_slot": actor_committed_slot,
		"target_visual_slot": target_visual_slot,
		"target_committed_slot": target_committed_slot,
		"actor_after": actor_visual_slot,
		"target_after": target_visual_slot,
		"attack_bound": attack_bound,
		"duration": _attack_bound_effect_move_duration(card, result) if attack_bound else 0.0,
	}

func _card_uses_attack_bound_effect_move(card: CardData) -> bool:
	if card == null:
		return false
	var style: String = _presentation_style_for_card(card)
	return style != "guard" and style != "focus" and style != "idle"

func _attack_bound_effect_move_duration(card: CardData, result: Dictionary) -> float:
	if card == null:
		return PRESENTATION_ATTACK_BOUND_EFFECT_MOVE_MIN_DURATION
	var style: String = _presentation_style_for_card(card)
	if style == "guard" or style == "focus" or style == "idle":
		return PRESENTATION_ATTACK_BOUND_EFFECT_MOVE_MIN_DURATION
	var target_will_break: bool = _presentation_target_will_break(false, result) or _presentation_target_will_break(true, result)
	var pause_duration: float = _presentation_hit_pause_duration(result, target_will_break)
	return max(PRESENTATION_ATTACK_BOUND_EFFECT_MOVE_MIN_DURATION, 0.28 + pause_duration)

func _clear_pending_presentation_effect_move() -> void:
	_pending_presentation_effect_move.clear()
	_pending_presentation_effect_move_started = false
	_pending_presentation_effect_move_running = false
	_pending_presentation_effect_move_completed = false

func _pending_presentation_effect_move_matches(is_player_actor: bool) -> bool:
	if _pending_presentation_effect_move.is_empty():
		return false
	return bool(_pending_presentation_effect_move.get("is_player_actor", false)) == is_player_actor

func _pending_effect_actor_has_move() -> bool:
	if _pending_presentation_effect_move.is_empty():
		return false
	var effect_step: Dictionary = _pending_presentation_effect_move.get("effect_step", {})
	if effect_step.is_empty():
		return false
	var actor_visual_slot: int = int(_pending_presentation_effect_move.get("actor_visual_slot", 0))
	var actor_to: int = int(effect_step.get("actor_to", actor_visual_slot))
	return _is_valid_presentation_slot(actor_to) and actor_to != actor_visual_slot

func _pending_effect_target_has_move() -> bool:
	if _pending_presentation_effect_move.is_empty():
		return false
	var effect_step: Dictionary = _pending_presentation_effect_move.get("effect_step", {})
	if effect_step.is_empty():
		return false
	var target_visual_slot: int = int(_pending_presentation_effect_move.get("target_visual_slot", 0))
	var target_to: int = int(effect_step.get("target_to", target_visual_slot))
	return _is_valid_presentation_slot(target_to) and target_to != target_visual_slot

func _schedule_pending_presentation_effect_move() -> void:
	_schedule_pending_presentation_effect_move_after_delay(0.0)

func _schedule_pending_presentation_effect_move_after_delay(delay_seconds: float) -> void:
	if _pending_presentation_effect_move.is_empty():
		return
	if _pending_presentation_effect_move_started or _pending_presentation_effect_move_running or _pending_presentation_effect_move_completed:
		return
	_pending_presentation_effect_move_running = true
	call_deferred("_run_pending_presentation_effect_move_async", delay_seconds)

func _run_pending_presentation_effect_move_async(delay_seconds: float = 0.0) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	await _apply_pending_presentation_effect_move()
	_pending_presentation_effect_move_running = false

func _wait_pending_presentation_effect_move_completed() -> void:
	while not _pending_presentation_effect_move_completed and not _pending_presentation_effect_move.is_empty():
		await get_tree().process_frame

func _apply_pending_presentation_effect_move() -> void:
	if _pending_presentation_effect_move.is_empty():
		return
	if _pending_presentation_effect_move_completed:
		return
	_pending_presentation_effect_move_started = true
	if bool(_pending_presentation_effect_move.get("attack_bound", false)):
		await _apply_attack_bound_presentation_effect_move()
	else:
		await _apply_stepwise_presentation_effect_move()
	_pending_presentation_effect_move_completed = true

func _apply_stepwise_presentation_effect_move() -> void:
	var is_player_actor: bool = bool(_pending_presentation_effect_move.get("is_player_actor", false))
	var effect_step: Dictionary = _pending_presentation_effect_move.get("effect_step", {})
	var actor_visual_slot: int = int(_pending_presentation_effect_move.get("actor_visual_slot", 0))
	var actor_committed_slot: int = int(_pending_presentation_effect_move.get("actor_committed_slot", actor_visual_slot))
	var target_visual_slot: int = int(_pending_presentation_effect_move.get("target_visual_slot", 0))
	var target_committed_slot: int = int(_pending_presentation_effect_move.get("target_committed_slot", target_visual_slot))
	var actor_after: int = await _apply_presentation_effect_actor_step(is_player_actor, actor_visual_slot, actor_committed_slot, effect_step)
	var target_after: int = await _apply_presentation_effect_target_step(not is_player_actor, target_visual_slot, target_committed_slot, effect_step)
	_pending_presentation_effect_move["actor_after"] = actor_after
	_pending_presentation_effect_move["target_after"] = target_after

func _apply_attack_bound_presentation_effect_move() -> void:
	var is_player_actor: bool = bool(_pending_presentation_effect_move.get("is_player_actor", false))
	var effect_step: Dictionary = _pending_presentation_effect_move.get("effect_step", {})
	var duration: float = max(0.01, float(_pending_presentation_effect_move.get("duration", PRESENTATION_ATTACK_BOUND_EFFECT_MOVE_MIN_DURATION)))
	var actor_visual_slot: int = int(_pending_presentation_effect_move.get("actor_visual_slot", 0))
	var actor_committed_slot: int = int(_pending_presentation_effect_move.get("actor_committed_slot", actor_visual_slot))
	var target_visual_slot: int = int(_pending_presentation_effect_move.get("target_visual_slot", 0))
	var target_committed_slot: int = int(_pending_presentation_effect_move.get("target_committed_slot", target_visual_slot))
	var actor_after: int = _attack_bound_target_slot(effect_step, "actor_to", actor_visual_slot)
	var target_after: int = _attack_bound_target_slot(effect_step, "target_to", target_visual_slot)
	var has_actor_move := actor_after != actor_visual_slot
	var has_target_move := target_after != target_visual_slot
	if not has_actor_move and not has_target_move:
		_pending_presentation_effect_move["actor_after"] = actor_visual_slot
		_pending_presentation_effect_move["target_after"] = target_visual_slot
		return
	if has_actor_move:
		var actor_to_offset := _slot_offset_between(is_player_actor, actor_after, actor_committed_slot)
		_tween_actor_offset(is_player_actor, _presentation_offset(is_player_actor), actor_to_offset, duration, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	if has_target_move:
		var target_is_player_actor := not is_player_actor
		var target_to_offset := _slot_offset_between(target_is_player_actor, target_after, target_committed_slot)
		_tween_actor_offset(target_is_player_actor, _presentation_offset(target_is_player_actor), target_to_offset, duration, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	await get_tree().create_timer(duration + 0.02).timeout
	if has_actor_move:
		var actor_final_offset := _slot_offset_between(is_player_actor, actor_after, actor_committed_slot)
		if is_player_actor:
			_set_player_presentation_offset(actor_final_offset)
		else:
			_set_enemy_presentation_offset(actor_final_offset)
	if has_target_move:
		var target_actor_side := not is_player_actor
		var target_final_offset := _slot_offset_between(target_actor_side, target_after, target_committed_slot)
		if target_actor_side:
			_set_player_presentation_offset(target_final_offset)
		else:
			_set_enemy_presentation_offset(target_final_offset)
	_pending_presentation_effect_move["actor_after"] = actor_after
	_pending_presentation_effect_move["target_after"] = target_after

func _attack_bound_target_slot(effect_step: Dictionary, key: String, fallback_slot: int) -> int:
	if effect_step.is_empty():
		return fallback_slot
	var slot: int = int(effect_step.get(key, fallback_slot))
	return slot if _is_valid_presentation_slot(slot) else fallback_slot

func _finish_presentation_after_lethal_action(_visual_player_slot: int, _visual_enemy_slot: int) -> void:
	_clear_actor_action_glows()
	await _play_pending_presentation_deaths()
	_finish_presentation_exchange("lethal-action")

func _presentation_actor_is_defeated(is_player_actor: bool) -> bool:
	if is_player_actor:
		return player != null and player.hp <= 0
	return enemy != null and enemy.hp <= 0

func _play_pending_presentation_deaths() -> void:
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)

func _apply_presentation_stance_step(is_player_actor: bool, visual_slot: int, committed_slot: int, card: CardData, move_step: Dictionary) -> int:
	var target_slot: int = int(move_step.get("to", visual_slot)) if not move_step.is_empty() else visual_slot
	var target_facing: String = str(move_step.get("facing", "")) if not move_step.is_empty() else ""
	if _is_valid_presentation_slot(target_slot) and target_slot != visual_slot:
		await _animate_actor_visual_slots_stepwise(is_player_actor, visual_slot, target_slot, committed_slot)
		visual_slot = target_slot
	if _is_valid_facing(target_facing) and not _card_has_turn_during_action(card):
		var from_facing: String = _actor_old_or_current_facing(is_player_actor)
		await _play_facing_turn(is_player_actor, target_facing, from_facing)
	return visual_slot

func _apply_presentation_effect_actor_step(is_player_actor: bool, visual_slot: int, committed_slot: int, effect_step: Dictionary) -> int:
	if effect_step.is_empty():
		return visual_slot
	var target_slot: int = int(effect_step.get("actor_to", visual_slot))
	if not _is_valid_presentation_slot(target_slot) or target_slot == visual_slot:
		return visual_slot
	await _animate_actor_visual_slots_stepwise(is_player_actor, visual_slot, target_slot, committed_slot)
	return target_slot

func _apply_presentation_effect_target_step(is_player_actor: bool, visual_slot: int, committed_slot: int, effect_step: Dictionary) -> int:
	if effect_step.is_empty():
		return visual_slot
	var target_slot: int = int(effect_step.get("target_to", visual_slot))
	if not _is_valid_presentation_slot(target_slot) or target_slot == visual_slot:
		return visual_slot
	await _animate_actor_visual_slots_stepwise(is_player_actor, visual_slot, target_slot, committed_slot)
	return target_slot

func _settle_visual_slots_to_committed_positions(visual_player_slot: int, visual_enemy_slot: int) -> void:
	var did_settle := false
	if player != null and _is_valid_presentation_slot(visual_player_slot) and _is_valid_presentation_slot(player.position) and visual_player_slot != player.position:
		did_settle = true
		await _animate_actor_visual_slots_stepwise(true, visual_player_slot, player.position, player.position)
	if enemy != null and _is_valid_presentation_slot(visual_enemy_slot) and _is_valid_presentation_slot(enemy.position) and visual_enemy_slot != enemy.position:
		did_settle = true
		await _animate_actor_visual_slots_stepwise(false, visual_enemy_slot, enemy.position, enemy.position)
	if not did_settle:
		await _settle_committed_slot_offsets()

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

func _play_attack_presentation(is_player_actor: bool, card: CardData, style: String, result: Dictionary) -> void:
	var dir: float = 1.0 if is_player_actor else -1.0
	var lunge_distance: float = _presentation_lunge_distance(style, result)
	var lunge_offset := Vector2(dir * lunge_distance, -5.0)
	var target_is_enemy: bool = is_player_actor
	var should_hit: bool = _presentation_result_should_hit(card, result)
	var target_will_break: bool = _presentation_target_will_break(not is_player_actor, result)
	var actor_effect_move_bound := _pending_presentation_effect_move_matches(is_player_actor) and bool(_pending_presentation_effect_move.get("attack_bound", false)) and _pending_effect_actor_has_move()
	var target_effect_move_bound := _pending_presentation_effect_move_matches(is_player_actor) and bool(_pending_presentation_effect_move.get("attack_bound", false)) and _pending_effect_target_has_move()
	var base_offset: Vector2 = _presentation_offset(is_player_actor)
	if not actor_effect_move_bound:
		_tween_actor_offset(is_player_actor, base_offset, base_offset + lunge_offset, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await get_tree().create_timer(0.08).timeout
	_play_presentation_attack_fx(is_player_actor, card, style, result)
	await get_tree().create_timer(0.04).timeout
	if should_hit:
		if not target_effect_move_bound:
			_play_presentation_hit_reaction(not is_player_actor, card, dir, result)
		if target_will_break:
			_play_break_ink_fx(not is_player_actor)
		var pause_duration: float = _presentation_hit_pause_duration(result, target_will_break)
		if pause_duration > 0.0:
			await get_tree().create_timer(pause_duration).timeout
	else:
		_play_presentation_miss_feedback(not is_player_actor, result)
	if not actor_effect_move_bound:
		var return_offset: Vector2 = _presentation_offset(is_player_actor)
		_tween_actor_offset(is_player_actor, return_offset + lunge_offset, return_offset, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	await _play_momentum_delta_presentation(is_player_actor, result)
	_show_presentation_result_text(target_is_enemy, card, result)
	await get_tree().create_timer(0.45).timeout

func _presentation_result_for_side(preview_sim: Dictionary, side: String) -> Dictionary:
	var result: Dictionary = super._presentation_result_for_side(preview_sim, side)
	var effect_step: Dictionary = _presentation_step_for_side(preview_sim, side, "effect")
	if effect_step.is_empty():
		return result
	result["will_break"] = bool(effect_step.get("will_break", false))
	result["will_die"] = bool(effect_step.get("will_die", false))
	result["was_back_hit"] = bool(effect_step.get("was_back_hit", false))
	result["back_hit_turn_to"] = str(effect_step.get("back_hit_turn_to", ""))
	result["actor_momentum_before"] = int(effect_step.get("actor_momentum_before", -1))
	result["actor_momentum_after"] = int(effect_step.get("actor_momentum_after", -1))
	result["target_momentum_before"] = int(effect_step.get("target_momentum_before", -1))
	result["target_momentum_after"] = int(effect_step.get("target_momentum_after", -1))
	return result

func _presentation_target_will_break(_target_is_player: bool, result: Dictionary) -> bool:
	if result.has("will_break"):
		return bool(result.get("will_break", false))
	return super._presentation_target_will_break(_target_is_player, result)

func _play_presentation_death(is_player_actor: bool) -> void:
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null:
		return
	await get_tree().create_timer(PRESENTATION_DEATH_HOLD_DURATION).timeout
	var start_offset: Vector2 = _presentation_offset(is_player_actor)
	var end_offset := start_offset + Vector2(0, 30)
	_tween_actor_offset(is_player_actor, start_offset, end_offset, 0.26, Tween.TRANS_QUAD, Tween.EASE_IN)
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.26)
	await get_tree().create_timer(0.28).timeout
	node.visible = false

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
	var committed_slot: int = to_slot
	if is_player_actor and player != null:
		committed_slot = player.position
	elif not is_player_actor and enemy != null:
		committed_slot = enemy.position
	await _animate_actor_visual_slots_stepwise(is_player_actor, from_slot, to_slot, committed_slot)

func _animate_actor_visual_slots_stepwise(is_player_actor: bool, from_slot: int, to_slot: int, committed_slot: int) -> void:
	if from_slot == to_slot:
		return
	var step_dir := 1 if to_slot > from_slot else -1
	var current_slot := from_slot
	var step_count := 0
	while current_slot != to_slot and step_count < PRESENTATION_STEP_MOVE_MAX_STEPS:
		var next_slot := current_slot + step_dir
		if not _is_valid_presentation_slot(next_slot):
			break
		var from_offset := _slot_offset_between(is_player_actor, current_slot, committed_slot)
		var to_offset := _slot_offset_between(is_player_actor, next_slot, committed_slot)
		await _tween_actor_one_grid_step(is_player_actor, from_offset, to_offset)
		current_slot = next_slot
		step_count += 1
		if current_slot != to_slot:
			await get_tree().create_timer(PRESENTATION_STEP_MOVE_PAUSE).timeout
	if current_slot != to_slot:
		var current_offset: Vector2 = _presentation_offset(is_player_actor)
		var final_offset := _slot_offset_between(is_player_actor, to_slot, committed_slot)
		_tween_actor_offset(is_player_actor, current_offset, final_offset, PRESENTATION_SLOT_SETTLE_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
		await get_tree().create_timer(PRESENTATION_SLOT_SETTLE_DURATION + 0.02).timeout

func _tween_actor_one_grid_step(is_player_actor: bool, from_offset: Vector2, to_offset: Vector2) -> void:
	var setter: Callable = Callable(self, "_set_player_presentation_offset") if is_player_actor else Callable(self, "_set_enemy_presentation_offset")
	var mid_offset := from_offset.lerp(to_offset, 0.55) + Vector2(0.0, PRESENTATION_STEP_MOVE_BOB_Y)
	var tween := create_tween()
	tween.tween_method(setter, from_offset, mid_offset, PRESENTATION_STEP_MOVE_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(setter, mid_offset, to_offset, PRESENTATION_STEP_MOVE_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

