extends "res://scripts/narrative_demo_cinematic_controller.gd"

const NARRATIVE_MVP_DATA_PATH := "res://data/narrative_mvp_nodes.json"

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

var narrative_mvp_data: Dictionary = {}
var narrative_mvp_data_loaded: bool = false

func _ready() -> void:
	_load_narrative_mvp_data()
	super._ready()

func _load_narrative_mvp_data() -> void:
	narrative_mvp_data.clear()
	narrative_mvp_data_loaded = false
	if not FileAccess.file_exists(NARRATIVE_MVP_DATA_PATH):
		return
	var file: FileAccess = FileAccess.open(NARRATIVE_MVP_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		narrative_mvp_data = parsed
		narrative_mvp_data_loaded = true

func _render_prologue() -> void:
	var prologue: Dictionary = _prologue_data()
	title_label.text = str(prologue.get("title", "《大明之沧海嘀鸣》"))
	status_label.text = "序章 %d/%d" % [step_index + 1, _prologue_steps_count()]
	map_label.text = ""
	scene_label.text = _format_scene_text(_prologue_scene_hint())
	_render_visual("", _prologue_visual_hint())
	body_label.text = _prologue_step_text(step_index)
	if step_index == PROLOGUE_CAREER_STEP:
		body_label.text += "\n\n[b]%s[/b]" % _career_prompt_text()
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_placeholder(map_buttons_box, "")
	if _prologue_step_has_combat(step_index):
		_add_button(combat_buttons_box, _prologue_combat_button(step_index), _on_request_prologue_master_battle)
		_add_button(combat_buttons_box, _prologue_skip_button(step_index), _on_skip_prologue_master_battle)
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
	var node_data: Dictionary = _node_config(node_id)
	title_label.text = str(node_data.get("title", node.get("title", "")))
	status_label.text = "%s / %s" % [str(node.get("column", "")), str(node.get("type", ""))]
	map_label.text = ""
	scene_label.text = _format_scene_text(str(node_data.get("scene", FRAGMENTED_SCENE_TEXT.get(node_id, node.get("scene", "")))))
	_render_visual(str(node.get("visual_path", "")), str(node_data.get("scene", node.get("scene", ""))))
	body_label.text = _node_body(node)
	if _node_has_combat_data(node_data):
		var pre_text: String = str((node_data.get("combat", {}) as Dictionary).get("pre", ""))
		if not pre_text.is_empty() and body_label.text.find(pre_text) < 0:
			body_label.text += "\n\n" + pre_text
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_safe_map_buttons()
	if _node_has_combat_data(node_data) or _is_combat_node(node):
		_add_button(combat_buttons_box, _combat_button_text(node_data), _on_request_battle)
		_add_button(combat_buttons_box, _combat_mock_button_text(node_data), _on_mock_battle_win)
	else:
		_add_placeholder(combat_buttons_box, "")
	var choices: Array = node.get("choices", [])
	for i in range(choices.size()):
		_add_choice_button(choices[i], i)

func _node_body(node: Dictionary) -> String:
	var node_id: String = str(node.get("id", ""))
	var node_data: Dictionary = _node_config(node_id)
	return str(node_data.get("text", FRAGMENTED_NODE_TEXT.get(node_id, node.get("text", ""))))

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var node: Dictionary = NODES[node_index]
	var node_id: String = str(node.get("id", ""))
	var label_text: String = _choice_label(node_id, choice, index)
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _add_career_button(career: Dictionary, index: int) -> void:
	var role_id: String = str(career.get("id", ""))
	var btn: Button = Button.new()
	btn.text = _career_choice_text(role_id, str(career.get("career", "")))
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_select_career.bind(index))
	choices_box.add_child(btn)

func _render_ending() -> void:
	var ending: Dictionary = _ending_data()
	title_label.text = str(ending.get("title", "潮声还在"))
	status_label.text = "单局结算"
	map_label.text = ""
	scene_label.text = _format_scene_text(str(ending.get("scene", "案卷缺页。灯还亮着。")))
	_render_visual("", str(ending.get("scene", "案卷缺页。灯还亮着。")))
	body_label.text = str(ending.get("text", "军功写进册里。\n\n清望写在别人嘴里。\n\n线索藏在袖中。\n\n案卷少了一页。\n\n潮声没有少。"))
	vars_label.text = _vars_text()
	_clear_dynamic_boxes()
	_add_placeholder(map_buttons_box, "")
	_add_placeholder(combat_buttons_box, "")
	_add_button(choices_box, str(ending.get("restart_label", "重开")), _restart)
	BattleFontHelper.enforce(self)

func _on_request_battle() -> void:
	var node: Dictionary = NODES[node_index]
	var node_id: String = str(node.get("id", ""))
	var node_data: Dictionary = _node_config(node_id)
	var combat: Dictionary = node_data.get("combat", {}) if node_data.get("combat", {}) is Dictionary else {}
	if bool(combat.get("enabled", false)):
		var encounter_id: String = str(combat.get("encounter_id", node.get("encounter_id", "")))
		var battle_id: String = str(combat.get("battle_id", ""))
		NarrativeBattleContext.set_request(encounter_id, node_id, battle_id)
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
		return
	super._on_request_battle()

