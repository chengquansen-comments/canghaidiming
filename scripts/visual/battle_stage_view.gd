extends RefCounted
class_name BattleStageHelper

static var _grid_width_cache: Dictionary = {}
static var _slot_center_cache: Dictionary = {}
static var _slot_top_left_cache: Dictionary = {}
static var _slot_state_cache: Dictionary = {}
static var _range_overlay_style_cache: Dictionary = {}

static func grid_total_width(slot_count: int, slot_width: float, slot_gap: float) -> float:
	var key: String = "%d|%.3f|%.3f" % [slot_count, slot_width, slot_gap]
	if _grid_width_cache.has(key):
		return _grid_width_cache[key] as float
	var width: float = slot_count * slot_width + (slot_count - 1) * slot_gap
	_grid_width_cache[key] = width
	return width

static func slot_center_x(scene_width: float, slot: int, slot_count: int, slot_width: float, slot_gap: float) -> float:
	var key: String = "%.3f|%d|%d|%.3f|%.3f" % [scene_width, slot, slot_count, slot_width, slot_gap]
	if _slot_center_cache.has(key):
		return _slot_center_cache[key] as float
	var total_width: float = grid_total_width(slot_count, slot_width, slot_gap)
	var left: float = (scene_width - total_width) * 0.5
	var center: float = left + slot * (slot_width + slot_gap) + slot_width * 0.5
	_slot_center_cache[key] = center
	return center

static func slot_top_left(scene_width: float, slot: int, is_player: bool, slot_count: int, slot_width: float, slot_gap: float, stage_ground_y: float, actor_height: float, player_foot_offset_x: float, enemy_foot_offset_x: float) -> Vector2:
	var key: String = "%.3f|%d|%s|%d|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f" % [scene_width, slot, str(is_player), slot_count, slot_width, slot_gap, stage_ground_y, actor_height, player_foot_offset_x, enemy_foot_offset_x]
	if _slot_top_left_cache.has(key):
		return _slot_top_left_cache[key] as Vector2
	var center_x: float = slot_center_x(scene_width, slot, slot_count, slot_width, slot_gap)
	var foot_offset: float = player_foot_offset_x if is_player else enemy_foot_offset_x
	var result: Vector2 = Vector2(center_x - foot_offset, stage_ground_y - actor_height)
	_slot_top_left_cache[key] = result
	return result

static func current_grid_positions(distance: int, right_anchor_slot: int, slot_count: int) -> Dictionary:
	var enemy_slot: int = right_anchor_slot
	var player_slot: int = enemy_slot - distance
	if player_slot < 0:
		player_slot = 0
		enemy_slot = mini(player_slot + distance, slot_count - 1)
	return {"player": player_slot, "enemy": enemy_slot}

static func target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: Object, slot_count: int) -> int:
	var actor_slot: int = player_slot if is_player else enemy_slot
	var opponent_slot: int = enemy_slot if is_player else player_slot
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
			var slot: int = origin_slot + distance
			if slot >= 0 and slot < slot_count:
				result.append(slot)
	else:
		for distance in range(card.min_distance, card.max_distance + 1):
			var slot: int = origin_slot - distance
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
	var start_pos: Vector2 = slot_top_left(scene_width, start_slot, is_player, slot_count, slot_width, slot_gap, stage_ground_y, actor_height, player_foot_offset_x, enemy_foot_offset_x)
	if not active:
		return start_pos
	var target_pos: Vector2 = slot_top_left(scene_width, target_slot, is_player, slot_count, slot_width, slot_gap, stage_ground_y, actor_height, player_foot_offset_x, enemy_foot_offset_x)
	if phase < 0.26:
		return start_pos.lerp(target_pos, ease_preview(phase / 0.26))
	if phase < 0.68:
		var hold: Vector2 = target_pos
		var dir: float = 1.0 if is_player else -1.0
		var attack_t: float = (phase - 0.26) / 0.42
		var lunge: float = sin(attack_t * PI) * 34.0
		return hold + Vector2(dir * lunge, -sin(attack_t * PI) * 12.0)
	if phase < 1.0:
		return target_pos.lerp(start_pos, ease_preview((phase - 0.68) / 0.32))
	return start_pos

static func ease_preview(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

static func build_slot_state(i: int, player_slot: int, enemy_slot: int, player_range: Array[int], enemy_range: Array[int], grid_base_color: Color, player_color: Color, enemy_color: Color) -> Dictionary:
	var key: String = "%d|%d|%d|%s|%s" % [i, player_slot, enemy_slot, str(player_range), str(enemy_range)]
	if _slot_state_cache.has(key):
		return _slot_state_cache[key] as Dictionary

	var in_player_range: bool = player_range.has(i)
	var in_enemy_range: bool = enemy_range.has(i)
	var has_player: bool = i == player_slot
	var has_enemy: bool = i == enemy_slot

	var fill: Color = grid_base_color
	if has_player:
		fill = player_color
	if has_enemy:
		fill = enemy_color

	var label_text: String = ""
	if (has_enemy and in_player_range) or (has_player and in_enemy_range):
		label_text = "×"
	elif in_player_range or in_enemy_range:
		label_text = "·"

	var state: Dictionary = {
		"fill": fill,
		"label": label_text,
		"has_player": has_player,
		"has_enemy": has_enemy
	}

	_slot_state_cache[key] = state
	return state

static func range_overlay_style(is_player: bool) -> Dictionary:
	var key: String = "player" if is_player else "enemy"
	if _range_overlay_style_cache.has(key):
		return _range_overlay_style_cache[key] as Dictionary
	var style: Dictionary = {}
	if is_player:
		style = {
			"fill_color": Color(0.25, 0.62, 1.0, 0.24),
			"outline_color": Color(0.62, 0.86, 1.0, 0.78),
			"line_width": 3.0,
			"polygon_z": 2,
			"line_z": 3
		}
	else:
		style = {
			"fill_color": Color(1.0, 0.32, 0.22, 0.23),
			"outline_color": Color(1.0, 0.67, 0.52, 0.78),
			"line_width": 3.0,
			"polygon_z": 2,
			"line_z": 3
		}
	_range_overlay_style_cache[key] = style
	return style

static func clear_geometry_cache() -> void:
	_grid_width_cache.clear()
	_slot_center_cache.clear()
	_slot_top_left_cache.clear()
	_slot_state_cache.clear()
	_range_overlay_style_cache.clear()
