extends "res://scripts/battle_controller_demo_visual_overlay.gd"

# Demo visual runtime placeholder and geometry helpers.

func _refresh_ui() -> void:
	super()
	_refresh_visual_ui()

func _refresh_visual_ui() -> void:
	pass

func _refresh_center_labels() -> void:
	pass

func _refresh_log_strip() -> void:
	pass

func _refresh_character_visuals() -> void:
	pass

func _refresh_hud_bars() -> void:
	pass

func _refresh_stage_grid(force: bool = false) -> void:
	pass

func _refresh_stage_actor_positions(force: bool = false) -> void:
	pass

func _set_actor_foot_highlights_visible(visible: bool) -> void:
	pass

func _refresh_card_detail_panel() -> void:
	pass

func _refresh_hand_buttons() -> void:
	pass

func _process(delta: float) -> void:
	preview_anim_time += delta

func _player_preview_card() -> CardData:
	return null

func _enemy_preview_card() -> CardData:
	return null

func _should_preview_card(card: CardData) -> bool:
	return false

func _grid_total_width() -> float:
	return GRID_SLOT_COUNT * GRID_SLOT_WIDTH + (GRID_SLOT_COUNT - 1) * GRID_SLOT_GAP

func _slot_center_x(slot: int) -> float:
	var left := (size.x - _grid_total_width()) * 0.5
	return left + slot * (GRID_SLOT_WIDTH + GRID_SLOT_GAP) + GRID_SLOT_WIDTH * 0.5

func _slot_center_point(slot: int) -> Vector2:
	return Vector2(_slot_center_x(slot), STAGE_GROUND_Y)

func _actor_foot_offset(sprite: TextureRect, is_player: bool) -> Vector2:
	if sprite != null:
		return BattleActorFootHelper.frame_foot_offset(sprite)
	return Vector2(PLAYER_FOOT_OFFSET_X if is_player else ENEMY_FOOT_OFFSET_X, ACTOR_DISPLAY_SIZE.y)

func _actor_top_left_for_slot(sprite: TextureRect, slot: int, is_player: bool) -> Vector2:
	return _slot_center_point(slot) - _actor_foot_offset(sprite, is_player)

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	var sprite := player_sprite if is_player else enemy_sprite
	return _actor_top_left_for_slot(sprite, slot, is_player)

func _preview_cycle_phase() -> float:
	return fmod(preview_anim_time, PREVIEW_CYCLE_DURATION) / PREVIEW_CYCLE_DURATION

func _preview_frame_for_card(card: CardData, active: bool) -> int:
	return 0

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	return _slot_top_left(start_slot, is_player)

func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	return player_slot if is_player else enemy_slot

func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	return []
