extends "res://scripts/battle_controller_visual_ui.gd"

const BattleActorRenderHelper = preload("res://scripts/visual/battle_actor_view.gd")
const BattleActorRuntimeCache := preload("res://scripts/visual/battle_actor_runtime_cache.gd")
const BattleFontHelper = preload("res://scripts/visual/battle_font_view.gd")
const BattleRangeOverlayCacheView := preload("res://scripts/visual/battle_range_overlay_cache_view.gd")
const ActorAnimationRuntime = preload("res://scripts/visual/actor_animation_runtime.gd")

var _last_stage_grid_state: Dictionary = {}
var _actor_runtime_cache
var _range_overlay_cache

func _actor_runtime_view():
	if _actor_runtime_cache == null:
		_actor_runtime_cache = BattleActorRuntimeCache.new(self)
	return _actor_runtime_cache

func _range_overlay_view():
	if _range_overlay_cache == null:
		_range_overlay_cache = BattleRangeOverlayCacheView.new(self)
	return _range_overlay_cache

func _ready() -> void:
	super()
	_force_cjk_font()

func _process(delta: float) -> void:
	super(delta)
	_update_actor_animation_runtimes(delta)

func _force_cjk_font() -> void:
	BattleFontHelper.enforce(self)

func _build_ui() -> void:
	super()
	_force_cjk_font()

func _refresh_visual_ui() -> void:
	super()
	_ensure_actor_animation_runtimes()
	_force_cjk_font()

func _refresh_character_visuals() -> void:
	super()
	_ensure_actor_animation_runtimes()
	_refresh_actor_runtime_visuals()

func _confirm_player_intent() -> void:
	_ensure_actor_animation_runtimes()
	var selected_player_card: CardData = _intent_card(draft_player_intent)
	if selected_player_card == null:
		selected_player_card = _intent_card(player_intent)
	_play_actor_runtime_for_card(true, selected_player_card)
	super()

func _build_stage_layer() -> void:
	super()
	BattleActorRenderHelper.apply_render_bounds(player_sprite, player_fallback_actor)
	BattleActorRenderHelper.apply_render_bounds(enemy_sprite, enemy_fallback_actor)
	_force_cjk_font()

func _set_actor_sheet_frame(actor: Fighter, frame_index: int) -> void:
	if actor == null:
		return
	if player != null and actor.data.id == player.data.id and _actor_runtime_view().actor_runtime_is_ready(true):
		return
	if enemy != null and actor.data.id == enemy.data.id and _actor_runtime_view().actor_runtime_is_ready(false):
		return
	super._set_actor_sheet_frame(actor, frame_index)

func _sheet_frame_texture(source: Texture2D, frame: int) -> Texture2D:
	return BattleActorRenderHelper.frame_texture(source, frame, FRAME_SIZE, SHEET_FRAME_COUNT)

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	var sprite: TextureRect = player_sprite if is_player else enemy_sprite
	return BattleActorRenderHelper.slot_top_left_for_sprite(size.x, slot, is_player, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, sprite)

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	var sprite: TextureRect = player_sprite if is_player else enemy_sprite
	return BattleActorRenderHelper.animated_actor_top_left_for_sprite(size.x, is_player, start_slot, target_slot, active, _preview_cycle_phase(), GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP, sprite)

func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	return BattleSkinHelper.make_flat_card_style(fill, border, border_width)

func _make_type_tag_style(card: CardData) -> StyleBoxFlat:
	return BattleSkinHelper.make_type_tag_style(card.is_guard_card(), card.is_feint_card())

func _make_card_art_style(card: CardData) -> StyleBoxFlat:
	return BattleSkinHelper.make_card_art_style(card.is_guard_card(), card.is_feint_card())

func _make_momentum_dot_style(filled: bool) -> StyleBoxFlat:
	return BattleSkinHelper.make_momentum_dot_style(filled)

func _intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	return BattleHudHelper.intent_bubble_text(card, actor_slot, opponent_slot, target_slot)

