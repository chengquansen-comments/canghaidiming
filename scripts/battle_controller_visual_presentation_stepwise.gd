extends "res://scripts/battle_controller_visual_presentation.gd"

# Phase 10/11/12/12.5/12.6/12.7/12.9 presentation wrapper.
# Phase 10 replaces final committed slot settling with clear grid-by-grid movement.
# Phase 11 adds event-driven facing turns. Facing never auto-turns merely because
# the opponent is now on the other side.
# Phase 12 decouples target slot and target facing selection.
# Phase 12.5 makes presentation consume the same target slot/facing sequence as
# preview and real resolution: stance move -> stance facing -> action -> effect move.
# Phase 12.6 validates target slot input and consumes explicit hit-time snapshots
# for break/back-hit/death presentation rules.
# Phase 12.7 folds the temporary death visibility guard back into this layer.
# Phase 12.9 folds the SVG FX asset wrapper into this layer so stepwise is the
# single active presentation layer above the base presentation implementation.

const FX_FIREARM_FLASH := "res://assets/pixel_battle/fx/fx_firearm_flash_ink.svg"
const FX_BREAK_INK_CRACK := "res://assets/pixel_battle/fx/fx_break_ink_crack.svg"
const FX_MISS_WISP := "res://assets/pixel_battle/fx/fx_miss_wisp.svg"
const FX_SLASH_INK_ARC := "res://assets/pixel_battle/fx/fx_slash_ink_arc.svg"
const FX_THRUST_INK_LINE := "res://assets/pixel_battle/fx/fx_thrust_ink_line.svg"
const FX_HIT_INK_BURST := "res://assets/pixel_battle/fx/fx_hit_ink_burst.svg"
const FX_GUARD_INK_SHIELD := "res://assets/pixel_battle/fx/fx_guard_ink_shield.svg"
const FX_FOCUS_INK_RIPPLE := "res://assets/pixel_battle/fx/fx_focus_ink_ripple.svg"
const FX_FIREARM_SMOKE_WISP := "res://assets/pixel_battle/fx/fx_firearm_smoke_wisp.svg"

const FX_Z_WISP := 86
const FX_Z_WEAPON := 88
const FX_Z_GUARD := 90
const FX_Z_HIT := 91
const FX_Z_FIREARM := 92
const FX_Z_BREAK := 96

const FX_ALPHA_SLASH := 0.86
const FX_ALPHA_THRUST := 0.88
const FX_ALPHA_HIT := 0.78
const FX_ALPHA_FIREARM_HIT := 0.82
const FX_ALPHA_FIREARM_MISS := 0.42
const FX_ALPHA_MISS := 0.72
const FX_ALPHA_BREAK := 0.92
const FX_ALPHA_GUARD := 0.78
const FX_ALPHA_FOCUS := 0.72
const FX_ALPHA_SMOKE := 0.58

const FX_FADE_SLASH := 0.18
const FX_FADE_THRUST := 0.16
const FX_FADE_HIT := 0.20
const FX_FADE_FIREARM := 0.18
const FX_FADE_MISS := 0.20
const FX_FADE_BREAK := 0.28
const FX_FADE_GUARD := 0.34
const FX_FADE_FOCUS := 0.34
const FX_FADE_SMOKE := 0.44

const FX_SIZE_SLASH := Vector2(270, 116)
const FX_SIZE_SLASH_FINISHER := Vector2(340, 148)
const FX_SIZE_THRUST := Vector2(310, 68)
const FX_SIZE_THRUST_FINISHER := Vector2(380, 82)
const FX_SIZE_HIT := Vector2(108, 82)
const FX_SIZE_HIT_FINISHER := Vector2(142, 108)
const FX_SIZE_FIREARM := Vector2(108, 108)
const FX_SIZE_FIREARM_FINISHER := Vector2(148, 148)
const FX_SIZE_MISS := Vector2(150, 56)
const FX_SIZE_BREAK := Vector2(188, 128)
const FX_SIZE_GUARD := Vector2(132, 112)
const FX_SIZE_FOCUS := Vector2(152, 96)
const FX_SIZE_SMOKE := Vector2(150, 84)

const FX_OFFSET_SLASH := Vector2(0, -18)
const FX_OFFSET_THRUST := Vector2(0, -6)
const FX_OFFSET_HIT := Vector2(0, -2)
const FX_OFFSET_BREAK := Vector2(-44, -4)
const FX_OFFSET_GUARD := Vector2(-58, -38)
const FX_OFFSET_FOCUS := Vector2(-72, 18)
const FX_OFFSET_MISS := Vector2(-66, 8)
const FX_OFFSET_FIREARM_PLAYER := Vector2(10, 12)
const FX_OFFSET_FIREARM_ENEMY := Vector2(-42, 12)
const FX_OFFSET_SMOKE_PLAYER := Vector2(-82, -28)
const FX_OFFSET_SMOKE_ENEMY := Vector2(-118, -28)

const PRESENTATION_STEP_MOVE_DURATION := 0.12
const PRESENTATION_DEATH_HOLD_DURATION := 0.20
const PRESENTATION_STEP_MOVE_PAUSE := 0.045
const PRESENTATION_STEP_MOVE_BOB_Y := -7.0
const PRESENTATION_STEP_MOVE_MAX_STEPS := 8

const PRESENTATION_TURN_PREP_DURATION := 0.06
const PRESENTATION_TURN_FLIP_DURATION := 0.08
const PRESENTATION_TURN_SETTLE_DURATION := 0.06
const PRESENTATION_TURN_COMPRESS_X := 0.82
const PRESENTATION_TURN_SETTLE_Y := 1.04
const PRESENTATION_POST_PLAYER_ACTION_PAUSE := 0.38
const PRESENTATION_ENEMY_ATTACK_START_DELAY_AFTER_PLAYER := 0.20
const PRESENTATION_PRE_ENEMY_ACTION_GLOW_PAUSE := 0.36
const PRESENTATION_POST_ENEMY_ACTION_PAUSE := 0.24
const PRESENTATION_PHASE_CUE_HOLD := 0.58

