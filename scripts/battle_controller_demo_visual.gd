extends "res://scripts/battle_controller_core.gd"

# Demo visual scaffold base class.
#
# This file now focuses on shared scene construction and default visual helpers.
# Runtime refresh behavior is expected to live in battle_controller_visual_ui.gd.

const FRAME_SIZE := Vector2i(512, 512)
const HUD_BAR_WIDTH := 208.0
const SHEET_FRAME_COUNT := 3
const PANEL_FRAME_PATH := "res://assets/pixel_battle/ui/panel_frame.png"
const BUTTON_FRAME_PATH := "res://assets/pixel_battle/ui/button_frame.png"
const SCHOOL_NAME := "清风剑阁"
const GRID_SLOT_COUNT := 9
const GRID_SLOT_WIDTH := 126.0
const GRID_SLOT_HEIGHT := 48.0
const GRID_SLOT_GAP := 6.0
const GRID_STAGE_Y := 468.0
const GRID_RIGHT_ANCHOR_SLOT := 5
const STAGE_GROUND_Y := 510.0
const STAGE_AREA_TOP := 168.0
const STAGE_AREA_BOTTOM := 592.0
const BOTTOM_AREA_TOP := 604.0
const BOTTOM_AREA_BOTTOM_MARGIN := 24.0
const ACTOR_DISPLAY_SIZE := Vector2(228, 228)
const ACTOR_FALLBACK_BASE_SIZE := 320.0
const PLAYER_FOOT_OFFSET_X := 114.0
const ENEMY_FOOT_OFFSET_X := 114.0
const PREVIEW_CYCLE_DURATION := 1.7
const PLAYER_POS_COLOR := Color(0.87, 0.9, 0.98, 0.12)
const ENEMY_POS_COLOR := Color(0.98, 0.86, 0.8, 0.12)
const PLAYER_RANGE_COLOR := Color(0.45, 0.78, 0.96, 0.12)
const ENEMY_RANGE_COLOR := Color(0.92, 0.47, 0.36, 0.12)
const RANGE_OVERLAP_COLOR := Color(0.96, 0.82, 0.48, 0.14)
const GRID_BASE_COLOR := Color(0.06, 0.08, 0.1, 0.12)
const GRID_NEUTRAL_BORDER_COLOR := Color(0.92, 0.88, 0.78, 0.62)
const GRID_PLAYER_BORDER_COLOR := Color(0.78, 0.89, 1.0, 0.95)
const GRID_ENEMY_BORDER_COLOR := Color(1.0, 0.79, 0.67, 0.95)
const GRID_PLAYER_RANGE_BORDER_COLOR := Color(0.63, 0.88, 1.0, 0.86)
const GRID_ENEMY_RANGE_BORDER_COLOR := Color(0.96, 0.62, 0.48, 0.86)
const GRID_OVERLAP_BORDER_COLOR := Color(0.97, 0.88, 0.64, 0.94)
const SLOT_LABELS := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

var stage_layer: Control
var stage_scene_clip: Control
var background_texture: TextureRect
var stage_area_frame: PanelContainer
var bottom_backdrop: PanelContainer
var range_overlay_layer: Node2D
var stage_grid_box: HBoxContainer
var stage_grid_cells: Array[PanelContainer] = []
var stage_grid_labels: Array[Label] = []
var stage_slot_label_box: HBoxContainer
var stage_slot_name_labels: Array[Label] = []
var player_intent_bubble: PanelContainer
var enemy_intent_bubble: PanelContainer
var player_intent_bubble_label: Label
var enemy_intent_bubble_label: Label
var player_sprite: TextureRect
var enemy_sprite: TextureRect
var center_fx_layer: Control
var player_fallback_actor: Control
var enemy_fallback_actor: Control
var player_sheet_source: Texture2D
var enemy_sheet_source: Texture2D

var top_hud: HBoxContainer
var player_hud: PanelContainer
var enemy_hud: PanelContainer
var center_hud: VBoxContainer
var battle_log_strip: Label
var bottom_root: VBoxContainer
var card_detail_panel: PanelContainer
var card_detail_label: RichTextLabel
var effect_preview_panel: PanelContainer
var effect_preview_label: RichTextLabel

