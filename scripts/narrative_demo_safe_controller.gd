extends Control

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")

var title_label: Label
var status_label: Label
var map_label: Label
var body_label: RichTextLabel
var vars_label: Label
var choices_box: VBoxContainer
var step_index := 0
var node_index := 0
var jun_gong := 0
var qing_wang := 0
var clues := 0
var in_prologue := true

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
	{"id":"military_order", "title":"军令巡海", "type":"事件", "text":"军令落下，潮声像旧案翻页。", "choices":[{"text":"问旧案", "dg":0, "dq":1, "dc":1}, {"text":"领命出发", "dg":1, "dq":0, "dc":0}]},
	{"id":"beach_ambush", "title":"海边伏击", "type":"普通战斗", "text":"芦苇摇晃，敌影先动。", "choices":[{"text":"搜身留证", "dg":1, "dq":0, "dc":1}, {"text":"斩首报功", "dg":2, "dq":-1, "dc":0}]},
	{"id":"ming_firearm", "title":"明制火器", "type":"旧物", "text":"箱中火器不是倭物，铸印仍在。", "choices":[{"text":"私下留证", "dg":0, "dq":0, "dc":2}, {"text":"上交火器", "dg":1, "dq":1, "dc":0}]},
	{"id":"transport_officer", "title":"失械案押运官", "type":"精英战斗", "text":"押运官看见你手中名册，脸色变了。", "choices":[{"text":"私藏名册", "dg":0, "dq":-1, "dc":2}, {"text":"当众审问", "dg":1, "dq":1, "dc":1}]},
	{"id":"wakou_boss", "title":"破船 Boss", "type":"Boss", "text":"敌首倒下前，看向火器箱。", "choices":[{"text":"查看火器箱", "dg":2, "dq":0, "dc":2}, {"text":"烧船灭迹", "dg":1, "dq":-1, "dc":0}]},
	{"id":"military_coverup", "title":"军门压案", "type":"结尾", "text":"军门灯火通明，案卷却少了一页。", "choices":[{"text":"据实上报", "dg":0, "dq":2, "dc":0}, {"text":"藏下一份证据", "dg":0, "dq":0, "dc":1}, {"text":"沉默退下", "dg":0, "dq":-1, "dc":0}]}
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
	layout.add_theme_constant_override("separation", 12)
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
	map_label.custom_minimum_size = Vector2(0, 70)
	layout.add_child(map_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 360)
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
		body_label.text = PROLOGUE[step_index]
		vars_label.text = "军功 %d / 清望 %d / 旧案线索 %d" % [jun_gong, qing_wang, clues]
		var btn := Button.new()
		btn.text = "继续"
		btn.custom_minimum_size = Vector2(160, 44)
		btn.pressed.connect(_on_continue_prologue)
		choices_box.add_child(btn)
	else:
		var node: Dictionary = NODES[node_index]
		title_label.text = str(node.get("title", ""))
		status_label.text = "当前：%s / %s" % [str(node.get("type", "")), str(node.get("id", ""))]
		map_label.text = _map_text()
		body_label.text = "[b]%s[/b]\n%s" % [str(node.get("type", "")), str(node.get("text", ""))]
		vars_label.text = "军功 %d / 清望 %d / 旧案线索 %d" % [jun_gong, qing_wang, clues]
		var choices: Array = node.get("choices", [])
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			var btn := Button.new()
			btn.text = "%s（军功 %+d / 清望 %+d / 旧案 %+d）" % [str(choice.get("text", "")), int(choice.get("dg", 0)), int(choice.get("dq", 0)), int(choice.get("dc", 0))]
			btn.custom_minimum_size = Vector2(0, 44)
			btn.pressed.connect(_on_choice.bind(i))
			choices_box.add_child(btn)
	BattleFontHelper.enforce(self)

func _on_continue_prologue() -> void:
	step_index += 1
	if step_index >= PROLOGUE.size():
		in_prologue = false
		node_index = 0
	_render()

func _on_choice(index: int) -> void:
	var node: Dictionary = NODES[node_index]
	var choices: Array = node.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	jun_gong += int(choice.get("dg", 0))
	qing_wang += int(choice.get("dq", 0))
	clues += int(choice.get("dc", 0))
	if node_index < NODES.size() - 1:
		node_index += 1
	else:
		body_label.text = "结局：潮声还在。\n军功 %d / 清望 %d / 旧案线索 %d" % [jun_gong, qing_wang, clues]
		_clear_choices()
		var btn := Button.new()
		btn.text = "重开叙事"
		btn.custom_minimum_size = Vector2(160, 44)
		btn.pressed.connect(_restart)
		choices_box.add_child(btn)
		return
	_render()

func _restart() -> void:
	step_index = 0
	node_index = 0
	jun_gong = 0
	qing_wang = 0
	clues = 0
	in_prologue = true
	_render()

func _map_text() -> String:
	var parts: Array[String] = []
	for i in range(NODES.size()):
		var n: Dictionary = NODES[i]
		var marker := "○"
		if i == node_index:
			marker = "▶"
		elif i < node_index:
			marker = "●"
		parts.append("%s %s" % [marker, str(n.get("title", ""))])
	return "  →  ".join(parts)
