extends RefCounted
class_name BattleStageHelper

static func grid_total_width(slot_count: int, slot_width: float, slot_gap: float) -> float:
	return slot_count * slot_width + (slot_count - 1) * slot_gap

static func slot_center_x(scene_width: float, slot: int, slot_count: int, slot_width: float, slot_gap: float) -> float:
	var total_width := grid_total_width(slot_count, slot_width, slot_gap)
	var left := (scene_width - total_width) * 0.5
	return left + slot * (slot_width + slot_gap) + slot_width * 0.5

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
	if card == null or card.damage <= 0:
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

static func ease_preview(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
