extends "res://scripts/battle_controller_visual_presentation_mode_aware.gd"

# Ordered preview position guard.
#
# Fixes preview drift caused by treating target_position as if it had already
# been committed before ordered resolution starts.
#
# Correct semantics:
# - Initial preview positions are always committed Fighter.position values.
# - A side's subjective/action movement is applied only when that side's turn is
#   reached in the preview order.
# - In reactive mode, the enemy pre-move has already been committed before the
#   player responds, so enemy intent movement is not applied a second time.
# - In symmetric mode, enemy movement is treated as a relative delta from the
#   original committed enemy position and applied when enemy acts. This keeps
#   previews aligned when the player pushes/pulls the enemy before enemy action.


func _compute_ordered_preview() -> Dictionary:
	if player == null or enemy == null:
		return {"has_preview": false}

	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var has_preview: bool = draft_player_has_position or p_card != null or e_card != null
	if not has_preview:
		return {"has_preview": false}

	var p_pos: int = player.position
	var e_pos: int = enemy.position
	var p_facing: String = player.facing
	var e_facing: String = enemy.facing
	var p_text := "预期：待命"
	var e_text := "预期：待命"

	var p_target_pos: int = _player_preview_position()
	var p_target_facing: String = _player_preview_facing()
	var enemy_move_delta: int = 0
	var enemy_target_facing: String = e_facing
	if e_intent != null:
		if e_intent.target_facing != "":
			enemy_target_facing = e_intent.target_facing
		if not _preview_is_reactive_mode() and e_intent.target_position >= 0:
			enemy_move_delta = e_intent.target_position - enemy.position

	var order: Array[String] = _preview_resolution_order(p_intent, e_intent)
	if draft_player_has_position and not order.has("player"):
		order.append("player")
	if e_intent != null and not order.has("enemy"):
		order.append("enemy")

	for side: String in order:
		if side == "player":
			p_pos = clampi(p_target_pos, 0, GRID_SLOT_COUNT - 1)
			p_facing = p_target_facing
			if p_card == null:
				continue
			var result: String = _preview_range_result_at(p_card, p_pos, p_facing, e_pos)
			var outcome: Dictionary = _preview_outcome_text(p_card, player, enemy, result)
			p_text = str(outcome.get("actor", "预期"))
			e_text = str(outcome.get("target", e_text))
			var moved: Dictionary = _apply_preview_movement(p_card, true, p_pos, e_pos, p_facing, result)
			p_pos = int(moved.get("player", p_pos))
			e_pos = int(moved.get("enemy", e_pos))
		elif side == "enemy":
			e_pos = clampi(e_pos + enemy_move_delta, 0, GRID_SLOT_COUNT - 1)
			e_facing = enemy_target_facing
			if e_card == null:
				continue
			var result2: String = _preview_range_result_at(e_card, e_pos, e_facing, p_pos)
			var outcome2: Dictionary = _preview_outcome_text(e_card, enemy, player, result2)
			e_text = str(outcome2.get("actor", "预期"))
			p_text = str(outcome2.get("target", p_text))
			var moved2: Dictionary = _apply_preview_movement(e_card, false, p_pos, e_pos, e_facing, result2)
			p_pos = int(moved2.get("player", p_pos))
			e_pos = int(moved2.get("enemy", e_pos))

	return {
		"has_preview": true,
		"player_final": clampi(p_pos, 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(e_pos, 0, GRID_SLOT_COUNT - 1),
		"player_text": p_text,
		"enemy_text": e_text
	}


func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	if is_player:
		return _player_preview_position()
	var intent: IntentData = _enemy_preview_intent()
	if intent == null or intent.target_position < 0:
		return enemy_slot
	if _preview_is_reactive_mode():
		return enemy.position if enemy != null else enemy_slot
	return clampi(enemy_slot + (intent.target_position - (enemy.position if enemy != null else enemy_slot)), 0, GRID_SLOT_COUNT - 1)


func _preview_is_reactive_mode() -> bool:
	return state_machine != null and state_machine.is_reactive_mode()
