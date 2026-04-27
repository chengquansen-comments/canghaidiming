extends "res://scripts/battle_controller_visual_ui.gd"

const BattleActorRenderHelper = preload("res://scripts/visual/battle_actor_view.gd")
const BattleFontHelper = preload("res://scripts/visual/battle_font_view.gd")
const ActorAnimationRuntime = preload("res://scripts/visual/actor_animation_runtime.gd")

var _last_stage_grid_state: Dictionary = {}
var _range_polygon_pool: Array[Polygon2D] = []
var _range_line_pool: Array[Line2D] = []
var _active_range_polygons: Array[Polygon2D] = []
var _active_range_lines: Array[Line2D] = []
var _player_actor_runtime: ActorAnimationRuntime = null
var _enemy_actor_runtime: ActorAnimationRuntime = null
var _player_actor_runtime_meta_path := ""
var _enemy_actor_runtime_meta_path := ""
var _last_player_animation_card: CardData = null
var _last_enemy_animation_card: CardData = null

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
	var visible_enemy_card: CardData = _enemy_preview_card()
	_play_actor_runtime_for_card(true, selected_player_card)
	_play_actor_runtime_for_card(false, visible_enemy_card)
	super()

func _build_stage_layer() -> void:
	super()
	BattleActorRenderHelper.apply_render_bounds(player_sprite, player_fallback_actor)
	BattleActorRenderHelper.apply_render_bounds(enemy_sprite, enemy_fallback_actor)
	_force_cjk_font()

