extends "res://scripts/battle_controller_visual_ui_state.gd"

func _safe_load_texture(path: String) -> Texture2D:
	return BattleSkinHelper.load_texture_or_svg(path)

func _make_demo_panel_style(fill: Color, border: Color) -> StyleBox:
	return BattleSkinHelper.make_visual_panel_style(fill, border, PANEL_FRAME_PATH)

func _make_button_style(tint: Color) -> StyleBox:
	return BattleSkinHelper.make_button_style(tint, BUTTON_FRAME_PATH, PANEL_FRAME_PATH)

func _hud_bar_width(bar: Control) -> float:
	if bar == null:
		return HUD_BAR_WIDTH + 40.0
	if bar.size.x > 1.0:
		return bar.size.x
	if bar.custom_minimum_size.x > 1.0:
		return bar.custom_minimum_size.x
	return HUD_BAR_WIDTH + 40.0

func _hud_state_signature() -> String:
	if player == null or enemy == null:
		return "no-session"
	var player_hp_width := int(round(player_hp_bg.size.x)) if player_hp_bg != null else 0
	var enemy_hp_width := int(round(enemy_hp_bg.size.x)) if enemy_hp_bg != null else 0
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		player.hp,
		player.data.max_hp,
		player.momentum,
		player.data.max_momentum,
		player_hp_width,
		enemy.hp,
		enemy.data.max_hp,
		enemy.momentum,
		enemy.data.max_momentum,
		enemy_hp_width
	]

func _grid_total_width() -> float:
	return BattleStageHelper.grid_total_width(GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_center_x(slot: int) -> float:
	return BattleStageHelper.slot_center_x(size.x, slot, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	var sprite := player_sprite if is_player else enemy_sprite
	var foot_offset := BattleActorFootHelper.frame_foot_offset(sprite)
	return BattleStageHelper.slot_top_left(size.x, slot, is_player, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, STAGE_GROUND_Y, foot_offset.y, foot_offset.x, foot_offset.x)

func _current_grid_positions() -> Dictionary:
	return {
		"player": player.position if player != null else 0,
		"enemy": enemy.position if enemy != null else GRID_RIGHT_ANCHOR_SLOT
	}

func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	if is_player:
		return _player_preview_position()
	var intent := _enemy_preview_intent()
	if intent != null and intent.target_position >= 0:
		return intent.target_position
	return enemy_slot

func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	var result: Array[int] = []
	if card == null or not card.requires_hit_check():
		return result
	var facing := _player_preview_facing() if is_player else _enemy_preview_facing()
	var dir := 1 if facing == "right" else -1
	for distance in range(card.min_distance, card.max_distance + 1):
		var slot := origin_slot + dir * distance
		if slot >= 0 and slot < GRID_SLOT_COUNT:
			result.append(slot)
	return result

func _player_preview_position() -> int:
	if player == null:
		return 0
	if draft_player_has_position:
		return draft_player_position
	if draft_player_intent != null and draft_player_intent.target_position >= 0:
		return draft_player_intent.target_position
	return player.position

func _player_preview_facing() -> String:
	if player == null:
		return "right"
	if draft_player_has_position and draft_player_facing != "":
		return draft_player_facing
	if draft_player_intent != null and draft_player_intent.target_facing != "":
		return draft_player_intent.target_facing
	return player.facing

func _enemy_preview_facing() -> String:
	var intent := _enemy_preview_intent()
	if intent != null and intent.target_facing != "":
		return intent.target_facing
	return enemy.facing if enemy != null else "left"

func _preview_cycle_phase() -> float:
	return BattleStageHelper.preview_cycle_phase(preview_anim_time, PREVIEW_CYCLE_DURATION)

func _preview_frame_for_card(card: CardData, active: bool) -> int:
	return BattleStageHelper.preview_frame_for_card(card, active, _preview_cycle_phase())

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	var sprite := player_sprite if is_player else enemy_sprite
	var foot_offset := BattleActorFootHelper.frame_foot_offset(sprite)
	return BattleStageHelper.animated_actor_top_left(size.x, is_player, start_slot, target_slot, active, _preview_cycle_phase(), GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, STAGE_GROUND_Y, foot_offset.y, foot_offset.x, foot_offset.x)

func _ease_preview(value: float) -> float:
	return BattleStageHelper.ease_preview(value)

func _preview_damage(card: CardData, target: Fighter, hits_target: bool) -> int:
	if card == null or not hits_target or card.damage <= 0:
		return 0
	var amount := card.damage
	if target != null and target.is_broken():
		amount *= 2
	if target != null:
		amount = maxi(amount - target.guard_points, 0)
	return amount

func _preview_damage_for_result(card: CardData, target: Fighter, range_result: String) -> int:
	if card == null or card.damage <= 0:
		return 0
	var is_effective_hit := range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)
	if not is_effective_hit:
		return 0
	var amount := card.damage
	if CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE:
		amount = maxi(ceili(float(amount) * 0.5), 1)
	if target != null and target.is_broken():
		amount *= 2
	if target != null:
		amount = maxi(amount - target.guard_points, 0)
	return amount

func _preview_break_for_result(card: CardData, range_result: String) -> int:
	if card == null:
		return 0
	var is_effective_hit := range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)
	if not is_effective_hit:
		return 0
	if CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE:
		return maxi(card.break_momentum - 1, 0)
	return card.break_momentum

