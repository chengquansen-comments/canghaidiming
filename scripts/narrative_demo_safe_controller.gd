extends Control

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")

var title_label: Label
var status_label: Label
var map_label: Label
var scene_label: Label
var body_label: RichTextLabel
var vars_label: Label
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
	{"id":"military_order", "title":"军令巡海", "column":"军令", "type":"事件", "scene":"背景占位：军门令牌、潮湿案牍、出海军令。人物占位：主角 / 上官。", "text":"军令落下，潮声像旧案翻页。", "choices":[{"text":"问旧案", "dg":0, "dq":1, "dc":1}, {"text":"领命出发", "dg":1, "dq":0, "dc":0}]},
	{"id":"beach_ambush", "title":"海边伏击", "column":"初遇", "type":"普通战斗", "scene":"背景占位：海滩芦苇、暗潮、伏兵剪影。敌人占位：敌方枪手。", "text":"芦苇摇晃，敌影先动。", "combat":"enc_beach_ambush", "choices":[{"text":"搜身留证", "dg":1, "dq":0, "dc":1}, {"text":"斩首报功", "dg":2, "dq":-1, "dc":0}]},
	{"id":"ming_firearm", "title":"明制火器", "column":"疑点", "type":"旧物", "scene":"旧物占位：官造火铳 relic_ming_firearm.png；背景占位：潮湿木箱、军械铸印。", "text":"箱中火器不是倭物，铸印仍在。", "choices":[{"text":"私下留证", "dg":0, "dq":0, "dc":2}, {"text":"上交火器", "dg":1, "dq":1, "dc":0}]},
	{"id":"transport_officer", "title":"失械案押运官", "column":"压迫", "type":"精英战斗", "scene":"人物占位：失械案押运官。背景占位：雨夜驿道、车辙、火器空箱。", "text":"押运官看见你手中名册，脸色变了。", "combat":"enc_transport_officer", "choices":[{"text":"私藏名册", "dg":0, "dq":-1, "dc":2}, {"text":"当众审问", "dg":1, "dq":1, "dc":1}]},
	{"id":"wakou_boss", "title":"破船 Boss", "column":"破船", "type":"Boss", "scene":"人物占位：小股倭寇首领。背景占位：搁浅破船、火器箱、暗箭方向。", "text":"敌首倒下前，看向火器箱。", "combat":"enc_wakou_boss", "choices":[{"text":"查看火器箱", "dg":2, "dq":0, "dc":2}, {"text":"烧船灭迹", "dg":1, "dq":-1, "dc":0}]},
	{"id":"military_coverup", "title":"军门压案", "column":"军门", "type":"结尾", "scene":"背景占位：军门灯火、缺页案卷、压案朱批。人物占位：军门上官 / 师父阴影。", "text":"军门灯火通明，案卷却少了一页。", "choices":[{"text":"据实上报", "dg":0, "dq":2, "dc":0}, {"text":"藏下一份证据", "dg":0, "dq":0, "dc":1}, {"text":"沉默退下", "dg":0, "dq":-1, "dc":0}]}
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
	scene_label.custom_minimum_size = Vector2(0, 62)
	layout.add_child(scene_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 250)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 24)
	layout.add_child(body_label)

	vars_label = Label.new()
	vars_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(vars_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	layout.add_child(choices_box)

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _render() -> void:
	_clear_choices()
	if in_prologue:
		title_label.text = "《大明之沧海嘀鸣》剧情 MVP"
		status_label.text = "序章 %d/%d" % [step_index + 1, PROLOGUE.size()]
		map_label.text = "尚未进入行军图"
		scene_label.text = _prologue_scene_hint()
		body_label.text = PROLOGUE[step_index]
		vars_label.text = _vars_text()
		_add_button("继续", _on_continue_prologue)
	else:
		var node: Dictionary = NODES[node_index]
		title_label.text = str(node.get("title", ""))
		status_label.text = "当前：%s / %s / %s" % [str(node.get("column", "")), str(node.get("type", "")), str(node.get("id", ""))]
		map_label.text = _map_text()
		scene_label.text = str(node.get("scene", ""))
		body_label.text = _node_body(node)
		if not last_hint.is_empty():
			body_label.text += "\n\n[i]%s[/i]" % last_hint
		vars_label.text = _vars_text()
		_add_safe_map_buttons()
		if _is_combat_node(node):
			_add_button("请求战斗：%s" % str(node.get("combat", "")), _on_request_battle)
			_add_button("视为胜利继续", _on_mock_battle_win)
		var choices: Array = node.get("choices", [])
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			_add_choice_button(choice, i)
	BattleFontHelper.enforce(self)

func _add_safe_map_buttons() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	choices_box.add_child(row)
	for i in range(NODES.size()):
		var node: Dictionary = NODES[i]
		var btn := Button.new()
		btn.text = "%s %s" % [_map_marker_for_index(i), str(node.get("title", ""))]
		btn.custom_minimum_size = Vector2(148, 38)
		btn.pressed.connect(_on_map_node_pressed.bind(i))
		row.add_child(btn)

func _add_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(callback)
	choices_box.add_child(btn)

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var btn := Button.new()
	btn.text = "%s（军功 %+d / 清望 %+d / 旧案 %+d）" % [str(choice.get("text", "")), int(choice.get("dg", 0)), int(choice.get("dq", 0)), int(choice.get("dc", 0))]
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _on_map_node_pressed(target_index: int) -> void:
	if target_index == node_index:
		last_hint = "地图节点：当前节点。"
	elif target_index < node_index:
		last_hint = "地图节点：已走过。"
	elif target_index == node_index + 1:
		last_hint = "地图节点：可前往，已通过地图选路推进。"
		node_index = target_index
		battle_requested = false
	else:
		last_hint = "地图节点：未开放。"
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
	jun_gong += int(choice.get("dg", 0))
	qing_wang += int(choice.get("dq", 0))
	clues += int(choice.get("dc", 0))
	battle_requested = false
	last_hint = ""
	if node_index < NODES.size() - 1:
		node_index += 1
		_render()
	else:
		_render_ending()

func _render_ending() -> void:
	title_label.text = "结局：潮声还在"
	status_label.text = "单局结算"
	map_label.text = _map_text()
	scene_label.text = "结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。"
	body_label.text = "军功 %d / 清望 %d / 旧案线索 %d\n\n案卷缺页，潮声仍在。" % [jun_gong, qing_wang, clues]
	vars_label.text = _vars_text()
	_clear_choices()
	_add_button("重开叙事", _restart)
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
	var columns: Array[String] = ["军令", "初遇", "疑点", "压迫", "破船", "军门"]
	var lines: Array[String] = []
	for col in columns:
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
