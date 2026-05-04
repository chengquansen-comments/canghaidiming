extends "res://scripts/battle_controller_visual_presentation_stepwise_fx.gd"

# Stepwise actor focus / glow layer.
#
# Owns actor halos, action glows, phase cue, stage focus, intent-bubble focus,
# and dead-actor visibility guard.

const ACTOR_GLOW_MARGIN := 16.0
const ACTOR_GLOW_PLAYER_COLOR := Color(0.48, 0.82, 1.0, 0.54)
const ACTOR_GLOW_ENEMY_COLOR := Color(1.0, 0.22, 0.14, 0.58)
const ACTOR_FOCUS_DIM_COLOR := Color(0.68, 0.70, 0.72, 0.74)
const ACTOR_HALO_SIZE := Vector2(142.0, 24.0)
const ACTOR_HALO_PLAYER_COLOR := Color(0.35, 0.76, 1.0, 0.36)
const ACTOR_HALO_ENEMY_COLOR := Color(1.0, 0.23, 0.12, 0.40)
const STAGE_FOCUS_OFFSET_X := 0.0
const PHASE_CUE_SIZE := Vector2(300.0, 48.0)

var _player_actor_glow: TextureRect
var _enemy_actor_glow: TextureRect
var _player_actor_glow_tween: Tween
var _enemy_actor_glow_tween: Tween
var _player_actor_glow_active := false
var _enemy_actor_glow_active := false
var _player_actor_halo: PanelContainer
var _enemy_actor_halo: PanelContainer
var _stage_focus_tween: Tween
var _stage_focus_target := Vector2.ZERO
var _phase_cue_panel: PanelContainer
var _phase_cue_label: Label
var _phase_cue_tween: Tween
var _player_intent_bubble_focus_active := false
var _enemy_intent_bubble_focus_active := false
var _player_intent_bubble_tween: Tween
var _enemy_intent_bubble_tween: Tween


func _build_ui() -> void:
	super._build_ui()
	_ensure_actor_action_glows()


func _refresh_ui() -> void:
	super._refresh_ui()
	_sync_actor_action_glows()
	_apply_dead_actor_visibility_guard()


func _apply_dead_actor_visibility_guard() -> void:
	if _presentation_busy():
		return
	if player != null and player.hp <= 0:
		if player_sprite != null:
			player_sprite.visible = false
		if player_fallback_actor != null:
			player_fallback_actor.visible = false
	if enemy != null and enemy.hp <= 0:
		if enemy_sprite != null:
			enemy_sprite.visible = false
		if enemy_fallback_actor != null:
			enemy_fallback_actor.visible = false
		_set_actor_action_glow(false, false)

func _ensure_actor_action_glows() -> void:
	if stage_layer == null:
		return
	if _player_actor_halo == null:
		_player_actor_halo = _make_actor_action_halo("PlayerActionHalo", true)
		stage_layer.add_child(_player_actor_halo)
	if _enemy_actor_halo == null:
		_enemy_actor_halo = _make_actor_action_halo("EnemyActionHalo", false)
		stage_layer.add_child(_enemy_actor_halo)
	if _player_actor_glow == null:
		_player_actor_glow = _make_actor_action_glow("PlayerActionGlow")
		stage_layer.add_child(_player_actor_glow)
	if _enemy_actor_glow == null:
		_enemy_actor_glow = _make_actor_action_glow("EnemyActionGlow")
		stage_layer.add_child(_enemy_actor_glow)
	_sync_actor_action_glows()
	_ensure_phase_cue()

func _make_actor_action_glow(node_name: String) -> TextureRect:
	var glow := TextureRect.new()
	glow.name = node_name
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = 7
	glow.visible = false
	return glow

