extends Control

const BattleStateMachine = preload("res://scripts/battle_state_machine.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const FighterData = preload("res://scripts/fighter_data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")

const HAND_SIZE := 4
const PLAYER_BATTLE_DECK_SIZE := 8
const PLAYER_DECK_SLOT_COUNT := 4
const PLAYER_DECK_CARD_COPY_LIMIT := 2
const DECK_LIBRARY_FILTERS := ["全部", "攻", "守", "藏招"]
const ENEMY_SESSION_REALM := 2
const ROUND_MOMENTUM_RECOVERY := 2
const BATTLE_SLOT_COUNT := 9

var state_machine := BattleStateMachine.new()
var enemy_ai := EnemyAI.new()
var fighter_catalog: Dictionary[String, FighterData] = {}
var reward_pool: Array[CardData] = []
var combo_registry: Dictionary[String, Array] = {}

var player: Fighter
var enemy: Fighter
var player_role_id := ""
var battle_active := false
var awaiting_player_input := false
var battle_count := 0
var node_pick_count := 0

var player_intent: IntentData
var enemy_intent: IntentData
var draft_player_intent: IntentData
var draft_player_position := -1
var draft_player_facing := ""
var draft_player_has_position := false
var declaration_order: PackedStringArray = PackedStringArray()
var declaration_index := 0

var fusion_first_index := -1
var deck_builder_selected_slot_index := -1
var deck_builder_filter := "全部"
var deck_builder_library_page := 0

var title_label: Label
var subtitle_label: Label
var round_label: Label
var phase_label: Label
var player_label: RichTextLabel
var enemy_label: RichTextLabel
var player_visible_label: RichTextLabel
var enemy_visible_label: RichTextLabel
var status_label: RichTextLabel
var preview_label: RichTextLabel
var hand_flow: Container
var log_label: RichTextLabel
var node_buttons_box: HBoxContainer
var deck_button: Button
var reset_pick_button: Button
var confirm_button: Button
var overlay_scrim: ColorRect
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: RichTextLabel
var overlay_actions: VBoxContainer
var battle_result_scrim: ColorRect
var battle_result_panel: PanelContainer
var battle_result_title: Label
var battle_result_body: Label
var battle_result_actions: VBoxContainer
var combat_banner: PanelContainer
var combat_banner_label: Label
var screen_flash: ColorRect
var pierce_line: ColorRect
var slash_cut: ColorRect
var left_hit_mark: ColorRect
var right_hit_mark: ColorRect


func _ready() -> void:
	position = Vector2.ZERO
	_build_catalog()
	_build_ui()
	state_machine.reset_for_session()
	_show_role_selection()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shell := Control.new()
	shell.visible = false
	shell.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shell)

	title_label = Label.new()
	shell.add_child(title_label)
	subtitle_label = Label.new()
	shell.add_child(subtitle_label)
	round_label = Label.new()
	shell.add_child(round_label)
	phase_label = Label.new()
	shell.add_child(phase_label)
	player_label = RichTextLabel.new()
	shell.add_child(player_label)
	enemy_label = RichTextLabel.new()
	shell.add_child(enemy_label)
	player_visible_label = RichTextLabel.new()
	shell.add_child(player_visible_label)
	enemy_visible_label = RichTextLabel.new()
	shell.add_child(enemy_visible_label)
	status_label = RichTextLabel.new()
	shell.add_child(status_label)
	preview_label = RichTextLabel.new()
	shell.add_child(preview_label)
	log_label = RichTextLabel.new()
	shell.add_child(log_label)
	deck_button = Button.new()
	shell.add_child(deck_button)
	reset_pick_button = Button.new()
	shell.add_child(reset_pick_button)
	confirm_button = Button.new()
	shell.add_child(confirm_button)
	node_buttons_box = HBoxContainer.new()
	shell.add_child(node_buttons_box)
	hand_flow = HFlowContainer.new()
	shell.add_child(hand_flow)

	combat_banner = PanelContainer.new()
	combat_banner.visible = false
	combat_banner.anchor_left = 0.5
	combat_banner.anchor_top = 0.02
	combat_banner.anchor_right = 0.5
	combat_banner.anchor_bottom = 0.02
	combat_banner.offset_left = -240
	combat_banner.offset_right = 240
	combat_banner.offset_top = 0
	combat_banner.offset_bottom = 72
	combat_banner.modulate = Color(1, 1, 1, 0)
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(Color("3a1f14"), Color("ffd479")))
	add_child(combat_banner)
	combat_banner_label = Label.new()
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner.add_child(combat_banner_label)

	screen_flash = ColorRect.new()
	screen_flash.visible = false
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(screen_flash)

	pierce_line = ColorRect.new()
	pierce_line.visible = false
	pierce_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pierce_line.anchor_left = 0.0
	pierce_line.anchor_top = 0.5
	pierce_line.anchor_right = 0.0
	pierce_line.anchor_bottom = 0.5
	pierce_line.offset_left = -120
	pierce_line.offset_top = -4
	pierce_line.offset_right = 120
	pierce_line.offset_bottom = 4
	pierce_line.color = Color(0.7, 0.9, 1.0, 0.0)
	add_child(pierce_line)

	slash_cut = ColorRect.new()
	slash_cut.visible = false
	slash_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash_cut.anchor_left = 0.5
	slash_cut.anchor_top = 0.5
	slash_cut.anchor_right = 0.5
	slash_cut.anchor_bottom = 0.5
	slash_cut.offset_left = -420
	slash_cut.offset_top = -18
	slash_cut.offset_right = 420
	slash_cut.offset_bottom = 18
	slash_cut.rotation_degrees = -18.0
	slash_cut.color = Color(1.0, 0.65, 0.45, 0.0)
	add_child(slash_cut)

	left_hit_mark = ColorRect.new()
	left_hit_mark.visible = false
	left_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_hit_mark.anchor_left = 0.04
	left_hit_mark.anchor_top = 0.25
	left_hit_mark.anchor_right = 0.22
	left_hit_mark.anchor_bottom = 0.74
	left_hit_mark.color = Color(1, 1, 1, 0)
	left_hit_mark.rotation_degrees = -14.0
	add_child(left_hit_mark)

	right_hit_mark = ColorRect.new()
	right_hit_mark.visible = false
	right_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_hit_mark.anchor_left = 0.78
	right_hit_mark.anchor_top = 0.25
	right_hit_mark.anchor_right = 0.96
	right_hit_mark.anchor_bottom = 0.74
	right_hit_mark.color = Color(1, 1, 1, 0)
	right_hit_mark.rotation_degrees = 14.0
	add_child(right_hit_mark)

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
	_build_battle_result_layer()


func _ready_card(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_min_distance: int,
	p_max_distance: int,
	p_cost: int,
	p_role: String,
	p_gain_momentum: int,
	p_break_momentum: int,
	p_damage: int,
	p_guard: int,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true
) -> CardData:
	return CardData.new(
		p_id,
		p_name,
		p_desc,
		p_min_distance,
		p_max_distance,
		p_cost,
		p_role,
		p_gain_momentum,
		p_break_momentum,
		p_damage,
		p_guard,
		p_tags,
		p_weapon_style,
		p_requires_facing
	)


func _build_catalog() -> void:
	var spear_read := _ready_card("spear_read", "拧枪探势", "长枪控距试探，稳住中远节奏。", 3, 5, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "枪")
	var spear_break := _ready_card("spear_break", "压杆破势", "枪杆压住来路，专削远处敌势。", 3, 5, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "枪")
	var spear_senki := _ready_card("spear_senki", "回身截枪", "错身后反手截势，背向也可命中。", 2, 4, 2, CardData.ROLE_ATTACK, 2, 2, 0, 0, PackedStringArray(["先机", "回身"]), "枪")
	var spear_mid := _ready_card("spear_mid", "中平长刺", "标准中远枪刺。", 3, 5, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(["连招起手", "起手"]), "枪")
	var spear_heavy := _ready_card("spear_heavy", "龙脊贯刺", "大开大合的远距重刺。", 4, 5, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["终结"]), "枪")
	var spear_guard := _ready_card("spear_guard", "回圆架", "回枪成圆，以守化险。", 0, 5, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "枪", false)
	var spear_wall := _ready_card("spear_wall", "封门守", "稳固门户，重守待机。", 0, 5, 2, CardData.ROLE_GUARD, 0, 0, 0, 8, PackedStringArray(), "枪", false)

	var blade_probe := _ready_card("blade_probe", "贴步探刀", "刀客贴身试探，抢近身势。", 0, 2, 1, CardData.ROLE_FEINT, 2, 0, 0, 0, PackedStringArray(), "刀")
	var blade_press := _ready_card("blade_press", "逼身断势", "短兵贴压，专破近处敌势。", 0, 2, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0, PackedStringArray(), "刀")
	var blade_senki := _ready_card("blade_senki", "回身燕返", "错身回刀争先，背向也可命中。", 0, 2, 2, CardData.ROLE_ATTACK, 2, 2, 0, 0, PackedStringArray(["先机", "回身"]), "刀")
	var blade_cut := _ready_card("blade_cut", "贴身快斩", "迅捷近身斩击。", 0, 2, 1, CardData.ROLE_ATTACK, 0, 0, 4, 0, PackedStringArray(["连招起手", "起手"]), "刀")
	var blade_heavy := _ready_card("blade_heavy", "断流重斩", "势大力沉的贴身压胜一斩。", 0, 1, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["终结"]), "刀")
	var blade_guard := _ready_card("blade_guard", "藏锋格", "低身藏锋，以格挡化险。", 0, 3, 1, CardData.ROLE_GUARD, 0, 0, 0, 4, PackedStringArray(), "刀", false)
	var blade_wall := _ready_card("blade_wall", "锁门架", "以刀封门，强守不退。", 0, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8, PackedStringArray(), "刀", false)

	var spear_deck: Array[CardData] = [spear_read, spear_break, spear_senki, spear_mid, spear_mid.duplicate_card(), spear_heavy, spear_guard, spear_wall]
	var blade_deck: Array[CardData] = [blade_probe, blade_press, blade_senki, blade_cut, blade_cut.duplicate_card(), blade_heavy, blade_guard, blade_wall]

	fighter_catalog["spearman"] = FighterData.new("spearman", "枪手", "长枪", 24, 6, 5, 1, PackedInt32Array([3, 4, 5]), spear_deck, 1, 2, "right")
	fighter_catalog["blademaster"] = FighterData.new("blademaster", "刀客", "单刀", 22, 6, 5, 2, PackedInt32Array([0, 1, 2]), blade_deck, 1, 6, "left")
	fighter_catalog["master_veteran"] = FighterData.new("master_veteran", "沉默老兵", "旧腰刀", 48, 12, 9, 4, PackedInt32Array([0, 1, 2]), blade_deck, 3, 2, "right")

	reward_pool = [
		_ready_card("reward_momentum_up", "聚势", "专注提振自身势头。", 1, 3, 1, CardData.ROLE_FEINT, 2, 0, 0, 0),
		_ready_card("reward_momentum_break", "断势", "专注削弱敌方势头。", 1, 3, 1, CardData.ROLE_ATTACK, 0, 2, 0, 0),
		_ready_card("reward_senki", "争先", "以先机抢夺势头。", 1, 2, 2, CardData.ROLE_ATTACK, 2, 2, 0, 0, PackedStringArray(["先机"])),
		_ready_card("reward_damage", "重手", "纯粹追求压倒性伤害。", 1, 3, 2, CardData.ROLE_ATTACK, 0, 0, 8, 0, PackedStringArray(["追击"])),
		_ready_card("reward_guard", "铁壁", "纯粹追求稳固格挡。", 1, 3, 2, CardData.ROLE_GUARD, 0, 0, 0, 8)
	]

	combo_registry["spearman"] = [
		{
			"id": "spear_combo_001",
			"display_name": "穿云三刺",
			"starter_card_id": "spear_mid",
			"required_card_ids": PackedStringArray(["spear_mid", "spear_heavy"]),
			"followups": [
				{"name": "追喉刺", "base_damage": 2, "segment_type": "追击"},
				{"name": "龙脊送枪", "base_damage": 4, "segment_type": "终结", "is_finisher": true}
			]
		}
	]
	combo_registry["blademaster"] = [
		{
			"id": "blade_combo_001",
			"display_name": "断流三斩",
			"starter_card_id": "blade_cut",
			"required_card_ids": PackedStringArray(["blade_cut", "blade_heavy"]),
			"followups": [
				{"name": "回身快斩", "base_damage": 2, "segment_type": "追击"},
				{"name": "断流收刀", "base_damage": 5, "segment_type": "终结", "is_finisher": true}
			]
		}
	]


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _build_battle_result_layer() -> void:
	if battle_result_panel != null:
		return
	battle_result_scrim = ColorRect.new()
	battle_result_scrim.visible = false
	battle_result_scrim.z_as_relative = false
	battle_result_scrim.z_index = 1100
	battle_result_scrim.color = Color(0.01, 0.02, 0.03, 0.76)
	battle_result_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(battle_result_scrim)

	battle_result_panel = PanelContainer.new()
	battle_result_panel.visible = false
	battle_result_panel.z_as_relative = false
	battle_result_panel.z_index = 1101
	battle_result_panel.anchor_left = 0.5
	battle_result_panel.anchor_top = 0.5
	battle_result_panel.anchor_right = 0.5
	battle_result_panel.anchor_bottom = 0.5
	battle_result_panel.offset_left = -240
	battle_result_panel.offset_right = 240
	battle_result_panel.offset_top = -120
	battle_result_panel.offset_bottom = 120
	battle_result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("2a2018"), Color("cfb889")))
	add_child(battle_result_panel)

	var result_margin := MarginContainer.new()
	result_margin.add_theme_constant_override("margin_left", 28)
	result_margin.add_theme_constant_override("margin_right", 28)
	result_margin.add_theme_constant_override("margin_top", 24)
	result_margin.add_theme_constant_override("margin_bottom", 24)
	battle_result_panel.add_child(result_margin)

	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 16)
	result_margin.add_child(result_box)

	battle_result_title = Label.new()
	battle_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result_title.add_theme_font_size_override("font_size", 30)
	battle_result_title.add_theme_color_override("font_color", Color("f4e0b8"))
	result_box.add_child(battle_result_title)

	battle_result_body = Label.new()
	battle_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_body.add_theme_font_size_override("font_size", 20)
	battle_result_body.add_theme_color_override("font_color", Color("e2d2b3"))
	result_box.add_child(battle_result_body)

	battle_result_actions = VBoxContainer.new()
	battle_result_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_result_actions.add_theme_constant_override("separation", 8)
	result_box.add_child(battle_result_actions)


func _show_combat_banner(text: String, fill_color: Color, border_color: Color = Color("ffd479")) -> void:
	if combat_banner == null or combat_banner_label == null:
		return
	combat_banner.visible = true
	combat_banner_label.text = text
	combat_banner_label.modulate = Color.WHITE
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(fill_color, border_color))
	combat_banner.scale = Vector2(0.92, 0.92)
	combat_banner.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(combat_banner, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.parallel().tween_property(combat_banner, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.28)
	tween.tween_property(combat_banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(func() -> void:
		combat_banner.visible = false
	)


func _flash_label(target_label: RichTextLabel, color: Color) -> void:
	if target_label == null:
		return
	target_label.modulate = color
	var tween := create_tween()
	tween.tween_property(target_label, "modulate", Color.WHITE, 0.22)


func _impact_feedback(flash_color: Color, shake_strength: float = 6.0, horizontal_only: bool = false, extra_pulse: bool = false) -> void:
	if screen_flash != null:
		screen_flash.visible = true
		screen_flash.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
		var flash_tween := create_tween()
		flash_tween.tween_property(screen_flash, "color", Color(flash_color.r, flash_color.g, flash_color.b, 0.18), 0.04)
		flash_tween.tween_property(screen_flash, "color", Color(flash_color.r, flash_color.g, flash_color.b, 0.0), 0.12)
		flash_tween.finished.connect(func() -> void:
			screen_flash.visible = false
		)
	var shake_tween := create_tween()
	if horizontal_only:
		shake_tween.tween_property(self, "position", Vector2(shake_strength, 0), 0.02)
		shake_tween.tween_property(self, "position", Vector2(-shake_strength, 0), 0.03)
		shake_tween.tween_property(self, "position", Vector2(shake_strength * 0.35, 0), 0.02)
		shake_tween.tween_property(self, "position", Vector2.ZERO, 0.05)
		return
	shake_tween.tween_property(self, "position", Vector2(shake_strength, 0), 0.03)
	shake_tween.tween_property(self, "position", Vector2(-shake_strength, 0), 0.03)
	shake_tween.tween_property(self, "position", Vector2(0, shake_strength * 0.5), 0.03)
	if extra_pulse:
		shake_tween.tween_property(self, "position", Vector2(shake_strength * 0.55, 0), 0.02)
		shake_tween.tween_property(self, "position", Vector2(-shake_strength * 0.4, 0), 0.02)
	shake_tween.tween_property(self, "position", Vector2.ZERO, 0.05)


func _show_pierce_line(color: Color, is_finisher: bool = false) -> void:
	if pierce_line == null:
		return
	pierce_line.visible = true
	pierce_line.color = Color(color.r, color.g, color.b, 0.0)
	pierce_line.scale = Vector2(0.75, 1.0 if not is_finisher else 1.4)
	pierce_line.position = Vector2(-260 if not is_finisher else -360, 0)
	var tween := create_tween()
	tween.tween_property(pierce_line, "color", Color(color.r, color.g, color.b, 0.95), 0.025)
	tween.parallel().tween_property(pierce_line, "position", Vector2(260 if not is_finisher else 360, 0), 0.07 if not is_finisher else 0.1)
	tween.parallel().tween_property(pierce_line, "scale", Vector2(1.2 if not is_finisher else 1.45, 1.0 if not is_finisher else 1.6), 0.05)
	tween.tween_property(pierce_line, "color", Color(color.r, color.g, color.b, 0.0), 0.08)
	tween.finished.connect(func() -> void:
		pierce_line.visible = false
		pierce_line.position = Vector2.ZERO
		pierce_line.scale = Vector2.ONE
	)


func _show_slash_cut(color: Color, is_finisher: bool = false) -> void:
	if slash_cut == null:
		return
	slash_cut.visible = true
	slash_cut.color = Color(color.r, color.g, color.b, 0.0)
	slash_cut.scale = Vector2(0.82, 0.82)
	slash_cut.position = Vector2(-90, -20)
	var tween := create_tween()
	tween.tween_property(slash_cut, "color", Color(color.r, color.g, color.b, 0.78), 0.03)
	tween.parallel().tween_property(slash_cut, "position", Vector2(90, 20), 0.06)
	tween.parallel().tween_property(slash_cut, "scale", Vector2(1.05, 1.0), 0.05)
	if is_finisher:
		tween.tween_property(slash_cut, "color", Color(color.r, color.g, color.b, 0.95), 0.02)
		tween.parallel().tween_property(slash_cut, "position", Vector2(-40, -8), 0.03)
		tween.parallel().tween_property(slash_cut, "scale", Vector2(1.18, 1.05), 0.03)
	tween.tween_property(slash_cut, "color", Color(color.r, color.g, color.b, 0.0), 0.09)
	tween.finished.connect(func() -> void:
		slash_cut.visible = false
		slash_cut.position = Vector2.ZERO
		slash_cut.scale = Vector2.ONE
	)


func _play_profession_shape_feedback(profession_id: String, color: Color, is_finisher: bool = false, is_start: bool = false) -> void:
	if profession_id == "spearman":
		_show_pierce_line(color, is_finisher)
		return
	_show_slash_cut(color, is_finisher or is_start)


func _show_target_hit_mark(target_is_enemy: bool, color: Color, profession_id: String, is_finisher: bool = false) -> void:
	var mark := right_hit_mark if target_is_enemy else left_hit_mark
	if mark == null:
		return
	mark.visible = true
	mark.color = Color(color.r, color.g, color.b, 0.0)
	mark.scale = Vector2(0.72, 0.72)
	mark.position = Vector2.ZERO
	var is_spear := profession_id == "spearman"
	if is_spear:
		mark.rotation_degrees = 6.0 if target_is_enemy else -6.0
	else:
		mark.rotation_degrees = 18.0 if target_is_enemy else -18.0
	var tween := create_tween()
	if is_spear:
		mark.pivot_offset = Vector2(10, 120)
		tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.52 if not is_finisher else 0.72), 0.025)
		tween.parallel().tween_property(mark, "scale", Vector2(0.18 if not is_finisher else 0.14, 1.0 if not is_finisher else 1.18), 0.035)
		tween.parallel().tween_property(mark, "position", Vector2(-18, 0) if target_is_enemy else Vector2(18, 0), 0.04)
	else:
		mark.pivot_offset = Vector2(72, 120)
		tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.42 if not is_finisher else 0.65), 0.03)
		tween.parallel().tween_property(mark, "scale", Vector2(1.08, 0.28 if not is_finisher else 0.34), 0.04)
		tween.parallel().tween_property(mark, "position", Vector2(-10, -6) if target_is_enemy else Vector2(10, -6), 0.04)
	if is_finisher:
		tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.78 if is_spear else 0.88), 0.025)
		tween.parallel().tween_property(mark, "scale", Vector2(0.08, 1.22) if is_spear else Vector2(1.15, 0.18), 0.03)
		tween.parallel().tween_property(mark, "position", Vector2(-30, 0) if target_is_enemy else Vector2(30, 0), 0.03)
	tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		mark.visible = false
		mark.position = Vector2.ZERO
		mark.scale = Vector2.ONE
	)


func _animate_target_status_reaction(target: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	if target == null:
		return
	var target_is_enemy := enemy != null and target.data.id == enemy.data.id
	var label := enemy_label if target_is_enemy else player_label
	if label == null:
		return
	label.position = Vector2.ZERO
	label.scale = Vector2.ONE
	var dir := 1.0 if target_is_enemy else -1.0
	var tween := create_tween()
	if profession_id == "spearman":
		var stab_push := (18.0 if not is_finisher else 28.0) * dir
		tween.tween_property(label, "position", Vector2(stab_push, 0), 0.025)
		tween.tween_interval(0.025 if not is_finisher else 0.04)
		tween.tween_property(label, "position", Vector2(stab_push * 0.55, 0), 0.04)
		tween.tween_property(label, "position", Vector2.ZERO, 0.07)
	else:
		var slash_x := (10.0 if not is_finisher else 16.0) * dir
		var slash_y := -8.0 if not is_finisher else -12.0
		tween.tween_property(label, "position", Vector2(slash_x, slash_y), 0.03)
		tween.parallel().tween_property(label, "scale", Vector2(1.02, 0.98), 0.03)
		tween.tween_property(label, "position", Vector2(-slash_x * 0.45, 6.0 if not is_finisher else 9.0), 0.04)
		tween.parallel().tween_property(label, "scale", Vector2(0.99, 1.01), 0.04)
		tween.tween_property(label, "position", Vector2.ZERO, 0.08)
		tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.08)


func _show_target_receive_feedback(target: Fighter, profession_id: String, color: Color, is_finisher: bool = false) -> void:
	if target == null:
		return
	var target_is_enemy := enemy != null and target.data.id == enemy.data.id
	_show_target_hit_mark(target_is_enemy, color, profession_id, is_finisher)
	_animate_target_status_reaction(target, profession_id, is_finisher)
	if profession_id == "spearman":
		_flash_label(enemy_label if target_is_enemy else player_label, Color("bfe9ff") if not is_finisher else Color("e0f4ff"))
	else:
		_flash_label(enemy_label if target_is_enemy else player_label, Color("ffb28f") if not is_finisher else Color("ffd0b5"))


func _combo_feedback_profile(profession_id: String) -> Dictionary:
	if profession_id == "spearman":
		return {
			"start_banner": "枪势连携",
			"start_fill": Color("21334a"),
			"start_border": Color("8fd3ff"),
			"start_flash": Color("8fd3ff"),
			"start_shake": 2.4,
			"start_horizontal_only": true,
			"segment_flash": Color("b7e3ff"),
			"segment_shake": 2.0,
			"segment_horizontal_only": true,
			"segment_extra_pulse": false,
			"finisher_banner": "穿枪贯甲",
			"finisher_fill": Color("1f2d47"),
			"finisher_border": Color("79c7ff"),
			"finisher_flash": Color("9cd8ff"),
			"finisher_shake": 6.2,
			"finisher_horizontal_only": true,
			"finisher_extra_pulse": false,
			"label_color": Color("a9dbff"),
			"log_flair": "枪锋一顿，长驱贯心",
			"segment_flair": "一点即穿"
		}
	return {
		"start_banner": "刀势连携",
		"start_fill": Color("3a2418"),
		"start_border": Color("ffb36b"),
		"start_flash": Color("ffd08a"),
		"start_shake": 4.2,
		"start_horizontal_only": false,
		"segment_flash": Color("ffb48a"),
		"segment_shake": 4.8,
		"segment_horizontal_only": false,
		"segment_extra_pulse": true,
		"finisher_banner": "断流绝斩",
		"finisher_fill": Color("4a1626"),
		"finisher_border": Color("ff7b54"),
		"finisher_flash": Color("ff8a63"),
		"finisher_shake": 10.0,
		"finisher_horizontal_only": false,
		"finisher_extra_pulse": true,
		"label_color": Color("ffb18b"),
		"log_flair": "刀光连斩，势如断流",
		"segment_flair": "连斩压上"
	}


func _combo_chains_for_profession(profession_id: String) -> Array:
	return combo_registry.get(profession_id, [])


func _combo_for_starter(profession_id: String, starter_card_id: String) -> Dictionary:
	for combo in _combo_chains_for_profession(profession_id):
		if combo.get("starter_card_id", "") == starter_card_id:
			return combo
	return {}


func _combo_missing_cards(fighter: Fighter, combo: Dictionary) -> Array[String]:
	var owned := {}
	for card in fighter.get_session_deck():
		owned[card.id] = true
	var missing: Array[String] = []
	for required_id in combo.get("required_card_ids", PackedStringArray()):
		if not owned.has(required_id):
			missing.append(required_id)
	return missing


func _is_combo_unlocked(fighter: Fighter, combo: Dictionary) -> bool:
	return _combo_missing_cards(fighter, combo).is_empty()


func _get_triggerable_combo(fighter: Fighter, card: CardData) -> Dictionary:
	if fighter == null or card == null:
		return {}
	var combo := _combo_for_starter(fighter.data.id, card.id)
	if combo.is_empty():
		return {}
	if not _is_combo_unlocked(fighter, combo):
		return {}
	return combo


func _damage_stage_tag(card: CardData) -> String:
	if card.has_tag("终结"):
		return "终结"
	if card.has_tag("追击"):
		return "追击"
	if card.has_tag("起手"):
		return "起手"
	return ""


func _combo_marker_text(fighter: Fighter, card: CardData) -> String:
	var combo := _combo_for_starter(fighter.data.id, card.id)
	if combo.is_empty():
		return ""
	if fighter.combo_window_active:
		if _is_combo_unlocked(fighter, combo):
			return "【连招起手·可触发】%s" % combo.get("display_name", "")
		return "【连招起手·未解锁】%s" % combo.get("display_name", "")
	return "【连招起手】%s" % combo.get("display_name", "")


func _card_role_prefix(card: CardData) -> String:
	if card.is_guard_card():
		return "【守】"
	if card.is_feint_card():
		return "【变】"
	var stage := _damage_stage_tag(card)
	if stage != "":
		return "【攻/%s】" % stage
	return "【攻】"


func _card_restriction_reason(fighter: Fighter, card: CardData) -> String:
	if fighter == null or card.id == "idle":
		return ""
	if fighter.is_broken():
		return "崩势中本回合无法行动"
	return ""


func _can_play_card(fighter: Fighter, card: CardData) -> bool:
	if fighter == null:
		return false
	if card.momentum_cost > fighter.momentum:
		return false
	return _card_restriction_reason(fighter, card) == ""


func _show_role_selection() -> void:
	_show_overlay(
		"选择角色",
		"[b]这版原型只做枪手与刀客。[/b]\n\n当前规则：当一方的势在本回合被削到 0 时，其将在下一回合崩势：无法行动，且受击伤害翻倍。打崩对手的一方，会在该回合获得一次连招窗口；若其打出的下一招接上已解锁的职业连招起手，则会自动连段。",
		[
			{"text": "枪手开局", "callback": Callable(self, "_start_session").bind("spearman")},
			{"text": "刀客开局", "callback": Callable(self, "_start_session").bind("blademaster")}
		]
	)
	_refresh_ui()


func _start_session(role_id: String) -> void:
	player_role_id = role_id
	var enemy_role_id := "blademaster" if role_id == "spearman" or role_id == "master_veteran" else "spearman"
	player = Fighter.new(_copy_fighter_data(fighter_catalog[role_id]))
	_prepare_player_battle_deck()
	enemy = Fighter.new(_copy_fighter_data(fighter_catalog[enemy_role_id]))
	enemy.set_session_realm(ENEMY_SESSION_REALM)
	battle_count = 0
	node_pick_count = 0
	battle_active = false
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	declaration_order = PackedStringArray()
	fusion_first_index = -1
	_hide_overlay()
	_log("[b]新会话开始。[/b] 玩家使用 %s，对手使用 %s。" % [player.data.display_name, enemy.data.display_name])
	_show_node_buttons()
	_refresh_ui()


func _copy_fighter_data(data: FighterData) -> FighterData:
	return FighterData.new(data.id, data.display_name, data.weapon_name, data.max_hp, data.max_momentum, data.starting_momentum, data.starting_realm, data.preferred_distances, data.clone_deck(), data.qinggong, data.starting_position, data.starting_facing)


func _show_node_buttons() -> void:
	if node_buttons_box == null:
		return
	for child in node_buttons_box.get_children():
		child.queue_free()
	if player == null:
		deck_button = null
		node_buttons_box.visible = false
		return
	var summary_button := Button.new()
	summary_button.text = "战斗摘要"
	summary_button.pressed.connect(_open_battle_summary)
	node_buttons_box.add_child(summary_button)
	deck_button = Button.new()
	deck_button.text = "牌组"
	deck_button.pressed.connect(_open_battle_deck_builder)
	deck_button.disabled = player == null
	node_buttons_box.add_child(deck_button)
	if battle_active:
		node_buttons_box.visible = true
		return
	for spec in [
			{"label": "开始战斗", "callback": Callable(self, "_start_battle")}
		]:
		var button := Button.new()
		button.text = spec["label"]
		button.pressed.connect(spec["callback"])
		node_buttons_box.add_child(button)
	node_buttons_box.visible = true


