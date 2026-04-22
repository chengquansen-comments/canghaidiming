extends "res://scripts/battle_controller.gd"

# Demo visual controller scaffold.
# This file adds a stage layout, character presentation, top HUD bars,
# and simple sprite-driven reactions while keeping the parent battle logic intact.
# If external image assets are missing, built-in fallback silhouettes and avatar blocks are shown.

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
	_refresh_character_visuals()
	_refresh_hud_bars()
	_refresh_center_labels()
	_refresh_stage_grid()
	_refresh_stage_actor_positions()
	_refresh_card_detail_panel()
	_refresh_log_strip()
	_apply_button_styles()

func _refresh_center_labels() -> void:
	if round_label != null:
		round_label.text = "演武 %d｜距离 %d" % [battle_count, state_machine.current_distance]
	if phase_label != null:
		if battle_active:
			phase_label.text = "回合 %d｜%s" % [state_machine.round_index, state_machine.pressure_state_text(player, enemy)]
		else:
			phase_label.text = "节点阶段：查看牌库 / 合成藏招 / 得招 / 点化 / 演武"

func _refresh_log_strip() -> void:
	if battle_log_strip == null:
		return
	var logs := _recent_logs()
	if logs.is_empty():
		battle_log_strip.text = "日志待命"
	else:
		battle_log_strip.text = logs[logs.size() - 1].replace("[b]", "").replace("[/b]", "")

func _refresh_character_visuals() -> void:
	player_sheet_source = _sheet_source_for(player, false)
	enemy_sheet_source = _sheet_source_for(enemy, true)
	var player_sheet := _sheet_frame_texture(player_sheet_source, 0)
	var enemy_sheet := _sheet_frame_texture(enemy_sheet_source, 0)
	if player_sprite != null:
		player_sprite.texture = player_sheet
	if enemy_sprite != null:
		enemy_sprite.texture = enemy_sheet
	if player_fallback_actor != null:
		player_fallback_actor.visible = player_sheet == null
	if enemy_fallback_actor != null:
		enemy_fallback_actor.visible = enemy_sheet == null
	var player_portrait := _portrait_texture_for(player)
	var enemy_portrait := _portrait_texture_for(enemy)
	if player_avatar != null:
		player_avatar.texture = player_portrait
	if enemy_avatar != null:
		enemy_avatar.texture = enemy_portrait
	if player_avatar_fallback != null:
		player_avatar_fallback.visible = player_portrait == null
	if enemy_avatar_fallback != null:
		enemy_avatar_fallback.visible = enemy_portrait == null
	if player_name_label != null:
		player_name_label.text = player.data.display_name if player != null else "玩家"
	if enemy_name_label != null:
		enemy_name_label.text = enemy.data.display_name if enemy != null else "敌方"


func _process(delta: float) -> void:
	preview_anim_time += delta
	if battle_active:
		_refresh_stage_grid()
		_refresh_stage_actor_positions()


func _refresh_stage_grid() -> void:
	if stage_grid_cells.is_empty():
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_preview_card := _player_preview_card()
	var enemy_preview_card := _enemy_preview_card()
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_preview_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_preview_card)
	var player_range := _attack_range_slots(true, player_target_slot, player_preview_card)
	var enemy_range := _attack_range_slots(false, enemy_target_slot, enemy_preview_card)
	for i in range(GRID_SLOT_COUNT):
		var fill := GRID_BASE_COLOR
		if player_range.has(i) and enemy_range.has(i):
			fill = RANGE_OVERLAP_COLOR
		elif player_range.has(i):
			fill = PLAYER_RANGE_COLOR
		elif enemy_range.has(i):
			fill = ENEMY_RANGE_COLOR
		if i == player_slot:
			fill = PLAYER_POS_COLOR
		if i == enemy_slot:
			fill = ENEMY_POS_COLOR
		stage_grid_cells[i].add_theme_stylebox_override("panel", _make_grid_cell_style(fill))
		if i == player_slot and i == enemy_slot:
			stage_grid_labels[i].text = "我/敌"
			stage_grid_labels[i].add_theme_color_override("font_color", Color("ffffff"))
		elif i == player_slot:
			stage_grid_labels[i].text = "我"
			stage_grid_labels[i].add_theme_color_override("font_color", Color("eef6ff"))
		elif i == enemy_slot:
			stage_grid_labels[i].text = "敌"
			stage_grid_labels[i].add_theme_color_override("font_color", Color("fff2ef"))
		else:
			stage_grid_labels[i].text = ""


