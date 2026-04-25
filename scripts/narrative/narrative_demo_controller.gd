extends Control
class_name NarrativeDemoController

const NarrativeStateScript := preload("res://scripts/narrative/narrative_state.gd")
const NarrativeFontHelper := preload("res://scripts/narrative/narrative_font_helper.gd")
const NarrativeCombatBridgeScript := preload("res://scripts/narrative/narrative_combat_bridge.gd")
const PROLOGUE_BACKGROUND_HINTS := {
	"p01_tide": "res://assets/pixel_battle/backgrounds/prologue_burning_village.png",
	"p04_blade": "res://assets/pixel_battle/backgrounds/prologue_burning_village.png",
	"p07_master_enter": "res://assets/pixel_battle/backgrounds/prologue_master_blocks_blade.png",
	"p08_master_cards": "res://assets/pixel_battle/backgrounds/prologue_master_blocks_blade.png",
	"p12_ten_years": "res://assets/pixel_battle/backgrounds/prologue_ten_years_later.png"
}
const PROLOGUE_PORTRAIT_HINTS := {
	"p02_father": {"name": "父亲", "path": ""},
	"p03_enemy": {"name": "敌人", "path": ""},
	"p05_child_card": {"name": "幼年主角", "path": "res://assets/pixel_battle/portraits/protagonist_child.png"},
	"p06_child_down": {"name": "敌人", "path": ""},
	"p07_master_enter": {"name": "师父", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"p08_master_cards": {"name": "师父", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"p11_dont_look": {"name": "师父", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"p12_ten_years": {"name": "主角 / 师父", "path": "res://assets/pixel_battle/portraits/protagonist_young.png"}
}
const SPEAKER_PORTRAIT_HINTS := {
	"主角": {"name": "主角：年轻武官", "path": "res://assets/pixel_battle/portraits/protagonist_young.png"},
	"师父": {"name": "师父：沉默老兵", "path": "res://assets/pixel_battle/portraits/mentor_veteran.png"},
	"上官": {"name": "军门上官", "path": "res://assets/pixel_battle/portraits/military_superior.png"},
	"Boss": {"name": "小股倭寇首领", "path": "res://assets/pixel_battle/portraits/wakou_leader.png"},
	"海商": {"name": "海商豪强", "path": "res://assets/pixel_battle/portraits/merchant_magnate.png"},
	"押运官": {"name": "失械案押运官", "path": "res://assets/pixel_battle/portraits/transport_officer.png"},
	"兵变营头": {"name": "兵变营头", "path": "res://assets/pixel_battle/portraits/mutiny_captain.png"},
	"敌方枪手": {"name": "敌方枪手", "path": "res://assets/pixel_battle/portraits/enemy_spearman_story.png"},
	"敌方刀客": {"name": "敌方刀客", "path": "res://assets/pixel_battle/portraits/enemy_blademaster_story.png"},
	"旧物": {"name": "旧物：官造火铳", "path": "res://assets/pixel_battle/relics/relic_ming_firearm.png"}
}

var narrative: NarrativeState
var combat_bridge: NarrativeCombatBridge
var root_panel: PanelContainer
var title_label: Label
var type_label: Label
var route_label: Label
var map_box: HBoxContainer
var visual_row: HBoxContainer
var art_frame: PanelContainer
var art_texture: TextureRect
var art_label: Label
var portrait_frame: PanelContainer
var portrait_texture: TextureRect
var portrait_label: Label
var body_label: RichTextLabel
var result_label: Label
var vars_label: Label
var combat_panel: PanelContainer
var combat_payload_label: Label
var request_battle_button: Button
var mock_win_button: Button
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
	root_panel.anchor_left = 0.04
	root_panel.anchor_top = 0.04
	root_panel.anchor_right = 0.96
	root_panel.anchor_bottom = 0.96
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
	layout.add_theme_constant_override("separation", 10)
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
	route_label.custom_minimum_size = Vector2(0, 42)
	route_label.modulate = Color(0.66, 0.78, 0.84, 1.0)
	layout.add_child(route_label)

	var map_scroll := HScrollContainer.new()
	map_scroll.custom_minimum_size = Vector2(0, 88)
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(map_scroll)

	map_box = HBoxContainer.new()
	map_box.add_theme_constant_override("separation", 8)
	map_scroll.add_child(map_box)

	visual_row = HBoxContainer.new()
	visual_row.add_theme_constant_override("separation", 10)
	visual_row.custom_minimum_size = Vector2(0, 170)
	layout.add_child(visual_row)

	art_frame = PanelContainer.new()
	art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_frame.custom_minimum_size = Vector2(0, 170)
	visual_row.add_child(art_frame)

	var art_stack := CenterContainer.new()
	art_frame.add_child(art_stack)

	art_texture = TextureRect.new()
	art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_texture.custom_minimum_size = Vector2(760, 160)
	art_stack.add_child(art_texture)

	art_label = Label.new()
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_label.custom_minimum_size = Vector2(720, 0)
	art_label.modulate = Color(0.86, 0.82, 0.7, 1.0)
	art_stack.add_child(art_label)

	portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(190, 170)
	visual_row.add_child(portrait_frame)

	var portrait_stack := CenterContainer.new()
	portrait_frame.add_child(portrait_stack)

	portrait_texture = TextureRect.new()
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.custom_minimum_size = Vector2(180, 160)
	portrait_stack.add_child(portrait_texture)

	portrait_label = Label.new()
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	portrait_label.custom_minimum_size = Vector2(170, 0)
	portrait_label.modulate = Color(0.86, 0.82, 0.7, 1.0)
	portrait_stack.add_child(portrait_label)

	body_label = RichTextLabel.new()
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(0, 160)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 22)
	layout.add_child(body_label)

	combat_panel = PanelContainer.new()
	combat_panel.visible = false
	layout.add_child(combat_panel)

	var combat_margin := MarginContainer.new()
	combat_margin.add_theme_constant_override("margin_left", 10)
	combat_margin.add_theme_constant_override("margin_top", 8)
	combat_margin.add_theme_constant_override("margin_right", 10)
	combat_margin.add_theme_constant_override("margin_bottom", 8)
	combat_panel.add_child(combat_margin)

	var combat_layout := VBoxContainer.new()
	combat_layout.add_theme_constant_override("separation", 6)
	combat_margin.add_child(combat_layout)

	combat_payload_label = Label.new()
	combat_payload_label.add_theme_font_size_override("font_size", 15)
	combat_payload_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_payload_label.modulate = Color(0.82, 0.88, 0.9, 1.0)
	combat_layout.add_child(combat_payload_label)

	var combat_buttons := HBoxContainer.new()
	combat_buttons.add_theme_constant_override("separation", 8)
	combat_layout.add_child(combat_buttons)

	request_battle_button = Button.new()
	request_battle_button.text = "请求战斗"
	request_battle_button.custom_minimum_size = Vector2(140, 38)
	request_battle_button.pressed.connect(_on_request_battle_pressed)
	combat_buttons.add_child(request_battle_button)

	mock_win_button = Button.new()
	mock_win_button.text = "视为胜利继续"
	mock_win_button.custom_minimum_size = Vector2(170, 38)
	mock_win_button.pressed.connect(_on_mock_battle_win_pressed)
	combat_buttons.add_child(mock_win_button)

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
	combat_bridge = NarrativeCombatBridgeScript.new()
	var ok := narrative.load_from_path()
	showing_prologue = true
	waiting_result = false
	result_label.text = ""
	if not ok:
		title_label.text = "叙事数据加载失败"
		body_label.text = "请检查 data/narrative/mvp_compressed_narrative.json"
		_set_art_placeholder("叙事数据加载失败。")
		_set_portrait_placeholder("无角色")
		_render_combat_bridge({})
		_render_map_strip()
		_force_cjk_font()
		return
	_render_next_prologue_step()
	_force_cjk_font()

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _clear_map() -> void:
	if map_box == null:
		return
	for child in map_box.get_children():
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
	_render_combat_bridge({})
	_render_map_strip()
	if not narrative.has_next_prologue_step():
		showing_prologue = false
		_render_node()
		return
	var step := narrative.advance_prologue()
	title_label.text = str(step.get("title", "刀下余声")) if step.has("title") else "刀下余声"
	type_label.text = "序章 / %d/%d" % [narrative.prologue_index, narrative.prologue_count()]
	_render_step_art(step)
	_render_step_portrait(step)
	body_label.text = _format_step(step)
	continue_button.visible = true
	_force_cjk_font()

func _render_step_art(step: Dictionary) -> void:
	var step_id := str(step.get("id", ""))
	var bg_path := str(PROLOGUE_BACKGROUND_HINTS.get(step_id, ""))
	if bg_path.is_empty():
		_set_art_placeholder("序章镜头：%s" % str(step.get("kind", "black")))
		return
	_set_art_from_path(bg_path, "P0 序章背景占位：%s" % bg_path)

func _render_step_portrait(step: Dictionary) -> void:
	var step_id := str(step.get("id", ""))
	var hint: Dictionary = PROLOGUE_PORTRAIT_HINTS.get(step_id, {})
	if hint.is_empty() and step.has("speaker"):
		hint = _portrait_hint_for_speaker(str(step.get("speaker", "")))
	_apply_portrait_hint(hint, "序章角色")

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
	_render_node_art(node)
	_render_node_portrait(node)
	body_label.text = _format_node(node)
	continue_button.visible = false
	_render_map_strip()
	_render_combat_bridge(node)
	var choices := narrative.available_choices(node)
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = _choice_button_text(choice)
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices_box.add_child(button)
	_force_cjk_font()

func _render_combat_bridge(node: Dictionary) -> void:
	if combat_panel == null:
		return
	if node.is_empty() or not NarrativeCombatBridge.node_has_combat(node):
		combat_panel.visible = false
		combat_payload_label.text = ""
		return
	combat_panel.visible = true
	var payload := NarrativeCombatBridge.build_payload(narrative.current_node_id, node)
	combat_payload_label.text = "战斗桥接占位：\n%s" % _combat_payload_text(payload)

func _combat_payload_text(payload: Dictionary) -> String:
	var enemies_text := ""
	var raw_enemies: Variant = payload.get("enemies", [])
	if typeof(raw_enemies) == TYPE_ARRAY:
		var parts: Array[String] = []
		for enemy in raw_enemies:
			parts.append(str(enemy))
		enemies_text = ", ".join(parts)
	return "node_id=%s｜encounter_id=%s｜enemies=%s" % [
		str(payload.get("node_id", "")),
		str(payload.get("encounter_id", "")),
		enemies_text
	]

func _on_request_battle_pressed() -> void:
	var node := narrative.current_node()
	var payload := combat_bridge.request_battle(narrative.current_node_id, node)
	if payload.is_empty():
		result_label.text = "当前节点没有 combat 配置。"
	else:
		result_label.text = "已请求战斗：%s" % _combat_payload_text(payload)
	_force_cjk_font()

func _on_mock_battle_win_pressed() -> void:
	if not combat_bridge.has_pending_battle():
		var node := narrative.current_node()
		combat_bridge.request_battle(narrative.current_node_id, node)
	var payload := combat_bridge.resolve_win({"source": "narrative_demo_mock"})
	result_label.text = "战斗占位胜利：%s。现在可选择战后处理。" % str(payload.get("encounter_id", ""))
	_force_cjk_font()

func _render_node_art(node: Dictionary) -> void:
	var bg := str(node.get("background", ""))
	if bg.is_empty():
		_set_art_placeholder("当前节点暂无背景配置。")
		return
	_set_art_from_path(bg, "P0 节点背景占位：%s" % bg)

func _render_node_portrait(node: Dictionary) -> void:
	var dialogue: Array = node.get("dialogue", [])
	for line_value in dialogue:
		if typeof(line_value) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = line_value
		var speaker := str(line.get("speaker", ""))
		if not speaker.is_empty():
			_apply_portrait_hint(_portrait_hint_for_speaker(speaker), speaker)
			return
	_set_portrait_placeholder("角色占位：当前节点暂无角色立绘。")

func _portrait_hint_for_speaker(speaker: String) -> Dictionary:
	return SPEAKER_PORTRAIT_HINTS.get(speaker, {"name": speaker, "path": ""})

func _apply_portrait_hint(hint: Dictionary, fallback_name: String) -> void:
	if hint.is_empty():
		_set_portrait_placeholder("角色占位：%s" % fallback_name)
		return
	var name := str(hint.get("name", fallback_name))
	var path := str(hint.get("path", ""))
	if path.is_empty():
		_set_portrait_placeholder("角色占位：%s" % name)
		return
	_set_portrait_from_path(path, "角色 / 旧物占位：%s\n%s" % [name, path])

func _set_art_from_path(path: String, fallback_text: String) -> void:
	if art_texture == null or art_label == null:
		return
	if ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			art_texture.texture = tex
			art_texture.visible = true
			art_label.visible = false
			return
	_set_art_placeholder(fallback_text)

func _set_art_placeholder(text: String) -> void:
	if art_texture != null:
		art_texture.texture = null
		art_texture.visible = false
	if art_label != null:
		art_label.text = text
		art_label.visible = true

func _set_portrait_from_path(path: String, fallback_text: String) -> void:
	if portrait_texture == null or portrait_label == null:
		return
	if ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			portrait_texture.texture = tex
			portrait_texture.visible = true
			portrait_label.visible = false
			return
	_set_portrait_placeholder(fallback_text)

func _set_portrait_placeholder(text: String) -> void:
	if portrait_texture != null:
		portrait_texture.texture = null
		portrait_texture.visible = false
	if portrait_label != null:
		portrait_label.text = text
		portrait_label.visible = true

func _render_map_strip() -> void:
	_clear_map()
	if narrative == null or map_box == null:
		return
	var route := narrative.map_route()
	if route.is_empty():
		var empty_label := Label.new()
		empty_label.text = "地图路线未配置"
		map_box.add_child(empty_label)
		return
	for node_id in route:
		map_box.add_child(_build_map_node_card(node_id))

func _build_map_node_card(node_id: String) -> Control:
	var node := narrative.node_by_id(node_id)
	var node_type := str(node.get("type", ""))
	var is_current := node_id == narrative.current_node_id and narrative.current_ending_id.is_empty() and not showing_prologue
	var is_visited := narrative.visited_node_ids.has(node_id) and not showing_prologue

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 76)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.bg_color = Color("202936")
	style.border_color = Color("536171")
	if is_visited:
		style.bg_color = Color("263548")
		style.border_color = Color("7d8fa6")
	if is_current:
		style.bg_color = Color("3a2c18")
		style.border_color = Color("d8b26e")
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s %s" % [_node_marker(node_id, is_current, is_visited), str(node.get("title", node_id))]
	title.add_theme_font_size_override("font_size", 14)
	title.clip_text = true
	box.add_child(title)

	var type := Label.new()
	type.text = "%s %s" % [_node_type_icon(node_type), narrative.node_type_label(node_type)]
	type.add_theme_font_size_override("font_size", 12)
	type.modulate = Color(0.78, 0.82, 0.86, 1.0)
	box.add_child(type)

	return card

func _node_marker(node_id: String, is_current: bool, is_visited: bool) -> String:
	if is_current:
		return "▶"
	if is_visited:
		return "●"
	return "○"

func _node_type_icon(node_type: String) -> String:
	match node_type:
		"battle":
			return "⚔"
		"elite":
			return "◆"
		"event":
			return "?"
		"camp":
			return "♨"
		"relic":
			return "◇"
		"boss":
			return "☠"
		"ending_gate":
			return "▣"
		_:
			return "·"

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
	_render_map_strip()
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
	_render_combat_bridge({})
	_set_art_placeholder("结局图占位：后续接入上报 / 掩盖 / 私查 / 借势四类结局图。")
	_set_portrait_placeholder("结局人物占位")
	_render_map_strip()
	_force_cjk_font()