func _open_battle_summary() -> void:
	_show_overlay("战斗摘要", _status_text(), [{"text": "关闭", "callback": Callable(self, "_hide_overlay")}])


func _open_gain_move() -> void:
	if player == null:
		return
	node_pick_count += 1
	var picks := _sample_rewards(3)
	var actions := []
	for card in picks:
		actions.append({"text": card.short_summary(), "callback": Callable(self, "_pick_reward_card").bind(card)})
	actions.append({"text": "取消", "callback": Callable(self, "_hide_overlay")})
	_show_overlay("得招", "从 3 张招式里选 1 张加入长期牌库。入战仍需在【牌组】中选满 8 张。", actions)


func _sample_rewards(count: int) -> Array[CardData]:
	var pool: Array[CardData] = []
	for template in reward_pool:
		pool.append(template.duplicate_card())
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func _pick_reward_card(card: CardData, source_label: String = "得招") -> void:
	player.add_card_to_deck(card)
	_log("你通过【%s】获得了 [color=#95e1d3]%s[/color]，已加入长期牌库。" % [source_label, card.display_name])
	_hide_overlay()
	_refresh_ui()


func _apply_enlighten() -> void:
	if player == null:
		return
	if player.upgrade_realm():
		_log("你通过【点化】将会话武境提升到 %d。" % player.session_realm)
		_open_realm_move_reward()
	else:
		_log("你的武境已达当前原型上限 3。")
		_refresh_ui()


func _open_realm_move_reward() -> void:
	var picks := _sample_rewards(3)
	var actions := []
	for card in picks:
		actions.append({"text": card.short_summary(), "callback": Callable(self, "_pick_reward_card").bind(card, "武境突破")})
	actions.append({"text": "稍后再说", "callback": Callable(self, "_hide_overlay")})
	_show_overlay("武境突破", "从 3 张招式里选 1 张加入长期牌库。新招不会自动进入当前入战 8 张。", actions)


func _prepare_player_battle_deck() -> void:
	if player == null:
		return
	player.set_battle_deck_limit(PLAYER_BATTLE_DECK_SIZE)
	_sanitize_player_battle_deck_selection()


func _player_battle_deck_ready() -> bool:
	if player == null:
		return false
	_prepare_player_battle_deck()
	return player.get_battle_deck_size() == PLAYER_BATTLE_DECK_SIZE


func _open_battle_deck_builder() -> void:
	if player == null:
		return
	if not battle_active:
		_prepare_player_battle_deck()
	_show_deck_builder_overlay()


func _show_deck_builder_overlay() -> void:
	if overlay_title == null or overlay_body == null or overlay_actions == null:
		return
	var read_only := battle_active
	_set_overlay_deck_builder_size()
	overlay_title.text = "牌组"
	overlay_body.text = ""
	overlay_body.visible = false
	for child in overlay_actions.get_children():
		child.queue_free()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.custom_minimum_size = Vector2(1060, 560)
	overlay_actions.add_child(root)
	_build_deck_library_column(root)
	_build_deck_slots_column(root)
	overlay_scrim.visible = true
	overlay_panel.visible = true
	overlay_scrim.move_to_front()
	overlay_panel.move_to_front()


func _build_deck_library_column(root: HBoxContainer) -> void:
	var read_only := battle_active
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(730, 540)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	left.add_child(tabs)
	for filter_label in DECK_LIBRARY_FILTERS:
		var tab := Button.new()
		tab.text = str(filter_label)
		tab.toggle_mode = true
		tab.button_pressed = deck_builder_filter == str(filter_label)
		tab.pressed.connect(_set_deck_builder_filter.bind(str(filter_label)))
		tabs.add_child(tab)
	var hint := Label.new()
	hint.text = "左侧牌库：当前战斗中只能查看，不能修改牌组。" if read_only else "左侧牌库：点击加入当前牌组。每个牌组 8 张，同名最多 2 张。"
	left.add_child(hint)
	var pager := HBoxContainer.new()
	pager.custom_minimum_size = Vector2(730, 438)
	pager.add_theme_constant_override("separation", 8)
	left.add_child(pager)
	var cards := _filtered_library_cards()
	var max_page := maxi(0, int(ceil(float(cards.size()) / 8.0)) - 1)
	deck_builder_library_page = clampi(deck_builder_library_page, 0, max_page)
	if deck_builder_library_page > 0:
		var prev := _deck_builder_page_button("◀")
		prev.pressed.connect(_change_deck_builder_page.bind(-1))
		pager.add_child(prev)
	else:
		pager.add_child(_deck_builder_page_spacer())
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(640, 438)
	card_panel.add_theme_stylebox_override("panel", _deck_library_panel_style())
	pager.add_child(card_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card_panel.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)
	var target_slot := _deck_builder_target_slot()
	var target_deck := player.get_battle_deck_slot(target_slot)
	var start_index := deck_builder_library_page * 8
	for i in range(8):
		var library_index := start_index + i
		if library_index < cards.size():
			var card: CardData = cards[library_index]
			var button := _build_deck_library_card_button(card, read_only or not _can_add_library_card_to_slot(card, target_deck))
			if not read_only:
				button.pressed.connect(_add_library_card_to_current_deck.bind(card.id))
			grid.add_child(button)
		else:
			grid.add_child(_empty_deck_library_card_slot())
	if deck_builder_library_page < max_page:
		var next := _deck_builder_page_button("▶")
		next.pressed.connect(_change_deck_builder_page.bind(1))
		pager.add_child(next)
	else:
		pager.add_child(_deck_builder_page_spacer())
	var close_row := HBoxContainer.new()
	close_row.custom_minimum_size = Vector2(730, 40)
	left.add_child(close_row)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(120, 38)
	close_button.pressed.connect(_hide_overlay)
	close_row.add_child(close_button)


func _build_deck_slots_column(root: HBoxContainer) -> void:
	var read_only := battle_active
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 540)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	if deck_builder_selected_slot_index < 0:
		var title := Label.new()
		title.text = "我的套牌"
		title.add_theme_font_size_override("font_size", 18)
		right.add_child(title)
		for i in range(PLAYER_DECK_SLOT_COUNT):
			var deck := player.get_battle_deck_slot(i)
			var button := Button.new()
			var marker := "启用｜" if i == player.get_active_battle_deck_index() else ""
			button.text = "%s%s\n%d/%d" % [marker, _deck_slot_name(i), deck.size(), PLAYER_BATTLE_DECK_SIZE]
			button.custom_minimum_size = Vector2(300, 82)
			button.pressed.connect(_open_deck_slot_detail.bind(i))
			right.add_child(button)
		return
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	right.add_child(header)
	var back := Button.new()
	back.text = "套牌"
	back.custom_minimum_size = Vector2(80, 34)
	back.pressed.connect(_return_deck_slot_list)
	header.add_child(back)
	var active := Button.new()
	active.text = "设为启用" if deck_builder_selected_slot_index != player.get_active_battle_deck_index() else "已启用"
	active.disabled = read_only or deck_builder_selected_slot_index == player.get_active_battle_deck_index()
	active.custom_minimum_size = Vector2(112, 34)
	if not read_only:
		active.pressed.connect(_set_active_deck_slot.bind(deck_builder_selected_slot_index))
	header.add_child(active)
	var deck := player.get_battle_deck_slot(deck_builder_selected_slot_index)
	var title := Label.new()
	title.text = "%s｜%d/%d" % [_deck_slot_name(deck_builder_selected_slot_index), deck.size(), PLAYER_BATTLE_DECK_SIZE]
	title.add_theme_font_size_override("font_size", 18)
	right.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, 430)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if deck.is_empty():
		var empty := Label.new()
		empty.text = "空牌组。" if read_only else "空牌组。点击左侧牌库加入招式。"
		list.add_child(empty)
	else:
		for i in range(deck.size()):
			var card: CardData = deck[i]
			var card_button := Button.new()
			card_button.text = "%d. %s" % [i + 1, card.display_name]
			card_button.custom_minimum_size = Vector2(286, 34)
			card_button.disabled = read_only
			if not read_only:
				card_button.pressed.connect(_remove_deck_slot_card.bind(deck_builder_selected_slot_index, i))
			list.add_child(card_button)


func _battle_deck_builder_text(library: Array[CardData], selected: Array[CardData]) -> String:
	var lines: Array[String] = []
	lines.append("[b]入战牌组：%d/%d[/b]" % [selected.size(), PLAYER_BATTLE_DECK_SIZE])
	if selected.is_empty():
		lines.append("尚未选择。")
	else:
		for i in range(selected.size()):
			lines.append("%d. %s" % [i + 1, selected[i].short_summary()])
	lines.append("")
	lines.append("[b]长期牌库：%d 张[/b]" % library.size())
	for i in range(library.size()):
		var card: CardData = library[i]
		var selected_count := _card_count_in_deck(selected, card.id)
		var library_count := _card_count_in_deck(library, card.id)
		lines.append("%d. [%d/%d] %s" % [i + 1, selected_count, library_count, card.short_summary()])
	if selected.size() != PLAYER_BATTLE_DECK_SIZE:
		lines.append("")
		lines.append("[color=#ffd479]需要正好 8 张才能开始战斗。[/color]")
	return "\n".join(lines)


func _deck_library_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("261f18")
	style.border_color = Color("c8a464")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _deck_builder_page_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 438)
	button.add_theme_font_size_override("font_size", 28)
	return button


func _deck_builder_page_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(36, 438)
	return spacer


func _change_deck_builder_page(delta: int) -> void:
	deck_builder_library_page = maxi(0, deck_builder_library_page + delta)
	_show_deck_builder_overlay()