func _refresh_stage_actor_positions() -> void:
	if player_sprite == null or enemy_sprite == null:
		return
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card := _player_preview_card()
	var enemy_card := _enemy_preview_card()
	var player_preview := _should_preview_card(player_card)
	var enemy_preview := _should_preview_card(enemy_card)
	var player_target_slot := _target_slot_for_preview(true, player_slot, enemy_slot, player_card)
	var enemy_target_slot := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var player_top_left := _animated_actor_top_left(true, player_slot, player_target_slot, player_preview)
	var enemy_top_left := _animated_actor_top_left(false, enemy_slot, enemy_target_slot, enemy_preview)
	player_sprite.position = player_top_left
	enemy_sprite.position = enemy_top_left
	player_fallback_actor.position = player_top_left
	enemy_fallback_actor.position = enemy_top_left
	_set_actor_sheet_frame(player, _preview_frame_for_card(player_card, player_preview))
	_set_actor_sheet_frame(enemy, _preview_frame_for_card(enemy_card, enemy_preview))


func _preview_frame_for_card(card: CardData, active: bool) -> int:
	if not active or card == null:
		return 0
	var phase := _preview_cycle_phase()
	if card.damage > 0 and phase >= 0.38 and phase <= 0.68:
		return 1
	return 0


func _animated_actor_top_left(is_player: bool, start_slot: int, target_slot: int, active: bool) -> Vector2:
	var start_pos := _slot_top_left(start_slot, is_player)
	if not active:
		return start_pos
	var target_pos := _slot_top_left(target_slot, is_player)
	var phase := _preview_cycle_phase()
	if phase < 0.26:
		return start_pos.lerp(target_pos, _ease_preview(phase / 0.26))
	if phase < 0.68:
		var hold := target_pos
		var dir := 1.0 if is_player else -1.0
		var attack_t := (phase - 0.26) / 0.42
		var lunge := sin(attack_t * PI) * 34.0
		return hold + Vector2(dir * lunge, -sin(attack_t * PI) * 12.0)
	if phase < 1.0:
		return target_pos.lerp(start_pos, _ease_preview((phase - 0.68) / 0.32))
	return start_pos


func _preview_cycle_phase() -> float:
	return fmod(preview_anim_time, PREVIEW_CYCLE_DURATION) / PREVIEW_CYCLE_DURATION


