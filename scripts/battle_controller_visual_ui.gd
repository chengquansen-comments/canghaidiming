extends "res://scripts/battle_controller_demo_visual.gd"

# Dedicated visual battle controller entry.
# This keeps the current demo presentation path explicit and separate
# from the pure text debugging entry, while delegating reusable concerns
# to helper scripts under scripts/visual/.

const BattleSkinHelper = preload("res://scripts/visual/battle_skin.gd")
const BattleStageHelper = preload("res://scripts/visual/battle_stage_view.gd")
const BattleHudHelper = preload("res://scripts/visual/battle_hud_view.gd")

func _safe_load_texture(path: String) -> Texture2D:
	return BattleSkinHelper.load_texture_or_svg(path)

func _make_demo_panel_style(fill: Color, border: Color) -> StyleBox:
	return BattleSkinHelper.make_visual_panel_style(fill, border, PANEL_FRAME_PATH)

func _make_button_style(tint: Color) -> StyleBox:
	return BattleSkinHelper.make_button_style(tint, BUTTON_FRAME_PATH, PANEL_FRAME_PATH)

func _grid_total_width() -> float:
	return BattleStageHelper.grid_total_width(GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_center_x(slot: int) -> float:
	return BattleStageHelper.slot_center_x(size.x, slot, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	return BattleStageHelper.slot_top_left(size.x, slot, is_player, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, STAGE_GROUND_Y, player_sprite.size.y, PLAYER_FOOT_OFFSET_X, ENEMY_FOOT_OFFSET_X)

func _current_grid_positions() -> Dictionary:
	var distance := state_machine.current_distance if state_machine != null else 2
	return BattleStageHelper.current_grid_positions(distance, GRID_RIGHT_ANCHOR_SLOT, GRID_SLOT_COUNT)

func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	return BattleStageHelper.target_slot_for_preview(is_player, player_slot, enemy_slot, card, GRID_SLOT_COUNT)

func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	return BattleStageHelper.attack_range_slots(is_player, origin_slot, card, GRID_SLOT_COUNT)

func _preview_cycle_phase() -> float:
	return BattleStageHelper.preview_cycle_phase(preview_anim_time, PREVIEW_CYCLE_DURATION)

func _preview_frame_for_card(card: CardData, active: bool) -> int:
	return BattleStageHelper.preview_frame_for_card(card, active, _preview_cycle_phase())

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	return BattleStageHelper.animated_actor_top_left(size.x, is_player, start_slot, target_slot, active, _preview_cycle_phase(), GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, STAGE_GROUND_Y, player_sprite.size.y, PLAYER_FOOT_OFFSET_X, ENEMY_FOOT_OFFSET_X)

func _ease_preview(value: float) -> float:
	return BattleStageHelper.ease_preview(value)

func _compact_effect_summary(card: CardData) -> String:
	return BattleHudHelper.compact_effect_summary(card)

func _compact_button_text(card: CardData, marker: String, reason: String) -> String:
	var text := BattleHudHelper.compact_button_text(card, _card_role_prefix(card), marker, _draft_uses_card(card))
	if reason != "":
		text += "\n限制：%s" % reason
	return text

func _card_detail_text(card: CardData) -> String:
	return BattleHudHelper.card_detail_text(card)

func _focused_card_for_detail() -> CardData:
	return BattleHudHelper.focused_card(draft_player_intent, player_intent, awaiting_player_input)

func _refresh_card_detail_panel() -> void:
	if card_detail_label == null:
		return
	card_detail_label.add_theme_color_override("default_color", Color("35281c"))
	var focused_card := _focused_card_for_detail()
	if focused_card == null:
		card_detail_label.text = BattleHudHelper.empty_detail_text()
		return
	card_detail_label.text = _card_detail_text(focused_card)

func _refresh_hand_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()
	if player == null:
		return
	for i in range(player.hand.size()):
		var card: CardData = player.hand[i]
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var button := Button.new()
		button.custom_minimum_size = Vector2(188, 112)
		button.text = _compact_button_text(card, marker, reason)
		button.disabled = not awaiting_player_input or not _can_play_card(player, card)
		button.pressed.connect(_on_player_card_pressed.bind(card))
		hand_flow.add_child(button)

	if awaiting_player_input:
		var idle_card := _idle_card()
		var idle_button := Button.new()
		idle_button.custom_minimum_size = Vector2(188, 112)
		idle_button.text = BattleHudHelper.compact_button_text(idle_card, "[势牌]", "", false)
		idle_button.pressed.connect(_on_player_card_pressed.bind(idle_card))
		hand_flow.add_child(idle_button)

func _refresh_stage_grid() -> void:
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
	for i in range(GRID_SLOT_COUNT):
		var fill := GRID_BASE_COLOR
		if player_range.has(i) and enemy_range.has(i):
			fill = RANGE_OVERLAP_COLOR
		elif player_range.has(i):
			fill = PLAYER_RANGE_COLOR
		elif enemy_range.has(i):
			fill = ENEMY_RANGE_COLOR
		if i == player_slot:
			fill = PLAYER_POS_COLOR
		if i == enemy_slot:
			fill = ENEMY_POS_COLOR
		stage_grid_cells[i].add_theme_stylebox_override("panel", _make_grid_cell_style(fill))
		if i == player_slot and i == enemy_slot:
			stage_grid_labels[i].text = "我/敌"
			stage_grid_labels[i].add_theme_color_override("font_color", Color("ffffff"))
		elif i == player_slot:
			stage_grid_labels[i].text = "我"
			stage_grid_labels[i].add_theme_color_override("font_color", Color("eef6ff"))
		elif i == enemy_slot:
			stage_grid_labels[i].text = "敌"
			stage_grid_labels[i].add_theme_color_override("font_color", Color("fff2ef"))
		else:
			stage_grid_labels[i].text = ""

func _refresh_stage_actor_positions() -> void:
	if player_sprite == null or enemy_sprite == null:
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card := _player_preview_card()
	var enemy_card := _enemy_preview_card()
	var player_preview := _should_preview_card(player_card)
	var enemy_preview := _should_preview_card(enemy_card)
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var player_top_left := _animated_actor_top_left(true, player_slot, player_target_slot, player_preview)
	var enemy_top_left := _animated_actor_top_left(false, enemy_slot, enemy_target_slot, enemy_preview)
	player_sprite.position = player_top_left
	enemy_sprite.position = enemy_top_left
	player_fallback_actor.position = player_top_left
	enemy_fallback_actor.position = enemy_top_left
	_set_actor_sheet_frame(player, _preview_frame_for_card(player_card, player_preview))
	_set_actor_sheet_frame(enemy, _preview_frame_for_card(enemy_card, enemy_preview))
