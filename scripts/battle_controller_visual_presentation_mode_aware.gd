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
	_reset_presentation_offsets()
	_apply_pre_resolution_slot_offsets(old_player_slot, old_enemy_slot)
	var visual_player_slot: int = old_player_slot
	var visual_enemy_slot: int = old_enemy_slot
	var has_step_trace := _presentation_has_step_trace(preview_sim)
	for side: String in order:
		if side == "player" and player_card != null:
			if has_step_trace and not _presentation_has_effect_step(preview_sim, "player"):
				continue
			var player_move_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "move")
			visual_player_slot = await _apply_presentation_stance_step(true, visual_player_slot, player.position, player_card, player_move_step)
			await _play_one_presentation_action(true, player_card, _presentation_result_for_side(preview_sim, "player"))
			var player_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "effect_move")
			visual_player_slot = await _apply_presentation_effect_actor_step(true, visual_player_slot, player.position, player_effect_step)
			visual_enemy_slot = await _apply_presentation_effect_target_step(false, visual_enemy_slot, enemy.position, player_effect_step)
		elif side == "enemy" and enemy_card != null:
			if has_step_trace and not _presentation_has_effect_step(preview_sim, "enemy"):
				continue
			var enemy_move_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "move")
			visual_enemy_slot = await _apply_presentation_stance_step(false, visual_enemy_slot, enemy.position, enemy_card, enemy_move_step)
			await _play_one_presentation_action(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"))
			var enemy_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "effect_move")
			visual_enemy_slot = await _apply_presentation_effect_actor_step(false, visual_enemy_slot, enemy.position, enemy_effect_step)
			visual_player_slot = await _apply_presentation_effect_target_step(true, visual_player_slot, player.position, enemy_effect_step)
	await _settle_visual_slots_to_committed_positions(visual_player_slot, visual_enemy_slot)
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_reset_presentation_offsets()
	_set_presentation_busy(false)


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
