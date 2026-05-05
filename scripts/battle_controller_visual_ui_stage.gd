extends "res://scripts/battle_controller_visual_ui_cards.gd"

func _clear_range_trapezoids() -> void:
	_stage_grid_signature = ""
	if range_overlay_layer == null:
		return
	for entry in _range_trapezoid_pool:
		var polygon: Polygon2D = entry.get("polygon", null)
		var outline: Line2D = entry.get("outline", null)
		if polygon != null:
			polygon.visible = false
		if outline != null:
			outline.visible = false

func _refresh_stage_grid(force: bool = false) -> void:
	if stage_grid_cells.is_empty():
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_preview_card := _player_preview_card()
	var enemy_preview_card := _enemy_preview_card()
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_preview_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_preview_card)
	var player_range := _attack_range_slots(true, player_target_slot, player_preview_card)
	var enemy_range := _attack_range_slots(false, enemy_target_slot, enemy_preview_card)
	var signature := _stage_grid_state_signature(player_target_slot, enemy_target_slot, player_range, enemy_range, player_preview_card, enemy_preview_card)
	if not force and signature == _stage_grid_signature:
		return
	_stage_grid_signature = signature
	_refresh_range_trapezoids(player_range, player_target_slot, enemy_range, enemy_target_slot)
	for i in range(GRID_SLOT_COUNT):
		var in_player_range := player_range.has(i)
		var in_enemy_range := enemy_range.has(i)
		var has_player := i == player_target_slot
		var has_enemy := i == enemy_target_slot
		var fill := GRID_BASE_COLOR
		if has_player:
			fill = GRID_BASE_COLOR
		if has_enemy:
			fill = GRID_BASE_COLOR
		stage_grid_cells[i].add_theme_stylebox_override("panel", _make_grid_cell_style(fill, i, false, false, false, false))
		if (has_enemy and in_player_range) or (has_player and in_enemy_range):
			stage_grid_labels[i].text = "×"
		elif in_player_range or in_enemy_range:
			stage_grid_labels[i].text = "·"
		else:
			stage_grid_labels[i].text = ""
	_refresh_actor_foot_highlights(player_target_slot, enemy_target_slot)

func _stage_grid_state_signature(
	player_target_slot: int,
	enemy_target_slot: int,
	player_range: Array[int],
	enemy_range: Array[int],
	player_preview_card: CardData,
	enemy_preview_card: CardData
) -> String:
	var player_card_id := player_preview_card.id if player_preview_card != null else "-"
	var enemy_card_id := enemy_preview_card.id if enemy_preview_card != null else "-"
	return "%d|%d|%s|%s|%s|%s|%d" % [
		player_target_slot,
		enemy_target_slot,
		_slot_array_key(player_range),
		_slot_array_key(enemy_range),
		player_card_id,
		enemy_card_id,
		int(round(size.x))
	]

func _slot_array_key(slots: Array[int]) -> String:
	var parts: Array[String] = []
	for slot in slots:
		parts.append(str(slot))
	return ",".join(parts)

func _refresh_range_trapezoids(player_range: Array[int], player_origin_slot: int, enemy_range: Array[int], enemy_origin_slot: int) -> void:
	if range_overlay_layer == null:
		return
	var used_count := 0
	for slot in player_range:
		_draw_range_trapezoid(used_count, slot, player_origin_slot, Color(0.25, 0.62, 1.0, 0.24), Color(0.62, 0.86, 1.0, 0.78))
		used_count += 1
	for slot in enemy_range:
		_draw_range_trapezoid(used_count, slot, enemy_origin_slot, Color(1.0, 0.32, 0.22, 0.23), Color(1.0, 0.67, 0.52, 0.78))
		used_count += 1
	for i in range(used_count, _range_trapezoid_pool.size()):
		var entry := _range_trapezoid_pool[i]
		var polygon: Polygon2D = entry.get("polygon", null)
		var outline: Line2D = entry.get("outline", null)
		if polygon != null:
			polygon.visible = false
		if outline != null:
			outline.visible = false

func _draw_range_trapezoid(pool_index: int, slot: int, origin_slot: int, fill_color: Color, outline_color: Color) -> void:
	if range_overlay_layer == null:
		return
	var entry := _range_trapezoid_entry(pool_index)
	var polygon: Polygon2D = entry.get("polygon", null)
	var outline: Line2D = entry.get("outline", null)
	if polygon == null or outline == null:
		return
	polygon.polygon = _range_trapezoid_points(slot, origin_slot)
	polygon.color = fill_color
	polygon.z_index = 2
	polygon.visible = true
	outline.points = polygon.polygon
	outline.closed = true
	outline.width = 3.0
	outline.default_color = outline_color
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.z_index = 3
	outline.visible = true