func _ease_preview(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _current_grid_positions() -> Dictionary:
	var distance := state_machine.current_distance if state_machine != null else 2
	var enemy_slot := GRID_RIGHT_ANCHOR_SLOT
	var player_slot := enemy_slot - distance
	if player_slot < 0:
		player_slot = 0
		enemy_slot = mini(player_slot + distance, GRID_SLOT_COUNT - 1)
	return {"player": player_slot, "enemy": enemy_slot}


func _slot_top_left(slot: int, is_player: bool) -> Vector2:
	var center_x := _slot_center_x(slot)
	var foot_offset := PLAYER_FOOT_OFFSET_X if is_player else ENEMY_FOOT_OFFSET_X
	return Vector2(center_x - foot_offset, STAGE_GROUND_Y - player_sprite.size.y)


func _slot_center_x(slot: int) -> float:
	var left := (size.x - _grid_total_width()) * 0.5
	return left + slot * (GRID_SLOT_WIDTH + GRID_SLOT_GAP) + GRID_SLOT_WIDTH * 0.5


func _grid_total_width() -> float:
	return GRID_SLOT_COUNT * GRID_SLOT_WIDTH + (GRID_SLOT_COUNT - 1) * GRID_SLOT_GAP


func _player_preview_card() -> CardData:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	return null


func _enemy_preview_card() -> CardData:
	if enemy_intent == null:
		return null
	if enemy_intent.is_hidden() and player != null and not enemy_intent.can_hidden_be_read(player):
		return enemy_intent.visible_card
	return enemy_intent.actual_card


func _should_preview_card(card: CardData) -> bool:
	return battle_active and card != null and state_machine != null and state_machine.phase == BattleStateMachine.BattlePhase.DECLARE


func _target_slot_for_preview(is_player: bool, player_slot: int, enemy_slot: int, card: CardData) -> int:
	var actor_slot := player_slot if is_player else enemy_slot
	var opponent_slot := enemy_slot if is_player else player_slot
	if card == null:
		return actor_slot
	if card.id == "idle" or card.id == "staggered":
		return actor_slot
	var current_distance: int = abs(enemy_slot - player_slot)
	var target_distance: int = current_distance
	if current_distance > card.max_distance:
		target_distance = card.max_distance
	elif current_distance < card.min_distance:
		target_distance = card.min_distance
	var delta: int = current_distance - target_distance
	if delta == 0:
		return actor_slot
	if is_player:
		if delta > 0:
			return clampi(actor_slot + delta, 0, opponent_slot - 1)
		return clampi(actor_slot - abs(delta), 0, GRID_SLOT_COUNT - 1)
	if delta > 0:
		return clampi(actor_slot - delta, opponent_slot + 1, GRID_SLOT_COUNT - 1)
	return clampi(actor_slot + abs(delta), 0, GRID_SLOT_COUNT - 1)


func _attack_range_slots(is_player: bool, origin_slot: int, card: CardData) -> Array[int]:
	var result: Array[int] = []
	if card == null or card.damage <= 0:
		return result
	if is_player:
		for distance in range(card.min_distance, card.max_distance + 1):
			var slot := origin_slot + distance
			if slot >= 0 and slot < GRID_SLOT_COUNT:
				result.append(slot)
	else:
		for distance in range(card.min_distance, card.max_distance + 1):
			var slot := origin_slot - distance
			if slot >= 0 and slot < GRID_SLOT_COUNT:
				result.append(slot)
	return result


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

func _refresh_hud_bars() -> void:
	if player != null and player_hp_fill != null and player_hp_bg != null:
		var player_hp_width := player_hp_bg.size.x if player_hp_bg.size.x > 1.0 else HUD_BAR_WIDTH
		player_hp_fill.size = Vector2(player_hp_width * clamp(float(player.hp) / max(1.0, float(player.data.max_hp)), 0.0, 1.0), player_hp_bg.size.y if player_hp_bg.size.y > 0.0 else 14.0)
		if player_hp_value_label != null:
			player_hp_value_label.text = "%d / %d" % [player.hp, player.data.max_hp]
	if player != null and player_momentum_fill != null and player_momentum_bg != null:
		var player_momentum_width := player_momentum_bg.size.x if player_momentum_bg.size.x > 1.0 else HUD_BAR_WIDTH
		player_momentum_fill.size = Vector2(player_momentum_width * clamp(float(player.momentum) / max(1.0, float(player.data.max_momentum)), 0.0, 1.0), player_momentum_bg.size.y if player_momentum_bg.size.y > 0.0 else 10.0)
	if enemy != null and enemy_hp_fill != null and enemy_hp_bg != null:
		var enemy_hp_width := enemy_hp_bg.size.x if enemy_hp_bg.size.x > 1.0 else HUD_BAR_WIDTH
		enemy_hp_fill.size = Vector2(enemy_hp_width * clamp(float(enemy.hp) / max(1.0, float(enemy.data.max_hp)), 0.0, 1.0), enemy_hp_bg.size.y if enemy_hp_bg.size.y > 0.0 else 14.0)
		if enemy_hp_value_label != null:
			enemy_hp_value_label.text = "%d / %d" % [enemy.hp, enemy.data.max_hp]
	if enemy != null and enemy_momentum_fill != null and enemy_momentum_bg != null:
		var enemy_momentum_width := enemy_momentum_bg.size.x if enemy_momentum_bg.size.x > 1.0 else HUD_BAR_WIDTH
		enemy_momentum_fill.size = Vector2(enemy_momentum_width * clamp(float(enemy.momentum) / max(1.0, float(enemy.data.max_momentum)), 0.0, 1.0), enemy_momentum_bg.size.y if enemy_momentum_bg.size.y > 0.0 else 10.0)

func _sheet_source_for(fighter: Fighter, is_enemy: bool) -> Texture2D:
	if fighter == null:
		return null
	var prefix := "enemy_" if is_enemy else ""
	var role := fighter.data.id
	return _safe_load_texture("res://assets/pixel_battle/sheets/%s%s_sheet.png" % [prefix, role])


func _sheet_frame_texture(source: Texture2D, frame_index: int) -> Texture2D:
	if source == null:
		return null
	var frame_width := maxi(source.get_width() / SHEET_FRAME_COUNT, 1)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(frame_width * clampi(frame_index, 0, SHEET_FRAME_COUNT - 1), 0, frame_width, source.get_height())
	return atlas

func _portrait_texture_for(fighter: Fighter) -> Texture2D:
	if fighter == null:
		return null
	return _safe_load_texture("res://assets/pixel_battle/portraits/%s_portrait.png" % fighter.data.id)

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


func _refresh_hand_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()
	if player == null:
		return
	for i in range(player.hand.size()):
		var card: CardData = player.hand[i]
		var reason := _card_restriction_reason(player, card)
		var marker := _combo_marker_text(player, card)
		var button := Button.new()
		button.custom_minimum_size = Vector2(188, 112)
		button.text = _compact_button_text(card, marker, reason)
		button.disabled = not awaiting_player_input or not _can_play_card(player, card)
		button.pressed.connect(_on_player_card_pressed.bind(card))
		hand_flow.add_child(button)

	if awaiting_player_input:
		var idle_card := _idle_card()
		var idle_button := Button.new()
		idle_button.custom_minimum_size = Vector2(188, 112)
		idle_button.text = "[势牌] 观势\n耗势 0｜回 1 势"
		idle_button.pressed.connect(_on_player_card_pressed.bind(idle_card))
		hand_flow.add_child(idle_button)


func _compact_button_text(card: CardData, marker: String, reason: String) -> String:
	var title := "%s %s" % [_card_role_prefix(card), card.display_name]
	if _draft_uses_card(card):
		title = "[已选] " + title
	var lines: Array[String] = [title, _compact_effect_summary(card)]
	return "\n".join(lines)


func _compact_effect_summary(card: CardData) -> String:
	var pieces: Array[String] = []
	pieces.append("耗势 %d" % card.momentum_cost)
	pieces.append("距%d-%d" % [card.min_distance, card.max_distance])
	if card.damage > 0:
		pieces.append("伤害 %d" % card.damage)
	elif card.guard > 0:
		pieces.append("格挡 %d" % card.guard)
	elif card.gain_momentum > 0 or card.break_momentum > 0:
		var momentum_parts: Array[String] = []
		if card.gain_momentum > 0:
			momentum_parts.append("增势 %d" % card.gain_momentum)
		if card.break_momentum > 0:
			momentum_parts.append("削势 %d" % card.break_momentum)
		pieces.append(" / ".join(momentum_parts))
	if not card.tags.is_empty():
		pieces.append("标签 %s" % " / ".join(card.tags))
	return "｜".join(pieces)


func _refresh_card_detail_panel() -> void:
	if card_detail_label == null:
		return
	card_detail_label.add_theme_color_override("default_color", Color("35281c"))
	var focused_card := _focused_card_for_detail()
	if focused_card == null:
		card_detail_label.text = "[b]招式详情[/b]\n点击下方手牌后，这里会显示完整效果、距离、耗势与标签说明。"
		return
	card_detail_label.text = _card_detail_text(focused_card)


func _focused_card_for_detail() -> CardData:
	if draft_player_intent != null and draft_player_intent.actual_card != null:
		return draft_player_intent.actual_card
	if player_intent != null and player_intent.actual_card != null and awaiting_player_input:
		return player_intent.actual_card
	return null


func _card_detail_text(card: CardData) -> String:
	var lines: Array[String] = []
	lines.append("[b]招式详情｜%s[/b]" % card.display_name)
	lines.append("%s｜距离 %d-%d｜耗势 %d" % [card.type_label(), card.min_distance, card.max_distance, card.momentum_cost])
	if not card.tags.is_empty():
		lines.append("标签：%s" % " / ".join(card.tags))
	var effect_lines: Array[String] = []
	if card.damage > 0:
		effect_lines.append("造成 %d 点伤害。" % card.damage)
	if card.guard > 0:
		effect_lines.append("提供 %d 点格挡。" % card.guard)
	if card.gain_momentum > 0:
		effect_lines.append("回复 %d 点势。" % card.gain_momentum)
	if card.break_momentum > 0:
		effect_lines.append("削减对手 %d 点势。" % card.break_momentum)
	if effect_lines.is_empty():
		effect_lines.append("本招式没有直接伤害、格挡或势变化。")
	lines.append("效果：%s" % " ".join(effect_lines))
	lines.append("说明：%s" % card.description)
	return "\n".join(lines)


func _set_actor_sheet_frame(actor: Fighter, frame_index: int) -> void:
	if actor == null:
		return
	if player != null and actor.data.id == player.data.id and player_sprite != null and player_sheet_source != null:
		player_sprite.texture = _sheet_frame_texture(player_sheet_source, frame_index)
		return
	if enemy != null and actor.data.id == enemy.data.id and enemy_sprite != null and enemy_sheet_source != null:
		enemy_sprite.texture = _sheet_frame_texture(enemy_sheet_source, frame_index)


func _pulse_actor_sheet_frame(actor: Fighter, frame_index: int, duration: float = 0.14) -> void:
	_set_actor_sheet_frame(actor, frame_index)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		_set_actor_sheet_frame(actor, 0)
	)