const ACTOR_GLOW_MARGIN := 16.0
const ACTOR_GLOW_PLAYER_COLOR := Color(0.48, 0.82, 1.0, 0.54)
const ACTOR_GLOW_ENEMY_COLOR := Color(1.0, 0.22, 0.14, 0.58)
const ACTOR_FOCUS_DIM_COLOR := Color(0.68, 0.70, 0.72, 0.74)
const ACTOR_HALO_SIZE := Vector2(142.0, 24.0)
const ACTOR_HALO_PLAYER_COLOR := Color(0.35, 0.76, 1.0, 0.36)
const ACTOR_HALO_ENEMY_COLOR := Color(1.0, 0.23, 0.12, 0.40)
const STAGE_FOCUS_OFFSET_X := 0.0
const PHASE_CUE_SIZE := Vector2(300.0, 48.0)

const FACING_CTX_OLD_PLAYER_FACING := &"facing_ctx_old_player_facing"
const FACING_CTX_OLD_ENEMY_FACING := &"facing_ctx_old_enemy_facing"
const FACING_CTX_OLD_PLAYER_HP := &"facing_ctx_old_player_hp"
const FACING_CTX_OLD_PLAYER_MOMENTUM := &"facing_ctx_old_player_momentum"
const FACING_CTX_PLAYER_ACTION_TARGET_FACING := &"facing_ctx_player_action_target_facing"
const FACING_CTX_PLAYER_TURN_DURING_ACTION := &"facing_ctx_player_turn_during_action"
const FACING_CTX_ENEMY_TURN_DURING_ACTION := &"facing_ctx_enemy_turn_during_action"

var undo_move_button: Button
var _player_draft_visual_active := false
var _player_draft_visual_origin_slot := -1
var _player_draft_visual_origin_facing := ""
var _player_draft_visual_slot := -1
var _player_draft_visual_facing := ""
var _player_draft_move_token := 0
var _player_draft_move_tween: Tween
var _player_draft_turn_tween: Tween
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
var _presentation_player_action_completed_this_exchange := false

func _build_ui() -> void:
	super._build_ui()
	_ensure_undo_move_button()
	_ensure_actor_action_glows()

func _refresh_ui() -> void:
	super._refresh_ui()
	_refresh_undo_move_button()
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

func _mark_player_presentation_action_completed() -> void:
	_presentation_player_action_completed_this_exchange = true

func _reset_player_presentation_action_gate() -> void:
	_presentation_player_action_completed_this_exchange = false

func _wait_for_enemy_attack_start_after_player() -> void:
	if not _presentation_player_action_completed_this_exchange:
		return
	if PRESENTATION_ENEMY_ATTACK_START_DELAY_AFTER_PLAYER <= 0.0:
		return
	await get_tree().create_timer(PRESENTATION_ENEMY_ATTACK_START_DELAY_AFTER_PLAYER).timeout

func _play_guard_presentation(is_player_actor: bool, card: CardData, result: Dictionary) -> void:
	_show_guard_ink_shield(is_player_actor)
	await super._play_guard_presentation(is_player_actor, card, result)

func _play_focus_presentation(is_player_actor: bool, card: CardData, result: Dictionary) -> void:
	_show_focus_ink_ripple(is_player_actor)
	await super._play_focus_presentation(is_player_actor, card, result)

func _show_slash_cut(color: Color, is_finisher: bool = false) -> void:
	var center := _stage_center_position()
	var size_value := FX_SIZE_SLASH if not is_finisher else FX_SIZE_SLASH_FINISHER
	var pos := center - size_value * 0.5 + FX_OFFSET_SLASH
	var fx := _spawn_svg_fx(FX_SLASH_INK_ARC, pos, size_value, -0.08, color, FX_ALPHA_SLASH, FX_Z_WEAPON)
	if fx == null:
		super._show_slash_cut(color, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.20, 1.12), 0.12)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_SLASH)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_pierce_line(color: Color, is_finisher: bool = false) -> void:
	var center := _stage_center_position()
	var size_value := FX_SIZE_THRUST if not is_finisher else FX_SIZE_THRUST_FINISHER
	var pos := center - size_value * 0.5 + FX_OFFSET_THRUST
	var fx := _spawn_svg_fx(FX_THRUST_INK_LINE, pos, size_value, 0.0, color, FX_ALPHA_THRUST, FX_Z_WEAPON)
	if fx == null:
		super._show_pierce_line(color, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale:x", 1.22, 0.10)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_THRUST)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_target_hit_mark(_from_player: bool, color: Color, _profession_id: String = "", is_finisher: bool = false) -> void:
	var center := _stage_center_position()
	var size_value := FX_SIZE_HIT if not is_finisher else FX_SIZE_HIT_FINISHER
	var pos := center - size_value * 0.5 + FX_OFFSET_HIT
	var fx := _spawn_svg_fx(FX_HIT_INK_BURST, pos, size_value, 0.0, color, FX_ALPHA_HIT, FX_Z_HIT)
	if fx == null:
		super._show_target_hit_mark(_from_player, color, _profession_id, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.28, 1.28), 0.11)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_HIT)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_presentation_firearm_flash(is_player_actor: bool, color: Color, should_hit: bool, is_finisher: bool) -> void:
	var origin := _presentation_float_position(is_player_actor) + (FX_OFFSET_FIREARM_PLAYER if is_player_actor else FX_OFFSET_FIREARM_ENEMY)
	var size_value := FX_SIZE_FIREARM if not is_finisher else FX_SIZE_FIREARM_FINISHER
	var alpha := FX_ALPHA_FIREARM_HIT if should_hit else FX_ALPHA_FIREARM_MISS
	var fx := _spawn_svg_fx(FX_FIREARM_FLASH, origin - size_value * 0.5, size_value, 0.0, color, alpha, FX_Z_FIREARM)
	if fx == null:
		super._show_presentation_firearm_flash(is_player_actor, color, should_hit, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.45, 1.45), 0.10)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_FIREARM)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)
	_show_firearm_smoke_wisp(is_player_actor, origin)