func _range_trapezoid_entry(pool_index: int) -> Dictionary:
	while _range_trapezoid_pool.size() <= pool_index:
		var polygon := Polygon2D.new()
		polygon.visible = false
		polygon.z_index = 2
		range_overlay_layer.add_child(polygon)
		var outline := Line2D.new()
		outline.visible = false
		outline.closed = true
		outline.width = 3.0
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		outline.z_index = 3
		range_overlay_layer.add_child(outline)
		_range_trapezoid_pool.append({"polygon": polygon, "outline": outline})
	return _range_trapezoid_pool[pool_index]

func _range_trapezoid_points(slot: int, origin_slot: int) -> PackedVector2Array:
	var center_x := _highlight_center_x(slot)
	var left := center_x - GRID_SLOT_WIDTH * 0.5
	var right := center_x + GRID_SLOT_WIDTH * 0.5
	var top_y := GRID_STAGE_Y - 18.0
	var bottom_y := GRID_STAGE_Y + GRID_SLOT_HEIGHT + 8.0
	var short_side_y_inset := 15.0
	var long_outset := 10.0
	if origin_slot <= slot:
		return PackedVector2Array([
			Vector2(left, top_y + short_side_y_inset),
			Vector2(right + long_outset, top_y),
			Vector2(right + long_outset, bottom_y),
			Vector2(left, bottom_y - short_side_y_inset)
		])
	return PackedVector2Array([
		Vector2(left - long_outset, top_y),
		Vector2(right, top_y + short_side_y_inset),
		Vector2(right, bottom_y - short_side_y_inset),
		Vector2(left - long_outset, bottom_y)
	])

func _highlight_center_x(slot: int) -> float:
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, _player_preview_card())
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, _enemy_preview_card())
	if slot == player_target_slot and player_sprite != null:
		return _actor_slot_foot_point(true, slot).x
	if slot == enemy_target_slot and enemy_sprite != null:
		return _actor_slot_foot_point(false, slot).x
	return _slot_center_x(slot)

func _actor_slot_foot_point(is_player: bool, slot: int) -> Vector2:
	var sprite := player_sprite if is_player else enemy_sprite
	if sprite == null:
		return Vector2(_slot_center_x(slot), STAGE_GROUND_Y)
	return _slot_top_left(slot, is_player) + BattleActorFootHelper.frame_foot_offset(sprite)

func _refresh_actor_foot_highlights(player_target_slot: int, enemy_target_slot: int) -> void:
	_position_actor_foot_highlight(true, player_target_slot)
	_position_actor_foot_highlight(false, enemy_target_slot)

func _position_actor_foot_highlight(is_player: bool, slot: int) -> void:
	var highlight := _actor_foot_highlight(is_player)
	if highlight == null:
		return
	var center := _actor_slot_foot_point(is_player, slot)
	highlight.position = Vector2(center.x - GRID_SLOT_WIDTH * 0.5, GRID_STAGE_Y)
	highlight.size = Vector2(GRID_SLOT_WIDTH, GRID_SLOT_HEIGHT)
	highlight.visible = battle_active
	var style := _make_grid_cell_style(PLAYER_POS_COLOR if is_player else ENEMY_POS_COLOR, slot, false, false, false, false)
	style.border_color = GRID_PLAYER_BORDER_COLOR if is_player else GRID_ENEMY_BORDER_COLOR
	style.set_border_width_all(3)
	highlight.add_theme_stylebox_override("panel", style)

func _actor_foot_highlight(is_player: bool) -> PanelContainer:
	if stage_layer == null:
		return null
	if is_player and _player_foot_grid_highlight != null:
		return _player_foot_grid_highlight
	if not is_player and _enemy_foot_grid_highlight != null:
		return _enemy_foot_grid_highlight
	var highlight := PanelContainer.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = 7
	highlight.custom_minimum_size = Vector2(GRID_SLOT_WIDTH, GRID_SLOT_HEIGHT)
	stage_layer.add_child(highlight)
	if is_player:
		_player_foot_grid_highlight = highlight
	else:
		_enemy_foot_grid_highlight = highlight
	return highlight

func _set_actor_foot_highlights_visible(visible: bool) -> void:
	if _player_foot_grid_highlight != null:
		_player_foot_grid_highlight.visible = visible
	if _enemy_foot_grid_highlight != null:
		_enemy_foot_grid_highlight.visible = visible

