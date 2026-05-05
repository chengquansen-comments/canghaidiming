extends "res://scripts/battle_controller_demo_visual_foundation.gd"

# Demo visual stage construction layer.

func _build_stage_layer() -> void:
	stage_layer = Control.new()
	stage_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage_layer.z_as_relative = false
	stage_layer.z_index = -100
	add_child(stage_layer)

	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	fallback.color = Color("10151d")
	stage_layer.add_child(fallback)

	stage_scene_clip = Control.new()
	stage_scene_clip.clip_contents = true
	stage_scene_clip.anchor_left = 0.0
	stage_scene_clip.anchor_right = 1.0
	stage_scene_clip.anchor_top = 0.0
	stage_scene_clip.anchor_bottom = 0.0
	stage_scene_clip.offset_left = 0.0
	stage_scene_clip.offset_right = 0.0
	stage_scene_clip.offset_top = 0.0
	stage_scene_clip.offset_bottom = STAGE_AREA_BOTTOM
	stage_layer.add_child(stage_scene_clip)

	background_texture = TextureRect.new()
	background_texture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.texture = _safe_load_texture("res://assets/pixel_battle/backgrounds/moon_courtyard.png")
	stage_scene_clip.add_child(background_texture)
	_build_stage_area_frame()
	_build_range_overlay_layer()
	_build_stage_grid()
	_build_intent_bubbles()

	player_sprite = TextureRect.new()
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_sprite.z_index = 8
	stage_layer.add_child(player_sprite)
	player_fallback_actor = _build_actor_fallback(Color("5c86b2"), Color("9fdcff"), false)
	player_fallback_actor.position = player_sprite.position
	player_fallback_actor.z_index = 8
	stage_layer.add_child(player_fallback_actor)
	BattleActorFootHelper.apply_render_bounds(player_sprite, player_fallback_actor)

	enemy_sprite = TextureRect.new()
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_sprite.z_index = 8
	stage_layer.add_child(enemy_sprite)
	enemy_fallback_actor = _build_actor_fallback(Color("8a4f47"), Color("ffb18b"), false)
	enemy_fallback_actor.position = enemy_sprite.position
	enemy_fallback_actor.z_index = 8
	stage_layer.add_child(enemy_fallback_actor)
	BattleActorFootHelper.apply_render_bounds(enemy_sprite, enemy_fallback_actor)

	center_fx_layer = Control.new()
	center_fx_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_layer.add_child(center_fx_layer)
	_build_debug_settings_button()

func _build_debug_settings_button() -> void:
	var button := Button.new()
	button.text = "Debug"
	button.tooltip_text = "打开战斗调试设置"
	button.custom_minimum_size = Vector2(96, 38)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.offset_left = -128.0
	button.offset_right = -28.0
	button.offset_top = 24.0
	button.offset_bottom = 62.0
	button.z_index = 80
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(Callable(self, "_show_debug_settings"))
	_style_button(button)
	stage_layer.add_child(button)

func _build_range_overlay_layer() -> void:
	range_overlay_layer = Node2D.new()
	range_overlay_layer.z_index = 2
	stage_layer.add_child(range_overlay_layer)

func _build_intent_bubbles() -> void:
	player_intent_bubble = _build_intent_bubble(true)
	stage_layer.add_child(player_intent_bubble)
	enemy_intent_bubble = _build_intent_bubble(false)
	stage_layer.add_child(enemy_intent_bubble)

