extends "res://scripts/battle_controller_visual_presentation.gd"

# Phase 6/7/8/9 assetized battle FX wrapper.
# Keep the timing/result presentation logic in battle_controller_visual_presentation.gd,
# and only replace selected ColorRect placeholder FX with lightweight SVG assets.
# Phase 9 centralizes visual tuning constants so size/alpha/offset tweaks stay local.

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
