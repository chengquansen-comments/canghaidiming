extends "res://scripts/battle_controller_visual_ui.gd"

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

func _intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	return BattleHudHelper.intent_bubble_text(card, actor_slot, opponent_slot, target_slot)

func _effect_preview_text() -> String:
	return BattleHudHelper.effect_preview_text(_effect_preview_context())

func _effect_preview_context() -> Dictionary:
	if player == null or enemy == null or state_machine == null:
		return {"has_data": false}
	var positions: Dictionary = _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card: CardData = _player_preview_card()
	var enemy_card: CardData = _enemy_preview_card()
	var preview_card: CardData = player_card
	var uses_wait: bool = false
	if preview_card == null:
		preview_card = _preview_wait_card()
		uses_wait = true
	var player_target: int = _target_slot_for_preview(true, player_slot, enemy_slot, preview_card)
	var enemy_target_for_preview: int = _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var player_range: Array[int] = _attack_range_slots(true, player_target, preview_card)
	var hits_enemy: bool = player_range.has(enemy_target_for_preview)
	var enemy_range: Array[int] = []
	var enemy_hits_player: bool = false
	var enemy_damage: int = 0
	var enemy_target: int = enemy_target_for_preview
	if enemy_card != null:
		enemy_range = _attack_range_slots(false, enemy_target, enemy_card)
		enemy_hits_player = enemy_range.has(player_target)
		enemy_damage = _preview_damage(enemy_card, player, enemy_hits_player)
	var input: Dictionary = {
		"has_data": true,
		"preview_card": preview_card,
		"enemy_card": enemy_card,
		"current_card_name": "未选招，按不动预览" if uses_wait else preview_card.display_name,
		"distance": state_machine.current_distance,
		"player_slot_label": _slot_label(player_slot),
		"player_target_label": _slot_label(player_target),
		"player_range_text": _slot_list_text(player_range),
		"hits_enemy": hits_enemy,
		"player_damage": _preview_damage(preview_card, enemy, hits_enemy),
		"player_momentum": player.momentum,
		"player_max_momentum": player.data.max_momentum,
		"enemy_momentum": enemy.momentum,
		"enemy_max_momentum": enemy.data.max_momentum,
		"enemy_hp": enemy.hp,
		"enemy_max_hp": enemy.data.max_hp,
		"player_hp": player.hp,
		"player_max_hp": player.data.max_hp,
		"enemy_hits_player": enemy_hits_player,
		"enemy_damage": enemy_damage
	}
	if enemy_card != null:
		input["enemy_slot_label"] = _slot_label(enemy_slot)
		input["enemy_target_label"] = _slot_label(enemy_target)
		input["enemy_range_text"] = _slot_list_text(enemy_range)
	return BattleHudHelper.build_effect_preview_context(input)

func _clear_range_trapezoids() -> void:
	_recycle_range_overlay_nodes()

func _refresh_range_trapezoids(player_range: Array[int], player_origin_slot: int, enemy_range: Array[int], enemy_origin_slot: int) -> void:
	if range_overlay_layer == null:
		return
	_recycle_range_overlay_nodes()
	var player_style: Dictionary = BattleStageHelper.range_overlay_style(true)
	for slot in player_range:
		_draw_range_trapezoid(slot, player_origin_slot, int(player_style.get("polygon_z", 2)), player_style.get("fill_color", Color(1, 1, 1, 0.2)) as Color, player_style.get("outline_color", Color(1, 1, 1, 0.7)) as Color)
	var enemy_style: Dictionary = BattleStageHelper.range_overlay_style(false)
	for slot in enemy_range:
		_draw_range_trapezoid(slot, enemy_origin_slot, int(enemy_style.get("polygon_z", 2)), enemy_style.get("fill_color", Color(1, 1, 1, 0.2)) as Color, enemy_style.get("outline_color", Color(1, 1, 1, 0.7)) as Color)

func _draw_range_trapezoid(slot: int, origin_slot: int, z_index: int, fill_color: Color, outline_color: Color) -> void:
	if range_overlay_layer == null:
		return
	var points: PackedVector2Array = _range_trapezoid_points(slot, origin_slot)
	var polygon: Polygon2D = _take_range_polygon()
	polygon.polygon = points
	polygon.color = fill_color
	polygon.z_index = z_index
	polygon.visible = true
	_active_range_polygons.append(polygon)
	var outline: Line2D = _take_range_line()
	outline.points = points
	outline.closed = true
	outline.width = 3.0
	outline.default_color = outline_color
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.z_index = z_index + 1
	outline.visible = true
	_active_range_lines.append(outline)

func _take_range_polygon() -> Polygon2D:
	if not _range_polygon_pool.is_empty():
		return _range_polygon_pool.pop_back()
	var polygon: Polygon2D = Polygon2D.new()
	range_overlay_layer.add_child(polygon)
	return polygon

func _take_range_line() -> Line2D:
	if not _range_line_pool.is_empty():
		return _range_line_pool.pop_back()
	var line: Line2D = Line2D.new()
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
		var slot_state: Dictionary = BattleStageHelper.build_slot_state(i, player_target_slot, enemy_target_slot, player_range, enemy_range, GRID_BASE_COLOR, PLAYER_POS_COLOR, ENEMY_POS_COLOR)
		var fill: Color = slot_state.get("fill", GRID_BASE_COLOR) as Color
		var label_text: String = slot_state.get("label", "") as String
		var has_player: bool = slot_state.get("has_player", false) as bool
		var has_enemy: bool = slot_state.get("has_enemy", false) as bool
		var state_key: String = "%s|%s|%s|%s" % [fill.to_html(), label_text, str(has_player), str(has_enemy)]
		next_state[i] = {"key": state_key}
		if not _last_stage_grid_state.has(i) or (_last_stage_grid_state[i] as Dictionary).get("key", "") != state_key:
			_apply_stage_grid_slot(i, fill, has_player, has_enemy, label_text)
	_last_stage_grid_state = next_state

func _apply_stage_grid_slot(slot: int, fill: Color, has_player: bool, has_enemy: bool, label_text: String) -> void:
	if slot < 0 or slot >= stage_grid_cells.size() or slot >= stage_grid_labels.size():
		return
	stage_grid_cells[slot].add_theme_stylebox_override("panel", _make_grid_cell_style(fill, slot, has_player, has_enemy, false, false))
	stage_grid_labels[slot].text = label_text