func _legacy_effect_preview_text() -> String:
	# Legacy approximate preview retained only for debugging fallback.
	# The active battle preview is provided by battle_controller_visual_resolver_preview.gd,
	# which uses _ordered_preview_simulation() and target_position/target_facing.
	return BattleHudHelper.effect_preview_text(_legacy_effect_preview_context())

func _legacy_effect_preview_context() -> Dictionary:
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
	var player_facing: String = _player_preview_facing()
	var enemy_facing: String = _enemy_preview_facing()
	var player_range: Array[int] = _attack_range_slots(true, player_target, preview_card)
	var player_result: String = _preview_range_result(preview_card, player_target, player_facing, enemy_target_for_preview)
	var hits_enemy: bool = preview_card.requires_hit_check() and (player_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and player_result == CombatResolver.RANGE_GRAZE))
	var enemy_range: Array[int] = []
	var enemy_hits_player: bool = false
	var enemy_damage: int = 0
	var enemy_result: String = BattleStateMachine.RANGE_HIT
	var enemy_target: int = enemy_target_for_preview
	if enemy_card != null:
		enemy_range = _attack_range_slots(false, enemy_target, enemy_card)
		enemy_result = _preview_range_result(enemy_card, enemy_target, enemy_facing, player_target)
		enemy_hits_player = enemy_card.requires_hit_check() and (enemy_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and enemy_result == CombatResolver.RANGE_GRAZE))
		enemy_damage = _preview_damage_for_result(enemy_card, player, enemy_result)
	var input: Dictionary = {
		"has_data": true,
		"preview_card": preview_card,
		"enemy_card": enemy_card,
		"current_card_name": "未选招，按不动预览" if uses_wait else preview_card.display_name,
		"distance": state_machine.current_distance,
		"player_slot_label": _slot_label(player_slot),
		"player_target_label": _slot_label(player_target),
		"player_facing": _facing_label(player_facing),
		"player_range_text": _slot_list_text(player_range),
		"hits_enemy": hits_enemy,
		"player_hit_text": _range_result_text(player_result) if preview_card.requires_hit_check() else "无",
		"player_damage": _preview_damage_for_result(preview_card, enemy, player_result),
		"player_momentum": player.momentum,
		"player_max_momentum": player.data.max_momentum,
		"enemy_momentum": enemy.momentum,
		"enemy_max_momentum": enemy.data.max_momentum,
		"enemy_hp": enemy.hp,
		"enemy_max_hp": enemy.data.max_hp,
		"player_hp": player.hp,
		"player_max_hp": player.data.max_hp,
		"enemy_hits_player": enemy_hits_player,
		"enemy_damage": enemy_damage,
		"player_break_amount": _preview_break_for_result(preview_card, player_result)
	}
	if enemy_card != null:
		input["enemy_slot_label"] = _slot_label(enemy_slot)
		input["enemy_target_label"] = _slot_label(enemy_target)
		input["enemy_facing"] = _facing_label(enemy_facing)
		input["enemy_range_text"] = _slot_list_text(enemy_range)
		input["enemy_hit_text"] = _range_result_text(enemy_result) if enemy_card.requires_hit_check() else "无"
		input["enemy_break_amount"] = _preview_break_for_result(enemy_card, enemy_result)
	return BattleHudHelper.build_effect_preview_context(input)

func _clear_range_trapezoids() -> void:
	_range_overlay_view().clear_range_trapezoids()

func _refresh_range_trapezoids(player_range: Array[int], player_origin_slot: int, enemy_range: Array[int], enemy_origin_slot: int) -> void:
	_range_overlay_view().refresh_range_trapezoids(player_range, player_origin_slot, enemy_range, enemy_origin_slot)

func _draw_range_trapezoid(slot: int, origin_slot: int, z_index: int, fill_color: Color, outline_color: Color) -> void:
	_range_overlay_view().draw_range_trapezoid(slot, origin_slot, z_index, fill_color, outline_color)

func _take_range_polygon() -> Polygon2D:
	return _range_overlay_view().take_range_polygon()

