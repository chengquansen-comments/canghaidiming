extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func ensure_preview_ghosts() -> void:
	if c.stage_layer == null:
		return
	if c.player_preview_ghost == null:
		c.player_preview_ghost = build_preview_ghost(true)
		c.stage_layer.add_child(c.player_preview_ghost)
	if c.enemy_preview_ghost == null:
		c.enemy_preview_ghost = build_preview_ghost(false)
		c.stage_layer.add_child(c.enemy_preview_ghost)
	if c.player_preview_label == null:
		c.player_preview_label = build_preview_label(true)
		c.stage_layer.add_child(c.player_preview_label)
	if c.enemy_preview_label == null:
		c.enemy_preview_label = build_preview_label(false)
		c.stage_layer.add_child(c.enemy_preview_label)

func build_preview_ghost(is_player: bool) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.visible = false
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.custom_minimum_size = c.ACTOR_DISPLAY_SIZE
	ghost.size = c.ACTOR_DISPLAY_SIZE
	ghost.clip_contents = true
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 14
	ghost.modulate = Color(0.55, 0.78, 1.0, 0.34) if is_player else Color(1.0, 0.64, 0.48, 0.32)
	return ghost

func build_preview_label(is_player: bool) -> Label:
	var label := Label.new()
	label.visible = false
	label.z_index = 32
	label.custom_minimum_size = Vector2(260, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("dff1ff") if is_player else Color("ffe0d0"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func force_real_actor_positions() -> void:
	if c.player != null and c.player_sprite != null:
		c.player_sprite.position = c._slot_top_left(c.player.position, true)
		if c.player_fallback_actor != null:
			c.player_fallback_actor.position = c.player_sprite.position
	if c.enemy != null and c.enemy_sprite != null:
		c.enemy_sprite.position = c._slot_top_left(c.enemy.position, false)
		if c.enemy_fallback_actor != null:
			c.enemy_fallback_actor.position = c.enemy_sprite.position

func refresh_preview_ghosts() -> void:
	ensure_preview_ghosts()
	if c.player_preview_ghost == null or c.enemy_preview_ghost == null or c.player_preview_label == null or c.enemy_preview_label == null:
		return
	if c.player == null or c.enemy == null or not c.battle_active:
		set_preview_ghosts_visible(false)
		return
	var preview: Dictionary = c._compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		set_preview_ghosts_visible(false)
		return
	c.player_preview_ghost.texture = c.player_sprite.texture if c.player_sprite != null else null
	c.enemy_preview_ghost.texture = c.enemy_sprite.texture if c.enemy_sprite != null else null
	c.player_preview_ghost.position = c._slot_top_left(preview.get("player_final", c.player.position), true)
	c.enemy_preview_ghost.position = c._slot_top_left(preview.get("enemy_final", c.enemy.position), false)
	c.player_preview_label.text = str(preview.get("player_text", "预期"))
	c.enemy_preview_label.text = str(preview.get("enemy_text", "预期"))
	c.player_preview_label.position = c.player_preview_ghost.position + Vector2(-16, -56)
	c.enemy_preview_label.position = c.enemy_preview_ghost.position + Vector2(-16, -56)
	set_preview_ghosts_visible(true)

func set_preview_ghosts_visible(value: bool) -> void:
	if c.player_preview_ghost != null:
		c.player_preview_ghost.visible = value
	if c.enemy_preview_ghost != null:
		c.enemy_preview_ghost.visible = value
	if c.player_preview_label != null:
		c.player_preview_label.visible = value
	if c.enemy_preview_label != null:
		c.enemy_preview_label.visible = value

func stabilize_actor_runtime_textures() -> void:
	c._ensure_actor_animation_runtimes()
	c._refresh_actor_runtime_visuals()

func bind_intent_bubbles_to_actor_sprites() -> void:
	bind_single_intent_bubble(c.player_intent_bubble, c.player_sprite, true)
	bind_single_intent_bubble(c.enemy_intent_bubble, c.enemy_sprite, false)

func bind_single_intent_bubble(bubble: PanelContainer, sprite: TextureRect, is_player_actor: bool) -> void:
	if bubble == null or sprite == null or not bubble.visible:
		return
	var bubble_size: Vector2 = bubble.size
	if bubble_size.x <= 1.0 or bubble_size.y <= 1.0:
		bubble_size = bubble.custom_minimum_size
	var sprite_rect: Rect2 = sprite_visible_rect(sprite)
	var foot_point: Vector2 = c._actor_foot_point(is_player_actor)
	var target_x: float = foot_point.x - bubble_size.x * 0.5
	var target_y: float = sprite_rect.position.y - bubble_size.y - c.BUBBLE_GAP_Y
	bubble.position = Vector2(
		clampf(target_x, c.BUBBLE_SAFE_MARGIN_X, maxf(c.BUBBLE_SAFE_MARGIN_X, c.size.x - bubble_size.x - c.BUBBLE_SAFE_MARGIN_X)),
		maxf(c.STAGE_AREA_TOP + 8.0, target_y)
	)

func sprite_visible_rect(sprite: TextureRect) -> Rect2:
	var rect := Rect2(sprite.position, sprite.size)
	if sprite.texture == null:
		return rect
	var texture_size: Vector2 = sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or sprite.size.x <= 0.0 or sprite.size.y <= 0.0:
		return rect
	var draw_scale: float = minf(sprite.size.x / texture_size.x, sprite.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * draw_scale
	var draw_offset: Vector2 = (sprite.size - draw_size) * 0.5
	return Rect2(sprite.position + draw_offset, draw_size)
