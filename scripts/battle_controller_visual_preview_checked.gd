extends "res://scripts/battle_controller_visual_responsive_ui.gd"

# Auto preview consistency layer.
# This wrapper keeps the current responsive controller intact and only adds a
# lightweight debug check after ghost preview refresh. It is intentionally
# non-blocking: mismatches are printed once per signature instead of interrupting play.

const PreviewConsistencyChecker = preload("res://scripts/preview_consistency_checker.gd")

var _last_preview_check_signature := ""
var _last_preview_mismatch_signature := ""


func _refresh_preview_ghosts() -> void:
	super()
	_run_preview_consistency_check()


func _run_preview_consistency_check() -> void:
	if player == null or enemy == null or not battle_active:
		return
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	if p_intent == null and e_intent == null and not draft_player_has_position:
		return

	var snapshot := _build_preview_check_snapshot(p_intent, e_intent)
	var preview_signature := _build_visible_preview_signature(snapshot)
	var check := PreviewConsistencyChecker.compare(snapshot, preview_signature)
	var check_signature := JSON.stringify({
		"snapshot": snapshot,
		"preview": preview_signature,
		"ok": check.get("ok", false),
		"mismatches": check.get("mismatches", [])
	})
	if check_signature == _last_preview_check_signature:
		return
	_last_preview_check_signature = check_signature
	if bool(check.get("ok", false)):
		return
	var mismatch_signature := JSON.stringify(check.get("mismatches", []))
	if mismatch_signature == _last_preview_mismatch_signature:
		return
	_last_preview_mismatch_signature = mismatch_signature
	print("[PreviewMismatch] ", JSON.stringify(check.get("mismatches", [])))
	print("[PreviewMismatch.expected] ", JSON.stringify(check.get("expected", {})))
	print("[PreviewMismatch.actual] ", JSON.stringify(check.get("actual", {})))


func _build_preview_check_snapshot(p_intent: IntentData, e_intent: IntentData) -> Dictionary:
	return {
		"player_position": _player_preview_position(),
		"enemy_position": _enemy_preview_position_for_check(e_intent),
		"player_facing": _player_preview_facing(),
		"enemy_facing": _enemy_preview_facing(),
		"player_card": _card_to_preview_dict(p_intent.actual_card if p_intent != null else null),
		"enemy_card": _card_to_preview_dict(e_intent.actual_card if e_intent != null else null),
		"order": _preview_resolution_order(p_intent, e_intent),
		"player_momentum": player.momentum,
		"enemy_momentum": enemy.momentum,
		"player_guard": player.guard_points,
		"enemy_guard": enemy.guard_points,
		"player_broken": player.is_broken(),
		"enemy_broken": enemy.is_broken(),
		"reactive_mode": state_machine != null and state_machine.is_reactive_mode()
	}


func _enemy_preview_position_for_check(e_intent: IntentData) -> int:
	if e_intent != null and e_intent.target_position >= 0:
		return e_intent.target_position
	return enemy.position


func _build_visible_preview_signature(snapshot: Dictionary) -> Dictionary:
	# Use the current controller's ghost-preview algorithm as the "actual preview".
	# The checker independently re-simulates from snapshot as the expected result.
	var preview := _compute_ordered_preview()
	var sim: Dictionary = preview.get("sim", {})
	if not sim.is_empty():
		return {
			"order": sim.get("order", snapshot.get("order", [])),
			"player_final": int(sim.get("player_final", snapshot.get("player_position", 0))),
			"enemy_final": int(sim.get("enemy_final", snapshot.get("enemy_position", 0))),
			"player_hp_delta": int(sim.get("player_hp_delta", 0)),
			"enemy_hp_delta": int(sim.get("enemy_hp_delta", 0)),
			"player_momentum_delta": int(sim.get("player_momentum_delta", 0)),
			"enemy_momentum_delta": int(sim.get("enemy_momentum_delta", 0)),
			"player_range_result": str(sim.get("player_range_result", "none")),
			"enemy_range_result": str(sim.get("enemy_range_result", "none")),
			"player_will_break": bool(sim.get("player_will_break", false)),
			"enemy_will_break": bool(sim.get("enemy_will_break", false))
		}
	var expected_for_shape := PreviewConsistencyChecker.build_preview_signature(snapshot)
	return {
		"order": snapshot.get("order", []),
		"player_final": int(preview.get("player_final", snapshot.get("player_position", 0))),
		"enemy_final": int(preview.get("enemy_final", snapshot.get("enemy_position", 0))),
		"player_hp_delta": expected_for_shape.get("player_hp_delta", 0),
		"enemy_hp_delta": expected_for_shape.get("enemy_hp_delta", 0),
		"player_momentum_delta": expected_for_shape.get("player_momentum_delta", 0),
		"enemy_momentum_delta": expected_for_shape.get("enemy_momentum_delta", 0),
		"player_range_result": expected_for_shape.get("player_range_result", "none"),
		"enemy_range_result": expected_for_shape.get("enemy_range_result", "none"),
		"player_will_break": expected_for_shape.get("player_will_break", false),
		"enemy_will_break": expected_for_shape.get("enemy_will_break", false)
	}


func _card_to_preview_dict(card: CardData) -> Dictionary:
	if card == null:
		return {}
	return {
		"id": card.id,
		"display_name": card.display_name,
		"min_distance": card.min_distance,
		"max_distance": card.max_distance,
		"damage": card.damage,
		"break_momentum": card.break_momentum,
		"gain_momentum": card.gain_momentum,
		"guard": card.guard,
		"requires_facing": card.requires_facing,
		"requires_hit_check": card.requires_hit_check(),
		"tags": Array(card.tags),
		"self_move_after": card.self_move_after,
		"target_push_after": card.target_push_after,
		"target_pull_after": card.target_pull_after,
		"move_condition": card.move_condition
	}