var player_avatar: TextureRect
var enemy_avatar: TextureRect
var player_avatar_fallback: ColorRect
var enemy_avatar_fallback: ColorRect
var player_hp_fill: ColorRect
var player_momentum_fill: ColorRect
var enemy_hp_fill: ColorRect
var enemy_momentum_fill: ColorRect
var player_hp_bg: ColorRect
var player_momentum_bg: ColorRect
var enemy_hp_bg: ColorRect
var enemy_momentum_bg: ColorRect
var player_hp_value_label: Label
var enemy_hp_value_label: Label
var player_name_label: Label
var enemy_name_label: Label
var player_school_label: Label
var enemy_school_label: Label
var player_momentum_label: Label
var enemy_momentum_label: Label
var player_momentum_dots: HBoxContainer
var enemy_momentum_dots: HBoxContainer
var preview_anim_time := 0.0

func _set_single_line_ellipsis(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _set_wrapped_label(label: Label, max_lines: int = 2) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = max_lines

func _make_hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.24)
	style.border_color = Color(0.76, 0.65, 0.45, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_badge_style(is_player: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("446b6e") if is_player else Color("3f5370")
	style.border_color = Color("d7c49b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _make_detail_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d7d0c3")
	style.border_color = Color("6f624e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func _make_stage_area_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.1)
	style.border_color = Color(0.82, 0.76, 0.62, 0.24)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 0
	style.border_width_right = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

func _make_intent_bubble_style(is_player: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.07, 0.86) if is_player else Color(0.13, 0.045, 0.035, 0.86)
	style.border_color = Color("8fb4dc") if is_player else Color("d48566")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_bottom_backdrop_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("070a0f")
	style.border_color = Color("6f6043")
	style.border_width_top = 2
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

func _make_momentum_dot_style(filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9b66c") if filled else Color(0.03, 0.035, 0.04, 0.72)
	style.border_color = Color("f3ddb0") if filled else Color(0.72, 0.66, 0.55, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	return style

func _make_overlay_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9d0bd")
	style.border_color = Color("5d4d35")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_stage_layer()
	_build_top_hud()
	_build_center_info()
	_build_bottom_hand_area()
	_build_overlay_layer()
	set_process(true)
	_refresh_visual_ui()

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
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.custom_minimum_size = ACTOR_DISPLAY_SIZE
	player_sprite.size = ACTOR_DISPLAY_SIZE
	player_sprite.clip_contents = true
	player_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_sprite.z_index = 8
	stage_layer.add_child(player_sprite)
	player_fallback_actor = _build_actor_fallback(Color("5c86b2"), Color("9fdcff"), false)
	player_fallback_actor.position = player_sprite.position
	player_fallback_actor.z_index = 8
	stage_layer.add_child(player_fallback_actor)

	enemy_sprite = TextureRect.new()
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.custom_minimum_size = ACTOR_DISPLAY_SIZE
	enemy_sprite.size = ACTOR_DISPLAY_SIZE
	enemy_sprite.clip_contents = true
	enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_sprite.z_index = 8
	stage_layer.add_child(enemy_sprite)
	enemy_fallback_actor = _build_actor_fallback(Color("8a4f47"), Color("ffb18b"), false)
	enemy_fallback_actor.position = enemy_sprite.position
	enemy_fallback_actor.z_index = 8
	stage_layer.add_child(enemy_fallback_actor)

	center_fx_layer = Control.new()
	center_fx_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_layer.add_child(center_fx_layer)

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

func _build_top_hud() -> void:
	top_hud = HBoxContainer.new()
	top_hud.z_as_relative = false
	top_hud.z_index = 100
	top_hud.anchor_left = 0.0
	top_hud.anchor_right = 1.0
	top_hud.anchor_top = 0.0
	top_hud.anchor_bottom = 0.0
	top_hud.offset_left = 20
	top_hud.offset_top = 18
	top_hud.offset_right = -20
	top_hud.offset_bottom = 150
	top_hud.add_theme_constant_override("separation", 20)
	add_child(top_hud)

	player_hud = _build_actor_hud(true)
	top_hud.add_child(player_hud)

	center_hud = VBoxContainer.new()
	center_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	center_hud.add_theme_constant_override("separation", 8)
	top_hud.add_child(center_hud)

	enemy_hud = _build_actor_hud(false)
	top_hud.add_child(enemy_hud)

func _build_actor_hud(is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 130)
	panel.clip_contents = false
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(96, 96)
	avatar_wrap.clip_contents = false

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.size = Vector2(96, 96)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	avatar_wrap.add_child(avatar)

	var avatar_fallback := ColorRect.new()
	avatar_fallback.custom_minimum_size = Vector2(96, 96)
	avatar_fallback.color = Color("3e5875") if is_player else Color("7a4d45")
	avatar_wrap.add_child(avatar_fallback)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	if is_player:
		row.add_child(avatar_wrap)
		row.add_child(box)
	else:
		row.add_child(box)
		row.add_child(avatar_wrap)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("f5e8c8"))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	_set_single_line_ellipsis(name_label)
	box.add_child(name_label)

	var school_label := Label.new()
	school_label.add_theme_font_size_override("font_size", 15)
	school_label.add_theme_color_override("font_color", Color("bba98a"))
	school_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	school_label.add_theme_constant_override("shadow_offset_x", 1)
	school_label.add_theme_constant_override("shadow_offset_y", 1)
	school_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	_set_single_line_ellipsis(school_label)
	box.add_child(school_label)

	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(HUD_BAR_WIDTH + 40, 16)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.clip_contents = true
	hp_bg.color = Color(0.14, 0.06, 0.06, 0.66)
	box.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.size = Vector2(HUD_BAR_WIDTH + 40, 16)
	hp_fill.color = Color("c44a3f")
	hp_bg.add_child(hp_fill)

	var hp_value := Label.new()
	hp_value.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_value.add_theme_font_size_override("font_size", 14)
	hp_value.add_theme_color_override("font_color", Color("f6ead4"))
	_set_single_line_ellipsis(hp_value)
	hp_bg.add_child(hp_value)

	var momentum_row := HBoxContainer.new()
	momentum_row.add_theme_constant_override("separation", 8)
	momentum_row.alignment = BoxContainer.ALIGNMENT_BEGIN if is_player else BoxContainer.ALIGNMENT_END
	box.add_child(momentum_row)

	var momentum_title := Label.new()
	momentum_title.text = "势"
	momentum_title.add_theme_font_size_override("font_size", 18)
	momentum_title.add_theme_color_override("font_color", Color("f0e2bf"))
	momentum_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	momentum_title.add_theme_constant_override("shadow_offset_x", 1)
	momentum_title.add_theme_constant_override("shadow_offset_y", 2)
	momentum_row.add_child(momentum_title)

	var momentum_dots := HBoxContainer.new()
	momentum_dots.add_theme_constant_override("separation", 5)
	momentum_dots.alignment = BoxContainer.ALIGNMENT_BEGIN if is_player else BoxContainer.ALIGNMENT_END
	momentum_row.add_child(momentum_dots)

	if is_player:
		player_avatar = avatar
		player_avatar_fallback = avatar_fallback
		player_hp_bg = hp_bg
		player_hp_fill = hp_fill
		player_hp_value_label = hp_value
		player_name_label = name_label
		player_school_label = school_label
		player_momentum_dots = momentum_dots
	else:
		enemy_avatar = avatar
		enemy_avatar_fallback = avatar_fallback
		enemy_hp_bg = hp_bg
		enemy_hp_fill = hp_fill
		enemy_hp_value_label = hp_value
		enemy_name_label = name_label
		enemy_school_label = school_label
		enemy_momentum_dots = momentum_dots

	return panel

func _build_center_info() -> void:
	if center_hud == null:
		return
	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 34)
	round_label.add_theme_color_override("font_color", Color("f2e2bf"))
	round_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	round_label.add_theme_constant_override("shadow_offset_x", 2)
	round_label.add_theme_constant_override("shadow_offset_y", 3)
	round_label.text = ""
	center_hud.add_child(round_label)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", Color("d6c3a0"))
	phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	phase_label.add_theme_constant_override("shadow_offset_x", 1)
	phase_label.add_theme_constant_override("shadow_offset_y", 2)
	_set_single_line_ellipsis(phase_label)
	phase_label.custom_minimum_size = Vector2(420, 28)
	center_hud.add_child(phase_label)

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.custom_minimum_size = Vector2(420, 60)
	combat_banner.clip_contents = true
	combat_banner.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("332418"), Color("e1b86c")))
	center_hud.add_child(combat_banner)
	combat_banner_label = Label.new()
	combat_banner_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner_label.add_theme_font_size_override("font_size", 24)
	combat_banner_label.add_theme_color_override("font_color", Color("f4e1b1"))
	_set_single_line_ellipsis(combat_banner_label)
	combat_banner.add_child(combat_banner_label)

func _build_bottom_hand_area() -> void:
	bottom_backdrop = PanelContainer.new()
	bottom_backdrop.z_as_relative = false
	bottom_backdrop.z_index = 110
	bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_backdrop.anchor_left = 0.0
	bottom_backdrop.anchor_right = 1.0
	bottom_backdrop.anchor_top = 0.0
	bottom_backdrop.anchor_bottom = 1.0
	bottom_backdrop.offset_left = 0.0
	bottom_backdrop.offset_right = 0.0
	bottom_backdrop.offset_top = BOTTOM_AREA_TOP - 12.0
	bottom_backdrop.offset_bottom = 0.0
	bottom_backdrop.add_theme_stylebox_override("panel", _make_bottom_backdrop_style())
	add_child(bottom_backdrop)

	bottom_root = VBoxContainer.new()
	bottom_root.z_as_relative = false
	bottom_root.z_index = 120
	bottom_root.anchor_left = 0.0
	bottom_root.anchor_right = 1.0
	bottom_root.anchor_top = 0.0
	bottom_root.anchor_bottom = 1.0
	bottom_root.offset_left = 24
	bottom_root.offset_right = -24
	bottom_root.offset_top = BOTTOM_AREA_TOP
	bottom_root.offset_bottom = -BOTTOM_AREA_BOTTOM_MARGIN
	bottom_root.add_theme_constant_override("separation", 12)
	add_child(bottom_root)

	var control_bar := HBoxContainer.new()
	control_bar.custom_minimum_size = Vector2(0, 44)
	control_bar.add_theme_constant_override("separation", 10)
	bottom_root.add_child(control_bar)

	reset_pick_button = Button.new()
	reset_pick_button.text = "重选招式"
	reset_pick_button.pressed.connect(_reset_draft_intent)
	control_bar.add_child(reset_pick_button)

	confirm_button = Button.new()
	confirm_button.text = "确认出招"
	confirm_button.pressed.connect(_confirm_player_intent)
	control_bar.add_child(confirm_button)

	node_buttons_box = HBoxContainer.new()
	node_buttons_box.add_theme_constant_override("separation", 10)
	node_buttons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_bar.add_child(node_buttons_box)

	var bottom_panels := HBoxContainer.new()
	bottom_panels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_panels.add_theme_constant_override("separation", 14)
	bottom_root.add_child(bottom_panels)

	var hand_panel := PanelContainer.new()
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_panel.size_flags_stretch_ratio = 2.0
	hand_panel.clip_contents = true
	hand_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("090d13"), Color("8a774f")))
	bottom_panels.add_child(hand_panel)

	var hand_margin := MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_left", 16)
	hand_margin.add_theme_constant_override("margin_right", 16)
	hand_margin.add_theme_constant_override("margin_top", 12)
	hand_margin.add_theme_constant_override("margin_bottom", 12)
	hand_panel.add_child(hand_margin)

	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	hand_margin.add_child(hand_box)

	var hand_title := Label.new()
	hand_title.text = "招式牌"
	hand_title.add_theme_font_size_override("font_size", 20)
	hand_title.add_theme_color_override("font_color", Color("e0c789"))
	hand_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	hand_title.add_theme_constant_override("shadow_offset_x", 1)
	hand_title.add_theme_constant_override("shadow_offset_y", 2)
	hand_box.add_child(hand_title)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_box.add_child(hand_scroll)

	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 14)
	hand_scroll.add_child(hand_row)
	hand_flow = hand_row

	card_detail_panel = PanelContainer.new()
	card_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_detail_panel.size_flags_stretch_ratio = 1.0
	card_detail_panel.clip_contents = true
	card_detail_panel.add_theme_stylebox_override("panel", _make_detail_panel_style())
	bottom_panels.add_child(card_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 22)
	detail_margin.add_theme_constant_override("margin_right", 22)
	detail_margin.add_theme_constant_override("margin_top", 20)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	card_detail_panel.add_child(detail_margin)

	card_detail_label = RichTextLabel.new()
	card_detail_label.bbcode_enabled = true
	card_detail_label.fit_content = false
	card_detail_label.scroll_active = true
	card_detail_label.scroll_following = false
	card_detail_label.custom_minimum_size = Vector2(0, 0)
	card_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_detail_label.add_theme_color_override("default_color", Color("2f2821"))
	detail_margin.add_child(card_detail_label)

	effect_preview_panel = PanelContainer.new()
	effect_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_preview_panel.size_flags_stretch_ratio = 1.0
	effect_preview_panel.clip_contents = true
	effect_preview_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("11151a"), Color("8a774f")))
	bottom_panels.add_child(effect_preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 16)
	preview_margin.add_theme_constant_override("margin_right", 16)
	preview_margin.add_theme_constant_override("margin_top", 12)
	preview_margin.add_theme_constant_override("margin_bottom", 12)
	effect_preview_panel.add_child(preview_margin)

	effect_preview_label = RichTextLabel.new()
	effect_preview_label.bbcode_enabled = true
	effect_preview_label.fit_content = false
	effect_preview_label.scroll_active = true
	effect_preview_label.scroll_following = false
	effect_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_preview_label.add_theme_color_override("default_color", Color("d8c8a4"))
	preview_margin.add_child(effect_preview_label)

	battle_log_strip = Label.new()
	battle_log_strip.text = "日志待命"
	battle_log_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_wrapped_label(battle_log_strip, 2)
	battle_log_strip.add_theme_color_override("font_color", Color("e1d4b5"))
	battle_log_strip.visible = false
	bottom_root.add_child(battle_log_strip)

	log_label = RichTextLabel.new()
	log_label.visible = false
	status_label = RichTextLabel.new()
	status_label.visible = false
	preview_label = RichTextLabel.new()
	preview_label.visible = false
	player_visible_label = RichTextLabel.new()
	player_visible_label.visible = false
	enemy_visible_label = RichTextLabel.new()
	enemy_visible_label.visible = false
	player_label = RichTextLabel.new()
	player_label.visible = false
	enemy_label = RichTextLabel.new()
	enemy_label.visible = false