func _sheet_frame_texture(source: Texture2D, frame: int) -> Texture2D:
	return BattleActorRenderHelper.frame_texture(source, frame, FRAME_SIZE, SHEET_FRAME_COUNT)

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	return BattleActorRenderHelper.slot_top_left(size.x, slot, is_player, GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	return BattleActorRenderHelper.animated_actor_top_left(size.x, is_player, start_slot, target_slot, active, _preview_cycle_phase(), GRID_SLOT_COUNT, GRID_SLOT_WIDTH, GRID_SLOT_GAP)

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
	var hits_enemy: bool = preview_card.requires_hit_check() and (player_result == BattleStateMachine.RANGE_HIT or player_result == BattleStateMachine.RANGE_GRAZE)
	var enemy_range: Array[int] = []
	var enemy_hits_player: bool = false
	var enemy_damage: int = 0
	var enemy_result: String = BattleStateMachine.RANGE_HIT
	var enemy_target: int = enemy_target_for_preview
	if enemy_card != null:
		enemy_range = _attack_range_slots(false, enemy_target, enemy_card)
		enemy_result = _preview_range_result(enemy_card, enemy_target, enemy_facing, player_target)
		enemy_hits_player = enemy_card.requires_hit_check() and (enemy_result == BattleStateMachine.RANGE_HIT or enemy_result == BattleStateMachine.RANGE_GRAZE)
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
		var is_legal: bool = awaiting_player_input and legal_positions.has(i)
		var is_selected: bool = i == player_target_slot
		if is_legal and not has_player and not has_enemy:
			fill = fill.lerp(Color("53745a"), 0.45)
		var state_key: String = "%s|%s|%s|%s|%s|%s" % [fill.to_html(), label_text, str(has_player), str(has_enemy), str(is_legal), str(is_selected)]
		next_state[i] = {"key": state_key}
		if not _last_stage_grid_state.has(i) or (_last_stage_grid_state[i] as Dictionary).get("key", "") != state_key:
			_apply_stage_grid_slot(i, fill, has_player, has_enemy, label_text, is_legal, is_selected)
	_last_stage_grid_state = next_state
	_force_cjk_font()

func _invalidate_stage_preview() -> void:
	super()
	_last_stage_grid_state.clear()

func _apply_stage_grid_slot(slot: int, fill: Color, has_player: bool, has_enemy: bool, label_text: String, is_legal: bool = false, is_selected: bool = false) -> void:
	if slot < 0 or slot >= stage_grid_cells.size() or slot >= stage_grid_labels.size():
		return
	var style := _make_grid_cell_style(fill, slot, has_player, has_enemy, false, false)
	if is_legal or is_selected:
		style.border_color = Color("9fe08f") if is_legal else Color("ffd479")
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_width_left = 4 if slot == 0 else 0
	stage_grid_cells[slot].add_theme_stylebox_override("panel", style)
	stage_grid_labels[slot].text = label_text
	if is_legal and label_text == "":
		stage_grid_labels[slot].text = "○"

func _update_actor_animation_runtimes(delta: float) -> void:
	if _player_actor_runtime != null and _player_actor_runtime.is_ready:
		_player_actor_runtime.update(delta)
	if _enemy_actor_runtime != null and _enemy_actor_runtime.is_ready:
		_enemy_actor_runtime.update(delta)

func _ensure_actor_animation_runtimes() -> void:
	_ensure_single_actor_runtime(true)
	_ensure_single_actor_runtime(false)

func _ensure_single_actor_runtime(is_player_actor: bool) -> void:
	var fighter: Fighter = player if is_player_actor else enemy
	var sprite: TextureRect = player_sprite if is_player_actor else enemy_sprite
	if fighter == null or sprite == null:
		_clear_actor_runtime(is_player_actor)
		return
	var meta_path: String = _actor_meta_path_for(fighter, not is_player_actor)
	if meta_path == "":
		_clear_actor_runtime(is_player_actor)
		return
	if is_player_actor:
		if _player_actor_runtime != null and _player_actor_runtime_meta_path == meta_path:
			return
		_player_actor_runtime = _create_actor_runtime("player", meta_path, sprite)
		_player_actor_runtime_meta_path = meta_path if _player_actor_runtime != null and _player_actor_runtime.is_ready else ""
	else:
		if _enemy_actor_runtime != null and _enemy_actor_runtime_meta_path == meta_path:
			return
		_enemy_actor_runtime = _create_actor_runtime("enemy", meta_path, sprite)
		_enemy_actor_runtime_meta_path = meta_path if _enemy_actor_runtime != null and _enemy_actor_runtime.is_ready else ""

func _create_actor_runtime(actor_key: String, meta_path: String, sprite: TextureRect) -> ActorAnimationRuntime:
	var runtime: ActorAnimationRuntime = ActorAnimationRuntime.new()
	runtime.runtime_ready.connect(_on_actor_runtime_ready)
	runtime.runtime_failed.connect(_on_actor_runtime_failed)
	runtime.hit_frame_reached.connect(_on_actor_runtime_hit_frame)
	runtime.animation_finished.connect(_on_actor_runtime_animation_finished)
	var ok: bool = runtime.bind(actor_key, meta_path, sprite)
	return runtime if ok else null

func _clear_actor_runtime(is_player_actor: bool) -> void:
	if is_player_actor:
		_player_actor_runtime = null
		_player_actor_runtime_meta_path = ""
	else:
		_enemy_actor_runtime = null
		_enemy_actor_runtime_meta_path = ""

func _refresh_actor_runtime_visuals() -> void:
	_refresh_single_actor_runtime_visual(_player_actor_runtime, player_fallback_actor)
	_refresh_single_actor_runtime_visual(_enemy_actor_runtime, enemy_fallback_actor)

func _refresh_single_actor_runtime_visual(runtime: ActorAnimationRuntime, fallback: Control) -> void:
	if runtime == null or not runtime.is_ready:
		return
	if fallback != null:
		fallback.visible = false
	if runtime.player != null and runtime.player.playing:
		runtime.player._apply_current_frame()
		return
	runtime.play_idle(false)

func _intent_card(intent: IntentData) -> CardData:
	if intent != null and intent.actual_card != null:
		return intent.actual_card
	return null

func _play_actor_runtime_for_card(is_player_actor: bool, card: CardData) -> void:
	var runtime: ActorAnimationRuntime = _player_actor_runtime if is_player_actor else _enemy_actor_runtime
	if runtime == null or not runtime.is_ready:
		return
	var event_name: String = _animation_event_for_card(card)
	if event_name == "":
		return
	if is_player_actor:
		_last_player_animation_card = card
	else:
		_last_enemy_animation_card = card
	runtime.play_event(event_name, true)

func _animation_event_for_card(card: CardData) -> String:
	if card == null:
		return "idle"
	if card.is_guard_card():
		return "guard"
	if card.is_momentum_card():
		return "focus"
	if card.damage > 0:
		return "attack_heavy" if _card_has_tag(card, "终结") else "attack_light"
	if card.break_momentum > 0:
		return "focus"
	return "idle"

func _card_has_tag(card: CardData, tag: String) -> bool:
	if card == null:
		return false
	for item in card.tags:
		if str(item) == tag:
			return true
	return false

func _play_defender_reaction_for_hit_frame(attacker_key: String) -> void:
	var attacking_card: CardData = _last_player_animation_card if attacker_key == "player" else _last_enemy_animation_card
	var defender_runtime: ActorAnimationRuntime = _enemy_actor_runtime if attacker_key == "player" else _player_actor_runtime
	var defender: Fighter = enemy if attacker_key == "player" else player
	if defender_runtime == null or not defender_runtime.is_ready or attacking_card == null:
		return
	var event_name := "hit"
	if defender != null and defender.is_broken():
		event_name = "break"
	elif attacking_card.break_momentum > 0 and attacking_card.damage <= 0:
		event_name = "break"
	elif attacking_card.guard > 0:
		event_name = "guard"
	defender_runtime.play_event(event_name, true)

func _trigger_runtime_fx_feedback(actor_key: String, fx_id: String, impact_offset: Vector2) -> void:
	var attacking_card: CardData = _last_player_animation_card if actor_key == "player" else _last_enemy_animation_card
	var attacker: Fighter = player if actor_key == "player" else enemy
	var defender: Fighter = enemy if actor_key == "player" else player
	if attacker == null or defender == null:
		return
	var profession_id: String = str(attacker.data.id)
	var is_finisher: bool = _card_has_tag(attacking_card, "终结")
	var color: Color = _runtime_fx_color(fx_id, profession_id, is_finisher)
	if fx_id == "pierce_streak" or profession_id == "spearman":
		_show_pierce_line(color, is_finisher)
	elif fx_id == "slash_arc" or profession_id == "blademaster":
		_show_slash_cut(color, is_finisher)
	else:
		_play_profession_shape_feedback(profession_id, color, is_finisher, false)
	_show_target_receive_feedback(defender, profession_id, color, is_finisher)
	_impact_feedback(color, 6.2 if is_finisher else 3.8, profession_id == "spearman", is_finisher)

func _runtime_fx_color(fx_id: String, profession_id: String, is_finisher: bool) -> Color:
	if fx_id == "pierce_streak" or profession_id == "spearman":
		return Color("dff4ff") if is_finisher else Color("9fd8ff")
	if fx_id == "slash_arc" or profession_id == "blademaster":
		return Color("ffd1a8") if is_finisher else Color("ff9f73")
	return Color("f5d889") if is_finisher else Color("d9c18a")

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
	return default_path if FileAccess.file_exists(default_path) else ""

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