func _refresh_stage_actor_positions(force: bool = false) -> void:
	if player_sprite == null or enemy_sprite == null:
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card := _player_preview_card()
	var enemy_card := _enemy_preview_card()
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var signature := _stage_actor_state_signature(player_target_slot, enemy_target_slot, player_card, enemy_card)
	if not force and signature == _stage_actor_signature:
		return
	_stage_actor_signature = signature

	# Static stance must be laid out from the current frame-0 foot anchor.
	# Set frame/anchor first, then facing, then calculate top-left from the live foot offset.
	_set_actor_sheet_frame(player, 0)
	_set_actor_sheet_frame(enemy, 0)
	_set_texture_actor_facing(player_sprite, _player_preview_facing() == "left")
	_set_texture_actor_facing(enemy_sprite, _enemy_preview_facing() == "left")
	var player_top_left := _slot_top_left(player_target_slot, true)
	var enemy_top_left := _slot_top_left(enemy_target_slot, false)
	player_sprite.position = player_top_left
	enemy_sprite.position = enemy_top_left
	player_fallback_actor.position = player_top_left
	enemy_fallback_actor.position = enemy_top_left
	_apply_actor_facing(player_target_slot, enemy_target_slot, player_top_left, enemy_top_left)

func _stage_actor_state_signature(player_target_slot: int, enemy_target_slot: int, player_card: CardData, enemy_card: CardData) -> String:
	var player_card_id := player_card.id if player_card != null else "-"
	var enemy_card_id := enemy_card.id if enemy_card != null else "-"
	var player_role := player.data.id if player != null else "-"
	var enemy_role := enemy.data.id if enemy != null else "-"
	var player_foot := BattleActorFootHelper.frame_foot_offset(player_sprite) if player_sprite != null else Vector2.ZERO
	var enemy_foot := BattleActorFootHelper.frame_foot_offset(enemy_sprite) if enemy_sprite != null else Vector2.ZERO
	return "%d|%d|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s" % [
		player_target_slot,
		enemy_target_slot,
		player_card_id,
		enemy_card_id,
		player_role,
		enemy_role,
		int(round(size.x)),
		int(round(player_sprite.size.x)),
		int(round(player_sprite.size.y)),
		int(round(enemy_sprite.size.x)),
		int(round(enemy_sprite.size.y)),
		int(round(player_foot.x)),
		int(round(player_foot.y)),
		int(round(enemy_foot.x)),
		int(round(enemy_foot.y)),
		_player_preview_facing(),
		_enemy_preview_facing()
	]

func _apply_actor_facing(player_slot: int, enemy_slot: int, player_top_left: Vector2, enemy_top_left: Vector2) -> void:
	# 当前素材默认朝右；按本回合选择的朝向翻转。
	var player_faces_left := _player_preview_facing() == "left"
	var enemy_faces_left := _enemy_preview_facing() == "left"
	_set_texture_actor_facing(player_sprite, player_faces_left)
	_set_texture_actor_facing(enemy_sprite, enemy_faces_left)
	_set_fallback_actor_facing(player_fallback_actor, player_faces_left, player_top_left)
	_set_fallback_actor_facing(enemy_fallback_actor, enemy_faces_left, enemy_top_left)

func _set_texture_actor_facing(sprite: TextureRect, faces_left: bool) -> void:
	if sprite == null:
		return
	sprite.flip_h = BattleActorFootHelper.flip_h_for_facing(sprite, faces_left)

func _set_fallback_actor_facing(actor: Control, faces_left: bool, top_left: Vector2) -> void:
	if actor == null:
		return
	var fallback_scale := ACTOR_DISPLAY_SIZE.x / ACTOR_FALLBACK_BASE_SIZE
	actor.scale = Vector2(-fallback_scale if faces_left else fallback_scale, fallback_scale)
	actor.position = top_left + (Vector2(ACTOR_DISPLAY_SIZE.x, 0.0) if faces_left else Vector2.ZERO)

func _set_actor_sheet_frame(actor: Fighter, frame_index: int) -> void:
	if actor == null:
		return
	if actor == player and player_sprite != null and player_sheet_source != null:
		player_sprite.texture = _sheet_frame_texture(player_sheet_source, frame_index)
		_apply_actor_anchor_meta(true, actor, frame_index)
		return
	if actor == enemy and enemy_sprite != null and enemy_sheet_source != null:
		enemy_sprite.texture = _sheet_frame_texture(enemy_sheet_source, frame_index)
		_apply_actor_anchor_meta(false, actor, frame_index)