func _preview_range_result(card: CardData, actor_position: int, actor_facing: String, target_position: int) -> String:
	return CombatResolver.evaluate_range(card, actor_position, actor_facing, target_position)

func _preview_faces_target(actor_position: int, actor_facing: String, target_position: int) -> bool:
	if actor_position == target_position:
		return true
	if target_position > actor_position:
		return actor_facing == "right"
	return actor_facing == "left"

func _range_result_text(result: String) -> String:
	match result:
		BattleStateMachine.RANGE_HIT:
			return "命中"
		BattleStateMachine.RANGE_GRAZE:
			return "擦中" if CombatResolver.ENABLE_GRAZE else "距离未中"
		BattleStateMachine.RANGE_MISS_FACING:
			return "朝向错误"
		BattleStateMachine.RANGE_MISS_RANGE:
			return "距离落空"
	return "无"

func _facing_label(value: String) -> String:
	return "左" if value == "left" else "右"

func _slot_label(slot: int) -> String:
	if slot >= 0 and slot < SLOT_LABELS.size():
		return SLOT_LABELS[slot]
	return "未知"

func _slot_list_text(slots: Array[int]) -> String:
	if slots.is_empty():
		return "无"
	var parts: Array[String] = []
	for slot in slots:
		parts.append(_slot_label(slot))
	return " / ".join(parts)

func _player_preview_card() -> CardData:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	if player_intent != null and player_intent.actual_card != null and state_machine != null and state_machine.phase == BattleStateMachine.BattlePhase.DECLARE:
		return player_intent.actual_card
	return null

func _enemy_preview_card() -> CardData:
	return _visible_card_for_intent(_enemy_preview_intent(), player)

func _enemy_preview_intent() -> IntentData:
	if enemy_intent != null:
		return enemy_intent
	if not battle_active or state_machine == null or state_machine.phase != BattleStateMachine.BattlePhase.DECLARE:
		return null
	if enemy_ai == null or enemy == null or player == null:
		return null
	var seen_intent := draft_player_intent if draft_player_intent != null else player_intent
	return enemy_ai.choose_intent(enemy, player, state_machine.current_distance, seen_intent)

func _visible_card_for_intent(intent: IntentData, viewer: Fighter) -> CardData:
	if intent == null:
		return null
	if intent.is_hidden() and viewer != null and not intent.can_hidden_be_read(viewer):
		return intent.visible_card
	return intent.actual_card

func _should_preview_card(card: CardData) -> bool:
	return battle_active and card != null and state_machine != null and state_machine.phase == BattleStateMachine.BattlePhase.DECLARE

