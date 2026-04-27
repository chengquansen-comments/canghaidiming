extends RefCounted

# Phase 13.0 helper.
# Owns target-slot / target-facing selection rules. It is intentionally pure:
# no UI mutation, no combat resolution, no animation side effects.

static func is_valid_facing(facing_value: String) -> bool:
	return facing_value == "left" or facing_value == "right"

static func opposite_facing(facing_value: String) -> String:
	if facing_value == "left":
		return "right"
	if facing_value == "right":
		return "left"
	return ""

static func current_target_slot(player, draft_has_position: bool, draft_position: int, draft_intent, grid_slot_count: int) -> int:
	if player == null:
		return 0
	if draft_has_position:
		return clampi(draft_position, 0, grid_slot_count - 1)
	if draft_intent != null and draft_intent.target_position >= 0:
		return clampi(draft_intent.target_position, 0, grid_slot_count - 1)
	return clampi(player.position, 0, grid_slot_count - 1)

static func current_target_facing(player, draft_has_position: bool, draft_facing: String, draft_intent) -> String:
	if player == null:
		return "right"
	if draft_has_position and is_valid_facing(draft_facing):
		return draft_facing
	if draft_intent != null and is_valid_facing(draft_intent.target_facing):
		return draft_intent.target_facing
	return player.facing if is_valid_facing(player.facing) else "right"

static func is_legal_target_slot(player, enemy, slot: int, grid_slot_count: int) -> bool:
	if player == null:
		return false
	if slot < 0 or slot >= grid_slot_count:
		return false
	if enemy != null and enemy.hp > 0 and slot == enemy.position:
		return false
	var max_steps: int = maxi(player.qinggong, 0)
	return absi(slot - player.position) <= max_steps

static func next_selection_for_click(player, enemy, clicked_slot: int, current_target_slot_value: int, current_target_facing_value: String, grid_slot_count: int) -> Dictionary:
	var safe_clicked: int = clampi(clicked_slot, 0, grid_slot_count - 1)
	if safe_clicked == current_target_slot_value:
		return {
			"ok": true,
			"slot": safe_clicked,
			"facing": opposite_facing(current_target_facing_value),
			"reason": "toggle_facing"
		}
	if not is_legal_target_slot(player, enemy, safe_clicked, grid_slot_count):
		return {
			"ok": false,
			"slot": current_target_slot_value,
			"facing": current_target_facing_value,
			"reason": "illegal_slot"
		}
	return {
		"ok": true,
		"slot": safe_clicked,
		"facing": player.facing if player != null and is_valid_facing(player.facing) else "right",
		"reason": "move_target"
	}

static func slot_label(slot: int) -> String:
	var labels := ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot
