extends "res://scripts/battle_controller_core.gd"

# Demo visual scaffold base class.
#
# This file now focuses on shared scene construction and default visual helpers.
# Runtime refresh behavior is expected to live in battle_controller_visual_ui.gd.

const FRAME_SIZE := Vector2i(384, 384)
const HUD_BAR_WIDTH := 208.0
const SHEET_FRAME_COUNT := 3
const PANEL_FRAME_PATH := "res://assets/pixel_battle/ui/panel_frame.png"
const BUTTON_FRAME_PATH := "res://assets/pixel_battle/ui/button_frame.png"
const GRID_SLOT_COUNT := 9
const GRID_SLOT_WIDTH := 88.0
const GRID_SLOT_HEIGHT := 44.0
const GRID_SLOT_GAP := 10.0
const GRID_STAGE_Y := 606.0
const GRID_RIGHT_ANCHOR_SLOT := 5
const STAGE_GROUND_Y := 700.0
const PLAYER_FOOT_OFFSET_X := 206.0
const ENEMY_FOOT_OFFSET_X := 124.0
const PREVIEW_CYCLE_DURATION := 1.7
const PLAYER_POS_COLOR := Color(0.27, 0.53, 0.96, 0.86)
const ENEMY_POS_COLOR := Color(0.93, 0.38, 0.38, 0.86)
const PLAYER_RANGE_COLOR := Color(0.32, 0.82, 0.47, 0.55)
const ENEMY_RANGE_COLOR := Color(0.98, 0.55, 0.34, 0.55)
const RANGE_OVERLAP_COLOR := Color(0.83, 0.71, 0.31, 0.6)
const GRID_BASE_COLOR := Color(0.07, 0.08, 0.11, 0.36)

var stage_layer: Control
var background_texture: TextureRect
var stage_grid_box: HBoxContainer
var stage_grid_cells: Array[PanelContainer] = []
var stage_grid_labels: Array[Label] = []
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
var card_detail_panel: PanelContainer
var card_detail_label: RichTextLabel

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
var preview_anim_time := 0.0

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
	add_child(stage_layer)

	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	fallback.color = Color("10151d")
	stage_layer.add_child(fallback)

	background_texture = TextureRect.new()
	background_texture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_SCALE
	background_texture.texture = _safe_load_texture("res://assets/pixel_battle/backgrounds/moon_courtyard.png")
	stage_layer.add_child(background_texture)
	_build_stage_grid()

	player_sprite = TextureRect.new()
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.custom_minimum_size = Vector2(320, 320)
	player_sprite.size = Vector2(320, 320)
	player_sprite.clip_contents = true
	stage_layer.add_child(player_sprite)
	player_fallback_actor = _build_actor_fallback(Color("5c86b2"), Color("9fdcff"), false)
	player_fallback_actor.position = player_sprite.position
	stage_layer.add_child(player_fallback_actor)

	enemy_sprite = TextureRect.new()
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.custom_minimum_size = Vector2(320, 320)
	enemy_sprite.size = Vector2(320, 320)
	enemy_sprite.clip_contents = true
	stage_layer.add_child(enemy_sprite)
	enemy_fallback_actor = _build_actor_fallback(Color("8a4f47"), Color("ffb18b"), true)
	enemy_fallback_actor.position = enemy_sprite.position
	stage_layer.add_child(enemy_fallback_actor)

	center_fx_layer = Control.new()
	center_fx_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage_layer.add_child(center_fx_layer)

func _build_stage_grid() -> void:
	stage_grid_box = HBoxContainer.new()
	stage_grid_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_grid_box.anchor_left = 0.5
	stage_grid_box.anchor_right = 0.5
	stage_grid_box.anchor_top = 0.0
	stage_grid_box.anchor_bottom = 0.0
	stage_grid_box.offset_left = -_grid_total_width() * 0.5
	stage_grid_box.offset_right = _grid_total_width() * 0.5
	stage_grid_box.offset_top = GRID_STAGE_Y
	stage_grid_box.offset_bottom = GRID_STAGE_Y + GRID_SLOT_HEIGHT
	stage_grid_box.add_theme_constant_override("separation", int(GRID_SLOT_GAP))
	stage_layer.add_child(stage_grid_box)
	for i in range(GRID_SLOT_COUNT):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(GRID_SLOT_WIDTH, GRID_SLOT_HEIGHT)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_grid_box.add_child(cell)
		stage_grid_cells.append(cell)
		var label := Label.new()
		label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		cell.add_child(label)
		stage_grid_labels.append(label)

func _build_actor_fallback(body_color: Color, weapon_color: Color, flip: bool) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(320, 320)
	var torso := ColorRect.new()
	torso.color = body_color
	torso.position = Vector2(120, 90)
	torso.size = Vector2(84, 126)
	root.add_child(torso)
	var head := ColorRect.new()
	head.color = Color("f0d1b0")
	head.position = Vector2(132, 46)
	head.size = Vector2(58, 50)
	root.add_child(head)
	var leg_l := ColorRect.new()
	leg_l.color = body_color.darkened(0.2)
	leg_l.position = Vector2(126, 216)
	leg_l.size = Vector2(26, 78)
	root.add_child(leg_l)
	var leg_r := ColorRect.new()
	leg_r.color = body_color.darkened(0.1)
	leg_r.position = Vector2(172, 216)
	leg_r.size = Vector2(26, 78)
	root.add_child(leg_r)
	var arm := ColorRect.new()
	arm.color = body_color.lightened(0.1)
	arm.position = Vector2(88 if not flip else 204, 112)
	arm.size = Vector2(34, 18)
	root.add_child(arm)
	var weapon := ColorRect.new()
	weapon.color = weapon_color
	weapon.position = Vector2(44 if not flip else 230, 84)
	weapon.size = Vector2(12, 156)
	weapon.rotation_degrees = -18 if not flip else 18
	root.add_child(weapon)
	var ground_shadow := ColorRect.new()
	ground_shadow.color = Color(0, 0, 0, 0.25)
	ground_shadow.position = Vector2(104, 292)
	ground_shadow.size = Vector2(112, 14)
	root.add_child(ground_shadow)
	return root

func _build_top_hud() -> void:
	top_hud = HBoxContainer.new()
	top_hud.anchor_left = 0.0
	top_hud.anchor_right = 1.0
	top_hud.anchor_top = 0.0
	top_hud.anchor_bottom = 0.0
	top_hud.offset_left = 24
	top_hud.offset_top = 20
	top_hud.offset_right = -24
	top_hud.offset_bottom = 140
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
	panel.custom_minimum_size = Vector2(360, 120)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("161a22"), Color("9e8351")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(72, 72)
	avatar_wrap.clip_contents = true
	row.add_child(avatar_wrap)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(72, 72)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_wrap.add_child(avatar)

	var avatar_fallback := ColorRect.new()
	avatar_fallback.custom_minimum_size = Vector2(72, 72)
	avatar_fallback.color = Color("3e5875") if is_player else Color("7a4d45")
	avatar_wrap.add_child(avatar_fallback)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color("4a3620"))
	box.add_child(name_label)

	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 14)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.clip_contents = true
	hp_bg.color = Color("3a1f24")
	box.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.size = Vector2(HUD_BAR_WIDTH, 14)
	hp_fill.color = Color("d95763")
	hp_bg.add_child(hp_fill)

	var hp_value := Label.new()
	hp_value.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_value.add_theme_font_size_override("font_size", 11)
	hp_value.add_theme_color_override("font_color", Color("f8f1e2"))
	hp_bg.add_child(hp_value)

	var mo_bg := ColorRect.new()
	mo_bg.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 10)
	mo_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mo_bg.clip_contents = true
	mo_bg.color = Color("203142")
	box.add_child(mo_bg)

	var mo_fill := ColorRect.new()
	mo_fill.size = Vector2(HUD_BAR_WIDTH, 10)
	mo_fill.color = Color("73c7ff")
	mo_bg.add_child(mo_fill)

	if is_player:
		player_avatar = avatar
		player_avatar_fallback = avatar_fallback
		player_hp_bg = hp_bg
		player_hp_fill = hp_fill
		player_momentum_bg = mo_bg
		player_momentum_fill = mo_fill
		player_hp_value_label = hp_value
		player_name_label = name_label
	else:
		enemy_avatar = avatar
		enemy_avatar_fallback = avatar_fallback
		enemy_hp_bg = hp_bg
		enemy_hp_fill = hp_fill
		enemy_momentum_bg = mo_bg
		enemy_momentum_fill = mo_fill
		enemy_hp_value_label = hp_value
		enemy_name_label = name_label

	return panel