func _make_actor_action_halo(node_name: String, is_player_actor: bool) -> PanelContainer:
	var halo := PanelContainer.new()
	halo.name = node_name
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.z_index = 6
	halo.visible = false
	halo.custom_minimum_size = ACTOR_HALO_SIZE
	halo.size = ACTOR_HALO_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = ACTOR_HALO_PLAYER_COLOR if is_player_actor else ACTOR_HALO_ENEMY_COLOR
	style.border_color = Color(style.bg_color.r, style.bg_color.g, style.bg_color.b, minf(style.bg_color.a + 0.32, 0.82))
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(style.bg_color.r, style.bg_color.g, style.bg_color.b, 0.42)
	style.shadow_size = 16
	style.shadow_offset = Vector2.ZERO
	halo.add_theme_stylebox_override("panel", style)
	return halo

func _ensure_phase_cue() -> void:
	if stage_layer == null or _phase_cue_panel != null:
		return
	_phase_cue_panel = PanelContainer.new()
	_phase_cue_panel.name = "PhaseFocusCue"
	_phase_cue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_cue_panel.z_index = 130
	_phase_cue_panel.visible = false
	_phase_cue_panel.size = PHASE_CUE_SIZE
	_phase_cue_panel.anchor_left = 0.5
	_phase_cue_panel.anchor_right = 0.5
	_phase_cue_panel.offset_left = -PHASE_CUE_SIZE.x * 0.5
	_phase_cue_panel.offset_right = PHASE_CUE_SIZE.x * 0.5
	_phase_cue_panel.offset_top = STAGE_AREA_TOP + 18.0
	_phase_cue_panel.offset_bottom = STAGE_AREA_TOP + 18.0 + PHASE_CUE_SIZE.y
	_phase_cue_label = Label.new()
	_phase_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_cue_label.add_theme_font_size_override("font_size", 24)
	_phase_cue_panel.add_child(_phase_cue_label)
	stage_layer.add_child(_phase_cue_panel)