func _show_miss_wisp(target_is_player: bool) -> void:
	var start_pos := _presentation_float_position(target_is_player) + FX_OFFSET_MISS
	var fx := _spawn_svg_fx(FX_MISS_WISP, start_pos, FX_SIZE_MISS, 0.0, Color(1, 1, 1, 1), FX_ALPHA_MISS, FX_Z_WEAPON)
	if fx == null:
		super._show_miss_wisp(target_is_player)
		return
	var drift := -42.0 if target_is_player else 42.0
	var tween := create_tween()
	tween.tween_property(fx, "position:x", fx.position.x + drift, FX_FADE_MISS)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_MISS)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _play_break_ink_fx(target_is_player: bool) -> void:
	var center := _presentation_float_position(target_is_player) + FX_OFFSET_BREAK
	var fx := _spawn_svg_fx(FX_BREAK_INK_CRACK, center, FX_SIZE_BREAK, 0.0, Color(1, 1, 1, 1), FX_ALPHA_BREAK, FX_Z_BREAK)
	if fx == null:
		super._play_break_ink_fx(target_is_player)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.22, 1.22), 0.13)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_BREAK)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)
	_show_presentation_float_text("破势", target_is_player, Color("c44a3f"))

func _show_guard_ink_shield(is_player_actor: bool) -> void:
	var pos := _presentation_float_position(is_player_actor) + FX_OFFSET_GUARD
	var fx := _spawn_svg_fx(FX_GUARD_INK_SHIELD, pos, FX_SIZE_GUARD, 0.0, Color(1, 1, 1, 1), FX_ALPHA_GUARD, FX_Z_GUARD)
	if fx == null:
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.12, 1.12), 0.12)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_GUARD)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_focus_ink_ripple(is_player_actor: bool) -> void:
	var pos := _presentation_float_position(is_player_actor) + FX_OFFSET_FOCUS
	var fx := _spawn_svg_fx(FX_FOCUS_INK_RIPPLE, pos, FX_SIZE_FOCUS, 0.0, Color(1, 1, 1, 1), FX_ALPHA_FOCUS, FX_Z_WEAPON - 1)
	if fx == null:
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.22, 1.22), 0.18)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_FOCUS)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_firearm_smoke_wisp(is_player_actor: bool, origin: Vector2) -> void:
	var pos := origin + (FX_OFFSET_SMOKE_PLAYER if is_player_actor else FX_OFFSET_SMOKE_ENEMY)
	var fx := _spawn_svg_fx(FX_FIREARM_SMOKE_WISP, pos, FX_SIZE_SMOKE, 0.0, Color(1, 1, 1, 1), FX_ALPHA_SMOKE, FX_Z_WISP)
	if fx == null:
		return
	var drift := 34.0 if is_player_actor else -34.0
	var tween := create_tween()
	tween.tween_property(fx, "position:x", fx.position.x + drift, 0.38)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, FX_FADE_SMOKE)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _stage_center_position() -> Vector2:
	var stage_area_height := STAGE_AREA_BOTTOM - STAGE_AREA_TOP
	return Vector2(size.x * 0.5, STAGE_AREA_TOP + stage_area_height * 0.48)

func _spawn_svg_fx(path: String, pos: Vector2, size_value: Vector2, rotation_value: float, color: Color, alpha: float, z: int) -> TextureRect:
	var texture := load(path)
	if texture == null:
		return null
	var layer: Control = center_fx_layer if center_fx_layer != null else self
	var fx := TextureRect.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.texture = texture
	fx.size = size_value
	fx.position = pos
	fx.rotation = rotation_value
	fx.z_index = z
	fx.modulate = color
	fx.modulate.a = alpha
	fx.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(fx)
	return fx

func _ensure_undo_move_button() -> void:
	if undo_move_button != null:
		return
	if confirm_button == null or confirm_button.get_parent() == null:
		return
	var parent := confirm_button.get_parent()
	undo_move_button = Button.new()
	undo_move_button.name = "UndoMoveButton"
	undo_move_button.text = "撤销移动(Z)"
	undo_move_button.focus_mode = Control.FOCUS_NONE
	undo_move_button.disabled = true
	undo_move_button.pressed.connect(_on_undo_move_pressed)
	parent.add_child(undo_move_button)
	parent.move_child(undo_move_button, confirm_button.get_index() + 1)
	if has_method("_style_plain_button_once"):
		call("_style_plain_button_once", undo_move_button)

func _refresh_undo_move_button() -> void:
	_ensure_undo_move_button()
	if undo_move_button == null:
		return
	var can_undo := battle_active and awaiting_player_input and draft_player_has_position and _player_draft_visual_active
	undo_move_button.visible = battle_active
	undo_move_button.disabled = not can_undo

func _on_undo_move_pressed() -> void:
	_cancel_player_draft_visual_move()
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false
	if draft_player_intent != null and player != null:
		draft_player_intent.set_stance(player.position, player.facing)
	_refresh_ui()

func _ensure_player_draft_visual_origin() -> void:
	if player == null:
		return
	if _player_draft_visual_active:
		return
	_player_draft_visual_active = true
	_player_draft_visual_origin_slot = player.position
	_player_draft_visual_origin_facing = player.facing
	_player_draft_visual_slot = player.position
	_player_draft_visual_facing = player.facing

func _play_player_draft_visual_to(target_slot: int, target_facing: String) -> void:
	if player == null or not _player_draft_visual_active:
		return
	_player_draft_move_token += 1
	var token := _player_draft_move_token
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	var start_slot: int = _player_draft_visual_slot if _is_valid_presentation_slot(_player_draft_visual_slot) else _player_draft_visual_origin_slot
	var safe_target_slot: int = clampi(target_slot, 0, GRID_SLOT_COUNT - 1)
	var safe_target_facing: String = target_facing if _is_valid_facing(target_facing) else _player_draft_visual_origin_facing
	call_deferred("_run_player_draft_visual_to", token, start_slot, safe_target_slot, safe_target_facing)

func _run_player_draft_visual_to(token: int, start_slot: int, target_slot: int, target_facing: String) -> void:
	if not _player_draft_visual_active or token != _player_draft_move_token:
		return
	_apply_visual_facing(true, _player_draft_visual_facing)
	var current_slot: int = start_slot
	while current_slot != target_slot and token == _player_draft_move_token:
		var next_slot: int = current_slot + (1 if target_slot > current_slot else -1)
		var from_offset := _slot_offset_between(true, current_slot, _player_draft_visual_origin_slot)
		var to_offset := _slot_offset_between(true, next_slot, _player_draft_visual_origin_slot)
		await _tween_player_draft_one_grid_step(token, from_offset, to_offset)
		current_slot = next_slot
		_player_draft_visual_slot = current_slot
	if token != _player_draft_move_token:
		return
	_player_draft_visual_slot = target_slot
	var final_offset := _slot_offset_between(true, target_slot, _player_draft_visual_origin_slot)
	_set_player_presentation_offset(final_offset)
	if _is_valid_facing(target_facing) and target_facing != _player_draft_visual_facing:
		await _play_player_draft_visual_turn(token, _player_draft_visual_facing, target_facing)
	if token != _player_draft_move_token:
		return
	_player_draft_visual_facing = target_facing

