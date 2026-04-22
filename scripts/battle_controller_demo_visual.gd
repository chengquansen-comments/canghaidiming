extends "res://scripts/battle_controller.gd"

# Demo visual controller scaffold.
# This file adds a stage layout, character presentation, top HUD bars,
# and simple sprite-driven reactions while keeping the parent battle logic intact.
# If external image assets are missing, built-in fallback silhouettes and avatar blocks are shown.

const FRAME_SIZE := Vector2i(384, 384)
const HUD_BAR_WIDTH := 240.0

var stage_layer: Control
var background_texture: TextureRect
var player_sprite: TextureRect
var enemy_sprite: TextureRect
var center_fx_layer: Control
var player_fallback_actor: Control
var enemy_fallback_actor: Control

var top_hud: HBoxContainer
var player_hud: PanelContainer
var enemy_hud: PanelContainer
var center_hud: VBoxContainer
var battle_log_strip: Label

var player_avatar: TextureRect
var enemy_avatar: TextureRect
var player_avatar_fallback: ColorRect
var enemy_avatar_fallback: ColorRect
var player_hp_fill: ColorRect
var player_momentum_fill: ColorRect
var enemy_hp_fill: ColorRect
var enemy_momentum_fill: ColorRect
var player_name_label: Label
var enemy_name_label: Label

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_stage_layer()
	_build_top_hud()
	_build_center_info()
	_build_bottom_hand_area()
	_build_overlay_layer()
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

	player_sprite = TextureRect.new()
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.custom_minimum_size = Vector2(320, 320)
	player_sprite.position = Vector2(120, 260)
	stage_layer.add_child(player_sprite)
	player_fallback_actor = _build_actor_fallback(Color("5c86b2"), Color("9fdcff"), false)
	player_fallback_actor.position = player_sprite.position
	stage_layer.add_child(player_fallback_actor)

	enemy_sprite = TextureRect.new()
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.custom_minimum_size = Vector2(320, 320)
	enemy_sprite.position = Vector2(980, 240)
	stage_layer.add_child(enemy_sprite)
	enemy_fallback_actor = _build_actor_fallback(Color("8a4f47"), Color("ffb18b"), true)
	enemy_fallback_actor.position = enemy_sprite.position
	stage_layer.add_child(enemy_fallback_actor)

	center_fx_layer = Control.new()
	center_fx_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage_layer.add_child(center_fx_layer)

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
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("161a22"), Color("9e8351")))

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
	box.add_child(name_label)

	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 14)
	hp_bg.color = Color("3a1f24")
	box.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 14)
	hp_fill.color = Color("d95763")
	hp_bg.add_child(hp_fill)

	var mo_bg := ColorRect.new()
	mo_bg.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 10)
	mo_bg.color = Color("203142")
	box.add_child(mo_bg)

	var mo_fill := ColorRect.new()
	mo_fill.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 10)
	mo_fill.color = Color("73c7ff")
	mo_bg.add_child(mo_fill)

	if is_player:
		player_avatar = avatar
		player_avatar_fallback = avatar_fallback
		player_hp_fill = hp_fill
		player_momentum_fill = mo_fill
		player_name_label = name_label
	else:
		enemy_avatar = avatar
		enemy_avatar_fallback = avatar_fallback
		enemy_hp_fill = hp_fill
		enemy_momentum_fill = mo_fill
		enemy_name_label = name_label

	return panel

func _build_center_info() -> void:
	if center_hud == null:
		return
	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 24)
	round_label.text = "尚未开战"
	center_hud.add_child(round_label)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.modulate = Color("cad3df")
	center_hud.add_child(phase_label)

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.custom_minimum_size = Vector2(420, 60)
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(Color("332418"), Color("e1b86c")))
	center_hud.add_child(combat_banner)
	combat_banner_label = Label.new()
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner_label.add_theme_font_size_override("font_size", 24)
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
	hand_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("161b24"), Color("5f6a78")))
	bottom_root.add_child(hand_panel)

	hand_flow = HFlowContainer.new()
	hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_flow.add_theme_constant_override("h_separation", 10)
	hand_flow.add_theme_constant_override("v_separation", 10)
	hand_panel.add_child(hand_flow)

	battle_log_strip = Label.new()
	battle_log_strip.text = "日志待命"
	battle_log_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.12
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("2a2018"), Color("cfb889")))
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
	overlay_box.add_child(overlay_title)
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.fit_content = true
	overlay_box.add_child(overlay_body)
	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 8)
	overlay_box.add_child(overlay_actions)

func _refresh_ui() -> void:
	._refresh_ui()
	_refresh_visual_ui()

func _refresh_visual_ui() -> void:
	_refresh_character_visuals()
	_refresh_hud_bars()
	_refresh_center_labels()
	_refresh_log_strip()

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
	var player_sheet := _sheet_texture_for(player, false)
	var enemy_sheet := _sheet_texture_for(enemy, true)
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

func _refresh_hud_bars() -> void:
	if player != null and player_hp_fill != null:
		player_hp_fill.size.x = HUD_BAR_WIDTH * clamp(float(player.hp) / max(1.0, float(player.data.max_hp)), 0.0, 1.0)
		player_momentum_fill.size.x = HUD_BAR_WIDTH * clamp(float(player.momentum) / max(1.0, float(player.data.max_momentum)), 0.0, 1.0)
	if enemy != null and enemy_hp_fill != null:
		enemy_hp_fill.size.x = HUD_BAR_WIDTH * clamp(float(enemy.hp) / max(1.0, float(enemy.data.max_hp)), 0.0, 1.0)
		enemy_momentum_fill.size.x = HUD_BAR_WIDTH * clamp(float(enemy.momentum) / max(1.0, float(enemy.data.max_momentum)), 0.0, 1.0)

func _sheet_texture_for(fighter: Fighter, is_enemy: bool) -> Texture2D:
	if fighter == null:
		return null
	var prefix := "enemy_" if is_enemy else ""
	var role := fighter.data.id
	return _safe_load_texture("res://assets/pixel_battle/sheets/%s%s_sheet.png" % [prefix, role])

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

func _animate_attacker_sprite(actor: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	var sprite := player_fallback_actor if actor != null and player != null and actor.data.id == player.data.id and player_fallback_actor != null and player_fallback_actor.visible else enemy_fallback_actor if actor != null and enemy != null and actor.data.id == enemy.data.id and enemy_fallback_actor != null and enemy_fallback_actor.visible else player_sprite if actor != null and player != null and actor.data.id == player.data.id else enemy_sprite
	if sprite == null:
		return
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
