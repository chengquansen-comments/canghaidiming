extends Control

const WEB_VISUAL_SCENE := "res://scenes/MainVisual.tscn"
const NARRATIVE_MVP_SCENE := "res://scenes/NarrativeDemo.tscn"
const WebRuntimeFlags = preload("res://scripts/web_runtime_flags.gd")
const BattleFontHelper = preload("res://scripts/visual/battle_font_view.gd")
const NarrativeBattleContext = preload("res://scripts/narrative_battle_context.gd")
const SMOKE_BATTLE_FLAG := "smoke_battle"
const NARRATIVE_FLAG := "narrative_mvp"

var _status_label: Label
var _content_box: VBoxContainer

func _ready() -> void:
	if not OS.has_feature("web"):
		get_tree().change_scene_to_file(WEB_VISUAL_SCENE)
		return
	_build_ui()
	_force_cjk_font()
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", "launcher-ready")
	if WebRuntimeFlags.has_query_flag(SMOKE_BATTLE_FLAG):
		_status_label.text += "\nSmoke：自动进入战斗入口中。"
		_force_cjk_font()
		call_deferred("_auto_enter_visual_scene_for_smoke")
	elif WebRuntimeFlags.has_query_flag(NARRATIVE_FLAG):
		_status_label.text += "\nNarrative：自动进入剧情 MVP。"
		_force_cjk_font()
		call_deferred("_enter_narrative_mvp_scene")

func _force_cjk_font() -> void:
	BattleFontHelper.enforce(self)

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
	panel.offset_left = -360
	panel.offset_top = -280
	panel.offset_right = 360
	panel.offset_bottom = 280
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

	_content_box = VBoxContainer.new()
	_content_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_theme_constant_override("separation", 14)
	panel.add_child(_content_box)
	_show_main_menu()

func _clear_content_box() -> void:
	for child in _content_box.get_children():
		child.queue_free()

func _show_main_menu() -> void:
	_clear_content_box()
	var title := Label.new()
	title.text = "沧海嘀鸣 · Web 版"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	_content_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "剧情 MVP 和战斗测试已经分开。先体验压缩叙事，或直接进入当前选角色战斗入口。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(640, 0)
	subtitle.modulate = Color("c9d2df")
	_content_box.add_child(subtitle)

	var hint := Label.new()
	hint.text = "浏览器环境下请通过本地服务器或静态站点打开，不要直接双击 html 文件。首次点击页面后再进入更稳。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(640, 0)
	hint.modulate = Color("9aa8bb")
	_content_box.add_child(hint)

	_status_label = Label.new()
	_status_label.text = _status_text()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(640, 0)
	_status_label.modulate = Color("d9cfb1")
	_content_box.add_child(_status_label)

	var narrative_button := Button.new()
	narrative_button.text = "进入剧情 MVP"
	narrative_button.custom_minimum_size = Vector2(300, 56)
	narrative_button.pressed.connect(_enter_narrative_mvp_scene)
	_content_box.add_child(narrative_button)

	var start_button := Button.new()
	start_button.text = "战斗测试"
	start_button.custom_minimum_size = Vector2(300, 56)
	start_button.pressed.connect(_enter_visual_scene)
	_content_box.add_child(start_button)

	var settings_button := Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(300, 56)
	settings_button.pressed.connect(_show_settings_page)
	_content_box.add_child(settings_button)

	var fallback_button := Button.new()
	fallback_button.text = "重新加载当前页"
	fallback_button.custom_minimum_size = Vector2(300, 48)
	fallback_button.pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
	_content_box.add_child(fallback_button)

func _show_settings_page() -> void:
	_clear_content_box()
	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	_content_box.add_child(title)

	var graze_state := "开" if CombatResolver.ENABLE_GRAZE else "关"
	var body := Label.new()
	body.text = "擦中规则：%s\n\n开启后，距离只差 1 格的攻击会判定为擦中，并按当前收束规则造成半伤、削势 -1。关闭后，擦中视为距离未命中。" % graze_state
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 0)
	body.modulate = Color("c9d2df")
	_content_box.add_child(body)

	var graze_button := Button.new()
	graze_button.text = "擦中规则：%s" % graze_state
	graze_button.custom_minimum_size = Vector2(300, 56)
	graze_button.pressed.connect(_toggle_graze_setting)
	_content_box.add_child(graze_button)

	var back_button := Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(300, 56)
	back_button.pressed.connect(_show_main_menu)
	_content_box.add_child(back_button)

func _toggle_graze_setting() -> void:
	CombatResolver.ENABLE_GRAZE = not CombatResolver.ENABLE_GRAZE
	_show_settings_page()

func _status_text() -> String:
	var viewport_size := get_viewport_rect().size
	var lines: Array[String] = []
	lines.append("运行环境：%s" % ("Web 浏览器" if OS.has_feature("web") else "本地运行"))
	lines.append("窗口大小：%d × %d" % [int(viewport_size.x), int(viewport_size.y)])
	lines.append("剧情入口：压缩版叙事 MVP；战斗入口：当前选角色战斗测试。")
	return "\n".join(lines)

func _auto_enter_visual_scene_for_smoke() -> void:
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", "launcher-autostart")
	_enter_visual_scene()

func _enter_visual_scene() -> void:
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", "battle-scene-change-requested")
	NarrativeBattleContext.clear()
	get_tree().change_scene_to_file(WEB_VISUAL_SCENE)

func _enter_narrative_mvp_scene() -> void:
	WebRuntimeFlags.set_body_dataset("webSmokeBattle", "narrative-scene-change-requested")
	get_tree().change_scene_to_file(NARRATIVE_MVP_SCENE)
