extends RefCounted
class_name BattleStageHelper

static var _grid_width_cache: Dictionary = {}
static var _slot_center_cache: Dictionary = {}
static var _slot_top_left_cache: Dictionary = {}
static var _slot_state_cache: Dictionary = {}

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

static func clear_geometry_cache() -> void:
	_grid_width_cache.clear()
	_slot_center_cache.clear()
	_slot_top_left_cache.clear()
	_slot_state_cache.clear()
