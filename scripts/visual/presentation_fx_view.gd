extends RefCounted

const MOMENTUM_DOT_ANIMATING_META := &"momentum_dot_animation_busy"
const MOMENTUM_DOT_FLASH_DURATION := 0.28
const MOMENTUM_DOT_GAIN_FLASH_DURATION := 0.44
const MOMENTUM_DOT_SETTLE_DURATION := 0.16
const MOMENTUM_DOT_GAIN_SETTLE_DURATION := 0.26
const MOMENTUM_DOT_LOSS_COLOR := Color("777a80")
const MOMENTUM_DOT_GAIN_COLOR := Color("f7fbff")

var c

func _init(controller) -> void:
	c = controller

func show_float_text(text: String, target_is_player: bool, color: Color) -> void:
	var layer: Control = c.center_fx_layer if c.center_fx_layer != null else c
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 120
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = presentation_float_position(target_is_player)
	layer.add_child(label)
	var tween: Tween = c.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.48)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.48)
	tween.finished.connect(func() -> void:
		label.queue_free()
	)

func play_momentum_delta(is_player_actor: bool, result: Dictionary) -> void:
	var break_value: int = max(0, int(result.get("break", 0)))
	var gain_value: int = max(0, int(result.get("gain", 0)))
	if break_value > 0:
		var target_before: int = int(result.get("target_momentum_before", -1))
		var target_after: int = int(result.get("target_momentum_after", -1))
		if target_before >= 0 and target_after >= 0:
			await animate_momentum_dots_between(not is_player_actor, target_before, target_after, false)
		else:
			await animate_momentum_dots(not is_player_actor, -break_value)
	if gain_value > 0:
		var actor_before: int = int(result.get("actor_momentum_before", -1))
		var actor_after: int = int(result.get("actor_momentum_after", -1))
		if actor_before >= 0 and actor_after >= 0:
			await animate_momentum_dots_between(is_player_actor, actor_before, actor_after, true)
		else:
			await animate_momentum_dots(is_player_actor, gain_value)

func animate_momentum_dots(is_player_side: bool, delta: int) -> void:
	if delta == 0:
		return
	var fighter: Fighter = c.player if is_player_side else c.enemy
	if fighter == null:
		return
	var maximum: int = clampi(fighter.data.max_momentum, 1, 12)
	var final_value: int = clampi(fighter.momentum, 0, maximum)
	var before_value: int = final_value
	if delta > 0:
		before_value = clampi(final_value - delta, 0, maximum)
	else:
		before_value = clampi(final_value + absi(delta), 0, maximum)
	await animate_momentum_dots_between(is_player_side, before_value, final_value, delta > 0)

func animate_momentum_dots_between(is_player_side: bool, before_value: int, final_value: int, is_gain: bool) -> void:
	var fighter: Fighter = c.player if is_player_side else c.enemy
	var container: HBoxContainer = c.player_momentum_dots if is_player_side else c.enemy_momentum_dots
	if fighter == null or container == null:
		return
	var maximum: int = clampi(fighter.data.max_momentum, 1, 12)
	if before_value < 0 or final_value < 0:
		final_value = clampi(fighter.momentum, 0, maximum)
		before_value = clampi(final_value - 1, 0, maximum) if is_gain else clampi(final_value + 1, 0, maximum)
	else:
		before_value = clampi(before_value, 0, maximum)
		final_value = clampi(final_value, 0, maximum)
	if before_value == final_value:
		return
	c.set_meta(MOMENTUM_DOT_ANIMATING_META, true)
	c._refresh_momentum_dots(container, before_value, maximum)
	await c.get_tree().process_frame
	if is_gain:
		apply_momentum_dot_flash(container, before_value, final_value, make_transient_momentum_dot_style(MOMENTUM_DOT_GAIN_COLOR, Color("ffffff")))
		pulse_momentum_dot_range(container, before_value, final_value, 1.42, MOMENTUM_DOT_GAIN_FLASH_DURATION)
	else:
		apply_momentum_dot_flash(container, final_value, before_value, make_transient_momentum_dot_style(MOMENTUM_DOT_LOSS_COLOR, Color("3d4148")))
		pulse_momentum_dot_range(container, final_value, before_value, 1.26, MOMENTUM_DOT_FLASH_DURATION)
	var flash_duration: float = MOMENTUM_DOT_GAIN_FLASH_DURATION if is_gain else MOMENTUM_DOT_FLASH_DURATION
	await c.get_tree().create_timer(flash_duration).timeout
	c._refresh_momentum_dots(container, final_value, maximum)
	if is_gain:
		pulse_momentum_dot_range(container, before_value, final_value, 1.18, MOMENTUM_DOT_GAIN_SETTLE_DURATION)
	var settle_duration: float = MOMENTUM_DOT_GAIN_SETTLE_DURATION if is_gain else MOMENTUM_DOT_SETTLE_DURATION
	await c.get_tree().create_timer(settle_duration).timeout
	c.remove_meta(MOMENTUM_DOT_ANIMATING_META)
	c._refresh_hud_bars(true)

