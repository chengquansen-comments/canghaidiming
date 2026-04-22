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

func _refresh_ui() -> void:
	super()
	_refresh_visual_ui()

func _refresh_visual_ui() -> void:
	_refresh_character_visuals()
	_refresh_hud_bars()
	_refresh_center_labels()
	_refresh_stage_grid()
	_refresh_stage_actor_positions()
	_refresh_card_detail_panel()
	_refresh_log_strip()
	_apply_button_styles()

func _refresh_center_labels() -> void:
	if round_label != null:
		round_label.text = "演武 %d｜距离 %d" % [battle_count, state_machine.current_distance]
	if phase_label != null:
		if battle_active:
			phase_label.text = "回合 %d｜%s" % [state_machine.round_index, state_machine.pressure_state_text(player, enemy)]
		else:
			phase_label.text = "节点阶段：查看牌库 / 合成藏招 / 得招 / 点化 / 演武"

func _refresh_log_strip() -> void:
	if battle_log_strip == null:
		return
	var logs := _recent_logs()
	if logs.is_empty():
		battle_log_strip.text = "日志待命"
	else:
		battle_log_strip.text = logs[logs.size() - 1].replace("[b]", "").replace("[/b]", "")

func _refresh_character_visuals() -> void:
	player_sheet_source = _sheet_source_for(player, false)
	enemy_sheet_source = _sheet_source_for(enemy, true)
	var player_sheet := _sheet_frame_texture(player_sheet_source, 0)
	var enemy_sheet := _sheet_frame_texture(enemy_sheet_source, 0)
	if player_sprite != null:
		player_sprite.texture = player_sheet
	if enemy_sprite != null:
		enemy_sprite.texture = enemy_sheet
	if player_fallback_actor != null:
		player_fallback_actor.visible = player_sheet == null
	if enemy_fallback_actor != null:
		enemy_fallback_actor.visible = enemy_sheet == null
	var player_portrait := _portrait_texture_for(player)
	var enemy_portrait := _portrait_texture_for(enemy)
	if player_avatar != null:
		player_avatar.texture = player_portrait
	if enemy_avatar != null:
		enemy_avatar.texture = enemy_portrait
	if player_avatar_fallback != null:
		player_avatar_fallback.visible = player_portrait == null
	if enemy_avatar_fallback != null:
		enemy_avatar_fallback.visible = enemy_portrait == null
	if player_name_label != null:
		player_name_label.text = player.data.display_name if player != null else "玩家"
	if enemy_name_label != null:
		enemy_name_label.text = enemy.data.display_name if enemy != null else "敌方"

func _refresh_hud_bars() -> void:
	if player != null and player_hp_fill != null and player_hp_bg != null:
		var player_hp_width := player_hp_bg.size.x if player_hp_bg.size.x > 1.0 else HUD_BAR_WIDTH
		player_hp_fill.size = Vector2(player_hp_width * clamp(float(player.hp) / max(1.0, float(player.data.max_hp)), 0.0, 1.0), player_hp_bg.size.y if player_hp_bg.size.y > 0.0 else 14.0)
		if player_hp_value_label != null:
			player_hp_value_label.text = "%d / %d" % [player.hp, player.data.max_hp]
	if player != null and player_momentum_fill != null and player_momentum_bg != null:
		var player_momentum_width := player_momentum_bg.size.x if player_momentum_bg.size.x > 1.0 else HUD_BAR_WIDTH
		player_momentum_fill.size = Vector2(player_momentum_width * clamp(float(player.momentum) / max(1.0, float(player.data.max_momentum)), 0.0, 1.0), player_momentum_bg.size.y if player_momentum_bg.size.y > 0.0 else 10.0)
	if enemy != null and enemy_hp_fill != null and enemy_hp_bg != null:
		var enemy_hp_width := enemy_hp_bg.size.x if enemy_hp_bg.size.x > 1.0 else HUD_BAR_WIDTH
		enemy_hp_fill.size = Vector2(enemy_hp_width * clamp(float(enemy.hp) / max(1.0, float(enemy.data.max_hp)), 0.0, 1.0), enemy_hp_bg.size.y if enemy_hp_bg.size.y > 0.0 else 14.0)
		if enemy_hp_value_label != null:
			enemy_hp_value_label.text = "%d / %d" % [enemy.hp, enemy.data.max_hp]
	if enemy != null and enemy_momentum_fill != null and enemy_momentum_bg != null:
		var enemy_momentum_width := enemy_momentum_bg.size.x if enemy_momentum_bg.size.x > 1.0 else HUD_BAR_WIDTH
		enemy_momentum_fill.size = Vector2(enemy_momentum_width * clamp(float(enemy.momentum) / max(1.0, float(enemy.data.max_momentum)), 0.0, 1.0), enemy_momentum_bg.size.y if enemy_momentum_bg.size.y > 0.0 else 10.0)

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

