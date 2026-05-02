extends "res://scripts/battle_controller_visual_presentation_stepwise.gd"

# Mode-aware presentation guard.
#
# Symmetric mode should present "planned actions executed by order".
# Reactive mode should present "enemy already moved -> player response -> enemy acts only if not interrupted".
#
# The parent stepwise presenter loops by resolution order and plays an action when
# a visible card exists. That is fine when every side resolves, but it is
# misleading when a side is canceled by reactive break/interruption: the enemy may
# still have a visible card, yet preview_sim contains no effect step for that side.
#
# This layer treats preview_sim.steps as the source of truth for presentation: if
# steps exist, a side only performs its stance/action/effect presentation when its
# "effect" step exists. This keeps canceled reactive enemy attacks from playing.


func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_begin_presentation_watchdog("mode-aware-exchange")
	_reset_presentation_offsets()
	_reset_player_presentation_action_gate()
	var visual_player_slot: int = _consume_player_draft_visual_start_slot(old_player_slot)
	_apply_pre_resolution_slot_offsets(visual_player_slot, old_enemy_slot)
	var visual_enemy_slot: int = old_enemy_slot
	var has_step_trace := _presentation_has_step_trace(preview_sim)
	var played_sides := {}
	for index in range(order.size()):
		var side: String = str(order[index])
		if bool(played_sides.get(side, false)):
			continue
		if side == "player" and player_card != null:
			if has_step_trace and not _presentation_has_effect_step(preview_sim, "player"):
				continue
			played_sides[side] = true
			_set_actor_action_glow(true, true)
			await _play_phase_focus_cue("我方出招", ACTOR_GLOW_PLAYER_COLOR)
			var player_move_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "move")
			visual_player_slot = await _apply_presentation_stance_step(true, visual_player_slot, player.position, player_card, player_move_step)
			await _play_one_presentation_action(true, player_card, _presentation_result_for_side(preview_sim, "player"))
			_mark_player_presentation_action_completed()
			var player_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "effect_move")
			visual_player_slot = await _apply_presentation_effect_actor_step(true, visual_player_slot, player.position, player_effect_step)
			visual_enemy_slot = await _apply_presentation_effect_target_step(false, visual_enemy_slot, enemy.position, player_effect_step)
			_set_actor_action_glow(true, false)
			if _presentation_enemy_action_remaining(order, index + 1, preview_sim, has_step_trace, enemy_card):
				await get_tree().create_timer(PRESENTATION_POST_PLAYER_ACTION_PAUSE).timeout
		elif side == "enemy" and enemy_card != null:
			if has_step_trace and not _presentation_has_effect_step(preview_sim, "enemy"):
				continue
			played_sides[side] = true
			_set_actor_action_glow(false, true)
			await _play_phase_focus_cue("敌方反击", ACTOR_GLOW_ENEMY_COLOR)
			await get_tree().create_timer(PRESENTATION_PRE_ENEMY_ACTION_GLOW_PAUSE).timeout
			var enemy_move_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "move")
			visual_enemy_slot = await _apply_presentation_stance_step(false, visual_enemy_slot, enemy.position, enemy_card, enemy_move_step)
			await _wait_for_enemy_attack_start_after_player()
			await _play_one_presentation_action(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"))
			var enemy_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "effect_move")
			visual_enemy_slot = await _apply_presentation_effect_actor_step(false, visual_enemy_slot, enemy.position, enemy_effect_step)
			visual_player_slot = await _apply_presentation_effect_target_step(true, visual_player_slot, player.position, enemy_effect_step)
			_set_actor_action_glow(false, false)
			await get_tree().create_timer(PRESENTATION_POST_ENEMY_ACTION_PAUSE).timeout
	await _settle_visual_slots_to_committed_positions(visual_player_slot, visual_enemy_slot)
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_finish_presentation_exchange()


func _presentation_has_step_trace(preview_sim: Dictionary) -> bool:
	var steps_value = preview_sim.get("steps", [])
	return steps_value is Array and (steps_value as Array).size() > 0


func _presentation_has_effect_step(preview_sim: Dictionary, side: String) -> bool:
	var steps_value = preview_sim.get("steps", [])
	if not (steps_value is Array):
		return false
	for step_value in (steps_value as Array):
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if str(step.get("side", "")) == side and str(step.get("phase", "")) == "effect":
			return true
	return false


func _presentation_enemy_action_remaining(order: Array[String], start_index: int, preview_sim: Dictionary, has_step_trace: bool, enemy_card: CardData) -> bool:
	if enemy_card == null:
		return false
	if has_step_trace and not _presentation_has_effect_step(preview_sim, "enemy"):
		return false
	for i in range(start_index, order.size()):
		if str(order[i]) == "enemy":
			return true
	return false
