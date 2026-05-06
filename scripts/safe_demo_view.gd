extends RefCounted

const BattleFontHelper := preload("res://scripts/visual/battle_font_view.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

var c

func _init(controller) -> void:
	c = controller

func render() -> void:
	c._clear_dynamic_boxes()
	if c.in_prologue:
		render_prologue()
	else:
		render_node()
	BattleFontHelper.enforce(c)

func render_prologue() -> void:
	c.title_label.text = "《大明之沧海嘀鸣》剧情 MVP"
	c.status_label.text = "序章 %d/%d" % [c.step_index + 1, c.PROLOGUE.size()]
	c.map_label.text = "尚未进入行军图"
	c.scene_label.text = format_scene_text(c._prologue_scene_hint())
	c._render_visual("", c._prologue_visual_hint())
	c.body_label.text = c.PROLOGUE[c.step_index]
	if c.step_index == c.PROLOGUE_CAREER_STEP:
		c.body_label.text += "\n\n[b]选择出山职业[/b]\n这会初始化玩家单局数据，后续战斗都沿用并成长。"
	if not c.last_hint.is_empty():
		c.body_label.text += "\n\n[i]%s[/i]" % c.last_hint
	c.vars_label.text = c._vars_text()
	c._add_placeholder(c.map_buttons_box, "序章阶段尚未开放行军图。")
	if c.step_index == c.PROLOGUE_MASTER_RESCUE_STEP:
		c._add_button(c.combat_buttons_box, "请求序章战斗：师父救场", c._on_request_prologue_master_battle)
		c._add_button(c.combat_buttons_box, "跳过战斗继续序章", c._on_skip_prologue_master_battle)
	elif c.step_index == c.PROLOGUE_CAREER_STEP:
		c._add_placeholder(c.combat_buttons_box, "先选择出山职业，随后进入行军图。")
	else:
		c._add_placeholder(c.combat_buttons_box, "序章当前段落无战斗跳转。")
	if c.step_index == c.PROLOGUE_CAREER_STEP:
		for i in range(c.CAREERS.size()):
			c._add_career_button(c.CAREERS[i], i)
	else:
		c._add_button(c.choices_box, "继续", c._on_continue_prologue)

func render_node() -> void:
	var node: Dictionary = c.NODES[c.node_index]
	c.title_label.text = str(node.get("title", ""))
	c.status_label.text = "当前：%s / %s / %s" % [str(node.get("column", "")), str(node.get("type", "")), str(node.get("id", ""))]
	c.map_label.text = c._map_text()
	c.scene_label.text = format_scene_text(str(node.get("scene", "")))
	c._render_visual(str(node.get("visual_path", "")), str(node.get("scene", "")))
	c.body_label.text = c._node_body(node)
	if not c.last_hint.is_empty():
		c.body_label.text += "\n\n[i]%s[/i]" % c.last_hint
	c.vars_label.text = c._vars_text()
	add_safe_map_buttons()
	if c._is_combat_node(node):
		c._add_button(c.combat_buttons_box, "请求战斗：%s" % str(node.get("combat", "")), c._on_request_battle)
		c._add_button(c.combat_buttons_box, "视为胜利继续", c._on_mock_battle_win)
	else:
		c._add_placeholder(c.combat_buttons_box, "当前节点无战斗。")
	var choices: Array = node.get("choices", [])
	for i in range(choices.size()):
		c._add_choice_button(choices[i], i)

func format_scene_text(raw_text: String) -> String:
	var normalized := raw_text.replace("；", "。")
	var parts := normalized.split("。", false)
	var lines: Array[String] = []
	for part in parts:
		var clean := str(part).strip_edges()
		if not clean.is_empty():
			lines.append("• %s" % clean)
	if lines.is_empty():
		return "• 场景占位：暂无"
	return "\n".join(lines)

func render_visual(path: String, fallback_text: String) -> void:
	if path.is_empty():
		set_visual_placeholder("视觉诊断：path=空｜状态=文本占位", fallback_text)
		return
	if not ResourceLoader.exists(path):
		set_visual_placeholder("视觉诊断：path=%s｜exists=false｜状态=文本占位" % path, fallback_text)
		return
	var resource := load(path)
	if resource is Texture2D:
		c.visual_texture.texture = resource
		c.visual_texture.visible = true
		c.visual_label.visible = false
		c.visual_debug_label.text = "视觉诊断：path=%s｜exists=true｜type=Texture2D｜状态=已显示" % path
		return
	var resource_class_name := "null"
	if resource != null:
		resource_class_name = str(resource.get_class())
	c.visual_texture.texture = null
	c.visual_texture.visible = false
	c.visual_label.visible = true
	c.visual_label.text = "视觉资源不是 Texture2D：%s" % path
	c.visual_debug_label.text = "视觉诊断：path=%s｜exists=true｜type=%s｜状态=非 Texture2D" % [path, resource_class_name]

func set_visual_placeholder(debug_text: String, fallback_text: String) -> void:
	c.visual_texture.texture = null
	c.visual_texture.visible = false
	c.visual_label.visible = true
	c.visual_label.text = "视觉占位：%s" % fallback_text
	c.visual_debug_label.text = debug_text

func add_safe_map_buttons() -> void:
	var column_row := HBoxContainer.new()
	column_row.add_theme_constant_override("separation", 8)
	c.map_buttons_box.add_child(column_row)
	for column_name in c.MAP_COLUMNS:
		var column_box := VBoxContainer.new()
		column_box.custom_minimum_size = Vector2(142, 0)
		column_box.add_theme_constant_override("separation", 4)
		column_row.add_child(column_box)
		var title := Label.new()
		title.text = column_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 13)
		column_box.add_child(title)
		for i in range(c.NODES.size()):
			var node: Dictionary = c.NODES[i]
			if str(node.get("column", "")) == column_name:
				var btn := Button.new()
				btn.text = "%s %s" % [c._map_marker_for_index(i), str(node.get("title", ""))]
				btn.custom_minimum_size = Vector2(136, 38)
				btn.pressed.connect(c._on_map_node_pressed.bind(i))
				column_box.add_child(btn)

func render_ending() -> void:
	c.title_label.text = "结局：潮声还在"
	c.status_label.text = "单局结算"
	c.map_label.text = c._map_text()
	c.scene_label.text = format_scene_text("结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。")
	c._render_visual("", "结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。")
	c.body_label.text = "军功 %d / 清望 %d / 旧案线索 %d\n%s\n\n案卷缺页，潮声仍在。" % [c.jun_gong, c.qing_wang, c.clues, NarrativeBattleContext.player_profile_debug_text()]
	c.vars_label.text = c._vars_text()
	c._clear_dynamic_boxes()
	c._add_placeholder(c.map_buttons_box, "单局已结束。")
	c._add_placeholder(c.combat_buttons_box, "结局阶段无战斗。")
	c._add_button(c.choices_box, "重开叙事", c._restart)
	BattleFontHelper.enforce(c)
