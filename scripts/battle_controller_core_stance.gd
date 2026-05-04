extends "res://scripts/battle_controller_core_deck_view_fusion.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _reset_player_stance_draft() -> void:
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false

func _player_target_position() -> int:
	if draft_player_has_position:
		return draft_player_position
	if draft_player_intent != null and draft_player_intent.target_position >= 0:
		return draft_player_intent.target_position
	return player.position if player != null else 0

func _player_target_facing() -> String:
	if draft_player_has_position and draft_player_facing != "":
		return draft_player_facing
	if draft_player_intent != null and draft_player_intent.target_facing != "":
		return draft_player_intent.target_facing
	return player.facing if player != null else "right"

func _apply_player_stance_draft_to_intent() -> void:
	if draft_player_intent == null or player == null:
		return
	var target_position := _player_target_position()
	var target_facing := _player_target_facing()
	if not draft_player_has_position:
		target_position = player.position
		target_facing = player.facing
	draft_player_intent.set_stance(target_position, target_facing)

func _legal_positions_for(fighter: Fighter) -> Array[int]:
	var result: Array[int] = []
	if fighter == null:
		return result
	var start := clampi(fighter.position - fighter.qinggong, 0, BATTLE_SLOT_COUNT - 1)
	var finish := clampi(fighter.position + fighter.qinggong, 0, BATTLE_SLOT_COUNT - 1)
	for slot in range(start, finish + 1):
		result.append(slot)
	return result

func _is_player_legal_position(slot: int) -> bool:
	if not _legal_positions_for(player).has(slot):
		return false
	if enemy != null and slot == enemy.position:
		return false
	return true

func _on_stage_grid_slot_pressed(slot: int) -> void:
	if not awaiting_player_input or player == null:
		return
	if not _is_player_legal_position(slot):
		if enemy != null and slot == enemy.position:
			_log("该格已被敌方占住，不能直接叠位。")
		else:
			_log("轻功不足，不能移动到该格。")
		return
	var current_target := _player_target_position()
	if draft_player_has_position and slot == current_target and slot == player.position:
		draft_player_facing = _opposite_facing(_player_target_facing())
	else:
		draft_player_position = slot
		draft_player_facing = _facing_toward(slot, enemy.position if enemy != null else slot, player.facing)
		draft_player_has_position = true
	_apply_player_stance_draft_to_intent()
	_log("已选身位：%d，朝向%s。" % [slot, "左" if _player_target_facing() == "left" else "右"])
	_invalidate_stage_preview()
	_refresh_ui()

func _facing_toward(actor_position: int, target_position: int, fallback: String) -> String:
	if actor_position == target_position:
		return fallback
	return "right" if target_position > actor_position else "left"

func _opposite_facing(value: String) -> String:
	return "left" if value == "right" else "right"

func _invalidate_stage_preview() -> void:
	pass