func _build_intent_bubble(is_player: bool) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.visible = false
	bubble.z_index = 20
	bubble.custom_minimum_size = Vector2(238, 54)
	bubble.size = bubble.custom_minimum_size
	bubble.clip_contents = true
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", _make_intent_bubble_style(is_player))
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("eadfc7"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	bubble.add_child(label)
	if is_player:
		player_intent_bubble_label = label
	else:
		enemy_intent_bubble_label = label
	return bubble

func _build_stage_area_frame() -> void:
	stage_area_frame = PanelContainer.new()
	stage_area_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_area_frame.anchor_left = 0.0
	stage_area_frame.anchor_right = 1.0
	stage_area_frame.anchor_top = 0.0
	stage_area_frame.anchor_bottom = 0.0
	stage_area_frame.offset_left = 0.0
	stage_area_frame.offset_right = 0.0
	stage_area_frame.offset_top = STAGE_AREA_TOP
	stage_area_frame.offset_bottom = STAGE_AREA_BOTTOM
	stage_area_frame.add_theme_stylebox_override("panel", _make_stage_area_style())
	stage_layer.add_child(stage_area_frame)

func _build_stage_grid() -> void:
	stage_grid_box = HBoxContainer.new()
	stage_grid_box.mouse_filter = Control.MOUSE_FILTER_PASS
	stage_grid_box.anchor_left = 0.5
	stage_grid_box.anchor_right = 0.5
	stage_grid_box.anchor_top = 0.0
	stage_grid_box.anchor_bottom = 0.0
	stage_grid_box.offset_left = -_grid_total_width() * 0.5
	stage_grid_box.offset_right = _grid_total_width() * 0.5
	stage_grid_box.offset_top = GRID_STAGE_Y
	stage_grid_box.offset_bottom = GRID_STAGE_Y + GRID_SLOT_HEIGHT
	stage_grid_box.add_theme_constant_override("separation", int(GRID_SLOT_GAP))
	stage_grid_box.z_index = 4
	stage_layer.add_child(stage_grid_box)
	for i in range(GRID_SLOT_COUNT):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(GRID_SLOT_WIDTH, GRID_SLOT_HEIGHT)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_stage_grid_cell_gui_input.bind(i))
		stage_grid_box.add_child(cell)
		stage_grid_cells.append(cell)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("f5efe1"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		cell.add_child(label)
		stage_grid_labels.append(label)
		var click_target := Button.new()
		click_target.text = ""
		click_target.flat = true
		click_target.focus_mode = Control.FOCUS_NONE
		click_target.mouse_filter = Control.MOUSE_FILTER_STOP
		click_target.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		click_target.pressed.connect(_on_stage_grid_slot_pressed.bind(i))
		cell.add_child(click_target)

	stage_slot_label_box = HBoxContainer.new()
	stage_slot_label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_slot_label_box.anchor_left = 0.5
	stage_slot_label_box.anchor_right = 0.5
	stage_slot_label_box.anchor_top = 0.0
	stage_slot_label_box.anchor_bottom = 0.0
	stage_slot_label_box.offset_left = -_grid_total_width() * 0.5
	stage_slot_label_box.offset_right = _grid_total_width() * 0.5
	stage_slot_label_box.offset_top = GRID_STAGE_Y
	stage_slot_label_box.offset_bottom = GRID_STAGE_Y + GRID_SLOT_HEIGHT
	stage_slot_label_box.add_theme_constant_override("separation", int(GRID_SLOT_GAP))
	stage_slot_label_box.z_index = 5
	stage_layer.add_child(stage_slot_label_box)
	for i in range(GRID_SLOT_COUNT):
		var slot_box := CenterContainer.new()
		slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_box.custom_minimum_size = Vector2(GRID_SLOT_WIDTH, GRID_SLOT_HEIGHT)
		stage_slot_label_box.add_child(slot_box)
		var slot_label := Label.new()
		slot_label.text = SLOT_LABELS[i]
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_label.add_theme_font_size_override("font_size", 17)
		slot_label.add_theme_color_override("font_color", Color(0.89, 0.78, 0.54, 0.34))
		slot_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.32))
		slot_label.add_theme_constant_override("shadow_offset_x", 1)
		slot_label.add_theme_constant_override("shadow_offset_y", 2)
		slot_box.add_child(slot_label)
		stage_slot_name_labels.append(slot_label)

func _on_stage_grid_cell_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_stage_grid_slot_pressed(slot)

func _build_actor_fallback(body_color: Color, weapon_color: Color, flip: bool) -> Control:
	var root := Control.new()
	root.custom_minimum_size = ACTOR_DISPLAY_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fallback_scale := ACTOR_DISPLAY_SIZE.x / ACTOR_FALLBACK_BASE_SIZE
	root.scale = Vector2.ONE * fallback_scale
	var torso := ColorRect.new()
	torso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	torso.color = body_color
	torso.position = Vector2(120, 90)
	torso.size = Vector2(84, 126)
	root.add_child(torso)
	var head := ColorRect.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.color = Color("f0d1b0")
	head.position = Vector2(132, 46)
	head.size = Vector2(58, 50)
	root.add_child(head)
	var leg_l := ColorRect.new()
	leg_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leg_l.color = body_color.darkened(0.2)
	leg_l.position = Vector2(126, 216)
	leg_l.size = Vector2(26, 78)
	root.add_child(leg_l)
	var leg_r := ColorRect.new()
	leg_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leg_r.color = body_color.darkened(0.1)
	leg_r.position = Vector2(172, 216)
	leg_r.size = Vector2(26, 78)
	root.add_child(leg_r)
	var arm := ColorRect.new()
	arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arm.color = body_color.lightened(0.1)
	arm.position = Vector2(88 if not flip else 204, 112)
	arm.size = Vector2(34, 18)
	root.add_child(arm)
	var weapon := ColorRect.new()
	weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon.color = weapon_color
	weapon.position = Vector2(44 if not flip else 230, 84)
	weapon.size = Vector2(12, 156)
	weapon.rotation_degrees = -18 if not flip else 18
	root.add_child(weapon)
	var ground_shadow := ColorRect.new()
	ground_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_shadow.color = Color(0, 0, 0, 0.25)
	ground_shadow.position = Vector2(104, 292)
	ground_shadow.size = Vector2(112, 14)
	root.add_child(ground_shadow)
	return root
