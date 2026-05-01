extends Control

const BattleFontHelper = preload("res://scripts/visual/battle_font_view.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")

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

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Label.new()
	title.text = "沧海嘀鸣 · 开发入口"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "剧情 MVP、字符版战斗、战斗测试已分开。剧情入口用于验证压缩叙事，战斗测试用于调试剧情遭遇、数值和表现。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(500, 0)
	subtitle.modulate = Color("c9d2df")
	box.add_child(subtitle)

	var narrative_button := Button.new()
	narrative_button.text = "进入剧情 MVP"
	narrative_button.custom_minimum_size = Vector2(300, 54)
	narrative_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/NarrativeDemo.tscn")
	)
	box.add_child(narrative_button)

	var text_button := Button.new()
	text_button.text = "进入字符版战斗"
	text_button.custom_minimum_size = Vector2(300, 54)
	text_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainText.tscn")
	)
	box.add_child(text_button)

	var visual_button := Button.new()
	visual_button.text = "战斗测试"
	visual_button.custom_minimum_size = Vector2(300, 54)
	visual_button.pressed.connect(func() -> void:
		NarrativeBattleContext.clear()
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
	)
	box.add_child(visual_button)