func _take_range_line() -> Line2D:
	return _range_overlay_view().take_range_line()

func _recycle_range_overlay_nodes() -> void:
	_range_overlay_view().recycle_range_overlay_nodes()

func _refresh_stage_grid(show_ranges: bool = true) -> void:
	if stage_grid_cells.is_empty():
		return
	var positions: Dictionary = _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_preview_card: CardData = _player_preview_card()
	var enemy_preview_card: CardData = _enemy_preview_card()
	var player_target_slot: int = _target_slot_for_preview(true, player_slot, enemy_slot, player_preview_card)
	var enemy_target_slot: int = _target_slot_for_preview(false, player_slot, enemy_slot, enemy_preview_card)
	var player_range: Array[int] = _attack_range_slots(true, player_target_slot, player_preview_card) if show_ranges else []
	var enemy_range: Array[int] = _attack_range_slots(false, enemy_target_slot, enemy_preview_card) if show_ranges else []
	_refresh_range_trapezoids(player_range, player_target_slot, enemy_range, enemy_target_slot)
	var next_state: Dictionary = {}
	var legal_positions := _legal_positions_for(player)
	for i in range(GRID_SLOT_COUNT):
		var slot_state: Dictionary = BattleStageHelper.build_slot_state(i, player_target_slot, enemy_target_slot, player_range, enemy_range, GRID_BASE_COLOR, PLAYER_POS_COLOR, ENEMY_POS_COLOR)
		var fill: Color = slot_state.get("fill", GRID_BASE_COLOR) as Color
		var label_text: String = slot_state.get("label", "") as String
		var has_player: bool = slot_state.get("has_player", false) as bool
		var has_enemy: bool = slot_state.get("has_enemy", false) as bool
		var is_actor_slot := has_player or has_enemy
		var is_legal: bool = awaiting_player_input and legal_positions.has(i) and not is_actor_slot
		var is_selected := false
		if is_actor_slot:
			fill = GRID_BASE_COLOR
		if is_legal:
			fill = fill.lerp(Color("53745a"), 0.45)
		var state_key: String = "%s|%s|%s|%s|%s|%s" % [fill.to_html(), label_text, str(has_player), str(has_enemy), str(is_legal), str(is_selected)]
		next_state[i] = {"key": state_key}
		if not _last_stage_grid_state.has(i) or (_last_stage_grid_state[i] as Dictionary).get("key", "") != state_key:
			_apply_stage_grid_slot(i, fill, has_player, has_enemy, label_text, is_legal, is_selected)
	_last_stage_grid_state = next_state
	_refresh_actor_foot_highlights(player_target_slot, enemy_target_slot)
	_force_cjk_font()

func _invalidate_stage_preview() -> void:
	super()
	_last_stage_grid_state.clear()

func _apply_stage_grid_slot(slot: int, fill: Color, has_player: bool, has_enemy: bool, label_text: String, is_legal: bool = false, is_selected: bool = false) -> void:
	if slot < 0 or slot >= stage_grid_cells.size() or slot >= stage_grid_labels.size():
		return
	var style := _make_grid_cell_style(fill, slot, false, false, false, false)
	if is_legal or is_selected:
		style.border_color = Color("9fe08f") if is_legal else Color("ffd479")
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_width_left = 4
	stage_grid_cells[slot].add_theme_stylebox_override("panel", style)
	stage_grid_labels[slot].text = label_text
	if is_legal and label_text == "":
		stage_grid_labels[slot].text = "○"

func _update_actor_animation_runtimes(delta: float) -> void:
	_actor_runtime_view().update_actor_animation_runtimes(delta)

func _ensure_actor_animation_runtimes() -> void:
	_actor_runtime_view().ensure_actor_animation_runtimes()

func _ensure_single_actor_runtime(is_player_actor: bool) -> void:
	_actor_runtime_view().ensure_single_actor_runtime(is_player_actor)

func _create_actor_runtime(actor_key: String, meta_path: String, sprite: TextureRect) -> ActorAnimationRuntime:
	return _actor_runtime_view().create_actor_runtime(actor_key, meta_path, sprite)

