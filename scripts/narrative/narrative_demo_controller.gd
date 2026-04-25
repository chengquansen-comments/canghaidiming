extends Control
class_name NarrativeDemoController

const NarrativeStateScript := preload("res://scripts/narrative/narrative_state.gd")
const NarrativeFontHelper := preload("res://scripts/narrative/narrative_font_helper.gd")

var narrative: NarrativeState
var root_panel: PanelContainer
var title_label: Label
var type_label: Label
var route_label: Label
var body_label: RichTextLabel
var result_label: Label
var vars_label: Label
var choices_box: VBoxContainer
var continue_button: Button
var restart_button: Button
var showing_prologue := true
var waiting_result := false

func _ready() -> void:
	_build_ui()
	_force_cjk_font()
	_start_narrative()

func _force_cjk_font() -> void:
	NarrativeFontHelper.enforce(self)

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.anchor_left = 0.06
	root_panel.anchor_top = 0.06
	root_panel.anchor_right = 0.94
	root_panel.anchor_bottom = 0.94
	root_panel.offset_left = 0
	root_panel.offset_top = 0
	root_panel.offset_right = 0
	root_panel.offset_bottom = 0
	add_child(root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	root_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.text = "《大明之沧海嘀鸣》"
	layout.add_child(title_label)

	type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.modulate = Color(0.82, 0.78, 0.68, 1.0)
	layout.add_child(type_label)

	route_label = Label.new()
	route_label.add_theme_font_size_override("font_size", 15)
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_label.custom_minimum_size = Vector2(0, 48)
	route_label.modulate = Color(0.66, 0.78, 0.84, 1.0)
	layout.add_child(route_label)

	body_label = RichTextLabel.new()
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 340)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 22)
	layout.add_child(body_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.modulate = Color(0.9, 0.84, 0.68, 1.0)
	layout.add_child(result_label)

	vars_label = Label.new()
	vars_label.add_theme_font_size_override("font_size", 18)
	vars_label.modulate = Color(0.72, 0.86, 0.9, 1.0)
	layout.add_child(vars_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	layout.add_child(choices_box)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	layout.add_child(button_row)

	continue_button = Button.new()
	continue_button.text = "继续"
	continue_button.custom_minimum_size = Vector2(160, 44)
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)

	restart_button = Button.new()
	restart_button.text = "重开叙事"
	restart_button.custom_minimum_size = Vector2(160, 44)
	restart_button.pressed.connect(_start_narrative)
	button_row.add_child(restart_button)

func _start_narrative() -> void:
	narrative = NarrativeStateScript.new()
	var ok := narrative.load_from_path()
	showing_prologue = true
	waiting_result = false
	result_label.text = ""
	if not ok:
		title_label.text = "叙事数据加载失败"
		body_label.text = "请检查 data/narrative/mvp_compressed_narrative.json"
		_force_cjk_font()
		return
	_render_next_prologue_step()
	_force_cjk_font()

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _on_continue_pressed() -> void:
	if showing_prologue:
		_render_next_prologue_step()
	elif waiting_result:
		waiting_result = false
		if not narrative.current_ending_id.is_empty():
			_render_ending()
		else:
			_render_node()
	_force_cjk_font()

func _render_next_prologue_step() -> void:
	_clear_choices()
	result_label.text = ""
	vars_label.text = ""
	route_label.text = "序章：短镜头链 / 尚未进入行军图"
	if not narrative.has_next_prologue_step():
		showing_prologue = false
		_render_node()
		return
	var step := narrative.advance_prologue()
	title_label.text = str(step.get("title", "刀下余声")) if step.has("title") else "刀下余声"
	type_label.text = "序章 / %d/%d" % [narrative.prologue_index, narrative.prologue_count()]
	body_label.text = _format_step(step)
	continue_button.visible = true
	_force_cjk_font()

func _format_step(step: Dictionary) -> String:
	var lines: Array[String] = []
	var speaker := str(step.get("speaker", ""))
	var text := str(step.get("text", ""))
	var sfx := str(step.get("sfx", ""))
	if not speaker.is_empty():
		lines.append("[b]%s：[/b]" % speaker)
	if not text.is_empty():
		lines.append(text)
	if not sfx.is_empty():
		lines.append("\n[i]%s[/i]" % sfx)
	if step.has("card"):
		var card: Dictionary = step.get("card", {})
		lines.append("\n[b]卡牌：%s[/b]" % str(card.get("name", "")))
		lines.append("费用：%d" % int(card.get("cost", 0)))
		lines.append(str(card.get("effect", "")))
		lines.append("[i]%s[/i]" % str(card.get("description", "")))
	if step.has("cards"):
		lines.append("\n[b]师父手牌[/b]")
		var cards: Array = step.get("cards", [])
		for card_value in cards:
			if typeof(card_value) != TYPE_DICTIONARY:
				continue
			var c: Dictionary = card_value
			lines.append("• %s｜费%d｜%s" % [str(c.get("name", "")), int(c.get("cost", 0)), str(c.get("effect", ""))])
	return "\n".join(lines)

func _render_node() -> void:
	_clear_choices()
	var node := narrative.current_node()
	title_label.text = str(node.get("title", "未知节点"))
	type_label.text = narrative.node_status_text()
	route_label.text = narrative.route_text()
	vars_label.text = narrative.variables_text()
	result_label.text = narrative.last_result_text
	body_label.text = _format_node(node)
	continue_button.visible = false
	var choices := narrative.available_choices(node)
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = _choice_button_text(choice)
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices_box.add_child(button)
	_force_cjk_font()

func _format_node(node: Dictionary) -> String:
	var lines: Array[String] = []
	var bg := str(node.get("background", ""))
	if not bg.is_empty():
		lines.append("[i]背景：%s[/i]" % bg)
	var narration := str(node.get("narration", ""))
	if not narration.is_empty():
		lines.append("[b]旁白[/b]\n%s" % narration)
	var dialogue: Array = node.get("dialogue", [])
	for line_value in dialogue:
		if typeof(line_value) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = line_value
		lines.append("[b]%s：[/b]%s" % [str(line.get("speaker", "")), str(line.get("text", ""))])
	if node.has("combat"):
		var combat: Dictionary = node.get("combat", {})
		lines.append("\n[b]战斗占位[/b]：%s" % str(combat.get("encounter_id", "")))
		lines.append("敌人：%s" % _enemy_list_text(combat.get("enemies", [])))
	if node.has("relic"):
		lines.append("\n[b]旧物[/b]：%s" % str(node.get("relic", "")))
	return "\n".join(lines)

func _enemy_list_text(value: Variant) -> String:
	var result: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			result.append(str(item))
	return ", ".join(result)

func _choice_button_text(choice: Dictionary) -> String:
	var text := str(choice.get("text", ""))
	var delta: Dictionary = choice.get("delta", {})
	var parts: Array[String] = []
	for key in delta.keys():
		var value := int(delta.get(key, 0))
		if value == 0:
			continue
		var sign := "+" if value > 0 else ""
		parts.append("%s%s%d" % [narrative.variable_short_label(str(key)), sign, value])
	if parts.is_empty():
		return text
	return "%s（%s）" % [text, " / ".join(parts)]

func _on_choice_pressed(index: int) -> void:
	var result := narrative.choose(index)
	if not bool(result.get("ok", false)):
		result_label.text = str(result.get("result", "无效选择。"))
		_force_cjk_font()
		return
	_clear_choices()
	result_label.text = str(result.get("result", ""))
	vars_label.text = narrative.variables_text()
	route_label.text = narrative.route_text()
	continue_button.visible = true
	waiting_result = true
	_force_cjk_font()

func _render_ending() -> void:
	_clear_choices()
	var ending := narrative.current_ending()
	title_label.text = "结局：%s" % str(ending.get("title", "沉默"))
	type_label.text = "单局结算"
	route_label.text = narrative.route_text()
	body_label.text = str(ending.get("text", "潮声还在。"))
	result_label.text = narrative.last_result_text
	vars_label.text = narrative.variables_text()
	continue_button.visible = false
	_force_cjk_font()