func _tween_player_draft_one_grid_step(token: int, from_offset: Vector2, to_offset: Vector2) -> void:
	var mid_offset := from_offset.lerp(to_offset, 0.55) + Vector2(0.0, PRESENTATION_STEP_MOVE_BOB_Y)
	_player_draft_move_tween = create_tween()
	_player_draft_move_tween.tween_method(Callable(self, "_set_player_presentation_offset"), from_offset, mid_offset, PRESENTATION_STEP_MOVE_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_player_draft_move_tween.tween_method(Callable(self, "_set_player_presentation_offset"), mid_offset, to_offset, PRESENTATION_STEP_MOVE_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _player_draft_move_tween.finished
	if token != _player_draft_move_token:
		return

func _play_player_draft_visual_turn(token: int, from_facing: String, to_facing: String) -> void:
	var node: CanvasItem = _presentation_visual_node(true)
	if node == null:
		_apply_visual_facing(true, to_facing)
		return
	_apply_visual_facing(true, from_facing)
	if node is TextureRect:
		var sprite := node as TextureRect
		sprite.pivot_offset = sprite.size * 0.5
		var sprite_scale := sprite.scale
		var sprite_base_x: float = maxf(absf(sprite_scale.x), 1.0)
		var sprite_base_y: float = maxf(absf(sprite_scale.y), 1.0)
		_player_draft_turn_tween = create_tween()
		_player_draft_turn_tween.tween_property(sprite, "scale", Vector2(sprite_base_x * PRESENTATION_TURN_COMPRESS_X, sprite_base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
		_player_draft_turn_tween.tween_callback(Callable(self, "_apply_texture_rect_facing").bind(sprite, to_facing))
		_player_draft_turn_tween.tween_property(sprite, "scale", Vector2(sprite_base_x, sprite_base_y), PRESENTATION_TURN_FLIP_DURATION + PRESENTATION_TURN_SETTLE_DURATION)
		await _player_draft_turn_tween.finished
	elif node is Control:
		var control := node as Control
		control.pivot_offset = control.size * 0.5
		var base_scale := control.scale
		var base_x: float = maxf(absf(base_scale.x), 1.0)
		var base_y: float = maxf(absf(base_scale.y), 1.0)
		_player_draft_turn_tween = create_tween()
		_player_draft_turn_tween.tween_property(control, "scale", Vector2(base_x * _facing_sign(from_facing) * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
		_player_draft_turn_tween.tween_property(control, "scale", Vector2(base_x * _facing_sign(to_facing) * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
		_player_draft_turn_tween.tween_property(control, "scale", Vector2(base_x * _facing_sign(to_facing), base_y), PRESENTATION_TURN_SETTLE_DURATION)
		await _player_draft_turn_tween.finished
	elif node is Node2D:
		var node2d := node as Node2D
		var base_scale2 := node2d.scale
		var base_x2: float = maxf(absf(base_scale2.x), 1.0)
		var base_y2: float = maxf(absf(base_scale2.y), 1.0)
		_player_draft_turn_tween = create_tween()
		_player_draft_turn_tween.tween_property(node2d, "scale", Vector2(base_x2 * _facing_sign(from_facing) * PRESENTATION_TURN_COMPRESS_X, base_y2 * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
		_player_draft_turn_tween.tween_property(node2d, "scale", Vector2(base_x2 * _facing_sign(to_facing) * PRESENTATION_TURN_COMPRESS_X, base_y2 * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
		_player_draft_turn_tween.tween_property(node2d, "scale", Vector2(base_x2 * _facing_sign(to_facing), base_y2), PRESENTATION_TURN_SETTLE_DURATION)
		await _player_draft_turn_tween.finished
	if token != _player_draft_move_token:
		return
	_apply_visual_facing(true, to_facing)
	_set_actor_facing_state(true, to_facing)

func _cancel_player_draft_visual_move() -> void:
	_player_draft_move_token += 1
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	_player_draft_move_tween = null
	if _player_draft_turn_tween != null and _player_draft_turn_tween.is_valid():
		_player_draft_turn_tween.kill()
	_player_draft_turn_tween = null
	_player_draft_visual_active = false
	_player_draft_visual_slot = -1
	_player_draft_visual_facing = ""
	_set_player_presentation_offset(Vector2.ZERO)
	if _is_valid_facing(_player_draft_visual_origin_facing):
		_apply_visual_facing(true, _player_draft_visual_origin_facing)
		_set_actor_facing_state(true, _player_draft_visual_origin_facing)
	_player_draft_visual_origin_slot = -1
	_player_draft_visual_origin_facing = ""

func _finish_player_draft_visual_instant() -> void:
	if not _player_draft_visual_active:
		return
	_player_draft_move_token += 1
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	_player_draft_move_tween = null
	if _player_draft_turn_tween != null and _player_draft_turn_tween.is_valid():
		_player_draft_turn_tween.kill()
	_player_draft_turn_tween = null
	var target_slot: int = draft_player_position if draft_player_has_position else _player_draft_visual_origin_slot
	var target_facing: String = draft_player_facing if _is_valid_facing(draft_player_facing) else _player_draft_visual_origin_facing
	if _is_valid_presentation_slot(target_slot) and _is_valid_presentation_slot(_player_draft_visual_origin_slot):
		_set_player_presentation_offset(_slot_offset_between(true, target_slot, _player_draft_visual_origin_slot))
	if _is_valid_facing(target_facing):
		_apply_visual_facing(true, target_facing)
		_set_actor_facing_state(true, target_facing)
	_player_draft_visual_slot = target_slot
	_player_draft_visual_facing = target_facing

func _freeze_player_draft_visual_for_confirm() -> void:
	if not _player_draft_visual_active:
		return
	_player_draft_move_token += 1
	if _player_draft_move_tween != null and _player_draft_move_tween.is_valid():
		_player_draft_move_tween.kill()
	_player_draft_move_tween = null
	if _player_draft_turn_tween != null and _player_draft_turn_tween.is_valid():
		_player_draft_turn_tween.kill()
	_player_draft_turn_tween = null
	if _is_valid_presentation_slot(_player_draft_visual_slot) and _is_valid_presentation_slot(_player_draft_visual_origin_slot):
		_set_player_presentation_offset(_slot_offset_between(true, _player_draft_visual_slot, _player_draft_visual_origin_slot))
	if _is_valid_facing(_player_draft_visual_facing):
		_apply_visual_facing(true, _player_draft_visual_facing)

func _consume_player_draft_visual_start_slot(default_slot: int) -> int:
	if not _player_draft_visual_active:
		return default_slot
	var slot_value: int = _player_draft_visual_slot
	if not _is_valid_presentation_slot(slot_value) and draft_player_has_position:
		slot_value = draft_player_position
	_player_draft_visual_active = false
	_player_draft_visual_origin_slot = -1
	_player_draft_visual_origin_facing = ""
	_player_draft_visual_slot = -1
	_player_draft_visual_facing = ""
	return slot_value if _is_valid_presentation_slot(slot_value) else default_slot

func _should_hide_player_preview_ghost() -> bool:
	return _player_draft_visual_active

func _on_stage_grid_slot_pressed(slot: int) -> void:
	if player == null or not battle_active or not awaiting_player_input:
		return
	var clicked_slot: int = clampi(slot, 0, GRID_SLOT_COUNT - 1)
	var current_target_slot: int = _current_player_target_slot()
	var current_target_facing: String = _current_player_target_facing()
	var next_facing: String = current_target_facing
	if clicked_slot == current_target_slot:
		next_facing = _opposite_facing(current_target_facing)
	else:
		if not _is_legal_player_target_slot(clicked_slot):
			_show_illegal_target_feedback(clicked_slot)
			return
		next_facing = player.facing
	_ensure_player_draft_visual_origin()
	_set_player_draft_target(clicked_slot, next_facing)
	_play_player_draft_visual_to(clicked_slot, next_facing)
	_refresh_ui()

func _is_legal_player_target_slot(slot: int) -> bool:
	if player == null:
		return false
	if not _is_valid_presentation_slot(slot):
		return false
	if enemy != null and enemy.hp > 0 and slot == enemy.position:
		return false
	var max_steps: int = maxi(player.qinggong, 0)
	var origin_slot: int = _player_draft_visual_origin_slot if _player_draft_visual_active and _is_valid_presentation_slot(_player_draft_visual_origin_slot) else player.position
	return absi(slot - origin_slot) <= max_steps

func _show_illegal_target_feedback(slot: int) -> void:
	if has_method("_show_combat_banner"):
		_show_combat_banner("无法移动到%s" % _slot_label_safe_local(slot), Color("2a2018"), Color("ffd479"))

func _slot_label_safe_local(slot: int) -> String:
	var labels := ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot

func _current_player_target_slot() -> int:
	if player == null:
		return 0
	if draft_player_has_position:
		return clampi(draft_player_position, 0, GRID_SLOT_COUNT - 1)
	if draft_player_intent != null and draft_player_intent.target_position >= 0:
		return clampi(draft_player_intent.target_position, 0, GRID_SLOT_COUNT - 1)
	return clampi(player.position, 0, GRID_SLOT_COUNT - 1)

func _current_player_target_facing() -> String:
	if player == null:
		return "right"
	if draft_player_has_position and _is_valid_facing(draft_player_facing):
		return draft_player_facing
	if draft_player_intent != null and _is_valid_facing(draft_player_intent.target_facing):
		return draft_player_intent.target_facing
	return player.facing if _is_valid_facing(player.facing) else "right"

func _set_player_draft_target(slot: int, facing_value: String) -> void:
	draft_player_position = clampi(slot, 0, GRID_SLOT_COUNT - 1)
	draft_player_facing = facing_value if _is_valid_facing(facing_value) else (player.facing if player != null and _is_valid_facing(player.facing) else "right")
	draft_player_has_position = true
	_sync_draft_intent_to_target()

func _reset_draft_intent() -> void:
	_cancel_player_draft_visual_move()
	super._reset_draft_intent()

func _sync_draft_intent_to_target() -> void:
	if not draft_player_has_position:
		return
	if draft_player_intent == null:
		return
	draft_player_intent.set_stance(draft_player_position, draft_player_facing)

func _confirm_player_intent() -> void:
	_freeze_player_draft_visual_for_confirm()
	_sync_draft_intent_to_target()
	_capture_presentation_facing_context()
	super._confirm_player_intent()

func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_reset_presentation_offsets()
	_reset_player_presentation_action_gate()
	var visual_player_slot: int = _consume_player_draft_visual_start_slot(old_player_slot)
	_apply_pre_resolution_slot_offsets(visual_player_slot, old_enemy_slot)
	var visual_enemy_slot: int = old_enemy_slot
	for side: String in order:
		if side == "player" and player_card != null:
			var player_move_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "move")
			visual_player_slot = await _apply_presentation_stance_step(true, visual_player_slot, player.position, player_card, player_move_step)
			await _play_one_presentation_action(true, player_card, _presentation_result_for_side(preview_sim, "player"))
			_mark_player_presentation_action_completed()
			var player_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "player", "effect_move")
			visual_player_slot = await _apply_presentation_effect_actor_step(true, visual_player_slot, player.position, player_effect_step)
			visual_enemy_slot = await _apply_presentation_effect_target_step(false, visual_enemy_slot, enemy.position, player_effect_step)
		elif side == "enemy" and enemy_card != null:
			var enemy_move_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "move")
			visual_enemy_slot = await _apply_presentation_stance_step(false, visual_enemy_slot, enemy.position, enemy_card, enemy_move_step)
			await _wait_for_enemy_attack_start_after_player()
			await _play_one_presentation_action(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"))
			var enemy_effect_step: Dictionary = _presentation_step_for_side(preview_sim, "enemy", "effect_move")
			visual_enemy_slot = await _apply_presentation_effect_actor_step(false, visual_enemy_slot, enemy.position, enemy_effect_step)
			visual_player_slot = await _apply_presentation_effect_target_step(true, visual_player_slot, player.position, enemy_effect_step)
	await _settle_visual_slots_to_committed_positions(visual_player_slot, visual_enemy_slot)
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_reset_presentation_offsets()
	_set_presentation_busy(false)

func _apply_presentation_stance_step(is_player_actor: bool, visual_slot: int, committed_slot: int, card: CardData, move_step: Dictionary) -> int:
	var target_slot: int = int(move_step.get("to", visual_slot)) if not move_step.is_empty() else visual_slot
	var target_facing: String = str(move_step.get("facing", "")) if not move_step.is_empty() else ""
	if _is_valid_presentation_slot(target_slot) and target_slot != visual_slot:
		await _animate_actor_visual_slots_stepwise(is_player_actor, visual_slot, target_slot, committed_slot)
		visual_slot = target_slot
	if _is_valid_facing(target_facing) and not _card_has_turn_during_action(card):
		var from_facing: String = _actor_old_or_current_facing(is_player_actor)
		await _play_facing_turn(is_player_actor, target_facing, from_facing)
	return visual_slot

func _apply_presentation_effect_actor_step(is_player_actor: bool, visual_slot: int, committed_slot: int, effect_step: Dictionary) -> int:
	if effect_step.is_empty():
		return visual_slot
	var target_slot: int = int(effect_step.get("actor_to", visual_slot))
	if not _is_valid_presentation_slot(target_slot) or target_slot == visual_slot:
		return visual_slot
	await _animate_actor_visual_slots_stepwise(is_player_actor, visual_slot, target_slot, committed_slot)
	return target_slot

func _apply_presentation_effect_target_step(is_player_actor: bool, visual_slot: int, committed_slot: int, effect_step: Dictionary) -> int:
	if effect_step.is_empty():
		return visual_slot
	var target_slot: int = int(effect_step.get("target_to", visual_slot))
	if not _is_valid_presentation_slot(target_slot) or target_slot == visual_slot:
		return visual_slot
	await _animate_actor_visual_slots_stepwise(is_player_actor, visual_slot, target_slot, committed_slot)
	return target_slot

func _settle_visual_slots_to_committed_positions(visual_player_slot: int, visual_enemy_slot: int) -> void:
	var did_settle := false
	if player != null and _is_valid_presentation_slot(visual_player_slot) and _is_valid_presentation_slot(player.position) and visual_player_slot != player.position:
		did_settle = true
		await _animate_actor_visual_slots_stepwise(true, visual_player_slot, player.position, player.position)
	if enemy != null and _is_valid_presentation_slot(visual_enemy_slot) and _is_valid_presentation_slot(enemy.position) and visual_enemy_slot != enemy.position:
		did_settle = true
		await _animate_actor_visual_slots_stepwise(false, visual_enemy_slot, enemy.position, enemy.position)
	if not did_settle:
		await _settle_committed_slot_offsets()

func _play_one_presentation_action(is_player_actor: bool, card: CardData, result: Dictionary) -> void:
	if card == null:
		return
	if _card_has_turn_during_action(card):
		var turn_to: String = _turn_during_action_target_facing(is_player_actor, card)
		if _is_valid_facing(turn_to):
			await _play_facing_turn(is_player_actor, turn_to, _actor_old_or_current_facing(is_player_actor))
	await super._play_one_presentation_action(is_player_actor, card, result)
	if not is_player_actor:
		await _maybe_turn_player_after_back_hit(result)

func _presentation_result_for_side(preview_sim: Dictionary, side: String) -> Dictionary:
	var result: Dictionary = super._presentation_result_for_side(preview_sim, side)
	var effect_step: Dictionary = _presentation_step_for_side(preview_sim, side, "effect")
	if effect_step.is_empty():
		return result
	result["will_break"] = bool(effect_step.get("will_break", false))
	result["will_die"] = bool(effect_step.get("will_die", false))
	result["was_back_hit"] = bool(effect_step.get("was_back_hit", false))
	result["back_hit_turn_to"] = str(effect_step.get("back_hit_turn_to", ""))
	return result

func _presentation_target_will_break(_target_is_player: bool, result: Dictionary) -> bool:
	if result.has("will_break"):
		return bool(result.get("will_break", false))
	return super._presentation_target_will_break(_target_is_player, result)

func _play_presentation_death(is_player_actor: bool) -> void:
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null:
		return
	await get_tree().create_timer(PRESENTATION_DEATH_HOLD_DURATION).timeout
	var start_offset: Vector2 = _presentation_offset(is_player_actor)
	var end_offset := start_offset + Vector2(0, 30)
	_tween_actor_offset(is_player_actor, start_offset, end_offset, 0.26, Tween.TRANS_QUAD, Tween.EASE_IN)
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.26)
	await get_tree().create_timer(0.28).timeout
	node.visible = false

func _settle_committed_slot_offsets_stepwise(old_player_slot: int, old_enemy_slot: int) -> void:
	var did_stepwise_settle := false
	if player != null and _is_valid_presentation_slot(old_player_slot) and _is_valid_presentation_slot(player.position) and old_player_slot != player.position:
		did_stepwise_settle = true
		await _animate_actor_committed_slots_stepwise(true, old_player_slot, player.position)
	if enemy != null and _is_valid_presentation_slot(old_enemy_slot) and _is_valid_presentation_slot(enemy.position) and old_enemy_slot != enemy.position:
		did_stepwise_settle = true
		await _animate_actor_committed_slots_stepwise(false, old_enemy_slot, enemy.position)
	if not did_stepwise_settle:
		await _settle_committed_slot_offsets()

func _animate_actor_committed_slots_stepwise(is_player_actor: bool, from_slot: int, to_slot: int) -> void:
	var committed_slot: int = player.position if is_player_actor and player != null else enemy.position if not is_player_actor and enemy != null else to_slot
	await _animate_actor_visual_slots_stepwise(is_player_actor, from_slot, to_slot, committed_slot)

func _animate_actor_visual_slots_stepwise(is_player_actor: bool, from_slot: int, to_slot: int, committed_slot: int) -> void:
	if from_slot == to_slot:
		return
	var step_dir := 1 if to_slot > from_slot else -1
	var current_slot := from_slot
	var step_count := 0
	while current_slot != to_slot and step_count < PRESENTATION_STEP_MOVE_MAX_STEPS:
		var next_slot := current_slot + step_dir
		if not _is_valid_presentation_slot(next_slot):
			break
		var from_offset := _slot_offset_between(is_player_actor, current_slot, committed_slot)
		var to_offset := _slot_offset_between(is_player_actor, next_slot, committed_slot)
		await _tween_actor_one_grid_step(is_player_actor, from_offset, to_offset)
		current_slot = next_slot
		step_count += 1
		if current_slot != to_slot:
			await get_tree().create_timer(PRESENTATION_STEP_MOVE_PAUSE).timeout
	if current_slot != to_slot:
		var current_offset: Vector2 = _presentation_offset(is_player_actor)
		var final_offset := _slot_offset_between(is_player_actor, to_slot, committed_slot)
		_tween_actor_offset(is_player_actor, current_offset, final_offset, PRESENTATION_SLOT_SETTLE_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
		await get_tree().create_timer(PRESENTATION_SLOT_SETTLE_DURATION + 0.02).timeout

func _tween_actor_one_grid_step(is_player_actor: bool, from_offset: Vector2, to_offset: Vector2) -> void:
	var setter: Callable = Callable(self, "_set_player_presentation_offset") if is_player_actor else Callable(self, "_set_enemy_presentation_offset")
	var mid_offset := from_offset.lerp(to_offset, 0.55) + Vector2(0.0, PRESENTATION_STEP_MOVE_BOB_Y)
	var tween := create_tween()
	tween.tween_method(setter, from_offset, mid_offset, PRESENTATION_STEP_MOVE_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(setter, mid_offset, to_offset, PRESENTATION_STEP_MOVE_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

func _capture_presentation_facing_context() -> void:
	var old_player_slot: int = player.position if player != null else -1
	var old_player_facing: String = player.facing if player != null else ""
	var old_enemy_facing: String = enemy.facing if enemy != null else ""
	var old_player_hp: int = player.hp if player != null else 0
	var old_player_momentum: int = player.momentum if player != null else 0
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = _intent_card(p_intent)
	var e_card: CardData = _intent_card(e_intent)
	set_meta(FACING_CTX_OLD_PLAYER_FACING, old_player_facing)
	set_meta(FACING_CTX_OLD_ENEMY_FACING, old_enemy_facing)
	set_meta(FACING_CTX_OLD_PLAYER_HP, old_player_hp)
	set_meta(FACING_CTX_OLD_PLAYER_MOMENTUM, old_player_momentum)
	set_meta(FACING_CTX_PLAYER_ACTION_TARGET_FACING, _action_target_facing(p_intent, old_player_slot))
	set_meta(FACING_CTX_PLAYER_TURN_DURING_ACTION, _card_has_turn_during_action(p_card))
	set_meta(FACING_CTX_ENEMY_TURN_DURING_ACTION, _card_has_turn_during_action(e_card))
	# No automatic turn is derived from relative position.

func _maybe_turn_player_after_action_target() -> void:
	# Kept for compatibility with older flows. Phase 12.5 now performs ordinary
	# target-facing turns before the action, after target-slot movement.
	return

func _maybe_turn_player_after_back_hit(result: Dictionary) -> void:
	if player == null or enemy == null:
		return
	if not bool(result.get("was_back_hit", _is_back_hit_on_player(result))):
		return
	if bool(result.get("will_die", false)) or bool(result.get("will_break", false)):
		return
	if player.hp <= 0:
		return
	var turn_to: String = str(result.get("back_hit_turn_to", ""))
	if not _is_valid_facing(turn_to):
		turn_to = _facing_toward_slot(player.position, enemy.position)
	if not _is_valid_facing(turn_to):
		return
	await _play_facing_turn(true, turn_to, player.facing)

func _is_back_hit_on_player(result: Dictionary) -> bool:
	if player == null or enemy == null:
		return false
	var range_result: String = str(result.get("range", ""))
	if range_result != "hit" and range_result != "graze":
		return false
	var damage_value: int = int(result.get("damage", 0))
	var break_value: int = int(result.get("break", 0))
	if damage_value <= 0 and break_value <= 0:
		return false
	return _facing_exposes_back_to_slot(player.facing, player.position, enemy.position)

func _presentation_step_for_side(preview_sim: Dictionary, side: String, phase: String) -> Dictionary:
	var steps_value = preview_sim.get("steps", [])
	if not (steps_value is Array):
		return {}
	for step_value in steps_value:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if str(step.get("side", "")) == side and str(step.get("phase", "")) == phase:
			return step
	return {}

func _action_target_facing(intent: IntentData, old_slot: int) -> String:
	if intent == null:
		return ""
	if _is_valid_facing(intent.target_facing):
		return intent.target_facing
	if intent.target_position >= 0 and old_slot >= 0:
		if intent.target_position > old_slot:
			return "right"
		if intent.target_position < old_slot:
			return "left"
	return ""

func _card_has_turn_during_action(card: CardData) -> bool:
	if card == null:
		return false
	if _card_has_tag(card, "转身") or _card_has_tag(card, "回身") or _card_has_tag(card, "反身") or _card_has_tag(card, "翻身") or _card_has_tag(card, "回马"):
		return true
	var id_text: String = str(card.id)
	var name_text: String = str(card.display_name)
	return id_text.findn("turn") >= 0 or id_text.findn("reverse") >= 0 or id_text.findn("backturn") >= 0 or name_text.find("转身") >= 0 or name_text.find("回身") >= 0 or name_text.find("反身") >= 0 or name_text.find("翻身") >= 0 or name_text.find("回马") >= 0

func _turn_during_action_target_facing(is_player_actor: bool, _card: CardData) -> String:
	var intent: IntentData = (draft_player_intent if draft_player_intent != null else player_intent) if is_player_actor else enemy_intent
	var actor: Fighter = player if is_player_actor else enemy
	var old_facing: String = _actor_old_or_current_facing(is_player_actor)
	if intent != null and _is_valid_facing(intent.target_facing):
		return intent.target_facing
	if intent != null and actor != null and intent.target_position >= 0:
		var target_facing := _action_target_facing(intent, actor.position)
		if _is_valid_facing(target_facing):
			return target_facing
	return _opposite_facing(old_facing)

func _play_facing_turn(is_player_actor: bool, to_facing: String, from_facing: String = "") -> void:
	if not _is_valid_facing(to_facing):
		return
	var actor: Fighter = player if is_player_actor else enemy
	if actor == null or actor.hp <= 0:
		return
	var safe_from := from_facing if _is_valid_facing(from_facing) else actor.facing
	if safe_from == to_facing:
		_set_actor_facing_state(is_player_actor, to_facing)
		_apply_visual_facing(is_player_actor, to_facing)
		return
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null:
		_set_actor_facing_state(is_player_actor, to_facing)
		return
	_apply_visual_facing(is_player_actor, safe_from)
	if node is TextureRect:
		await _play_texture_rect_facing_turn(node as TextureRect, safe_from, to_facing)
	elif node is Control:
		await _play_control_facing_turn(node as Control, safe_from, to_facing)
	elif node is Node2D:
		await _play_node2d_facing_turn(node as Node2D, safe_from, to_facing)
	else:
		_set_actor_facing_state(is_player_actor, to_facing)
		return
	_set_actor_facing_state(is_player_actor, to_facing)
	_apply_visual_facing(is_player_actor, to_facing)

func _play_texture_rect_facing_turn(node: TextureRect, from_facing: String, to_facing: String) -> void:
	_apply_texture_rect_facing(node, from_facing)
	node.pivot_offset = node.size * 0.5
	var base_scale := node.scale
	var base_x: float = maxf(absf(base_scale.x), 1.0)
	var base_y: float = maxf(absf(base_scale.y), 1.0)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base_x * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
	tween.tween_callback(Callable(self, "_apply_texture_rect_facing").bind(node, to_facing))
	tween.tween_property(node, "scale", Vector2(base_x, base_y), PRESENTATION_TURN_FLIP_DURATION + PRESENTATION_TURN_SETTLE_DURATION)
	await tween.finished

func _play_control_facing_turn(node: Control, from_facing: String, to_facing: String) -> void:
	node.pivot_offset = node.size * 0.5
	var base_scale := node.scale
	var base_x: float = maxf(absf(base_scale.x), 1.0)
	var base_y: float = maxf(absf(base_scale.y), 1.0)
	var from_sign: float = _facing_sign(from_facing)
	var to_sign: float = _facing_sign(to_facing)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base_x * from_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign, base_y), PRESENTATION_TURN_SETTLE_DURATION)
	await tween.finished

func _play_node2d_facing_turn(node: Node2D, from_facing: String, to_facing: String) -> void:
	var base_scale := node.scale
	var base_x: float = maxf(absf(base_scale.x), 1.0)
	var base_y: float = maxf(absf(base_scale.y), 1.0)
	var from_sign: float = _facing_sign(from_facing)
	var to_sign: float = _facing_sign(to_facing)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base_x * from_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_PREP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign * PRESENTATION_TURN_COMPRESS_X, base_y * PRESENTATION_TURN_SETTLE_Y), PRESENTATION_TURN_FLIP_DURATION)
	tween.tween_property(node, "scale", Vector2(base_x * to_sign, base_y), PRESENTATION_TURN_SETTLE_DURATION)
	await tween.finished

func _apply_visual_facing(is_player_actor: bool, facing_value: String) -> void:
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null or not _is_valid_facing(facing_value):
		return
	if node is TextureRect:
		_apply_texture_rect_facing(node as TextureRect, facing_value)
	elif node is Control:
		var control := node as Control
		control.pivot_offset = control.size * 0.5
		var control_scale := control.scale
		var control_base_x: float = maxf(absf(control_scale.x), 1.0)
		var control_base_y: float = maxf(absf(control_scale.y), 1.0)
		control.scale = Vector2(control_base_x * _facing_sign(facing_value), control_base_y)
	elif node is Node2D:
		var node2d := node as Node2D
		var node2d_scale := node2d.scale
		var node2d_base_x: float = maxf(absf(node2d_scale.x), 1.0)
		var node2d_base_y: float = maxf(absf(node2d_scale.y), 1.0)
		node2d.scale = Vector2(node2d_base_x * _facing_sign(facing_value), node2d_base_y)

func _apply_texture_rect_facing(sprite: TextureRect, facing_value: String) -> void:
	if sprite == null or not _is_valid_facing(facing_value):
		return
	sprite.flip_h = facing_value == "left"
	var sprite_scale := sprite.scale
	sprite.scale = Vector2(maxf(absf(sprite_scale.x), 1.0), maxf(absf(sprite_scale.y), 1.0))
	_sync_actor_action_glows()

func _set_actor_facing_state(is_player_actor: bool, facing_value: String) -> void:
	if not _is_valid_facing(facing_value):
		return
	if is_player_actor and player != null:
		player.facing = facing_value
	elif not is_player_actor and enemy != null:
		enemy.facing = facing_value

func _actor_old_or_current_facing(is_player_actor: bool) -> String:
	if is_player_actor:
		var old_player_facing: String = str(get_meta(FACING_CTX_OLD_PLAYER_FACING, ""))
		if _is_valid_facing(old_player_facing):
			return old_player_facing
		return player.facing if player != null else ""
	var old_enemy_facing: String = str(get_meta(FACING_CTX_OLD_ENEMY_FACING, ""))
	if _is_valid_facing(old_enemy_facing):
		return old_enemy_facing
	return enemy.facing if enemy != null else ""

func _facing_exposes_back_to_slot(facing_value: String, actor_slot: int, attacker_slot: int) -> bool:
	if not _is_valid_facing(facing_value):
		return false
	if attacker_slot > actor_slot:
		return facing_value == "left"
	if attacker_slot < actor_slot:
		return facing_value == "right"
	return false

func _facing_toward_slot(actor_slot: int, target_slot: int) -> String:
	if target_slot > actor_slot:
		return "right"
	if target_slot < actor_slot:
		return "left"
	return ""

func _opposite_facing(facing_value: String) -> String:
	if facing_value == "left":
		return "right"
	if facing_value == "right":
		return "left"
	return ""

func _facing_sign(facing_value: String) -> float:
	return -1.0 if facing_value == "left" else 1.0

func _is_valid_facing(facing_value: String) -> bool:
	return facing_value == "left" or facing_value == "right"

func _is_valid_presentation_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < GRID_SLOT_COUNT