func _build_deck_library_card_button(card: CardData, disabled: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(148, 200)
	button.text = ""
	button.tooltip_text = card.short_summary()
	button.disabled = disabled
	_apply_deck_library_card_style(button, card, disabled)
	_build_deck_library_card_face(button, card)
	return button


func _empty_deck_library_card_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(148, 200)
	panel.add_theme_stylebox_override("panel", _make_flat_card_style(Color("15120f"), Color("3b332a"), 1))
	return panel


func _apply_deck_library_card_style(button: Button, card: CardData, disabled: bool) -> void:
	var base := Color("141a20")
	var border := Color("8a7856")
	if card.is_guard_card():
		border = Color("637d91")
	elif card.is_feint_card():
		border = Color("6f8d76")
	var normal := _make_flat_card_style(base, border, 2)
	var hover := _make_flat_card_style(base.lightened(0.08), border.lightened(0.15), 3)
	var pressed := _make_flat_card_style(base.lightened(0.14), Color("e6c36a"), 3)
	var disabled_style := _make_flat_card_style(Color("111418"), Color("4d4a42"), 1)
	button.add_theme_stylebox_override("normal", disabled_style if disabled else normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _make_flat_card_style(base.lightened(0.04), Color("efd382"), 3))
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0))


func _make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _build_deck_library_card_face(button: Button, card: CardData) -> void:
	var face := MarginContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_constant_override("margin_left", 9)
	face.add_theme_constant_override("margin_right", 9)
	face.add_theme_constant_override("margin_top", 9)
	face.add_theme_constant_override("margin_bottom", 9)
	button.add_child(face)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	face.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)
	var cost := Label.new()
	cost.text = str(card.momentum_cost)
	cost.custom_minimum_size = Vector2(28, 28)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 17)
	cost.add_theme_color_override("font_color", Color("f5efe1"))
	cost.add_theme_stylebox_override("normal", _deck_card_badge_style())
	title_row.add_child(cost)
	var name := Label.new()
	name.text = card.display_name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color("f0e4c4"))
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(name)
	var tag := Label.new()
	tag.text = _short_card_type_tag_for_builder(card)
	tag.custom_minimum_size = Vector2(24, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color("f7ead0"))
	tag.add_theme_stylebox_override("normal", _deck_card_type_style(card))
	title_row.add_child(tag)
	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(0, 50)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_theme_stylebox_override("panel", _deck_card_art_style(card))
	box.add_child(art)
	var art_label := Label.new()
	art_label.text = _deck_card_art_glyph(card)
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.add_theme_font_size_override("font_size", 20)
	art_label.add_theme_color_override("font_color", Color("ced8dd"))
	art.add_child(art_label)
	var summary := Label.new()
	summary.text = _compact_effect_summary(card)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.clip_text = true
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color("d9d2bf"))
	box.add_child(summary)


func _deck_card_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("244b73")
	style.border_color = Color("d7e4f5")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style


func _deck_card_type_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6f2824")
	if card.is_guard_card():
		style.bg_color = Color("29495f")
	elif card.is_feint_card():
		style.bg_color = Color("355d46")
	style.border_color = Color("c7b181")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _deck_card_art_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202934")
	if card.is_guard_card():
		style.bg_color = Color("243443")
	elif card.is_feint_card():
		style.bg_color = Color("24382e")
	style.border_color = Color("403b31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _short_card_type_tag_for_builder(card: CardData) -> String:
	return card.type_label()


func _deck_card_art_glyph(card: CardData) -> String:
	if card.is_guard_card():
		return "架"
	if card.is_feint_card():
		return "行"
	return "击"


func _compact_effect_summary(card: CardData) -> String:
	if card == null:
		return ""
	return card.short_summary()


func _set_deck_builder_filter(filter_label: String) -> void:
	deck_builder_filter = filter_label
	deck_builder_library_page = 0
	_show_deck_builder_overlay()


func _open_deck_slot_detail(slot_index: int) -> void:
	deck_builder_selected_slot_index = clampi(slot_index, 0, PLAYER_DECK_SLOT_COUNT - 1)
	_show_deck_builder_overlay()


func _return_deck_slot_list() -> void:
	deck_builder_selected_slot_index = -1
	_show_deck_builder_overlay()


func _set_active_deck_slot(slot_index: int) -> void:
	if player == null:
		return
	player.set_active_battle_deck_index(slot_index)
	_log("已启用【%s】。" % _deck_slot_name(player.get_active_battle_deck_index()))
	_show_deck_builder_overlay()


func _deck_builder_target_slot() -> int:
	if player == null:
		return 0
	if deck_builder_selected_slot_index >= 0:
		return deck_builder_selected_slot_index
	return player.get_active_battle_deck_index()


func _deck_slot_name(index: int) -> String:
	match index:
		0: return "牌组一"
		1: return "牌组二"
		2: return "牌组三"
		3: return "牌组四"
	return "牌组%d" % (index + 1)


func _filtered_library_cards() -> Array[CardData]:
	var cards := _unique_library_cards()
	if deck_builder_filter == "全部":
		return cards
	var result: Array[CardData] = []
	for card in cards:
		if _card_matches_library_filter(card, deck_builder_filter):
			result.append(card)
	return result


func _unique_library_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}
	if player == null:
		return result
	for card in player.get_session_deck():
		if card == null or seen.has(card.id):
			continue
		seen[card.id] = true
		result.append(card.duplicate_card())
	return result


func _card_matches_library_filter(card: CardData, filter_label: String) -> bool:
	if card == null:
		return false
	match filter_label:
		"攻":
			return card.is_attack_card()
		"守":
			return card.is_guard_card()
		"藏招":
			return card.has_tag("藏招") or card.id.begins_with("hidden_")
	return true


func _card_meta_line(card: CardData) -> String:
	var role_label := card.type_label()
	return "耗%d｜%s｜距%d-%d" % [card.momentum_cost, role_label, card.min_distance, card.max_distance]


func _find_library_card(card_id: String) -> CardData:
	for card in player.get_session_deck():
		if card != null and card.id == card_id:
			return card
	return null


func _can_add_library_card_to_slot(card: CardData, deck: Array[CardData]) -> bool:
	if card == null:
		return false
	if deck.size() >= PLAYER_BATTLE_DECK_SIZE:
		return false
	return _card_count_in_deck(deck, card.id) < PLAYER_DECK_CARD_COPY_LIMIT


func _add_library_card_to_current_deck(card_id: String) -> void:
	if player == null:
		return
	var card := _find_library_card(card_id)
	if card == null:
		return
	var slot_index := _deck_builder_target_slot()
	var deck := player.get_battle_deck_slot(slot_index)
	if deck.size() >= PLAYER_BATTLE_DECK_SIZE:
		_log("【%s】已满 8 张，不能继续加入。" % _deck_slot_name(slot_index))
	elif _card_count_in_deck(deck, card.id) >= PLAYER_DECK_CARD_COPY_LIMIT:
		_log("每个牌组中同一张牌最多 %d 张。" % PLAYER_DECK_CARD_COPY_LIMIT)
	else:
		player.add_card_to_battle_deck(card, slot_index)
		_log("已将【%s】加入【%s】。" % [card.display_name, _deck_slot_name(slot_index)])
	_refresh_ui()
	_show_deck_builder_overlay()


func _remove_deck_slot_card(slot_index: int, card_index: int) -> void:
	if player == null:
		return
	if player.remove_battle_deck_card(card_index, slot_index):
		_log("已从【%s】移出 1 张招式。" % _deck_slot_name(slot_index))
	_refresh_ui()
	_show_deck_builder_overlay()


func _add_battle_deck_card(library_index: int) -> void:
	if player == null:
		return
	var library := player.get_session_deck()
	var selected := player.get_selected_battle_deck()
	if library_index < 0 or library_index >= library.size():
		_open_battle_deck_builder()
		return
	var card: CardData = library[library_index]
	if not _can_add_library_card_to_battle_deck(card, selected, library):
		_log("这张招式在当前牌组中已达到上限，或牌组已满。")
	else:
		player.add_card_to_battle_deck(card)
	_refresh_ui()
	_open_battle_deck_builder()


func _remove_battle_deck_card(index: int) -> void:
	if player == null:
		return
	player.remove_battle_deck_card(index)
	_refresh_ui()
	_open_battle_deck_builder()


func _auto_fill_battle_deck_and_reopen() -> void:
	_auto_fill_player_battle_deck()
	_refresh_ui()
	_open_battle_deck_builder()


func _confirm_battle_deck_builder() -> void:
	if _player_battle_deck_ready():
		_log("入战牌组已确认：8 张。")
		_hide_overlay()
		_refresh_ui()
		return
	_log("入战牌组需要正好 8 张。")
	_open_battle_deck_builder()


func _auto_fill_player_battle_deck() -> void:
	if player == null:
		return
	_prepare_player_battle_deck()
	var library := _unique_library_cards()
	var selected := player.get_selected_battle_deck()
	while selected.size() < PLAYER_BATTLE_DECK_SIZE:
		var added := false
		for card in library:
			if selected.size() >= PLAYER_BATTLE_DECK_SIZE:
				break
			if _can_add_library_card_to_battle_deck(card, selected, library):
				selected.append(card.duplicate_card())
				added = true
		if not added:
			break
	player.set_selected_battle_deck(selected)


func _sanitize_player_battle_deck_selection() -> void:
	if player == null:
		return
	var library := player.get_session_deck()
	var selected := player.get_selected_battle_deck()
	var sanitized: Array[CardData] = []
	for card in selected:
		if card == null:
			continue
		if sanitized.size() >= PLAYER_BATTLE_DECK_SIZE:
			break
		if _library_has_card(library, card.id) and _card_count_in_deck(sanitized, card.id) < PLAYER_DECK_CARD_COPY_LIMIT:
			sanitized.append(card.duplicate_card())
	player.set_selected_battle_deck(sanitized)


func _can_add_library_card_to_battle_deck(card: CardData, selected: Array[CardData], library: Array[CardData]) -> bool:
	if card == null:
		return false
	if selected.size() >= PLAYER_BATTLE_DECK_SIZE:
		return false
	return _library_has_card(library, card.id) and _card_count_in_deck(selected, card.id) < PLAYER_DECK_CARD_COPY_LIMIT


func _card_count_in_deck(cards: Array[CardData], card_id: String) -> int:
	var count := 0
	for card in cards:
		if card != null and card.id == card_id:
			count += 1
	return count


func _library_has_card(library: Array[CardData], card_id: String) -> bool:
	for card in library:
		if card != null and card.id == card_id:
			return true
	return false