func _process(delta: float) -> void:
	preview_anim_time += delta
	if battle_active:
		_refresh_stage_grid()
		_refresh_stage_actor_positions()

func _player_preview_card() -> CardData:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	return null

func _enemy_preview_card() -> CardData:
	if enemy_intent == null:
		return null
	if enemy_intent.is_hidden() and player != null and not enemy_intent.can_hidden_be_read(player):
		return enemy_intent.visible_card
	return enemy_intent.actual_card

func _should_preview_card(card: CardData) -> bool:
	return battle_active and card != null and state_machine != null and state_machine.phase == BattleStateMachine.BattlePhase.DECLARE

func _sheet_source_for(fighter: Fighter, is_enemy: bool) -> Texture2D:
	if fighter == null:
		return null
	var prefix := "enemy_" if is_enemy else ""
	var role := fighter.data.id
	return _safe_load_texture("res://assets/pixel_battle/sheets/%s%s_sheet.png" % [prefix, role])

func _sheet_frame_texture(source: Texture2D, frame_index: int) -> Texture2D:
	if source == null:
		return null
	var frame_width := maxi(source.get_width() / SHEET_FRAME_COUNT, 1)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(frame_width * clampi(frame_index, 0, SHEET_FRAME_COUNT - 1), 0, frame_width, source.get_height())
	return atlas

func _portrait_texture_for(fighter: Fighter) -> Texture2D:
	if fighter == null:
		return null
	return _safe_load_texture("res://assets/pixel_battle/portraits/%s_portrait.png" % fighter.data.id)

func _set_actor_sheet_frame(actor: Fighter, frame_index: int) -> void:
	if actor == null:
		return
	if player != null and actor.data.id == player.data.id and player_sprite != null and player_sheet_source != null:
		player_sprite.texture = _sheet_frame_texture(player_sheet_source, frame_index)
		return
	if enemy != null and actor.data.id == enemy.data.id and enemy_sprite != null and enemy_sheet_source != null:
		enemy_sprite.texture = _sheet_frame_texture(enemy_sheet_source, frame_index)

func _pulse_actor_sheet_frame(actor: Fighter, frame_index: int, duration: float = 0.14) -> void:
	_set_actor_sheet_frame(actor, frame_index)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		_set_actor_sheet_frame(actor, 0)
	)

