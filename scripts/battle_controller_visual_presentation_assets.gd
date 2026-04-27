extends "res://scripts/battle_controller_visual_presentation.gd"

# Phase 6 assetized battle FX wrapper.
# Keep the timing/result presentation logic in battle_controller_visual_presentation.gd,
# and only replace selected ColorRect placeholder FX with lightweight SVG assets.

const FX_FIREARM_FLASH := "res://assets/pixel_battle/fx/fx_firearm_flash_ink.svg"
const FX_BREAK_INK_CRACK := "res://assets/pixel_battle/fx/fx_break_ink_crack.svg"
const FX_MISS_WISP := "res://assets/pixel_battle/fx/fx_miss_wisp.svg"

func _show_presentation_firearm_flash(is_player_actor: bool, color: Color, should_hit: bool, is_finisher: bool) -> void:
	var origin := _presentation_float_position(is_player_actor) + Vector2(10 if is_player_actor else -42, 12)
	var size_value := Vector2(108, 108) if not is_finisher else Vector2(148, 148)
	var alpha := 0.82 if should_hit else 0.42
	var fx := _spawn_svg_fx(FX_FIREARM_FLASH, origin - size_value * 0.5, size_value, 0.0, color, alpha, 92)
	if fx == null:
		super._show_presentation_firearm_flash(is_player_actor, color, should_hit, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.45, 1.45), 0.10)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _show_miss_wisp(target_is_player: bool) -> void:
	var start_pos := _presentation_float_position(target_is_player) + Vector2(-66, 8)
	var fx := _spawn_svg_fx(FX_MISS_WISP, start_pos, Vector2(150, 56), 0.0, Color(1, 1, 1, 1), 0.72, 88)
	if fx == null:
		super._show_miss_wisp(target_is_player)
		return
	var drift := -42.0 if target_is_player else 42.0
	var tween := create_tween()
	tween.tween_property(fx, "position:x", fx.position.x + drift, 0.20)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, 0.20)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)

func _play_break_ink_fx(target_is_player: bool) -> void:
	var center := _presentation_float_position(target_is_player) + Vector2(-44, -4)
	var fx := _spawn_svg_fx(FX_BREAK_INK_CRACK, center, Vector2(188, 128), 0.0, Color(1, 1, 1, 1), 0.92, 96)
	if fx == null:
		super._play_break_ink_fx(target_is_player)
		return
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(1.22, 1.22), 0.13)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, 0.28)
	tween.finished.connect(func() -> void:
		fx.queue_free()
	)
	_show_presentation_float_text("破势", target_is_player, Color("c44a3f"))

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
