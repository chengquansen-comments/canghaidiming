extends Control

const BattleFontHelper = preload("res://scripts/visual/battle_font_view.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")

var _content_box: VBoxContainer

func _ready() -> void:
	_build_ui()
	_force_cjk_font()

func _force_cjk_font() -> void:
	BattleFontHelper.enforce(self)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("10151d")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -220
	panel.offset_right = 300
	panel.offset_bottom = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2230")
	style.border_color = Color("bfa06a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_content_box = VBoxContainer.new()
	_content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_theme_constant_override("separation", 16)
	panel.add_child(_content_box)
	_show_main_menu()

func _clear_content_box() -> void:
	for child in _content_box.get_children():
		child.queue_free()

func _show_main_menu() -> void:
	_clear_content_box()
	var title := Label.new()
	title.text = "沧海嘀鸣 · 开发入口"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	_content_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "剧情 MVP 和战斗测试已分开。剧情入口用于验证压缩叙事，战斗测试用于调试剧情遭遇、数值和表现。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(500, 0)
	subtitle.modulate = Color("c9d2df")
	_content_box.add_child(subtitle)

	var narrative_button := Button.new()
	narrative_button.text = "进入剧情 MVP"
	narrative_button.custom_minimum_size = Vector2(300, 54)
	narrative_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/NarrativeDemo.tscn")
	)
	_content_box.add_child(narrative_button)

	var world_map_debug_button := Button.new()
	world_map_debug_button.text = "海疆大势图 Debug"
	world_map_debug_button.custom_minimum_size = Vector2(300, 54)
	world_map_debug_button.pressed.connect(func() -> void:
		NarrativeBattleContext.set_debug_entry_world_map()
		get_tree().change_scene_to_file("res://scenes/NarrativeDemo.tscn")
	)
	_content_box.add_child(world_map_debug_button)

	var visual_button := Button.new()
	visual_button.text = "战斗测试"
	visual_button.custom_minimum_size = Vector2(300, 54)
	visual_button.pressed.connect(func() -> void:
		NarrativeBattleContext.clear()
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
	)
	_content_box.add_child(visual_button)

	var settings_button := Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(300, 54)
	settings_button.pressed.connect(_show_settings_page)
	_content_box.add_child(settings_button)

func _show_settings_page() -> void:
	_clear_content_box()
	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	_content_box.add_child(title)

	var graze_state := "开" if CombatResolver.ENABLE_GRAZE else "关"
	var body := Label.new()
	body.text = "擦中规则：%s\n\n开启后，距离只差 1 格的攻击会判定为擦中，并按当前收束规则造成半伤、削势 -1。关闭后，擦中视为距离未命中。" % graze_state
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(500, 0)
	body.modulate = Color("c9d2df")
	_content_box.add_child(body)

	var graze_button := Button.new()
	graze_button.text = "擦中规则：%s" % graze_state
	graze_button.custom_minimum_size = Vector2(300, 54)
	graze_button.pressed.connect(_toggle_graze_setting)
	_content_box.add_child(graze_button)

	var back_button := Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(300, 54)
	back_button.pressed.connect(_show_main_menu)
	_content_box.add_child(back_button)

func _toggle_graze_setting() -> void:
	CombatResolver.ENABLE_GRAZE = not CombatResolver.ENABLE_GRAZE
	_show_settings_page()