func _animate_attacker_sprite(actor: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	var sprite := player_fallback_actor if actor != null and player != null and actor.data.id == player.data.id and player_fallback_actor != null and player_fallback_actor.visible else enemy_fallback_actor if actor != null and enemy != null and actor.data.id == enemy.data.id and enemy_fallback_actor != null and enemy_fallback_actor.visible else player_sprite if actor != null and player != null and actor.data.id == player.data.id else enemy_sprite
	if sprite == null:
		return
	_pulse_actor_sheet_frame(actor, 1, 0.16 if is_finisher else 0.12)
	var start := sprite.position
	var dir := 1.0 if sprite == player_sprite or sprite == player_fallback_actor else -1.0
	var tween := create_tween()
	if profession_id == "spearman":
		tween.tween_property(sprite, "position", start + Vector2((28 if not is_finisher else 40) * dir, 0), 0.04)
		tween.tween_property(sprite, "position", start, 0.06)
	else:
		tween.tween_property(sprite, "position", start + Vector2((20 if not is_finisher else 30) * dir, -10), 0.04)
		tween.tween_property(sprite, "position", start, 0.07)

func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines := super._resolve_combo_chain_if_any(actor, target, intent)
	if actor != null and intent != null and intent.actual_card != null and intent.actual_card.id != "staggered":
		var is_finisher := intent.actual_card.has_tag("终结")
		_animate_attacker_sprite(actor, actor.data.id, is_finisher)
	return lines

func _spawn_fx_texture(path: String, draw_size: Vector2, at_position: Vector2, tint: Color, rotation_deg: float = 0.0, start_scale: Vector2 = Vector2.ONE) -> TextureRect:
	var texture := _safe_load_texture(path)
	if texture == null:
		return null
	var fx := TextureRect.new()
	fx.texture = texture
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.custom_minimum_size = draw_size
	fx.size = draw_size
	fx.position = at_position - draw_size * 0.5
	fx.rotation_degrees = rotation_deg
	fx.scale = start_scale
	fx.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	if center_fx_layer != null:
		center_fx_layer.add_child(fx)
	else:
		add_child(fx)
	return fx

func _actor_fx_anchor(target_is_enemy: bool) -> Vector2:
	var sprite := enemy_sprite if target_is_enemy else player_sprite
	if sprite != null:
		return sprite.position + sprite.size * 0.5
	var fallback := enemy_fallback_actor if target_is_enemy else player_fallback_actor
	if fallback != null:
		return fallback.position + fallback.custom_minimum_size * 0.5
	return size * 0.5

func _show_pierce_line(color: Color, is_finisher: bool = false) -> void:
	var fx := _spawn_fx_texture(
		"res://assets/pixel_battle/fx/pierce_streak.png",
		Vector2(320 if not is_finisher else 380, 72 if not is_finisher else 88),
		Vector2(size.x * 0.5, size.y * 0.5),
		color,
		0.0,
		Vector2(0.78, 1.0)
	)
	if fx == null:
		super(color, is_finisher)
		return
	var start_pos := fx.position + Vector2(-220 if not is_finisher else -280, 0)
	var end_pos := fx.position + Vector2(220 if not is_finisher else 280, 0)
	fx.position = start_pos
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.96), 0.03)
	tween.parallel().tween_property(fx, "position", end_pos, 0.09 if not is_finisher else 0.12)
	tween.parallel().tween_property(fx, "scale", Vector2(1.08 if not is_finisher else 1.22, 1.0 if not is_finisher else 1.16), 0.06)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.09)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_slash_cut(color: Color, is_finisher: bool = false) -> void:
	var fx := _spawn_fx_texture(
		"res://assets/pixel_battle/fx/slash_arc.png",
		Vector2(260 if not is_finisher else 320, 160 if not is_finisher else 200),
		Vector2(size.x * 0.5, size.y * 0.5),
		color,
		-16.0,
		Vector2(0.84, 0.84)
	)
	if fx == null:
		super(color, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.88), 0.03)
	tween.parallel().tween_property(fx, "scale", Vector2(1.02 if not is_finisher else 1.16, 1.02 if not is_finisher else 1.16), 0.06)
	tween.parallel().tween_property(fx, "position", fx.position + Vector2(84, 18), 0.06)
	if is_finisher:
		tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.98), 0.02)
		tween.parallel().tween_property(fx, "position", fx.position + Vector2(-36, -6), 0.04)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_target_hit_mark(target_is_enemy: bool, color: Color, profession_id: String, is_finisher: bool = false) -> void:
	var fx := _spawn_fx_texture(
		"res://assets/pixel_battle/fx/hit_spark.png",
		Vector2(128 if not is_finisher else 156, 128 if not is_finisher else 156),
		_actor_fx_anchor(target_is_enemy) + Vector2(12 if target_is_enemy else -12, -24),
		color,
		0.0,
		Vector2(0.72, 0.72)
	)
	if fx == null:
		super(target_is_enemy, color, profession_id, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.9 if is_finisher else 0.72), 0.03)
	tween.parallel().tween_property(fx, "scale", Vector2(1.0 if not is_finisher else 1.18, 1.0 if not is_finisher else 1.18), 0.05)
	tween.parallel().tween_property(fx, "rotation_degrees", 14.0 if profession_id == "spearman" else -18.0, 0.05)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_target_receive_feedback(target: Fighter, profession_id: String, color: Color, is_finisher: bool = false) -> void:
	super(target, profession_id, color, is_finisher)
	_pulse_actor_sheet_frame(target, 2, 0.16 if is_finisher else 0.12)