func _animate_attacker_sprite(actor: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	var sprite := player_fallback_actor if actor != null and player != null and actor.data.id == player.data.id and player_fallback_actor != null and player_fallback_actor.visible else enemy_fallback_actor if actor != null and enemy != null and actor.data.id == enemy.data.id and enemy_fallback_actor != null and enemy_fallback_actor.visible else player_sprite if actor != null and player != null and actor.data.id == player.data.id else enemy_sprite
	if sprite == null:
		return
	_pulse_actor_sheet_frame(actor, 1, 0.16 if is_finisher else 0.12)
	var start := sprite.position
	var dir := 1.0 if sprite == player_sprite or sprite == player_fallback_actor else -1.0
	var tween := create_tween()
	if profession_id == "spearman":
		tween.tween_property(sprite, "position", start + Vector2((28 if not is_finisher else 40) * dir, 0), 0.04)
		tween.tween_property(sprite, "position", start, 0.06)
	else:
		tween.tween_property(sprite, "position", start + Vector2((20 if not is_finisher else 30) * dir, -10), 0.04)
		tween.tween_property(sprite, "position", start, 0.07)

func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines := super._resolve_combo_chain_if_any(actor, target, intent)
	if actor != null and intent != null and intent.actual_card != null and intent.actual_card.id != "staggered":
		var is_finisher := intent.actual_card.has_tag("终结")
		_animate_attacker_sprite(actor, actor.data.id, is_finisher)
	return lines


func _show_target_receive_feedback(target: Fighter, profession_id: String, color: Color, is_finisher: bool = false) -> void:
	super(target, profession_id, color, is_finisher)
	_pulse_actor_sheet_frame(target, 2, 0.16 if is_finisher else 0.12)