func _build_overlay_layer() -> void:
	screen_flash = ColorRect.new()
	screen_flash.visible = false
	screen_flash.z_as_relative = false
	screen_flash.z_index = 900
	screen_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.color = Color(1, 1, 1, 0)
	add_child(screen_flash)

	overlay_scrim = ColorRect.new()
	overlay_scrim.visible = false
	overlay_scrim.z_as_relative = false
	overlay_scrim.z_index = 1000
	overlay_scrim.color = Color(0.01, 0.02, 0.03, 0.72)
	overlay_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(overlay_scrim)

	overlay_panel = PanelContainer.new()
	overlay_panel.visible = false
	overlay_panel.z_as_relative = false
	overlay_panel.z_index = 1001
	overlay_panel.clip_contents = true
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.08
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.92
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.offset_top = 0
	overlay_panel.offset_bottom = 0
	overlay_panel.add_theme_stylebox_override("panel", _make_overlay_panel_style())
	add_child(overlay_panel)

	var overlay_margin := MarginContainer.new()
	overlay_margin.add_theme_constant_override("margin_left", 20)
	overlay_margin.add_theme_constant_override("margin_right", 20)
	overlay_margin.add_theme_constant_override("margin_top", 18)
	overlay_margin.add_theme_constant_override("margin_bottom", 18)
	overlay_panel.add_child(overlay_margin)
	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	overlay_margin.add_child(overlay_box)
	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 24)
	overlay_title.add_theme_color_override("font_color", Color("251b11"))
	_set_single_line_ellipsis(overlay_title)
	overlay_box.add_child(overlay_title)
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.fit_content = false
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.scroll_active = false
	overlay_body.custom_minimum_size = Vector2(0, 92)
	overlay_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	overlay_body.add_theme_color_override("default_color", Color("2d2419"))
	overlay_box.add_child(overlay_body)
	var overlay_action_scroll := ScrollContainer.new()
	overlay_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay_action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	overlay_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_action_scroll.custom_minimum_size = Vector2(0, 280)
	overlay_box.add_child(overlay_action_scroll)
	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_action_scroll.add_child(overlay_actions)
	_build_battle_result_layer()