func _begin_hidden_fusion() -> void:
	if player == null:
		return
	var deck := player.get_session_deck()
	if deck.size() < 2:
		_log("牌库少于 2 张，无法合成藏招。")
		return
	fusion_first_index = -1
	_show_fusion_pick_overlay()


func _show_fusion_pick_overlay() -> void:
	if player == null:
		return
	var deck := player.get_session_deck()
	var actions := []
	var title := "合成藏招"
	var body := "从当前牌库中选择两张已有招式，合成为一张更强的藏招。合成后原两张移出牌库，新牌加入牌库末尾。"
	if fusion_first_index >= 0 and fusion_first_index < deck.size():
		title = "选择第二张牌"
		body = "已选第一张：[b]%s[/b]\n再选一张不同的牌完成合成。" % deck[fusion_first_index].short_summary()
	for i in range(deck.size()):
		var card: CardData = deck[i]
		var prefix := ""
		if i == fusion_first_index:
			prefix = "[已选] "
		actions.append({"text": "%s%d. %s" % [prefix, i + 1, card.short_summary()], "callback": Callable(self, "_on_fusion_pick").bind(i)})
	if fusion_first_index >= 0:
		actions.append({"text": "取消本次合成", "callback": Callable(self, "_cancel_hidden_fusion")})
	else:
		actions.append({"text": "关闭", "callback": Callable(self, "_hide_overlay")})
	_show_overlay(title, body, actions)


func _on_fusion_pick(index: int) -> void:
	if player == null:
		return
	if fusion_first_index < 0:
		fusion_first_index = index
		_show_fusion_pick_overlay()
		return
	if index == fusion_first_index:
		_log("合成藏招需要两张不同的牌。")
		return
	var deck := player.get_session_deck()
	if fusion_first_index >= deck.size() or index >= deck.size():
		fusion_first_index = -1
		_hide_overlay()
		return
	var first_card: CardData = deck[fusion_first_index]
	var second_card: CardData = deck[index]
	var fused := _build_hidden_fusion_card(first_card, second_card)
	if player.replace_cards_in_session_deck(fusion_first_index, index, fused):
		_log("你将 [color=#95e1d3]%s[/color] 与 [color=#95e1d3]%s[/color] 合成为藏招 [color=#ffd479]%s[/color]。" % [first_card.display_name, second_card.display_name, fused.display_name])
		_auto_fill_player_battle_deck()
	fusion_first_index = -1
	_hide_overlay()
	_refresh_ui()


func _cancel_hidden_fusion() -> void:
	fusion_first_index = -1
	_hide_overlay()


func _build_hidden_fusion_card(first_card: CardData, second_card: CardData) -> CardData:
	var tags := PackedStringArray(["藏招"])
	var fused_cost := first_card.momentum_cost + second_card.momentum_cost
	if first_card.is_feint_card() and second_card.is_feint_card():
		return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双变并行的藏招。", 1, 3, fused_cost, CardData.ROLE_FEINT, first_card.gain_momentum + second_card.gain_momentum, first_card.break_momentum + second_card.break_momentum, 0, 0, tags)
	if first_card.is_guard_card() and second_card.is_guard_card():
		return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双守并立的藏招。", 1, 3, fused_cost, CardData.ROLE_GUARD, 0, 0, 0, first_card.guard + second_card.guard, tags)
	tags.append("终结")
	return _ready_card("hidden_%s_%s" % [first_card.id, second_card.id], "藏招·%s/%s" % [first_card.display_name, second_card.display_name], "双重杀伤的藏招。", 1, 3, fused_cost, CardData.ROLE_ATTACK, 0, 0, first_card.damage + second_card.damage, 0, tags)


func _open_deck_view() -> void:
	if player == null:
		return
	if not battle_active:
		_open_battle_deck_builder()
		return
	var body := _build_deck_view_text()
	_show_overlay("牌组", body, [{"text": "关闭", "callback": Callable(self, "_hide_overlay")}])


func _build_deck_view_text() -> String:
	if player == null:
		return "尚未初始化。"
	var lines: Array[String] = []
	var deck := player.get_session_deck()
	var battle_deck := player.get_selected_battle_deck()
	if not battle_active:
		lines.append("[b]长期牌库[/b]")
		for i in range(deck.size()):
			lines.append("%d. %s" % [i + 1, deck[i].short_summary()])
		lines.append("")
		lines.append("[b]入战牌组 %d/%d[/b]" % [battle_deck.size(), PLAYER_BATTLE_DECK_SIZE])
		for i in range(battle_deck.size()):
			lines.append("%d. %s" % [i + 1, battle_deck[i].short_summary()])
	else:
		lines.append("[b]本场入战牌组[/b]")
		for i in range(battle_deck.size()):
			lines.append("%d. %s" % [i + 1, battle_deck[i].short_summary()])
		lines.append("")
		lines.append("[b]当前手牌[/b]")
		for i in range(player.hand.size()):
			lines.append("%d. %s" % [i + 1, player.hand[i].short_summary()])
		lines.append("")
		lines.append("[b]抽牌堆[/b]")
		for i in range(player.draw_pile.size()):
			lines.append("%d. %s" % [i + 1, player.draw_pile[i].short_summary()])
		lines.append("")
		lines.append("[b]弃牌堆[/b]")
		for i in range(player.discard_pile.size()):
			lines.append("%d. %s" % [i + 1, player.discard_pile[i].short_summary()])
	lines.append("")
	lines.append("[b]已解锁连招[/b]")
	for combo in _combo_chains_for_profession(player.data.id):
		var missing := _combo_missing_cards(player, combo)
		if missing.is_empty():
			lines.append("- %s：已解锁" % combo.get("display_name", ""))
		else:
			lines.append("- %s：未解锁（缺 %s）" % [combo.get("display_name", ""), ", ".join(missing)])
	return "\n".join(lines)


func _start_battle() -> void:
	if player == null or enemy == null:
		return
	if not _player_battle_deck_ready():
		_log("入战牌组需要正好 %d 张，请先用【牌组】调整；开始战斗不会自动打开牌库。" % PLAYER_BATTLE_DECK_SIZE)
		return
	_hide_battle_result_overlay()
	battle_active = true
	battle_count += 1
	player.reset_for_battle(HAND_SIZE)
	enemy.reset_for_battle(HAND_SIZE)
	state_machine.begin_battle(absi(enemy.position - player.position))
	state_machine.update_distance_from_positions(player, enemy)
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	declaration_index = 0
	fusion_first_index = -1
	_log("[b]演武开始。[/b] 第 %d 场，对距固定从 2 开始。玩家会话武境 %d，敌方会话武境 %d。" % [battle_count, player.session_realm, enemy.session_realm])
	_show_node_buttons()
	_begin_round()