func _build_center_info() -> void:
	if center_hud == null:
		return
	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 24)
	round_label.add_theme_color_override("font_color", Color("f4ead0"))
	round_label.text = "尚未开战"
	center_hud.add_child(round_label)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", Color("c9d0dc"))
	center_hud.add_child(phase_label)

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.custom_minimum_size = Vector2(420, 60)
	combat_banner.clip_contents = true
	combat_banner.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("332418"), Color("e1b86c")))
	center_hud.add_child(combat_banner)
	combat_banner_label = Label.new()
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner_label.add_theme_font_size_override("font_size", 24)
	combat_banner_label.add_theme_color_override("font_color", Color("f4e1b1"))
	combat_banner.add_child(combat_banner_label)

func _build_bottom_hand_area() -> void:
	var bottom_root := VBoxContainer.new()
	bottom_root.anchor_left = 0.0
	bottom_root.anchor_right = 1.0
	bottom_root.anchor_top = 1.0
	bottom_root.anchor_bottom = 1.0
	bottom_root.offset_left = 24
	bottom_root.offset_right = -24
	bottom_root.offset_top = -280
	bottom_root.offset_bottom = -24
	bottom_root.add_theme_constant_override("separation", 10)
	add_child(bottom_root)

	var control_bar := HBoxContainer.new()
	control_bar.add_theme_constant_override("separation", 10)
	bottom_root.add_child(control_bar)

	deck_button = Button.new()
	deck_button.text = "查看牌库"
	deck_button.pressed.connect(_open_deck_view)
	control_bar.add_child(deck_button)

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
	control_bar.add_child(node_buttons_box)

	var hand_panel := PanelContainer.new()
	hand_panel.custom_minimum_size = Vector2(0, 170)
	hand_panel.clip_contents = true
	hand_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("161b24"), Color("5f6a78")))
	bottom_root.add_child(hand_panel)

	hand_flow = HFlowContainer.new()
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_flow.add_theme_constant_override("h_separation", 10)
	hand_flow.add_theme_constant_override("v_separation", 10)
	hand_panel.add_child(hand_flow)

	card_detail_panel = PanelContainer.new()
	card_detail_panel.custom_minimum_size = Vector2(0, 128)
	card_detail_panel.clip_contents = true
	card_detail_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("17151a"), Color("8c744c")))
	bottom_root.add_child(card_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 18)
	detail_margin.add_theme_constant_override("margin_right", 18)
	detail_margin.add_theme_constant_override("margin_top", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 14)
	card_detail_panel.add_child(detail_margin)

	card_detail_label = RichTextLabel.new()
	card_detail_label.bbcode_enabled = true
	card_detail_label.fit_content = true
	card_detail_label.scroll_active = false
	card_detail_label.custom_minimum_size = Vector2(0, 96)
	detail_margin.add_child(card_detail_label)

	battle_log_strip = Label.new()
	battle_log_strip.text = "日志待命"
	battle_log_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_log_strip.add_theme_color_override("font_color", Color("e1d4b5"))
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
	screen_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.color = Color(1, 1, 1, 0)
	add_child(screen_flash)

	overlay_scrim = ColorRect.new()
	overlay_scrim.visible = false
	overlay_scrim.color = Color(0.01, 0.02, 0.03, 0.72)
	overlay_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(overlay_scrim)

	overlay_panel = PanelContainer.new()
	overlay_panel.visible = false
	overlay_panel.clip_contents = true
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.12
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.add_theme_stylebox_override("panel", _make_demo_panel_style(Color("2a2018"), Color("cfb889")))
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
	overlay_title.add_theme_color_override("font_color", Color("3d2d1a"))
	overlay_box.add_child(overlay_title)
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.fit_content = true
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_color_override("default_color", Color("34271b"))
	overlay_box.add_child(overlay_body)
	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_box.add_child(overlay_actions)

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

func _make_grid_cell_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.92, 0.84, 0.65, 0.75)
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
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.88, 0.82, 0.72, 1.0)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(1.0, 0.94, 0.8, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.72, 0.62, 0.46, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(1.0, 0.9, 0.66, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.48, 0.45, 0.42, 0.95)))
	button.add_theme_color_override("font_color", Color("3c2a17"))
	button.add_theme_color_override("font_hover_color", Color("2f2113"))
	button.add_theme_color_override("font_pressed_color", Color("1c1610"))
	button.add_theme_color_override("font_disabled_color", Color("6f6559"))
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size = button.custom_minimum_size.max(Vector2(108, 44))