func _refresh_ui() -> void:
	super()
	_refresh_visual_ui()

func _refresh_visual_ui() -> void:
	pass

func _refresh_center_labels() -> void:
	pass

func _refresh_log_strip() -> void:
	pass

func _refresh_character_visuals() -> void:
	pass

func _refresh_hud_bars() -> void:
	pass

func _refresh_stage_grid() -> void:
	pass

func _refresh_stage_actor_positions() -> void:
	pass

func _refresh_card_detail_panel() -> void:
	pass

func _refresh_hand_buttons() -> void:
	pass

func _process(delta: float) -> void:
	preview_anim_time += delta

func _player_preview_card() -> CardData:
	return null

func _enemy_preview_card() -> CardData:
	return null

func _should_preview_card(card: CardData) -> bool:
	return false

func _grid_total_width() -> float:
	return GRID_SLOT_COUNT * GRID_SLOT_WIDTH + (GRID_SLOT_COUNT - 1) * GRID_SLOT_GAP

func _slot_center_x(slot: int) -> float:
	var left := (size.x - _grid_total_width()) * 0.5
	return left + slot * (GRID_SLOT_WIDTH + GRID_SLOT_GAP) + GRID_SLOT_WIDTH * 0.5

func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	var center_x := _slot_center_x(slot)
	var foot_offset := PLAYER_FOOT_OFFSET_X if is_player else ENEMY_FOOT_OFFSET_X
	return Vector2(center_x - foot_offset, STAGE_GROUND_Y - player_sprite.size.y)