func _visual_actor_role_id_for(fighter: Fighter) -> String:
	if fighter == null or fighter.data == null:
		return ""
	var role_id: String = str(fighter.data.id)
	var weapon_text: String = str(fighter.data.weapon_name)
	if role_id == "master_veteran":
		return role_id
	if role_id == "player_spearman" or role_id.findn("spear") >= 0 or weapon_text.findn("spear") >= 0 or weapon_text.find("枪") >= 0:
		return "spearman"
	if role_id == "player_blademaster" or role_id.findn("blade") >= 0 or weapon_text.findn("blade") >= 0 or weapon_text.find("刀") >= 0:
		return "blademaster"
	return role_id

func _sheet_source_for(fighter: Fighter, is_enemy: bool) -> Texture2D:
	if fighter == null:
		return null
	var prefix := "enemy_" if is_enemy else ""
	var role := fighter.data.id
	var texture := _safe_load_texture("res://assets/pixel_battle/sheets/%s%s_sheet.png" % [prefix, role])
	if texture != null:
		return texture
	var visual_role: String = _visual_actor_role_id_for(fighter)
	if visual_role != role:
		texture = _safe_load_texture("res://assets/pixel_battle/sheets/%s%s_sheet.png" % [prefix, visual_role])
		if texture != null:
			return texture
	return null

func _sheet_frame_texture(source: Texture2D, frame_index: int) -> Texture2D:
	if source == null:
		return null
	var frame_size := Vector2i(maxi(source.get_width(), 1), maxi(source.get_height() / SHEET_FRAME_COUNT, 1))
	if source.get_height() < source.get_width():
		frame_size = Vector2i(maxi(source.get_width() / SHEET_FRAME_COUNT, 1), maxi(source.get_height(), 1))
	var layout := "vertical" if source.get_height() >= frame_size.y * SHEET_FRAME_COUNT else "horizontal"
	return BattleSkinHelper.atlas_frame(source, frame_size, clampi(frame_index, 0, SHEET_FRAME_COUNT - 1), layout)

func _portrait_texture_for(fighter: Fighter) -> Texture2D:
	if fighter == null:
		return null
	var fighter_id := str(fighter.data.id)
	if ENEMY_PORTRAIT_OVERRIDES.has(fighter_id):
		var portrait_base := str(ENEMY_PORTRAIT_OVERRIDES[fighter_id])
		var overridden := _safe_load_texture("res://assets/pixel_battle/portraits/%s.png" % portrait_base)
		if overridden != null:
			return overridden
		overridden = _safe_load_texture("res://assets/pixel_battle/portraits/%s_portrait.png" % portrait_base)
		if overridden != null:
			return overridden
		overridden = _safe_load_texture("res://assets/pixel_battle/portraits/%s_bust.png" % portrait_base)
		if overridden != null:
			return overridden
	var texture := _safe_load_texture("res://assets/pixel_battle/portraits/%s_portrait.png" % fighter_id)
	if texture != null:
		return texture
	texture = _safe_load_texture("res://assets/pixel_battle/portraits/%s_bust.png" % fighter_id)
	if texture != null:
		return texture
	var visual_role: String = _visual_actor_role_id_for(fighter)
	if visual_role != fighter_id:
		texture = _safe_load_texture("res://assets/pixel_battle/portraits/%s_portrait.png" % visual_role)
		if texture != null:
			return texture
		return _safe_load_texture("res://assets/pixel_battle/portraits/%s_bust.png" % visual_role)
	return null

func _actor_control_faces_left(sprite: Control) -> bool:
	if sprite == null:
		return false
	if sprite is TextureRect:
		return (sprite as TextureRect).flip_h
	return sprite.scale.x < 0.0

func _actor_fx_anchor(target_is_enemy: bool) -> Vector2:
	var sprite := enemy_sprite if target_is_enemy else player_sprite
	if sprite != null:
		return sprite.position + sprite.size * 0.5
	var fallback := enemy_fallback_actor if target_is_enemy else player_fallback_actor
	if fallback != null:
		return fallback.position + fallback.custom_minimum_size * 0.5
	return size * 0.5
