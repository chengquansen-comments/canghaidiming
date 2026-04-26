extends "res://scripts/narrative_demo_cinematic_controller.gd"

const FRAGMENTED_PROLOGUE := [
	"黑。\n\n潮声很近。\n\n有人在跑。",
	"父亲把你按进柴堆。\n\n他说：\n别出声。",
	"刀背敲门。\n\n有人问：\n东西在哪？\n\n父亲说：\n孩子不知道。",
	"那人笑了。\n\n他说：\n死人也不知道。\n\n潮声停了一下。",
	"你冲出去。\n\n木刀打在甲片上。\n\n零声。",
	"天翻过来。\n\n火光很高。\n\n你看见母亲的鞋。",
	"一只手挡住你的眼。\n\n那人说：\n还活着。\n\n换我。",
	"刀。\n\n步。\n\n断气。",
	"敌人还没死透。\n\n他吐出一个字：\n军……\n\n箭到了。",
	"箭从黑处来。\n\n不是海上。\n\n不是倭人。",
	"师父说：\n别看。\n\n可你已经看见了。",
	"十年。\n\n潮声没有远过。\n\n师父把刀还给你。\n\n他说：\n该走了。"
]

const FRAGMENTED_NODE_TEXT := {
	"military_order": "军令压在案上。\n\n出海。\n巡岸。\n剿寇。\n\n最后一行被墨盖住。",
	"beach_ambush": "风从芦苇里出来。\n\n枪尖也出来。\n\n对方没有喊杀。\n\n他挡住去路。\n你看见他靴上的官泥。",
	"ming_firearm": "箱子裂开。\n\n火器没有锈完。\n\n铸印还在。\n\n不是倭物。",
	"transport_officer": "押运官在等你。\n\n他没有拔刀。\n\n他说：\n你不该翻箱。\n\n雨打在名册上。\n墨开始散。",
	"wakou_boss": "船搁浅了。\n\n人没有。\n\n箱子还在。\n\n有个倭首坐在箱上。\n像在等你。\n\n他说：\n你来晚了。\n\n又说：\n也来早了。",
	"military_coverup": "军门灯火通明。\n\n案卷摊开。\n\n正好少了一页。\n\n上官说：\n倭患已平。\n\n你想起十年前。\n那支箭。\n\n也是从岸上来的。"
}

const FRAGMENTED_SCENE_TEXT := {
	"military_order": "军门。湿案牍。朱批没干。",
	"beach_ambush": "芦苇。湿沙。先动的影子。",
	"ming_firearm": "木箱。潮水。官造铸印。这里只有那枚印。",
	"transport_officer": "雨夜。车辙。空箱。",
	"wakou_boss": "破船。火器箱。黑处的箭位。",
	"military_coverup": "灯火。缺页。朱批。"
}

const FRAGMENTED_CHOICES := {
	"military_order": ["问旧案", "领命出发"],
	"beach_ambush": ["搜身留证", "斩首报功"],
	"ming_firearm": ["私下留证", "上交火器"],
	"transport_officer": ["私藏名册", "当众审问"],
	"wakou_boss": ["查看火器箱", "烧船灭迹"],
	"military_coverup": ["据实上报", "藏下一份证据", "沉默退下"]
}

func _render_prologue() -> void:
	title_label.text = "《大明之沧海嘀鸣》"
	status_label.text = "序章 %d/%d" % [step_index + 1, FRAGMENTED_PROLOGUE.size()]
	map_label.text = ""
	scene_label.text = _format_scene_text(_prologue_scene_hint())
	_render_visual("", _prologue_visual_hint())
	body_label.text = FRAGMENTED_PROLOGUE[step_index]
	if step_index == PROLOGUE_CAREER_STEP:
		body_label.text += "\n\n[b]选一条路。[/b]\n不是为了升官。\n是为了知道那支箭从哪来。"
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_placeholder(map_buttons_box, "")
	if step_index == PROLOGUE_MASTER_RESCUE_STEP:
		_add_button(combat_buttons_box, "换我。", _on_request_prologue_master_battle)
		_add_button(combat_buttons_box, "潮声跳过这一段", _on_skip_prologue_master_battle)
	elif step_index == PROLOGUE_CAREER_STEP:
		_add_placeholder(combat_buttons_box, "先选路。")
	else:
		_add_placeholder(combat_buttons_box, "")
	if step_index == PROLOGUE_CAREER_STEP:
		for i in range(CAREERS.size()):
			_add_career_button(CAREERS[i], i)
	else:
		_add_button(choices_box, "继续", _on_continue_prologue)

func _render_node() -> void:
	var node: Dictionary = NODES[node_index]
	var node_id: String = str(node.get("id", ""))
	title_label.text = str(node.get("title", ""))
	status_label.text = "%s / %s" % [str(node.get("column", "")), str(node.get("type", ""))]
	map_label.text = ""
	scene_label.text = _format_scene_text(str(FRAGMENTED_SCENE_TEXT.get(node_id, node.get("scene", ""))))
	_render_visual(str(node.get("visual_path", "")), str(FRAGMENTED_SCENE_TEXT.get(node_id, node.get("scene", ""))))
	body_label.text = _node_body(node)
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_safe_map_buttons()
	if _is_combat_node(node):
		_add_button(combat_buttons_box, "接敌", _on_request_battle)
		_add_button(combat_buttons_box, "尸身已经倒下", _on_mock_battle_win)
	else:
		_add_placeholder(combat_buttons_box, "")
	var choices: Array = node.get("choices", [])
	for i in range(choices.size()):
		_add_choice_button(choices[i], i)

func _node_body(node: Dictionary) -> String:
	var node_id: String = str(node.get("id", ""))
	return str(FRAGMENTED_NODE_TEXT.get(node_id, node.get("text", "")))

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var node: Dictionary = NODES[node_index]
	var node_id: String = str(node.get("id", ""))
	var labels: Array = FRAGMENTED_CHOICES.get(node_id, [])
	var label_text: String = str(choice.get("text", ""))
	if index >= 0 and index < labels.size():
		label_text = str(labels[index])
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _add_career_button(career: Dictionary, index: int) -> void:
	var role_id: String = str(career.get("id", ""))
	var btn: Button = Button.new()
	if role_id == "spearman":
		btn.text = "长枪。远一点。活久一点。"
	elif role_id == "blademaster":
		btn.text = "腰刀。近一点。快一点。"
	else:
		btn.text = str(career.get("career", ""))
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_select_career.bind(index))
	choices_box.add_child(btn)

func _render_ending() -> void:
	title_label.text = "潮声还在"
	status_label.text = "单局结算"
	map_label.text = ""
	scene_label.text = _format_scene_text("案卷缺页。灯还亮着。")
	_render_visual("", "案卷缺页。灯还亮着。")
	body_label.text = "军功写进册里。\n\n清望写在别人嘴里。\n\n线索藏在袖中。\n\n案卷少了一页。\n\n潮声没有少。\n\n你赢了几场。\n升了几分。\n也只多知道一点：\n\n倭寇从海上来。\n箭从岸上来。"
	vars_label.text = _vars_text()
	_clear_dynamic_boxes()
	_add_placeholder(map_buttons_box, "")
	_add_placeholder(combat_buttons_box, "")
	_add_button(choices_box, "重开", _restart)
	BattleFontHelper.enforce(self)

func _fragmented_hint(raw: String) -> String:
	if raw.find("战斗胜利") >= 0:
		return "尸身很轻。\n袖中多了一点东西。"
	if raw.find("已选择出山职业") >= 0:
		return "路选好了。\n潮声仍在。"
	return raw