func _preview_cycle_phase() -> float:
	return fmod(preview_anim_time, PREVIEW_CYCLE_DURATION) / PREVIEW_CYCLE_DURATION

func _preview_frame_for_card(card: CardData, active: bool) -> int:
	return 0

func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	return _slot_top_left(start_slot, is_player)

func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	return player_slot if is_player else enemy_slot

func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	return []

func _safe_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var svg_path := path.get_basename() + ".svg"
	if ResourceLoader.exists(svg_path):
		return load(svg_path)
	return null

func _make_demo_panel_style(fill: Color, border: Color) -> StyleBox:
	var texture := _safe_load_texture(PANEL_FRAME_PATH)
	if texture == null:
		return _make_panel_style(fill, border)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 24
	style.texture_margin_top = 24
	style.texture_margin_right = 24
	style.texture_margin_bottom = 24
	style.expand_margin_left = 10
	style.expand_margin_top = 10
	style.expand_margin_right = 10
	style.expand_margin_bottom = 10
	style.content_margin_left = 26
	style.content_margin_top = 20
	style.content_margin_right = 26
	style.content_margin_bottom = 20
	style.draw_center = true
	style.modulate_color = Color(0.96, 0.92, 0.84, 1.0)
	return style

func _make_button_style(tint: Color) -> StyleBox:
	var texture := _safe_load_texture(BUTTON_FRAME_PATH)
	if texture == null:
		return _make_demo_panel_style(Color("2a2018"), Color("cfb889"))
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 28
	style.texture_margin_top = 20
	style.texture_margin_right = 28
	style.texture_margin_bottom = 20
	style.expand_margin_left = 8
	style.expand_margin_top = 8
	style.expand_margin_right = 8
	style.expand_margin_bottom = 8
	style.content_margin_left = 24
	style.content_margin_top = 12
	style.content_margin_right = 24
	style.content_margin_bottom = 12
	style.draw_center = true
	style.modulate_color = tint
	return style