func _on_request_prologue_master_battle() -> void:
	var combat: Dictionary = _prologue_combat_data(PROLOGUE_MASTER_RESCUE_STEP)
	var encounter_id: String = str(combat.get("encounter_id", "enc_prologue_master_rescue"))
	var battle_id: String = str(combat.get("battle_id", "prologue_master_rescue"))
	NarrativeBattleContext.set_request(encounter_id, "prologue_master_rescue", battle_id)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

func _fragmented_hint(raw: String) -> String:
	var hints: Dictionary = _hints_data()
	if raw.find("战斗胜利") >= 0:
		return str(hints.get("battle_win", "尸身很轻。\n袖中多了一点东西。"))
	if raw.find("已选择出山职业") >= 0:
		return str(hints.get("career_selected", "路选好了。\n潮声仍在。"))
	return raw

func _prologue_data() -> Dictionary:
	if narrative_mvp_data_loaded and narrative_mvp_data.get("prologue", {}) is Dictionary:
		return narrative_mvp_data.get("prologue", {})
	return {}

func _prologue_steps() -> Array:
	var prologue: Dictionary = _prologue_data()
	var steps = prologue.get("steps", [])
	return steps if steps is Array else []

func _prologue_steps_count() -> int:
	var steps: Array = _prologue_steps()
	return steps.size() if steps.size() > 0 else FRAGMENTED_PROLOGUE.size()

func _prologue_step_data(index: int) -> Dictionary:
	var steps: Array = _prologue_steps()
	if index >= 0 and index < steps.size() and steps[index] is Dictionary:
		return steps[index]
	return {}

func _prologue_step_text(index: int) -> String:
	var data: Dictionary = _prologue_step_data(index)
	if data.has("text"):
		return str(data.get("text", ""))
	if index >= 0 and index < FRAGMENTED_PROLOGUE.size():
		return FRAGMENTED_PROLOGUE[index]
	return ""

func _career_prompt_text() -> String:
	var data: Dictionary = _prologue_step_data(PROLOGUE_CAREER_STEP)
	return str(data.get("career_prompt", "选一条路。\n不是为了升官。\n是为了知道那支箭从哪来。"))

func _career_choice_text(role_id: String, fallback: String) -> String:
	var prologue: Dictionary = _prologue_data()
	var choices = prologue.get("career_choices", {})
	if choices is Dictionary:
		return str((choices as Dictionary).get(role_id, fallback))
	if role_id == "spearman":
		return "长枪。远一点。活久一点。"
	if role_id == "blademaster":
		return "腰刀。近一点。快一点。"
	return fallback

func _prologue_combat_data(index: int) -> Dictionary:
	var data: Dictionary = _prologue_step_data(index)
	var combat = data.get("combat", {})
	return combat if combat is Dictionary else {}

func _prologue_step_has_combat(index: int) -> bool:
	return bool(_prologue_combat_data(index).get("enabled", false)) or index == PROLOGUE_MASTER_RESCUE_STEP

func _prologue_combat_button(index: int) -> String:
	return str(_prologue_combat_data(index).get("button", "换我。"))

func _prologue_skip_button(index: int) -> String:
	return str(_prologue_combat_data(index).get("skip_button", "潮声跳过这一段"))

func _nodes_data() -> Array:
	if narrative_mvp_data_loaded and narrative_mvp_data.get("nodes", []) is Array:
		return narrative_mvp_data.get("nodes", [])
	return []

func _node_config(node_id: String) -> Dictionary:
	for item in _nodes_data():
		if item is Dictionary and str((item as Dictionary).get("id", "")) == node_id:
			return item
	return {}

func _node_has_combat_data(node_data: Dictionary) -> bool:
	var combat = node_data.get("combat", {})
	return combat is Dictionary and bool((combat as Dictionary).get("enabled", false))

func _combat_button_text(node_data: Dictionary) -> String:
	var combat = node_data.get("combat", {})
	if combat is Dictionary:
		return str((combat as Dictionary).get("button", "接敌"))
	return "接敌"

func _combat_mock_button_text(node_data: Dictionary) -> String:
	var combat = node_data.get("combat", {})
	if combat is Dictionary:
		return str((combat as Dictionary).get("mock_button", "尸身已经倒下"))
	return "尸身已经倒下"

func _choice_label(node_id: String, choice: Dictionary, index: int) -> String:
	var node_data: Dictionary = _node_config(node_id)
	var configured_choices = node_data.get("choices", [])
	if configured_choices is Array and index >= 0 and index < (configured_choices as Array).size():
		var configured = (configured_choices as Array)[index]
		if configured is Dictionary:
			return str((configured as Dictionary).get("label", choice.get("text", "")))
	var labels: Array = FRAGMENTED_CHOICES.get(node_id, [])
	if index >= 0 and index < labels.size():
		return str(labels[index])
	return str(choice.get("text", ""))

func _ending_data() -> Dictionary:
	if narrative_mvp_data_loaded and narrative_mvp_data.get("ending", {}) is Dictionary:
		return narrative_mvp_data.get("ending", {})
	return {}

func _hints_data() -> Dictionary:
	if narrative_mvp_data_loaded and narrative_mvp_data.get("hints", {}) is Dictionary:
		return narrative_mvp_data.get("hints", {})
	return {}
