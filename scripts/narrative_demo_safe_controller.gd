extends Control

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")
const MAP_COLUMNS: Array[String] = ["军令", "初遇", "疑点", "压迫", "破船", "军门"]

var title_label: Label
var status_label: Label
var map_label: Label
var scene_label: Label
var visual_texture: TextureRect
var visual_label: Label
var body_label: RichTextLabel
var vars_label: Label
var map_buttons_box: VBoxContainer
var combat_buttons_box: VBoxContainer
var choices_box: VBoxContainer
var step_index := 0
var node_index := 0
var jun_gong := 0
var qing_wang := 0
var clues := 0
var in_prologue := true
var battle_requested := false
var last_hint := ""

const PROLOGUE := [
	"倭寇袭村：黑屏潮声",
	"父亲：孩子不知道。",
	"敌人：死人也不知道。",
	"父母遇害，黑屏刀声。",
	"幼年主角挥木刀，造成 0 伤害。",
	"敌人一刀击倒主角。",
	"师父入场，玩家操控师父。",
	"用 3 张强力牌击败敌人。",
	"敌人临死：军……",
	"暗箭灭口。",
	"师父：别看。",
	"十年后：该出山了。"
]

const NODES := [
	{"id":"military_order", "title":"军令巡海", "column":"军令", "type":"事件", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_order.svg", "scene":"背景占位：军门令牌、潮湿案牍、出海军令。人物占位：主角 / 上官。", "text":"军令落下，潮声像旧案翻页。", "choices":[{"text":"问旧案", "dg":0, "dq":1, "dc":1}, {"text":"领命出发", "dg":1, "dq":0, "dc":0}]},
	{"id":"beach_ambush", "title":"海边伏击", "column":"初遇", "type":"普通战斗", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_beach_ambush.svg", "scene":"背景占位：海滩芦苇、暗潮、伏兵剪影。敌人占位：敌方枪手。", "text":"芦苇摇晃，敌影先动。", "combat":"enc_beach_ambush", "choices":[{"text":"搜身留证", "dg":1, "dq":0, "dc":1}, {"text":"斩首报功", "dg":2, "dq":-1, "dc":0}]},
	{"id":"ming_firearm", "title":"明制火器", "column":"疑点", "type":"旧物", "visual_path":"res://assets/pixel_battle/relics/relic_ming_firearm.svg", "scene":"旧物占位：官造火铳 relic_ming_firearm.svg；背景占位：潮湿木箱、军械铸印。", "text":"箱中火器不是倭物，铸印仍在。", "choices":[{"text":"私下留证", "dg":0, "dq":0, "dc":2}, {"text":"上交火器", "dg":1, "dq":1, "dc":0}]},
	{"id":"transport_officer", "title":"失械案押运官", "column":"压迫", "type":"精英战斗", "visual_path":"res://assets/pixel_battle/portraits/transport_officer.svg", "scene":"人物占位：失械案押运官。背景占位：雨夜驿道、车辙、火器空箱。", "text":"押运官看见你手中名册，脸色变了。", "combat":"enc_transport_officer", "choices":[{"text":"私藏名册", "dg":0, "dq":-1, "dc":2}, {"text":"当众审问", "dg":1, "dq":1, "dc":1}]},
	{"id":"wakou_boss", "title":"破船 Boss", "column":"破船", "type":"Boss", "visual_path":"res://assets/pixel_battle/portraits/wakou_leader.svg", "scene":"人物占位：小股倭寇首领。背景占位：搁浅破船、火器箱、暗箭方向。", "text":"敌首倒下前，看向火器箱。", "combat":"enc_wakou_boss", "choices":[{"text":"查看火器箱", "dg":2, "dq":0, "dc":2}, {"text":"烧船灭迹", "dg":1, "dq":-1, "dc":0}]},
	{"id":"military_coverup", "title":"军门压案", "column":"军门", "type":"结尾", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_coverup.svg", "scene":"背景占位：军门灯火、缺页案卷、压案朱批。人物占位：军门上官 / 师父阴影。", "text":"军门灯火通明，案卷却少了一页。", "choices":[{"text":"据实上报", "dg":0, "dq":2, "dc":0}, {"text":"藏下一份证据", "dg":0, "dq":0, "dc":1}, {"text":"沉默退下", "dg":0, "dq":-1, "dc":0}]}
]

func _ready() -> void:
	_build_ui()
	BattleFontHelper.enforce(self)
	_render()

func _build_ui() -> void:
	var root := PanelContainer.new()
	root.anchor_left = 0.04
	root.anchor_top = 0.04
	root.anchor_right = 0.96
	root.anchor_bottom = 0.96
	add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	layout.add_child(title_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(status_label)

	map_label = Label.new()
	map_label.add_theme_font_size_override("font_size", 16)
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_label.custom_minimum_size = Vector2(0, 92)
	layout.add_child(map_label)

	scene_label = Label.new()
	scene_label.add_theme_font_size_override("font_size", 16)
	scene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_label.custom_minimum_size = Vector2(0, 48)
	layout.add_child(scene_label)

	var visual_frame := PanelContainer.new()
	visual_frame.custom_minimum_size = Vector2(0, 110)
	layout.add_child(visual_frame)
	var visual_center := CenterContainer.new()
	visual_frame.add_child(visual_center)
	visual_texture = TextureRect.new()
	visual_texture.custom_minimum_size = Vector2(520, 100)
	visual_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual_center.add_child(visual_texture)
	visual_label = Label.new()
	visual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual_label.custom_minimum_size = Vector2(520, 0)
	visual_center.add_child(visual_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 160)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 24)
	layout.add_child(body_label)

	vars_label = Label.new()
	vars_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(vars_label)

	map_buttons_box = _build_section_box(layout, "行军图操作")
	combat_buttons_box = _build_section_box(layout, "战斗桥接")
	choices_box = _build_section_box(layout, "叙事选择")

func _build_section_box(parent: VBoxContainer, title: String) -> VBoxContainer:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	return box

func _clear_box(box: VBoxContainer) -> void:
	if box == null:
		return
	for child in box.get_children():
		child.queue_free()

func _clear_dynamic_boxes() -> void:
	_clear_box(map_buttons_box)
	_clear_box(combat_buttons_box)
	_clear_box(choices_box)

func _render() -> void:
	_clear_dynamic_boxes()
	if in_prologue:
		title_label.text = "《大明之沧海嘀鸣》剧情 MVP"
		status_label.text = "序章 %d/%d" % [step_index + 1, PROLOGUE.size()]
		map_label.text = "尚未进入行军图"
		scene_label.text = _prologue_scene_hint()
		_render_visual("", _prologue_visual_hint())
		body_label.text = PROLOGUE[step_index]
		vars_label.text = _vars_text()
		_add_button(choices_box, "继续", _on_continue_prologue)
	else:
		var node: Dictionary = NODES[node_index]
		title_label.text = str(node.get("title", ""))
		status_label.text = "当前：%s / %s / %s" % [str(node.get("column", "")), str(node.get("type", "")), str(node.get("id", ""))]
		map_label.text = _map_text()
		scene_label.text = str(node.get("scene", ""))
		_render_visual(str(node.get("visual_path", "")), str(node.get("scene", "")))
		body_label.text = _node_body(node)
		if not last_hint.is_empty():
			body_label.text += "\n\n[i]%s[/i]" % last_hint
		vars_label.text = _vars_text()
		_add_safe_map_buttons()
		if _is_combat_node(node):
			_add_button(combat_buttons_box, "请求战斗：%s" % str(node.get("combat", "")), _on_request_battle)
			_add_button(combat_buttons_box, "视为胜利继续", _on_mock_battle_win)
		else:
			_add_placeholder(combat_buttons_box, "当前节点无战斗。")
		var choices: Array = node.get("choices", [])
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			_add_choice_button(choice, i)
	BattleFontHelper.enforce(self)

func _render_visual(path: String, fallback_text: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		visual_texture.texture = null
		visual_texture.visible = false
		visual_label.visible = true
		visual_label.text = "视觉占位：%s" % fallback_text
		return
	var resource := load(path)
	if resource is Texture2D:
		visual_texture.texture = resource
		visual_texture.visible = true
		visual_label.visible = false
	else:
		visual_texture.texture = null
		visual_texture.visible = false
		visual_label.visible = true
		visual_label.text = "视觉资源不是 Texture2D：%s" % path

func _add_safe_map_buttons() -> void:
	var column_row := HBoxContainer.new()
	column_row.add_theme_constant_override("separation", 8)
	map_buttons_box.add_child(column_row)
	for column_name in MAP_COLUMNS:
		var column_box := VBoxContainer.new()
		column_box.custom_minimum_size = Vector2(142, 0)
		column_box.add_theme_constant_override("separation", 4)
		column_row.add_child(column_box)
		var title := Label.new()
		title.text = column_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 13)
		column_box.add_child(title)
		for i in range(NODES.size()):
			var node: Dictionary = NODES[i]
			if str(node.get("column", "")) != column_name:
				continue
			var btn := Button.new()
			btn.text = "%s %s" % [_map_marker_for_index(i), str(node.get("title", ""))]
			btn.custom_minimum_size = Vector2(136, 38)
			btn.pressed.connect(_on_map_node_pressed.bind(i))
			column_box.add_child(btn)

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _add_placeholder(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var btn := Button.new()
	btn.text = "%s（军功 %+d / 清望 %+d / 旧案 %+d）" % [str(choice.get("text", "")), int(choice.get("dg", 0)), int(choice.get("dq", 0)), int(choice.get("dc", 0))]
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _on_map_node_pressed(target_index: int) -> void:
	if target_index == node_index:
		last_hint = "地图节点：当前节点。"
		_render()
		return
	if target_index < node_index:
		last_hint = "地图节点：已走过。"
		_render()
		return
	if target_index != node_index + 1:
		last_hint = "地图节点：未开放。"
		_render()
		return
	_apply_default_map_reward(target_index)
	_advance_to_node(target_index, "地图节点：可前往，已通过地图选路推进，并获得默认行军收益。")

func _apply_choice_delta(choice: Dictionary) -> void:
	jun_gong += int(choice.get("dg", 0))
	qing_wang += int(choice.get("dq", 0))
	clues += int(choice.get("dc", 0))

func _apply_default_map_reward(target_index: int) -> void:
	if target_index < 0 or target_index >= NODES.size():
		return
	var node: Dictionary = NODES[target_index]
	match str(node.get("type", "")):
		"普通战斗":
			jun_gong += 1
			clues += 1
		"精英战斗":
			jun_gong += 1
			clues += 1
		"Boss":
			jun_gong += 2
			clues += 1
		"旧物":
			clues += 2
		"结尾":
			qing_wang += 1
		_:
			qing_wang += 1

func _advance_to_node(target_index: int, hint: String = "") -> void:
	battle_requested = false
	last_hint = hint
	if target_index < 0:
		return
	if target_index >= NODES.size():
		_render_ending()
		return
	node_index = target_index
	_render()

func _on_continue_prologue() -> void:
	step_index += 1
	if step_index >= PROLOGUE.size():
		in_prologue = false
		node_index = 0
		last_hint = ""
	_render()

func _on_request_battle() -> void:
	battle_requested = true
	var node: Dictionary = NODES[node_index]
	body_label.text = _node_body(node) + "\n\n[b]战斗桥接占位[/b]\nnode_id=%s｜encounter_id=%s｜状态=已请求" % [str(node.get("id", "")), str(node.get("combat", ""))]
	BattleFontHelper.enforce(self)

func _on_mock_battle_win() -> void:
	battle_requested = false
	var node: Dictionary = NODES[node_index]
	body_label.text = _node_body(node) + "\n\n[b]战斗占位胜利[/b]\n现在可选择战后处理。"
	BattleFontHelper.enforce(self)

func _on_choice(index: int) -> void:
	var node: Dictionary = NODES[node_index]
	var choices: Array = node.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	_apply_choice_delta(choice)
	if node_index < NODES.size() - 1:
		_advance_to_node(node_index + 1, "")
	else:
		_render_ending()

func _render_ending() -> void:
	title_label.text = "结局：潮声还在"
	status_label.text = "单局结算"
	map_label.text = _map_text()
	scene_label.text = "结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。"
	_render_visual("", "结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。")
	body_label.text = "军功 %d / 清望 %d / 旧案线索 %d\n\n案卷缺页，潮声仍在。" % [jun_gong, qing_wang, clues]
	vars_label.text = _vars_text()
	_clear_dynamic_boxes()
	_add_button(choices_box, "重开叙事", _restart)
	BattleFontHelper.enforce(self)

func _restart() -> void:
	step_index = 0
	node_index = 0
	jun_gong = 0
	qing_wang = 0
	clues = 0
	in_prologue = true
	battle_requested = false
	last_hint = ""
	_render()

func _map_text() -> String:
	var lines: Array[String] = []
	for col in MAP_COLUMNS:
		var items: Array[String] = []
		for i in range(NODES.size()):
			var n: Dictionary = NODES[i]
			if str(n.get("column", "")) != col:
				continue
			items.append("%s %s" % [_map_marker_for_index(i), str(n.get("title", ""))])
		lines.append("【%s】%s" % [col, " / ".join(items)])
	return "\n".join(lines)

func _map_marker_for_index(index: int) -> String:
	if index == node_index:
		return "▶"
	if index < node_index:
		return "●"
	if index == node_index + 1:
		return "◎"
	return "○"

func _node_body(node: Dictionary) -> String:
	var body := "[b]%s[/b]\n%s" % [str(node.get("type", "")), str(node.get("text", ""))]
	if _is_combat_node(node):
		body += "\n\n[b]战斗桥接占位[/b]\nnode_id=%s｜encounter_id=%s｜状态=未请求" % [str(node.get("id", "")), str(node.get("combat", ""))]
	return body

func _is_combat_node(node: Dictionary) -> bool:
	return node.has("combat") and not str(node.get("combat", "")).is_empty()

func _vars_text() -> String:
	return "军功 %d / 清望 %d / 旧案线索 %d" % [jun_gong, qing_wang, clues]

func _prologue_scene_hint() -> String:
	if step_index <= 3:
		return "序章背景占位：黑屏潮声、火光、村口刀影。"
	if step_index <= 8:
		return "序章人物占位：幼年主角 / 师父 / 敌人。"
	return "序章背景占位：暗箭、师父背影、十年后山路。"

func _prologue_visual_hint() -> String:
	if step_index <= 3:
		return "黑屏潮声 / 火光 / 村口刀影"
	if step_index <= 8:
		return "幼年主角 / 师父 / 敌人"
	return "暗箭 / 师父背影 / 十年后山路"
