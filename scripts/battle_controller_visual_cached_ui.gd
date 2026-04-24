extends "res://scripts/battle_controller_visual_ui.gd"

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")

var _last_stage_grid_state: Dictionary = {}

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
