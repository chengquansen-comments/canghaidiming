extends "res://scripts/battle_controller_visual_presentation_assets.gd"

# Phase 10 stepwise committed movement wrapper.
# Keep all existing combat presentation, result feedback, and SVG FX from the
# assetized wrapper. Only replace the final committed slot settling:
# old slot -> next slot -> ... -> committed slot.

const PRESENTATION_STEP_MOVE_DURATION := 0.12
const PRESENTATION_STEP_MOVE_PAUSE := 0.045
const PRESENTATION_STEP_MOVE_BOB_Y := -7.0
const PRESENTATION_STEP_MOVE_MAX_STEPS := 8

func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_reset_presentation_offsets()
	_apply_pre_resolution_slot_offsets(old_player_slot, old_enemy_slot)
	for side: String in order:
		if side == "player" and player_card != null:
			await _play_one_presentation_action(true, player_card, _presentation_result_for_side(preview_sim, "player"))
		elif side == "enemy" and enemy_card != null:
			await _play_one_presentation_action(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"))
	await _settle_committed_slot_offsets_stepwise(old_player_slot, old_enemy_slot)
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_reset_presentation_offsets()
	_set_presentation_busy(false)

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

func _is_valid_presentation_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < GRID_SLOT_COUNT
