extends Control

const WEB_VISUAL_SCENE := "res://scenes/MainVisual.tscn"

var _status_label: Label

func _ready() -> void:
	if not OS.has_feature("web"):
		get_tree().change_scene_to_file(WEB_VISUAL_SCENE)
		return
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("0f141d")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_top = -228
	panel.offset_right = 340
	panel.offset_bottom = 228
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182231")
	style.border_color = Color("d8b26e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "沧海嘀鸣 · Web 版"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "点击开始进入正式视觉版战斗。建议使用 Chrome / Edge / Firefox 桌面浏览器。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(600, 0)
	subtitle.modulate = Color("c9d2df")
	box.add_child(subtitle)

	var hint := Label.new()
	hint.text = "浏览器环境下请通过本地服务器或静态站点打开，不要直接双击 html 文件。首次点击页面后再进入战斗更稳。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(600, 0)
	hint.modulate = Color("9aa8bb")
	box.add_child(hint)

	_status_label = Label.new()
	_status_label.text = _status_text()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(600, 0)
	_status_label.modulate = Color("d9cfb1")
	box.add_child(_status_label)

	var start_button := Button.new()
	start_button.text = "开始战斗"
	start_button.custom_minimum_size = Vector2(280, 56)
	start_button.pressed.connect(_enter_visual_scene)
	box.add_child(start_button)

	var fallback_button := Button.new()
	fallback_button.text = "重新加载当前页"
	fallback_button.custom_minimum_size = Vector2(280, 48)
	fallback_button.pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
	box.add_child(fallback_button)

func _status_text() -> String:
	var viewport_size := get_viewport_rect().size
	var lines: Array[String] = []
	lines.append("运行环境：%s" % ("Web 浏览器" if OS.has_feature("web") else "本地运行"))
	lines.append("窗口大小：%d × %d" % [int(viewport_size.x), int(viewport_size.y)])
	lines.append("推荐先点击页面，再开始战斗。")
	return "\n".join(lines)

func _enter_visual_scene() -> void:
	get_tree().change_scene_to_file(WEB_VISUAL_SCENE)