static func apply_momentum_dot_flash(container: HBoxContainer, from_index: int, to_index: int, style: StyleBox) -> void:
	if container == null:
		return
	var start_index: int = clampi(min(from_index, to_index), 0, container.get_child_count())
	var end_index: int = clampi(max(from_index, to_index), 0, container.get_child_count())
	for i in range(start_index, end_index):
		var dot := container.get_child(i)
		if dot is PanelContainer:
			dot.add_theme_stylebox_override("panel", style)

func pulse_momentum_dot_range(container: HBoxContainer, from_index: int, to_index: int, pulse_scale: float, duration: float) -> void:
	if container == null:
		return
	var start_index: int = clampi(min(from_index, to_index), 0, container.get_child_count())
	var end_index: int = clampi(max(from_index, to_index), 0, container.get_child_count())
	for i in range(start_index, end_index):
		var dot := container.get_child(i)
		if dot is Control:
			var control := dot as Control
			control.pivot_offset = control.size * 0.5
			control.scale = Vector2.ONE
			var tween: Tween = c.create_tween()
			tween.tween_property(control, "scale", Vector2(pulse_scale, pulse_scale), duration * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(control, "scale", Vector2.ONE, duration * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func make_transient_momentum_dot_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	return style

func show_firearm_flash(is_player_actor: bool, color: Color, should_hit: bool, is_finisher: bool) -> void:
	var layer: Control = c.center_fx_layer if c.center_fx_layer != null else c
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 90
	flash.color = color
	flash.modulate.a = 0.70 if should_hit else 0.35
	flash.size = Vector2(46, 46) if not is_finisher else Vector2(64, 64)
	var origin := presentation_float_position(is_player_actor) + Vector2(10 if is_player_actor else -38, 18)
	flash.position = origin
	layer.add_child(flash)
	var tween: Tween = c.create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.09)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.finished.connect(func() -> void:
		flash.queue_free()
	)

func show_miss_wisp(target_is_player: bool) -> void:
	var layer: Control = c.center_fx_layer if c.center_fx_layer != null else c
	var wisp := ColorRect.new()
	wisp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wisp.z_index = 88
	wisp.color = Color(0.72, 0.72, 0.68, 0.40)
	wisp.size = Vector2(76, 5)
	wisp.position = presentation_float_position(target_is_player) + Vector2(-26, 32)
	layer.add_child(wisp)
	var tween: Tween = c.create_tween()
	tween.tween_property(wisp, "position:x", wisp.position.x + (-34.0 if target_is_player else 34.0), 0.18)
	tween.parallel().tween_property(wisp, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		wisp.queue_free()
	)

func play_break_ink_fx(target_is_player: bool) -> void:
	var layer: Control = c.center_fx_layer if c.center_fx_layer != null else c
	var center := presentation_float_position(target_is_player) + Vector2(28, 38)
	for i in range(3):
		var crack := ColorRect.new()
		crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crack.z_index = 95
		crack.color = Color(0.08, 0.07, 0.06, 0.78)
		crack.size = Vector2(70.0 - i * 10.0, 5.0)
		crack.position = center + Vector2(-35.0 + i * 12.0, -10.0 + i * 10.0)
		crack.rotation = -0.55 + i * 0.45
		layer.add_child(crack)
		var tween: Tween = c.create_tween()
		tween.tween_property(crack, "scale:x", 1.45, 0.12)
		tween.parallel().tween_property(crack, "modulate:a", 0.0, 0.22)
		tween.finished.connect(func() -> void:
			crack.queue_free()
		)
	show_float_text("破势", target_is_player, Color("c44a3f"))

func presentation_visual_node(is_player_actor: bool) -> CanvasItem:
	var sprite: TextureRect = c.player_sprite if is_player_actor else c.enemy_sprite
	if sprite != null and sprite.visible and sprite.texture != null:
		return sprite
	var fallback: Control = c.player_fallback_actor if is_player_actor else c.enemy_fallback_actor
	if fallback != null and fallback.visible:
		return fallback
	return sprite

func presentation_float_position(target_is_player: bool) -> Vector2:
	var node: CanvasItem = presentation_visual_node(target_is_player)
	if node is Control:
		var control := node as Control
		return control.position + Vector2(control.size.x * 0.44, 18.0)
	return Vector2(c.size.x * (0.32 if target_is_player else 0.68), c.STAGE_AREA_TOP + 210.0)