func _begin_round() -> void:
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	state_machine.update_distance_from_positions(player, enemy)
	if state_machine.round_index > 1:
		var player_gain := player.recover_momentum(ROUND_MOMENTUM_RECOVERY)
		var enemy_gain := enemy.recover_momentum(ROUND_MOMENTUM_RECOVERY)
		if player_gain > 0 or enemy_gain > 0:
			_log("[b]回合调息。[/b] 玩家 +%d 势，敌方 +%d 势。" % [player_gain, enemy_gain])
	if player.control_state != Fighter.CONTROL_NONE or enemy.control_state != Fighter.CONTROL_NONE or player.combo_window_active or enemy.combo_window_active:
		_log("[b]当前势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
	declaration_order = state_machine.get_declaration_order(player, enemy)
	declaration_index = 0
	awaiting_player_input = false
	_update_phase_label()
	_advance_declaration()
	_refresh_ui()


func _advance_declaration() -> void:
	while declaration_index < declaration_order.size():
		var actor_id: String = declaration_order[declaration_index]
		if actor_id == player.data.id:
			if player.is_broken():
				player_intent = IntentData.from_card(player, _stagger_card())
				_show_combat_banner("玩家崩势", Color("4a1f24"), Color("ff6b6b"))
				_impact_feedback(Color("ff6b6b"), 7.0)
				_flash_label(player_label, Color("ff9f9f"))
				_log("玩家崩势未稳，本回合无法行动。")
				declaration_index += 1
				continue
			awaiting_player_input = true
			_refresh_hand_buttons()
			_refresh_ui()
			return
		if enemy.is_broken():
			enemy_intent = IntentData.from_card(enemy, _stagger_card())
			_show_combat_banner("敌方崩势", Color("4a1f24"), Color("ff6b6b"))
			_impact_feedback(Color("ff6b6b"), 7.0)
			_flash_label(enemy_label, Color("ff9f9f"))
			_log("敌方崩势未稳，本回合无法行动。")
			declaration_index += 1
			continue
		var seen_intent: IntentData = player_intent if player_intent != null else null
		enemy_intent = enemy_ai.choose_intent(enemy, player, state_machine.current_distance, seen_intent)
		if enemy_intent.actual_card.id != "idle" and enemy_intent.actual_card.id != "staggered":
			enemy.spend_momentum(enemy_intent.actual_card.momentum_cost)
		_log("敌方定招：%s。" % state_machine.get_visible_intent_text(enemy_intent, player))
		declaration_index += 1
	awaiting_player_input = false
	_resolve_round()


func _reset_draft_intent() -> void:
	draft_player_intent = null
	_reset_player_stance_draft()
	_refresh_ui()


func _refresh_hand_buttons() -> void:
	pass


func _on_player_card_pressed(card: CardData) -> void:
	if not awaiting_player_input:
		return
	var reason := _card_restriction_reason(player, card)
	if reason != "":
		_log(reason)
		return
	if card.momentum_cost > player.momentum:
		_log("势不足，无法选用 %s。" % card.display_name)
		return
	draft_player_intent = IntentData.from_card(player, card)
	_apply_player_stance_draft_to_intent()
	var combo_marker := _combo_marker_text(player, card)
	if combo_marker != "":
		_log("已选定%s [color=#95e1d3]%s[/color]。%s" % [_card_role_prefix(card), card.display_name, combo_marker])
	else:
		_log("已选定%s [color=#95e1d3]%s[/color]，请确认出招。" % [_card_role_prefix(card), card.display_name])
	_refresh_ui()


func _confirm_player_intent() -> void:
	if not awaiting_player_input or draft_player_intent == null:
		return
	_apply_player_stance_draft_to_intent()
	if draft_player_intent.actual_card.id != "idle" and draft_player_intent.actual_card.id != "staggered" and not player.spend_momentum(draft_player_intent.actual_card.momentum_cost):
		_log("你的势不足，无法确认这招。")
		_refresh_ui()
		return
	player_intent = draft_player_intent
	draft_player_intent = null
	_finish_player_declaration()


func _finish_player_declaration() -> void:
	awaiting_player_input = false
	declaration_index += 1
	_log("玩家定招：%s。" % state_machine.get_visible_intent_text(player_intent, enemy))
	_advance_declaration()
	_refresh_ui()


func _reset_player_stance_draft() -> void:
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false


func _player_target_position() -> int:
	if draft_player_has_position:
		return draft_player_position
	if draft_player_intent != null and draft_player_intent.target_position >= 0:
		return draft_player_intent.target_position
	return player.position if player != null else 0


func _player_target_facing() -> String:
	if draft_player_has_position and draft_player_facing != "":
		return draft_player_facing
	if draft_player_intent != null and draft_player_intent.target_facing != "":
		return draft_player_intent.target_facing
	return player.facing if player != null else "right"


func _apply_player_stance_draft_to_intent() -> void:
	if draft_player_intent == null or player == null:
		return
	var target_position := _player_target_position()
	var target_facing := _player_target_facing()
	if not draft_player_has_position:
		target_position = player.position
		target_facing = player.facing
	draft_player_intent.set_stance(target_position, target_facing)


func _legal_positions_for(fighter: Fighter) -> Array[int]:
	var result: Array[int] = []
	if fighter == null:
		return result
	var start := clampi(fighter.position - fighter.qinggong, 0, BATTLE_SLOT_COUNT - 1)
	var finish := clampi(fighter.position + fighter.qinggong, 0, BATTLE_SLOT_COUNT - 1)
	for slot in range(start, finish + 1):
		result.append(slot)
	return result


func _is_player_legal_position(slot: int) -> bool:
	return _legal_positions_for(player).has(slot)


func _on_stage_grid_slot_pressed(slot: int) -> void:
	if not awaiting_player_input or player == null:
		return
	if not _is_player_legal_position(slot):
		_log("轻功不足，不能移动到该格。")
		return
	var current_target := _player_target_position()
	if draft_player_has_position and slot == current_target and slot == player.position:
		draft_player_facing = _opposite_facing(_player_target_facing())
	else:
		draft_player_position = slot
		draft_player_facing = _facing_toward(slot, enemy.position if enemy != null else slot, player.facing)
		draft_player_has_position = true
	_apply_player_stance_draft_to_intent()
	_log("已选身位：%d，朝向%s。" % [slot, "左" if _player_target_facing() == "left" else "右"])
	_invalidate_stage_preview()
	_refresh_ui()


func _facing_toward(actor_position: int, target_position: int, fallback: String) -> String:
	if actor_position == target_position:
		return fallback
	return "right" if target_position > actor_position else "left"


func _opposite_facing(value: String) -> String:
	return "left" if value == "right" else "right"


func _invalidate_stage_preview() -> void:
	pass


func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines: Array[String] = []
	if actor == null or intent == null or intent.actual_card == null:
		return lines
	if not actor.combo_window_active:
		return lines
	var card: CardData = intent.actual_card
	if card.id == "staggered":
		return lines
	actor.consume_combo_window()
	var combo := _get_triggerable_combo(actor, card)
	if combo.is_empty():
		lines.append("[color=#7f8c8d]%s 未衔接到已解锁连招，本次连招窗口消散。[/color]" % actor.data.display_name)
		return lines
	var fx := _combo_feedback_profile(actor.data.id)
	_show_combat_banner(
		"%s：%s" % [fx.get("start_banner", "连招启动"), combo.get("display_name", "")],
		fx.get("start_fill", Color("3f2916")),
		fx.get("start_border", Color("ffd479"))
	)
	_impact_feedback(
		fx.get("start_flash", Color("ffd479")),
		float(fx.get("start_shake", 4.0)),
		bool(fx.get("start_horizontal_only", false)),
		bool(fx.get("start_extra_pulse", false))
	)
	_play_profession_shape_feedback(actor.data.id, fx.get("start_flash", Color("ffd479")), false, true)
	_flash_label(player_label if actor.data.id == player.data.id else enemy_label, fx.get("label_color", Color("ffe39c")))
	lines.append("[color=#ffd479][b]>>> %s · %s <<<[/b][/color]" % [fx.get("log_flair", "连招启动"), combo.get("display_name", "")])
	for idx in range(combo.get("followups", []).size()):
		if target.hp <= 0:
			break
		var segment: Dictionary = combo.get("followups", [])[idx]
		var segment_name: String = segment.get("name", "追击")
		var segment_type: String = segment.get("segment_type", "追击")
		var is_finisher := bool(segment.get("is_finisher", false))
		var effective_damage: int = int(segment.get("base_damage", 0))
		if target.is_broken():
			effective_damage *= 2
			lines.append("[color=#ff8c42]%s 处于崩势，%s伤害翻倍至 %d。[/color]" % [target.data.display_name, segment_name, effective_damage])
		var remaining_damage := target.absorb_damage(effective_damage)
		var blocked := effective_damage - remaining_damage
		var header := "[b][%d/%d][%s]%s[/%s][/b]" % [idx + 1, combo.get("followups", []).size(), segment_type, segment_name, segment_type]
		if blocked > 0:
			lines.append("%s 被格挡化去 %d。" % [segment_name, blocked])
		if remaining_damage > 0:
			target.hp = maxi(target.hp - remaining_damage, 0)
			if is_finisher:
				_impact_feedback(
					fx.get("finisher_flash", Color("ff4d6d")),
					float(fx.get("finisher_shake", 9.0)),
					bool(fx.get("finisher_horizontal_only", false)),
					bool(fx.get("finisher_extra_pulse", false))
				)
				_play_profession_shape_feedback(actor.data.id, fx.get("finisher_flash", Color("ff4d6d")), true, false)
				_show_target_receive_feedback(target, actor.data.id, fx.get("finisher_flash", Color("ff4d6d")), true)
			else:
				_impact_feedback(
					fx.get("segment_flash", Color("ffc7c7")),
					float(fx.get("segment_shake", 3.0)),
					bool(fx.get("segment_horizontal_only", false)),
					bool(fx.get("segment_extra_pulse", false))
				)
				_play_profession_shape_feedback(actor.data.id, fx.get("segment_flash", Color("ffc7c7")), false, false)
				_show_target_receive_feedback(target, actor.data.id, fx.get("segment_flash", Color("ffc7c7")), false)
			lines.append("%s %s 命中，造成 %d 伤害。%s。" % [header, actor.data.display_name, remaining_damage, fx.get("segment_flair", "气势压上")])
		else:
			lines.append("%s 被完全格挡。" % header)
			if is_finisher:
				_show_combat_banner(
					"%s：%s" % [fx.get("finisher_banner", "终结"), segment_name],
					fx.get("finisher_fill", Color("4a1626")),
					fx.get("finisher_border", Color("ff4d6d"))
				)
				_flash_label(enemy_label if target.data.id == enemy.data.id else player_label, fx.get("label_color", Color("ff7a7a")))
				lines.append("[color=#ff4d6d][b]!!! %s 以 %s 完成终结 · %s !!![/b][/color]" % [actor.data.display_name, segment_name, fx.get("log_flair", "")])
	return lines


func _build_intent_feedback(actor: Fighter, target: Fighter, intent: IntentData, resolution_distance: int, target_hp_before: int, target_guard_before: int) -> Dictionary:
	var feedback := {
		"is_attack": false,
		"was_in_range": false,
		"connected": false,
		"blocked_only": false,
		"missed": false,
		"range_result": BattleStateMachine.RANGE_HIT,
		"hp_damage": 0,
		"guard_damage": 0
	}
	if actor == null or target == null or intent == null or intent.actual_card == null:
		return feedback
	var card: CardData = intent.actual_card
	if card.damage <= 0:
		return feedback
	var hp_damage := maxi(target_hp_before - target.hp, 0)
	var guard_damage := maxi(target_guard_before - target.guard_points, 0)
	var range_result := state_machine.evaluate_card_range(card, actor, target)
	var was_in_range := range_result == BattleStateMachine.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == BattleStateMachine.RANGE_GRAZE)
	feedback["is_attack"] = true
	feedback["was_in_range"] = was_in_range
	feedback["connected"] = was_in_range and (hp_damage > 0 or guard_damage > 0)
	feedback["blocked_only"] = was_in_range and hp_damage == 0 and guard_damage > 0
	feedback["missed"] = not was_in_range
	feedback["range_result"] = range_result
	feedback["hp_damage"] = hp_damage
	feedback["guard_damage"] = guard_damage
	return feedback


func _on_intent_resolved(_actor: Fighter, _target: Fighter, _intent: IntentData, _feedback: Dictionary) -> void:
	pass


