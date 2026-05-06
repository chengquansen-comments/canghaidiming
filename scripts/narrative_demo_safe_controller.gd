extends Control

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const SafeDemoRuntime := preload("res://scripts/safe_demo_runtime.gd")
const SafeDemoView := preload("res://scripts/safe_demo_view.gd")
const MAIN_VISUAL_SCENE := "res://scenes/MainVisual.tscn"
const MAP_COLUMNS := ["军令", "初遇", "疑点", "压迫", "破船", "军门"]
const PROLOGUE_MASTER_RESCUE_STEP := 6
const PROLOGUE_AFTER_MASTER_BATTLE_STEP := 8
const PROLOGUE_CAREER_STEP := 11
const PROLOGUE_MASTER_ENCOUNTER_ID := "enc_prologue_master_rescue"
const PROLOGUE_MASTER_SOURCE_ID := "prologue_master_rescue"

const CAREERS := [
	{"id":"spearman", "career":"长枪武官", "weapon":"长枪", "max_hp":20, "hp":20, "max_posture":3, "posture":3, "martial_level":1, "qinggong":1, "desc":"长枪路线。初始 HP 20，轻功 1，势上限 3。"},
	{"id":"blademaster", "career":"腰刀武官", "weapon":"腰刀", "max_hp":20, "hp":20, "max_posture":3, "posture":3, "martial_level":1, "qinggong":1, "desc":"腰刀路线。初始 HP 20，轻功 1，势上限 3。"}
]

var title_label: Label
var status_label: Label
var map_label: Label
var scene_label: Label
var visual_texture: TextureRect
var visual_label: Label
var visual_debug_label: Label
var body_label: RichTextLabel
var vars_label: Label
var action_scroll: ScrollContainer
var action_content: VBoxContainer
var map_buttons_box: VBoxContainer
var combat_buttons_box: VBoxContainer
var choices_box: VBoxContainer

var step_index := 0
var node_index := 0
var jun_gong := 0
var qing_wang := 0
var clues := 0
var in_prologue := true
var career_selected := false
var last_hint := ""
var _safe_demo_runtime
var _safe_demo_view

func _safe_runtime():
	if _safe_demo_runtime == null:
		_safe_demo_runtime = SafeDemoRuntime.new(self)
	return _safe_demo_runtime