func _make_phase_cue_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.36)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _set_actor_action_glow(is_player_actor: bool, active: bool) -> void:
	_ensure_actor_action_glows()
	var glow: TextureRect = _player_actor_glow if is_player_actor else _enemy_actor_glow
	if glow == null:
		return
	var was_active: bool = _player_actor_glow_active if is_player_actor else _enemy_actor_glow_active
	if was_active == active:
		_sync_actor_action_glow(is_player_actor)
		_sync_actor_focus_state()
		return
	var tween: Tween = _player_actor_glow_tween if is_player_actor else _enemy_actor_glow_tween
	if tween != null and tween.is_valid():
		tween.kill()
	if is_player_actor:
		_player_actor_glow_active = active
	else:
		_enemy_actor_glow_active = active
	if active:
		var color := ACTOR_GLOW_PLAYER_COLOR if is_player_actor else ACTOR_GLOW_ENEMY_COLOR
		glow.modulate = color
		glow.visible = true
		_sync_actor_action_glow(is_player_actor)
		_set_actor_intent_bubble_focus(is_player_actor, true, color)
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(glow, "modulate:a", minf(color.a + 0.20, 0.86), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "modulate:a", maxf(color.a - 0.16, 0.24), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if is_player_actor:
			_player_actor_glow_tween = pulse
		else:
			_enemy_actor_glow_tween = pulse
	else:
		glow.visible = false
		_set_actor_intent_bubble_focus(is_player_actor, false)
		if is_player_actor:
			_player_actor_glow_tween = null
		else:
			_enemy_actor_glow_tween = null
	_sync_actor_focus_state()

func _clear_actor_action_glows() -> void:
	_set_actor_action_glow(true, false)
	_set_actor_action_glow(false, false)

func _sync_actor_action_glows() -> void:
	_sync_actor_action_glow(true)
	_sync_actor_action_glow(false)

func _sync_actor_action_glow(is_player_actor: bool) -> void:
	var glow: TextureRect = _player_actor_glow if is_player_actor else _enemy_actor_glow
	var sprite: TextureRect = player_sprite if is_player_actor else enemy_sprite
	if glow == null or sprite == null:
		return
	glow.texture = sprite.texture
	glow.flip_h = sprite.flip_h
	var active: bool = _player_actor_glow_active if is_player_actor else _enemy_actor_glow_active
	glow.visible = active and sprite.visible and sprite.texture != null
	glow.position = sprite.position - Vector2(ACTOR_GLOW_MARGIN, ACTOR_GLOW_MARGIN)
	glow.size = sprite.size + Vector2(ACTOR_GLOW_MARGIN * 2.0, ACTOR_GLOW_MARGIN * 2.0)
	var sprite_scale := sprite.scale
	glow.scale = Vector2(maxf(absf(sprite_scale.x), 1.0), maxf(absf(sprite_scale.y), 1.0))
	_sync_actor_action_halo(is_player_actor)

func _sync_actor_action_halo(is_player_actor: bool) -> void:
	var halo: PanelContainer = _player_actor_halo if is_player_actor else _enemy_actor_halo
	var sprite: TextureRect = player_sprite if is_player_actor else enemy_sprite
	if halo == null or sprite == null:
		return
	var active: bool = _player_actor_glow_active if is_player_actor else _enemy_actor_glow_active
	halo.visible = active and sprite.visible
	var foot_point := sprite.position + BattleActorFootHelper.frame_foot_offset(sprite)
	halo.position = Vector2(
		foot_point.x - ACTOR_HALO_SIZE.x * 0.5,
		GRID_STAGE_Y + GRID_SLOT_HEIGHT * 0.5 - ACTOR_HALO_SIZE.y * 0.5
	)
	halo.size = ACTOR_HALO_SIZE

func _sync_actor_focus_state() -> void:
	var focused_side := 0
	if _player_actor_glow_active and not _enemy_actor_glow_active:
		focused_side = 1
	elif _enemy_actor_glow_active and not _player_actor_glow_active:
		focused_side = -1
	_apply_actor_focus_dim(focused_side)
	_apply_stage_focus(focused_side)

func _apply_actor_focus_dim(focused_side: int) -> void:
	_set_actor_visual_modulate(true, Color.WHITE if focused_side >= 0 else ACTOR_FOCUS_DIM_COLOR)
	_set_actor_visual_modulate(false, Color.WHITE if focused_side <= 0 else ACTOR_FOCUS_DIM_COLOR)

func _set_actor_visual_modulate(is_player_actor: bool, color: Color) -> void:
	var sprite: TextureRect = player_sprite if is_player_actor else enemy_sprite
	var fallback: Control = player_fallback_actor if is_player_actor else enemy_fallback_actor
	if sprite != null and sprite.visible:
		sprite.modulate = color
	if fallback != null and fallback.visible:
		fallback.modulate = color

func _apply_stage_focus(focused_side: int) -> void:
	if stage_layer == null:
		return
	var target := Vector2.ZERO
	if focused_side > 0:
		target = Vector2(STAGE_FOCUS_OFFSET_X, 0.0)
	elif focused_side < 0:
		target = Vector2(-STAGE_FOCUS_OFFSET_X, 0.0)
	if _stage_focus_target.distance_to(target) < 0.5:
		return
	_stage_focus_target = target
	if _stage_focus_tween != null and _stage_focus_tween.is_valid():
		_stage_focus_tween.kill()
	_stage_focus_tween = create_tween()
	_stage_focus_tween.tween_property(stage_layer, "position", target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_phase_focus_cue(text: String, color: Color, hold_duration: float = PRESENTATION_PHASE_CUE_HOLD) -> void:
	_ensure_phase_cue()
	if _phase_cue_panel == null or _phase_cue_label == null:
		await get_tree().create_timer(hold_duration).timeout
		return
	if _phase_cue_tween != null and _phase_cue_tween.is_valid():
		_phase_cue_tween.kill()
	_phase_cue_panel.visible = true
	_phase_cue_panel.modulate = Color(1, 1, 1, 0)
	_phase_cue_panel.scale = Vector2(0.94, 0.94)
	_phase_cue_label.text = text
	_phase_cue_label.add_theme_color_override("font_color", color.lightened(0.42))
	_phase_cue_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	_phase_cue_label.add_theme_constant_override("shadow_offset_x", 1)
	_phase_cue_label.add_theme_constant_override("shadow_offset_y", 2)
	_phase_cue_panel.add_theme_stylebox_override("panel", _make_phase_cue_style(Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.86), color))
	_phase_cue_tween = create_tween()
	_phase_cue_tween.tween_property(_phase_cue_panel, "modulate", Color(1, 1, 1, 1), 0.08)
	_phase_cue_tween.parallel().tween_property(_phase_cue_panel, "scale", Vector2.ONE, 0.08)
	_phase_cue_tween.tween_interval(maxf(hold_duration - 0.16, 0.10))
	_phase_cue_tween.tween_property(_phase_cue_panel, "modulate", Color(1, 1, 1, 0), 0.08)
	await _phase_cue_tween.finished
	_phase_cue_panel.visible = false

func _set_actor_intent_bubble_focus(is_player_actor: bool, active: bool, color: Color = Color.WHITE) -> void:
	var was_active: bool = _player_intent_bubble_focus_active if is_player_actor else _enemy_intent_bubble_focus_active
	if is_player_actor:
		_player_intent_bubble_focus_active = active
	else:
		_enemy_intent_bubble_focus_active = active
	var bubble: PanelContainer = player_intent_bubble if is_player_actor else enemy_intent_bubble
	if bubble == null or not bubble.visible:
		return
	if was_active == active:
		return
	var tween: Tween = _player_intent_bubble_tween if is_player_actor else _enemy_intent_bubble_tween
	if tween != null and tween.is_valid():
		tween.kill()
	bubble.pivot_offset = bubble.size * 0.5
	if active:
		bubble.add_theme_stylebox_override("panel", _make_focused_intent_bubble_style(is_player_actor, color))
		bubble.modulate = color.lightened(0.32)
		var focus_tween := create_tween()
		focus_tween.tween_property(bubble, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		focus_tween.parallel().tween_property(bubble, "modulate", Color.WHITE, 0.18)
		if is_player_actor:
			_player_intent_bubble_tween = focus_tween
		else:
			_enemy_intent_bubble_tween = focus_tween
	else:
		bubble.add_theme_stylebox_override("panel", _make_intent_bubble_style(is_player_actor))
		var restore_tween := create_tween()
		restore_tween.tween_property(bubble, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		restore_tween.parallel().tween_property(bubble, "modulate", Color.WHITE, 0.16)
		if is_player_actor:
			_player_intent_bubble_tween = restore_tween
		else:
			_enemy_intent_bubble_tween = restore_tween

func _make_focused_intent_bubble_style(is_player_actor: bool, color: Color) -> StyleBoxFlat:
	var style := _make_intent_bubble_style(is_player_actor)
	style.border_color = color.lightened(0.28)
	style.set_border_width_all(3)
	style.shadow_color = Color(color.r, color.g, color.b, 0.52)
	style.shadow_size = 14
	style.shadow_offset = Vector2.ZERO
	return style

func _current_grid_positions() -> Dictionary:
	if _presentation_busy() and has_meta(PRESENTATION_OLD_PLAYER_SLOT_META) and has_meta(PRESENTATION_OLD_ENEMY_SLOT_META):
		return {
			"player": int(get_meta(PRESENTATION_OLD_PLAYER_SLOT_META, player.position if player != null else 0)),
			"enemy": int(get_meta(PRESENTATION_OLD_ENEMY_SLOT_META, enemy.position if enemy != null else GRID_RIGHT_ANCHOR_SLOT))
		}
	return super._current_grid_positions()

func _apply_presentation_offsets() -> void:
	super._apply_presentation_offsets()
	_sync_actor_action_glows()

