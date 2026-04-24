extends "res://scripts/battle_controller_visual_ui.gd"

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")

var _last_stage_grid_state: Dictionary = {}
var _range_polygon_pool: Array[Polygon2D] = []
var _range_line_pool: Array[Line2D] = []
var _active_range_polygons: Array[Polygon2D] = []
var _active_range_lines: Array[Line2D] = []

func _sheet_frame_texture(source: Texture2D, frame: int) -> Texture2D:
	return BattleSkinHelper.atlas_frame(source, FRAME_SIZE, frame)

func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	return BattleSkinHelper.make_flat_card_style(fill, border, border_width)

func _make_type_tag_style(card: CardData) -> StyleBoxFlat:
	return BattleSkinHelper.make_type_tag_style(card.is_guard_card(), card.is_momentum_card())

func _make_card_art_style(card: CardData) -> StyleBoxFlat:
	return BattleSkinHelper.make_card_art_style(card.is_guard_card(), card.is_momentum_card())

func _make_momentum_dot_style(filled: bool) -> StyleBoxFlat:
	return BattleSkinHelper.make_momentum_dot_style(filled)

func _clear_range_trapezoids() -> void:
	_recycle_range_overlay_nodes()

func _refresh_range_trapezoids(player_range: Array[int], player_origin_slot: int, enemy_range: Array[int], enemy_origin_slot: int) -> void:
	if range_overlay_layer == null:
		return
	_recycle_range_overlay_nodes()
	for slot in player_range:
		_draw_range_trapezoid(slot, player_origin_slot, Color(0.25, 0.62, 1.0, 0.24), Color(0.62, 0.86, 1.0, 0.78))
	for slot in enemy_range:
		_draw_range_trapezoid(slot, enemy_origin_slot, Color(1.0, 0.32, 0.22, 0.23), Color(1.0, 0.67, 0.52, 0.78))

func _draw_range_trapezoid(slot: int, origin_slot: int, fill_color: Color, outline_color: Color) -> void:
	if range_overlay_layer == null:
		return
	var points: PackedVector2Array = _range_trapezoid_points(slot, origin_slot)
	var polygon: Polygon2D = _take_range_polygon()
	polygon.polygon = points
	polygon.color = fill_color
	polygon.z_index = 2
	polygon.visible = true
	_active_range_polygons.append(polygon)
	var outline: Line2D = _take_range_line()
	outline.points = points
	outline.closed = true
	outline.width = 3.0
	outline.default_color = outline_color
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.z_index = 3
	outline.visible = true
	_active_range_lines.append(outline)

func _take_range_polygon() -> Polygon2D:
	if not _range_polygon_pool.is_empty():
		return _range_polygon_pool.pop_back()
	var polygon := Polygon2D.new()
	range_overlay_layer.add_child(polygon)
	return polygon

func _take_range_line() -> Line2D:
	if not _range_line_pool.is_empty():
		return _range_line_pool.pop_back()
	var line := Line2D.new()
	range_overlay_layer.add_child(line)
	return line

func _recycle_range_overlay_nodes() -> void:
	for polygon in _active_range_polygons:
		polygon.visible = false
		_range_polygon_pool.append(polygon)
	for line in _active_range_lines:
		line.visible = false
		_range_line_pool.append(line)
	_active_range_polygons.clear()
	_active_range_lines.clear()

func _refresh_stage_grid() -> void:
	if stage_grid_cells.is_empty():
		return
	var positions: Dictionary = _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_preview_card: CardData = _player_preview_card()
	var enemy_preview_card: CardData = _enemy_preview_card()
	var player_target_slot: int = _target_slot_for_preview(true, player_slot, enemy_slot, player_preview_card)
	var enemy_target_slot: int = _target_slot_for_preview(false, player_slot, enemy_slot, enemy_preview_card)
	var player_range: Array[int] = _attack_range_slots(true, player_target_slot, player_preview_card)
	var enemy_range: Array[int] = _attack_range_slots(false, enemy_target_slot, enemy_preview_card)
	_refresh_range_trapezoids(player_range, player_target_slot, enemy_range, enemy_target_slot)
	var next_state: Dictionary = {}
	for i in range(GRID_SLOT_COUNT):
		var in_player_range: bool = player_range.has(i)
		var in_enemy_range: bool = enemy_range.has(i)
		var has_player: bool = i == player_target_slot
		var has_enemy: bool = i == enemy_target_slot
		var fill: Color = GRID_BASE_COLOR
		if has_player:
			fill = PLAYER_POS_COLOR
		if has_enemy:
			fill = ENEMY_POS_COLOR
		var label_text: String = ""
		if (has_enemy and in_player_range) or (has_player and in_enemy_range):
			label_text = "×"
		elif in_player_range or in_enemy_range:
			label_text = "·"
		var state_key: String = "%s|%s|%s|%s|%s|%s" % [fill.to_html(), str(i), str(has_player), str(has_enemy), str(in_player_range), str(in_enemy_range)]
		next_state[i] = {"key": state_key, "fill": fill, "label": label_text, "has_player": has_player, "has_enemy": has_enemy}
		if not _last_stage_grid_state.has(i) or (_last_stage_grid_state[i] as Dictionary).get("key", "") != state_key or (_last_stage_grid_state[i] as Dictionary).get("label", "") != label_text:
			_apply_stage_grid_slot(i, fill, has_player, has_enemy, label_text)
	_last_stage_grid_state = next_state

func _apply_stage_grid_slot(slot: int, fill: Color, has_player: bool, has_enemy: bool, label_text: String) -> void:
	if slot < 0 or slot >= stage_grid_cells.size() or slot >= stage_grid_labels.size():
		return
	stage_grid_cells[slot].add_theme_stylebox_override("panel", _make_grid_cell_style(fill, slot, has_player, has_enemy, false, false))
	stage_grid_labels[slot].text = label_text