func _clear_actor_runtime(is_player_actor: bool) -> void:
	_actor_runtime_view().clear_actor_runtime(is_player_actor)

func _refresh_actor_runtime_visuals() -> void:
	_actor_runtime_view().refresh_actor_runtime_visuals()

func _refresh_single_actor_runtime_visual(runtime: ActorAnimationRuntime, fallback: Control) -> void:
	_actor_runtime_view().refresh_single_actor_runtime_visual(runtime, fallback)

func _intent_card(intent: IntentData) -> CardData:
	return _actor_runtime_view().intent_card(intent)

func _play_actor_runtime_for_card(is_player_actor: bool, card: CardData) -> void:
	_actor_runtime_view().play_actor_runtime_for_card(is_player_actor, card)

func _animation_event_for_card(card: CardData) -> String:
	return _actor_runtime_view().animation_event_for_card(card)

func _card_has_tag(card: CardData, tag: String) -> bool:
	return _actor_runtime_view().card_has_tag(card, tag)

func _play_defender_reaction_for_hit_frame(attacker_key: String) -> void:
	_actor_runtime_view().play_defender_reaction_for_hit_frame(attacker_key)

func _trigger_runtime_fx_feedback(actor_key: String, fx_id: String, impact_offset: Vector2) -> void:
	_actor_runtime_view().trigger_runtime_fx_feedback(actor_key, fx_id, impact_offset)

func _runtime_fx_color(fx_id: String, profession_id: String, is_finisher: bool) -> Color:
	return _actor_runtime_view().runtime_fx_color(fx_id, profession_id, is_finisher)

func _actor_meta_path_for(fighter: Fighter, prefer_enemy_variant: bool) -> String:
	if fighter == null or fighter.data == null:
		return ""
	var role_id: String = str(fighter.data.id)
	if role_id == "":
		return ""
	if prefer_enemy_variant:
		var enemy_role_id: String = "enemy_%s" % role_id
		var enemy_path: String = "res://assets/pixel_battle/actors/%s/%s.meta.json" % [enemy_role_id, enemy_role_id]
		if FileAccess.file_exists(enemy_path):
			return enemy_path
	var default_path: String = "res://assets/pixel_battle/actors/%s/%s.meta.json" % [role_id, role_id]
	if FileAccess.file_exists(default_path):
		return default_path
	var visual_role_id := _visual_actor_role_id_for(fighter)
	if visual_role_id == "" or visual_role_id == role_id:
		return ""
	if prefer_enemy_variant:
		var visual_enemy_role_id: String = "enemy_%s" % visual_role_id
		var visual_enemy_path: String = "res://assets/pixel_battle/actors/%s/%s.meta.json" % [visual_enemy_role_id, visual_enemy_role_id]
		if FileAccess.file_exists(visual_enemy_path):
			return visual_enemy_path
	var visual_path: String = "res://assets/pixel_battle/actors/%s/%s.meta.json" % [visual_role_id, visual_role_id]
	return visual_path if FileAccess.file_exists(visual_path) else ""

func _on_actor_runtime_ready(actor_key: String, role_id: String) -> void:
	print("[actor-runtime] ready %s role=%s" % [actor_key, role_id])

func _on_actor_runtime_failed(actor_key: String, message: String) -> void:
	print("[actor-runtime] failed %s: %s" % [actor_key, message])

func _on_actor_runtime_hit_frame(actor_key: String, animation_name: String, frame_index: int, fx_id: String, impact_offset: Vector2) -> void:
	print("[actor-runtime] hit_frame %s %s frame=%d fx=%s offset=%s" % [actor_key, animation_name, frame_index, fx_id, str(impact_offset)])
	_trigger_runtime_fx_feedback(actor_key, fx_id, impact_offset)
	_play_defender_reaction_for_hit_frame(actor_key)

func _on_actor_runtime_animation_finished(actor_key: String, animation_name: String) -> void:
	print("[actor-runtime] finished %s %s" % [actor_key, animation_name])
