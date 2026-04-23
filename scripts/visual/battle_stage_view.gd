extends RefCounted
class_name BattleStageHelper

static func grid_total_width(slot_count: int, slot_width: float, slot_gap: float) -> float:
	return slot_count * slot_width + (slot_count - 1) * slot_gap

static func slot_center_x(scene_width: float, slot: int, slot_count: int, slot_width: float, slot_gap: float) -> float:
	var total_width := grid_total_width(slot_count, slot_width, slot_gap)
	var left := (scene_width - total_width) * 0.5
	return left + slot * (slot_width + slot_gap) + slot_width * 0.5

static func slot_top_left(scene_width: float, slot: int, is_player: bool, slot_count: int, slot_width: float, slot_gap: float, stage_ground_y: float, actor_height: float, player_foot_offset_x: float, enemy_foot_offset_x: float) -> Vector2:
	var center_x := slot_center_x(scene_width, slot, slot_count, slot_width, slot_gap)
	var foot_offset := player_foot_offset_x if is_player else enemy_foot_offset_x
	return Vector2(center_x - foot_offset, stage_ground_y - actor_height)

static func current_grid_positions(distance: int, right_anchor_slot: int, slot_count: int) -> Dictionary:
	var enemy_slot := right_anchor_slot
	var player_slot := enemy_slot - distance
	if player_slot < 0:
		player_slot = 0
		enemy_slot = mini(player_slot + distance, slot_count - 1)
	return {"player": player_slot, "enemy": enemy_slot}

static func target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: Object, slot_count: int) -> int:
	var actor_slot := player_slot if is_player else enemy_slot
	var opponent_slot := enemy_slot if is_player else player_slot
	if card == null:
		return actor_slot
	if card.id == "idle" or card.id == "staggered":
		return actor_slot
	var current_distance: int = abs(enemy_slot - player_slot)
	var target_distance: int = current_distance
	if current_distance > card.max_distance:
		target_distance = card.max_distance
	elif current_distance < card.min_distance:
		target_distance = card.min_distance
	var delta: int = current_distance - target_distance
	if delta == 0:
		return actor_slot
	if is_player:
		if delta > 0:
			return clampi(actor_slot + delta, 0, opponent_slot - 1)
		return clampi(actor_slot - abs(delta), 0, slot_count - 1)
	if delta > 0:
		return clampi(actor_slot - delta, opponent_slot + 1, slot_count - 1)
	return clampi(actor_slot + abs(delta), 0, slot_count - 1)

static func attack_range_slots(is_player: bool, origin_slot: int, card: Object, slot_count: int) -> Array[int]:
	var result: Array[int] = []
	if card == null or not card.has_method("requires_hit_check") or not card.requires_hit_check():
		return result
	if is_player:
		for distance in range(card.min_distance, card.max_distance + 1):
			var slot := origin_slot + distance
			if slot >= 0 and slot < slot_count:
				result.append(slot)
	else:
		for distance in range(card.min_distance, card.max_distance + 1):
			var slot := origin_slot - distance
			if slot >= 0 and slot < slot_count:
				result.append(slot)
	return result

static func preview_cycle_phase(preview_anim_time: float, preview_cycle_duration: float) -> float:
	return fmod(preview_anim_time, preview_cycle_duration) / preview_cycle_duration

static func preview_frame_for_card(card: Object, active: bool, phase: float) -> int:
	if not active or card == null:
		return 0
	if card.has_method("requires_hit_check") and card.requires_hit_check() and phase >= 0.38 and phase <= 0.68:
		return 1
	return 0

static func animated_actor_top_left(scene_width: float, is_player: bool, start_slot: int, target_slot: int, active: bool, phase: float, slot_count: int, slot_width: float, slot_gap: float, stage_ground_y: float, actor_height: float, player_foot_offset_x: float, enemy_foot_offset_x: float) -> Vector2:
	var start_pos := slot_top_left(scene_width, start_slot, is_player, slot_count, slot_width, slot_gap, stage_ground_y, actor_height, player_foot_offset_x, enemy_foot_offset_x)
	if not active:
		return start_pos
	var target_pos := slot_top_left(scene_width, target_slot, is_player, slot_count, slot_width, slot_gap, stage_ground_y, actor_height, player_foot_offset_x, enemy_foot_offset_x)
	if phase < 0.26:
		return start_pos.lerp(target_pos, ease_preview(phase / 0.26))
	if phase < 0.68:
		var hold := target_pos
		var dir := 1.0 if is_player else -1.0
		var attack_t := (phase - 0.26) / 0.42
		var lunge := sin(attack_t * PI) * 34.0
		return hold + Vector2(dir * lunge, -sin(attack_t * PI) * 12.0)
	if phase < 1.0:
		return target_pos.lerp(start_pos, ease_preview((phase - 0.68) / 0.32))
	return start_pos

static func ease_preview(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