func _make_grid_cell_style(
	fill: Color,
	slot_index: int,
	has_player: bool,
	has_enemy: bool,
	in_player_range: bool,
	in_enemy_range: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	# Draw shared edges only once so adjacent attack-range cells stay readable.
	style.border_width_left = 2 if slot_index == 0 else 0
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = GRID_NEUTRAL_BORDER_COLOR
	if in_player_range and in_enemy_range:
		style.border_color = GRID_OVERLAP_BORDER_COLOR
	elif in_player_range:
		style.border_color = GRID_PLAYER_RANGE_BORDER_COLOR
	elif in_enemy_range:
		style.border_color = GRID_ENEMY_RANGE_BORDER_COLOR
	if has_player and has_enemy:
		style.border_color = GRID_OVERLAP_BORDER_COLOR
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_width_left = 3 if slot_index == 0 else 0
	elif has_player:
		style.border_color = GRID_PLAYER_BORDER_COLOR
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_width_left = 3 if slot_index == 0 else 0
	elif has_enemy:
		style.border_color = GRID_ENEMY_BORDER_COLOR
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_width_left = 3 if slot_index == 0 else 0
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _apply_button_styles() -> void:
	var groups: Array = [
		[deck_button, reset_pick_button, confirm_button],
		hand_flow.get_children() if hand_flow != null else [],
		node_buttons_box.get_children() if node_buttons_box != null else [],
		overlay_actions.get_children() if overlay_actions != null else []
	]
	for group in groups:
		for child in group:
			if child is Button:
				_style_button(child)

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.22, 0.24, 0.28, 0.98)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.28, 0.29, 0.34, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.36, 0.3, 0.2, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.45, 0.36, 0.2, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.16, 0.17, 0.2, 0.88)))
	button.add_theme_color_override("font_color", Color("eadfbe"))
	button.add_theme_color_override("font_hover_color", Color("f6edcf"))
	button.add_theme_color_override("font_pressed_color", Color("fff7db"))
	button.add_theme_color_override("font_disabled_color", Color("938871"))
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = button.custom_minimum_size.max(Vector2(108, 44))