func _safe_view():
	if _safe_demo_view == null:
		_safe_demo_view = SafeDemoView.new(self)
	return _safe_demo_view

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
	{"id":"military_order", "title":"军令巡海", "column":"军令", "type":"事件", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_order.png", "scene":"背景占位：军门令牌、潮湿案牍、出海军令。人物占位：主角 / 上官。", "text":"军令落下，潮声像旧案翻页。", "choices":[{"text":"问旧案", "dg":0, "dq":1, "dc":1}, {"text":"领命出发", "dg":1, "dq":0, "dc":0}]},
	{"id":"beach_ambush", "title":"海边伏击", "column":"初遇", "type":"普通战斗", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png", "scene":"背景占位：海滩芦苇、暗潮、伏兵剪影。敌人占位：敌方枪手。", "text":"芦苇摇晃，敌影先动。", "combat":"enc_beach_ambush", "choices":[{"text":"搜身留证", "dg":1, "dq":0, "dc":1}, {"text":"斩首报功", "dg":2, "dq":-1, "dc":0}]},
	{"id":"ming_firearm", "title":"明制火器", "column":"疑点", "type":"旧物", "visual_path":"res://assets/pixel_battle/relics/relic_ming_firearm.png", "scene":"旧物：官造火铳 relic_ming_firearm.png；背景：潮湿木箱、军械铸印。", "text":"箱中火器不是倭物，铸印仍在。", "choices":[{"text":"私下留证", "dg":0, "dq":0, "dc":2}, {"text":"上交火器", "dg":1, "dq":1, "dc":0}]},
	{"id":"transport_officer", "title":"失械案押运官", "column":"压迫", "type":"精英战斗", "visual_path":"res://assets/pixel_battle/portraits/transport_officer.png", "scene":"人物占位：失械案押运官。背景占位：雨夜驿道、车辙、火器空箱。", "text":"押运官看见你手中名册，脸色变了。", "combat":"enc_transport_officer", "choices":[{"text":"私藏名册", "dg":0, "dq":-1, "dc":2}, {"text":"当众审问", "dg":1, "dq":1, "dc":1}]},
	{"id":"wakou_boss", "title":"破船 Boss", "column":"破船", "type":"Boss", "visual_path":"res://assets/pixel_battle/portraits/wakou_leader.png", "scene":"人物占位：小股倭寇首领。背景占位：搁浅破船、火器箱、暗箭方向。", "text":"敌首倒下前，看向火器箱。", "combat":"enc_wakou_boss", "choices":[{"text":"查看火器箱", "dg":2, "dq":0, "dc":2}, {"text":"烧船灭迹", "dg":1, "dq":-1, "dc":0}]},
	{"id":"military_coverup", "title":"军门压案", "column":"军门", "type":"结尾", "visual_path":"res://assets/pixel_battle/backgrounds/narrative_military_coverup.png", "scene":"背景占位：军门灯火、缺页案卷、压案朱批。人物占位：军门上官 / 师父阴影。", "text":"军门灯火通明，案卷却少了一页。", "choices":[{"text":"据实上报", "dg":0, "dq":2, "dc":0}, {"text":"藏下一份证据", "dg":0, "dq":0, "dc":1}, {"text":"沉默退下", "dg":0, "dq":-1, "dc":0}]}
]

func _ready() -> void:
	_restore_narrative_state_from_context()
	_consume_battle_result_if_needed()
	_build_ui()
	BattleFontHelper.enforce(self)
	_render()

func _narrative_state_snapshot() -> Dictionary:
	return {
		"step_index": step_index,
		"node_index": node_index,
		"jun_gong": jun_gong,
		"qing_wang": qing_wang,
		"clues": clues,
		"in_prologue": in_prologue,
		"career_selected": career_selected,
		"last_hint": last_hint
	}

func _save_narrative_state_to_context() -> void:
	NarrativeBattleContext.set_narrative_state(_narrative_state_snapshot())

func _restore_narrative_state_from_context() -> void:
	if not NarrativeBattleContext.has_narrative_state():
		return
	var state: Dictionary = NarrativeBattleContext.get_narrative_state()
	step_index = int(state.get("step_index", step_index))
	node_index = int(state.get("node_index", node_index))
	jun_gong = int(state.get("jun_gong", jun_gong))
	qing_wang = int(state.get("qing_wang", qing_wang))
	clues = int(state.get("clues", clues))
	in_prologue = bool(state.get("in_prologue", in_prologue))
	career_selected = bool(state.get("career_selected", career_selected))
	last_hint = str(state.get("last_hint", last_hint))

func _clear_narrative_state_context() -> void:
	NarrativeBattleContext.clear_narrative_state()

func _consume_battle_result_if_needed() -> void:
	_safe_runtime().consume_battle_result_if_needed()

func _apply_battle_result_reward(source_index: int) -> void:
	_safe_runtime().apply_battle_result_reward(source_index)

func _build_ui() -> void:
	var root := PanelContainer.new()
	root.anchor_left = 0.035
	root.anchor_top = 0.03
	root.anchor_right = 0.965
	root.anchor_bottom = 0.97
	add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(layout)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(title_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(status_label)

	map_label = Label.new()
	map_label.add_theme_font_size_override("font_size", 15)
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_label.custom_minimum_size = Vector2(0, 72)
	layout.add_child(map_label)

	scene_label = Label.new()
	scene_label.add_theme_font_size_override("font_size", 15)
	scene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_label.custom_minimum_size = Vector2(0, 50)
	layout.add_child(scene_label)

	var visual_frame := PanelContainer.new()
	visual_frame.custom_minimum_size = Vector2(0, 82)
	layout.add_child(visual_frame)
	var visual_center := CenterContainer.new()
	visual_frame.add_child(visual_center)
	visual_texture = TextureRect.new()
	visual_texture.custom_minimum_size = Vector2(480, 74)
	visual_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual_center.add_child(visual_texture)
	visual_label = Label.new()
	visual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual_label.custom_minimum_size = Vector2(480, 0)
	visual_center.add_child(visual_label)

	visual_debug_label = Label.new()
	visual_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_debug_label.add_theme_font_size_override("font_size", 11)
	visual_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(visual_debug_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 112)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 22)
	layout.add_child(body_label)

	vars_label = Label.new()
	vars_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(vars_label)

	action_scroll = ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(0, 250)
	action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(action_scroll)

	action_content = VBoxContainer.new()
	action_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_content.add_theme_constant_override("separation", 6)
	action_scroll.add_child(action_content)

	map_buttons_box = _build_section_box(action_content, "行军图操作")
	combat_buttons_box = _build_section_box(action_content, "战斗桥接")
	choices_box = _build_section_box(action_content, "叙事选择")

func _build_section_box(parent: VBoxContainer, title: String) -> VBoxContainer:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if action_scroll != null:
		action_scroll.scroll_vertical = 0

func _render() -> void:
	_safe_view().render()

func _render_prologue() -> void:
	_safe_view().render_prologue()

func _render_node() -> void:
	_safe_view().render_node()

func _format_scene_text(raw_text: String) -> String:
	return _safe_view().format_scene_text(raw_text)

func _render_visual(path: String, fallback_text: String) -> void:
	_safe_view().render_visual(path, fallback_text)

func _set_visual_placeholder(debug_text: String, fallback_text: String) -> void:
	_safe_view().set_visual_placeholder(debug_text, fallback_text)

func _add_safe_map_buttons() -> void:
	_safe_view().add_safe_map_buttons()

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _add_placeholder(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _add_career_button(career: Dictionary, index: int) -> void:
	var btn := Button.new()
	btn.text = "%s｜%s｜HP %d｜轻功 %d｜势上限 %d｜武境 %d｜%s" % [
		str(career.get("career", "")),
		str(career.get("weapon", "")),
		int(career.get("max_hp", 0)),
		int(career.get("qinggong", 1)),
		int(career.get("max_posture", 0)),
		int(career.get("martial_level", 1)),
		str(career.get("desc", ""))
	]
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_select_career.bind(index))
	choices_box.add_child(btn)

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var btn := Button.new()
	btn.text = "%s（军功 %+d / 清望 %+d / 旧案 %+d）" % [str(choice.get("text", "")), int(choice.get("dg", 0)), int(choice.get("dq", 0)), int(choice.get("dc", 0))]
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _on_map_node_pressed(target_index: int) -> void:
	_safe_runtime().on_map_node_pressed(target_index)

func _apply_choice_delta(choice: Dictionary) -> void:
	_safe_runtime().apply_choice_delta(choice)

func _apply_default_map_reward(target_index: int) -> void:
	_safe_runtime().apply_default_map_reward(target_index)

func _advance_to_node(target_index: int, hint: String = "") -> void:
	_safe_runtime().advance_to_node(target_index, hint)

func _on_continue_prologue() -> void:
	_safe_runtime().on_continue_prologue()

func _on_select_career(index: int) -> void:
	_safe_runtime().on_select_career(index)

func _on_request_prologue_master_battle() -> void:
	_safe_runtime().on_request_prologue_master_battle()

func _on_skip_prologue_master_battle() -> void:
	_safe_runtime().on_skip_prologue_master_battle()

func _on_request_battle() -> void:
	_safe_runtime().on_request_battle()

func _change_to_main_visual() -> void:
	get_tree().change_scene_to_file(MAIN_VISUAL_SCENE)

func _on_mock_battle_win() -> void:
	_safe_runtime().on_mock_battle_win()

func _on_choice(index: int) -> void:
	_safe_runtime().on_choice(index)

func _render_ending() -> void:
	_safe_view().render_ending()

func _restart() -> void:
	_safe_runtime().restart()

func _map_text() -> String:
	var lines: Array[String] = []
	for col in MAP_COLUMNS:
		var items: Array[String] = []
		for i in range(NODES.size()):
			var n: Dictionary = NODES[i]
			if str(n.get("column", "")) == col:
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
	body += "\n\n[b]玩家数据[/b]\n%s" % NarrativeBattleContext.player_profile_debug_text()
	if _is_combat_node(node):
		body += "\n\n[b]战斗桥接[/b]\nnode_id=%s｜encounter_id=%s｜状态=可请求" % [str(node.get("id", "")), str(node.get("combat", ""))]
	return body

func _is_combat_node(node: Dictionary) -> bool:
	return node.has("combat") and not str(node.get("combat", "")).is_empty()

func _vars_text() -> String:
	return "军功 %d / 清望 %d / 旧案线索 %d｜%s" % [jun_gong, qing_wang, clues, NarrativeBattleContext.player_profile_debug_text()]

func _prologue_scene_hint() -> String:
	if step_index <= 3:
		return "序章背景占位：黑屏潮声、火光、村口刀影。"
	if step_index <= 8:
		return "序章人物占位：幼年主角 / 师父 / 敌人。"
	if step_index == PROLOGUE_CAREER_STEP:
		return "序章出山占位：师父背影、兵器架、山路远潮。"
	return "序章背景占位：暗箭、师父背影、十年后山路。"

func _prologue_visual_hint() -> String:
	if step_index <= 3:
		return "黑屏潮声 / 火光 / 村口刀影"
	if step_index <= 8:
		return "幼年主角 / 师父 / 敌人"
	if step_index == PROLOGUE_CAREER_STEP:
		return "出山职业选择 / 长枪 / 腰刀 / 山路"
	return "暗箭 / 师父背影 / 十年后山路"