func _resolve_round() -> void:
	state_machine.phase = BattleStateMachine.BattlePhase.RESOLUTION
	if not state_machine.is_reactive_mode():
		_apply_symmetric_declared_stances()
	var order: Array[IntentData] = state_machine.get_resolution_order(player, enemy, player_intent, enemy_intent)
	_log_declared_stances()
	_log("[b]结算顺序：[/b] %s -> %s" % [order[0].get_actual_name(), order[1].get_actual_name()])
	for intent in order:
		var actor := player if intent.actor_id == player.data.id else enemy
		var target := enemy if intent.actor_id == player.data.id else player
		if actor.hp <= 0:
			break
		var resolution_distance := state_machine.update_distance_from_positions(player, enemy)
		var target_hp_before := target.hp
		var target_guard_before := target.guard_points
		var target_was_pending_broken := target.pending_control_state == Fighter.CONTROL_BROKEN
		var actor_action_canceled := state_machine.is_reactive_mode() and actor.pending_control_state == Fighter.CONTROL_BROKEN
		var lines := state_machine.resolve_intent(intent, actor, target)
		var feedback := _build_intent_feedback(actor, target, intent, resolution_distance, target_hp_before, target_guard_before)
		if not target_was_pending_broken and target.pending_control_state == Fighter.CONTROL_BROKEN:
			_show_combat_banner("崩势", Color("4a1f24"), Color("ff6b6b"))
			_impact_feedback(Color("ff6b6b"), 8.0)
			_flash_label(enemy_label if target.data.id == enemy.data.id else player_label, Color("ff8a8a"))
		for line in lines:
			_log(line)
		if not actor_action_canceled:
			_on_intent_resolved(actor, target, intent, feedback)
			var combo_lines := _resolve_combo_chain_if_any(actor, target, intent)
			for line in combo_lines:
				_log(line)
		_refresh_ui()
		if target.hp <= 0:
			break

	player.discard_cards(player_intent.get_consumed_cards())
	enemy.discard_cards(enemy_intent.get_consumed_cards())
	player.draw_to(HAND_SIZE)
	enemy.draw_to(HAND_SIZE)
	if player.hp <= 0 or enemy.hp <= 0:
		_finish_battle()
		return
	state_machine.finish_round(player, enemy)
	_log("[b]回合势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
	_begin_round()


func _log_declared_stances() -> void:
	var player_position: int = _intent_target_position_or_current(player, player_intent)
	var enemy_position: int = _intent_target_position_or_current(enemy, enemy_intent)
	var player_facing: String = _intent_target_facing_or_current(player, player_intent)
	var enemy_facing: String = _intent_target_facing_or_current(enemy, enemy_intent)
	_log("[b]身位宣告：[/b] 玩家 %d 朝%s，敌方 %d 朝%s，宣告距离 %d。" % [
		player_position,
		"左" if player_facing == "left" else "右",
		enemy_position,
		"左" if enemy_facing == "left" else "右",
		absi(enemy_position - player_position)
	])


func _apply_symmetric_declared_stances() -> void:
	_apply_intent_stance(player, player_intent)
	_apply_intent_stance(enemy, enemy_intent)
	state_machine.update_distance_from_positions(player, enemy)


func _apply_intent_stance(fighter: Fighter, intent: IntentData) -> void:
	if fighter == null or intent == null:
		return
	var target_position := _intent_target_position_or_current(fighter, intent)
	var target_facing := _intent_target_facing_or_current(fighter, intent)
	fighter.set_stance(target_position, target_facing)


func _intent_target_position_or_current(fighter: Fighter, intent: IntentData) -> int:
	if fighter == null:
		return 0
	if intent == null or intent.target_position < 0:
		return fighter.position
	return intent.target_position


func _intent_target_facing_or_current(fighter: Fighter, intent: IntentData) -> String:
	if fighter == null:
		return "right"
	if intent == null or intent.target_facing == "":
		return fighter.facing
	return intent.target_facing


func _finish_battle() -> void:
	battle_active = false
	awaiting_player_input = false
	state_machine.phase = BattleStateMachine.BattlePhase.RESULT
	var result_text := "玩家落败。"
	if enemy.hp <= 0:
		result_text = "玩家获胜。"
	_show_combat_banner(
		result_text,
		Color("1f3f2a") if enemy.hp <= 0 else Color("4a1f24"),
		Color("8be28b") if enemy.hp <= 0 else Color("ff8a8a")
	)
	_impact_feedback(Color("8be28b") if enemy.hp <= 0 else Color("ff8a8a"), 5.0)
	_log("[b]演武结束。[/b] %s" % result_text)
	_show_node_buttons()
	_refresh_ui()
	_queue_battle_result_overlay(enemy.hp <= 0 and player.hp > 0)


func _queue_battle_result_overlay(victory: bool) -> void:
	call_deferred("_show_battle_result_overlay_after_presentation", victory)


func _show_battle_result_overlay_after_presentation(victory: bool) -> void:
	while has_method("_presentation_busy") and bool(call("_presentation_busy")):
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.30).timeout
	_show_battle_result_overlay(victory)


func _show_battle_result_overlay(victory: bool) -> void:
	if battle_result_title == null or battle_result_body == null or battle_result_actions == null:
		return
	var title := "战斗胜利" if victory else "战斗失败"
	var body := "" if victory else "重新再来"
	var callback := Callable(self, "_on_battle_result_confirm_pressed") if victory else Callable(self, "_on_battle_retry_confirm_pressed")
	battle_result_title.text = title
	battle_result_body.text = body
	for child in battle_result_actions.get_children():
		child.queue_free()
	var button := Button.new()
	button.text = "确认"
	button.custom_minimum_size = Vector2(160, 42)
	button.pressed.connect(callback)
	battle_result_actions.add_child(button)
	if battle_result_scrim != null:
		battle_result_scrim.visible = true
		battle_result_scrim.move_to_front()
	if battle_result_panel != null:
		battle_result_panel.visible = true
		battle_result_panel.move_to_front()
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")


func _on_battle_result_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	_show_node_buttons()
	_refresh_ui()


func _on_battle_retry_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	_start_battle()


func _hide_battle_result_overlay() -> void:
	if battle_result_scrim != null:
		battle_result_scrim.visible = false
	if battle_result_panel != null:
		battle_result_panel.visible = false


func _update_phase_label() -> void:
	if phase_label == null:
		return
	if not battle_active:
		phase_label.text = "节点阶段：战斗摘要 / 牌组 / 演武"
		return
	var declare_names: Array[String] = []
	for actor_id in declaration_order:
		if player != null and actor_id == player.data.id:
			declare_names.append(player.data.display_name)
		elif enemy != null and actor_id == enemy.data.id:
			declare_names.append(enemy.data.display_name)
		else:
			declare_names.append(actor_id)
	var declare_text := " -> ".join(declare_names)
	phase_label.text = "回合 %d｜定招顺序：%s" % [state_machine.round_index, declare_text]
	if player != null and player.combo_window_active:
		phase_label.text += "｜玩家连招窗口开启"
	elif enemy != null and enemy.combo_window_active:
		phase_label.text += "｜敌方连招窗口开启"


func _refresh_ui() -> void:
	if round_label != null:
		round_label.text = "演武 %d｜距离 %d" % [battle_count, state_machine.current_distance]
	_update_phase_label()
	if deck_button != null:
		deck_button.disabled = player == null
	if reset_pick_button != null:
		reset_pick_button.disabled = not awaiting_player_input or draft_player_intent == null
	if confirm_button != null:
		confirm_button.disabled = not awaiting_player_input or draft_player_intent == null
	_refresh_log()
	_show_node_buttons()


func _fighter_status_text(fighter: Fighter) -> String:
	if fighter == null:
		return ""
	return fighter.data.display_name


func _intent_panel_text(intent: IntentData, viewer: Fighter, is_player: bool) -> String:
	if intent == null:
		return ""
	return intent.get_actual_name()


func _status_text() -> String:
	if player == null or enemy == null:
		return "等待选择角色。"
	var lines: Array[String] = []
	lines.append("[b]当前概况[/b]")
	lines.append("演武 %d｜距离 %d｜回合 %d" % [battle_count, state_machine.current_distance, state_machine.round_index])
	lines.append("玩家：%s｜生命 %d/%d｜势 %d/%d｜护值 %d｜位 %d｜朝%s" % [player.data.display_name, player.hp, player.data.max_hp, player.momentum, player.data.max_momentum, player.guard_points, player.position, "左" if player.facing == "left" else "右"])
	lines.append("敌方：%s｜生命 %d/%d｜势 %d/%d｜护值 %d｜位 %d｜朝%s" % [enemy.data.display_name, enemy.hp, enemy.data.max_hp, enemy.momentum, enemy.data.max_momentum, enemy.guard_points, enemy.position, "左" if enemy.facing == "left" else "右"])
	lines.append("")
	lines.append("[b]当前规则状态[/b]")
	lines.append("- %s" % state_machine.tie_rule_text(player, enemy))
	lines.append("- %s" % state_machine.pressure_state_text(player, enemy))
	return "\n".join(lines)


func _preview_text() -> String:
	return ""


func _simulate_preview(player_preview_intent: IntentData, enemy_preview_intent: IntentData) -> String:
	return ""


func _draft_uses_card(card: CardData) -> bool:
	if draft_player_intent == null:
		return false
	for used_card in draft_player_intent.get_consumed_cards():
		if used_card == card:
			return true
	return false


func _idle_card() -> CardData:
	return _ready_card("idle", "不动", "本回合不出招，不产生额外效果。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0, PackedStringArray(), "", false)


func _preview_wait_card() -> CardData:
	return _ready_card("preview_wait", "待机", "仅用于预览：尚未选招时按什么都不做处理。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0, PackedStringArray(), "", false)


func _stagger_card() -> CardData:
	return _ready_card("staggered", "崩势硬直", "势被打崩，下一回合无法行动。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0, PackedStringArray(), "", false)


func _refresh_log() -> void:
	if log_label != null:
		log_label.text = "\n".join(_recent_logs())


func _recent_logs() -> Array[String]:
	var logs: Array[String] = []
	for line in get_meta("battle_logs", []):
		logs.append(line)
	return logs.slice(maxi(logs.size() - 20, 0), logs.size())


func _log(message: String) -> void:
	var logs: Array[String] = []
	if has_meta("battle_logs"):
		logs = get_meta("battle_logs")
	logs.append(message)
	set_meta("battle_logs", logs)
	_refresh_log()


func _show_overlay(title: String, body: String, actions: Array) -> void:
	if overlay_title == null or overlay_body == null or overlay_actions == null:
		return
	_set_overlay_standard_size()
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = true
	for child in overlay_actions.get_children():
		child.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = action["text"]
		button.pressed.connect(action["callback"])
		button.disabled = bool(action.get("disabled", false))
		overlay_actions.add_child(button)
	overlay_scrim.visible = true
	overlay_panel.visible = true
	overlay_scrim.move_to_front()
	overlay_panel.move_to_front()


func _set_overlay_standard_size() -> void:
	if overlay_panel == null:
		return
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.12
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.offset_top = 0
	overlay_panel.offset_bottom = 0


func _set_overlay_deck_builder_size() -> void:
	if overlay_panel == null:
		return
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.06
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.85
	overlay_panel.offset_left = -570
	overlay_panel.offset_right = 570
	overlay_panel.offset_top = 0
	overlay_panel.offset_bottom = 0


func _hide_overlay() -> void:
	if overlay_scrim != null:
		overlay_scrim.visible = false
	if overlay_panel != null:
		overlay_panel.visible = false
