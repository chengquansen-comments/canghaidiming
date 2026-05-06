extends RefCounted

const NarrativeCombatBridgeScript := preload("res://scripts/narrative/narrative_combat_bridge.gd")

var c

func _init(controller) -> void:
	c = controller

func render_next_prologue_step() -> void:
	c._clear_choices()
	c.result_label.text = ""
	c.vars_label.text = ""
	c.route_label.text = "序章：短镜头链 / 尚未进入行军图"
	c._render_combat_bridge({})
	c._render_map_strip()
	if not c.narrative.has_next_prologue_step():
		c.showing_prologue = false
		c._render_node()
		return
	var step: Dictionary = c.narrative.advance_prologue()
	c.title_label.text = str(step.get("title", "刀下余声")) if step.has("title") else "刀下余声"
	c.type_label.text = "序章 / %d/%d" % [c.narrative.prologue_index, c.narrative.prologue_count()]
	c._render_step_art(step)
	c._render_step_portrait(step)
	c.body_label.text = _format_step(step)
	c.continue_button.visible = true
	c._force_cjk_font()

func render_step_art(step: Dictionary) -> void:
	var step_id := str(step.get("id", ""))
	var bg_path := str(c.PROLOGUE_BACKGROUND_HINTS.get(step_id, ""))
	if bg_path.is_empty():
		c._set_art_placeholder("序章镜头：%s" % str(step.get("kind", "black")))
		return
	c._set_art_from_path(bg_path, "P0 序章背景占位：%s" % bg_path)

func render_step_portrait(step: Dictionary) -> void:
	var step_id := str(step.get("id", ""))
	var hint: Dictionary = c.PROLOGUE_PORTRAIT_HINTS.get(step_id, {})
	if hint.is_empty() and step.has("speaker"):
		hint = _portrait_hint_for_speaker(str(step.get("speaker", "")))
	_apply_portrait_hint(hint, "序章角色")

func format_step(step: Dictionary) -> String:
	return _format_step(step)

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
			var card_data: Dictionary = card_value
			lines.append("• %s｜费%d｜%s" % [str(card_data.get("name", "")), int(card_data.get("cost", 0)), str(card_data.get("effect", ""))])
	return "\n".join(lines)

func render_node() -> void:
	c._clear_choices()
	var node: Dictionary = c.narrative.current_node()
	c.title_label.text = str(node.get("title", "未知节点"))
	c.type_label.text = c.narrative.node_status_text()
	c.route_label.text = c.narrative.route_text()
	c.vars_label.text = c.narrative.variables_text()
	c.result_label.text = c.narrative.last_result_text
	c._render_node_art(node)
	c._render_node_portrait(node)
	c.body_label.text = _format_node(node)
	c.continue_button.visible = false
	c._render_map_strip()
	c._render_combat_bridge(node)
	var choices: Array = c.narrative.available_choices(node)
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = c._choice_button_text(choice)
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(c._on_choice_pressed.bind(i))
		c.choices_box.add_child(button)
	c._force_cjk_font()

func render_combat_bridge(node: Dictionary) -> void:
	if c.combat_panel == null:
		return
	if node.is_empty() or not NarrativeCombatBridgeScript.node_has_combat(node):
		c.combat_panel.visible = false
		c.combat_payload_label.text = ""
		return
	c.combat_panel.visible = true
	var payload: Dictionary = NarrativeCombatBridgeScript.build_payload(c.narrative.current_node_id, node)
	c.combat_payload_label.text = "战斗桥接占位：\n%s" % combat_payload_text(payload)

func combat_payload_text(payload: Dictionary) -> String:
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

func render_node_art(node: Dictionary) -> void:
	var bg := str(node.get("background", ""))
	if bg.is_empty():
		c._set_art_placeholder("当前节点暂无背景配置。")
		return
	c._set_art_from_path(bg, "P0 节点背景占位：%s" % bg)

func render_node_portrait(node: Dictionary) -> void:
	var dialogue: Array = node.get("dialogue", [])
	for line_value in dialogue:
		if typeof(line_value) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = line_value
		var speaker := str(line.get("speaker", ""))
		if not speaker.is_empty():
			_apply_portrait_hint(_portrait_hint_for_speaker(speaker), speaker)
			return
	c._set_portrait_placeholder("角色占位：当前节点暂无角色立绘。")

func portrait_hint_for_speaker(speaker: String) -> Dictionary:
	return _portrait_hint_for_speaker(speaker)

func _portrait_hint_for_speaker(speaker: String) -> Dictionary:
	return c.SPEAKER_PORTRAIT_HINTS.get(speaker, {"name": speaker, "path": ""})

func apply_portrait_hint(hint: Dictionary, fallback_name: String) -> void:
	_apply_portrait_hint(hint, fallback_name)

func _apply_portrait_hint(hint: Dictionary, fallback_name: String) -> void:
	if hint.is_empty():
		c._set_portrait_placeholder("角色占位：%s" % fallback_name)
		return
	var name := str(hint.get("name", fallback_name))
	var path := str(hint.get("path", ""))
	if path.is_empty():
		c._set_portrait_placeholder("角色占位：%s" % name)
		return
	c._set_portrait_from_path(path, "角色 / 旧物占位：%s\n%s" % [name, path])

func set_art_from_path(path: String, fallback_text: String) -> void:
	if c.art_texture == null or c.art_label == null:
		return
	if ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			c.art_texture.texture = tex
			c.art_texture.visible = true
			c.art_label.visible = false
			return
	set_art_placeholder(fallback_text)

func set_art_placeholder(text: String) -> void:
	if c.art_texture != null:
		c.art_texture.texture = null
		c.art_texture.visible = false
	if c.art_label != null:
		c.art_label.text = text
		c.art_label.visible = true

func set_portrait_from_path(path: String, fallback_text: String) -> void:
	if c.portrait_texture == null or c.portrait_label == null:
		return
	if ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			c.portrait_texture.texture = tex
			c.portrait_texture.visible = true
			c.portrait_label.visible = false
			return
	set_portrait_placeholder(fallback_text)

func set_portrait_placeholder(text: String) -> void:
	if c.portrait_texture != null:
		c.portrait_texture.texture = null
		c.portrait_texture.visible = false
	if c.portrait_label != null:
		c.portrait_label.text = text
		c.portrait_label.visible = true

func render_map_strip() -> void:
	c._clear_map()
	if c.narrative == null or c.map_box == null:
		return
	if c.map_layout != null and c.map_layout.is_loaded():
		_render_static_branch_map()
		return
	_render_fallback_route_strip()

func _render_static_branch_map() -> void:
	var columns: Array = c.map_layout.columns()
	if columns.is_empty():
		_render_fallback_route_strip()
		return
	for column_value in columns:
		if typeof(column_value) != TYPE_DICTIONARY:
			continue
		var column: Dictionary = column_value
		c.map_box.add_child(_build_map_column(column))

func _build_map_column(column: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(176, 126)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17202b")
	style.border_color = Color("344354")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := Label.new()
	title.text = str(column.get("title", column.get("column_id", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.86, 0.80, 0.64, 1.0)
	box.add_child(title)
	var nodes: Array = column.get("nodes", [])
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node_entry: Dictionary = node_value
		box.add_child(_build_static_map_node_card(node_entry))
	return panel

func _build_static_map_node_card(node_entry: Dictionary) -> Control:
	var node_id := str(node_entry.get("node_id", ""))
	var node: Dictionary = c.narrative.node_by_id(node_id)
	var node_type := str(node.get("type", ""))
	var is_current: bool = node_id == c.narrative.current_node_id and c.narrative.current_ending_id.is_empty() and not c.showing_prologue
	var is_visited: bool = c.narrative.visited_node_ids.has(node_id) and not c.showing_prologue
	var is_available: bool = _is_static_map_node_available(node_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(156, 30)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.bg_color = Color("202936")
	style.border_color = Color("536171")
	if is_available:
		style.bg_color = Color("203240")
		style.border_color = Color("6f8899")
	if is_visited:
		style.bg_color = Color("263548")
		style.border_color = Color("7d8fa6")
	if is_current:
		style.bg_color = Color("3a2c18")
		style.border_color = Color("d8b26e")
	card.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%s %s %s" % [_static_map_marker(is_current, is_visited, is_available), _node_type_icon(node_type), str(node.get("title", node_id))]
	label.add_theme_font_size_override("font_size", 12)
	label.clip_text = true
	card.add_child(label)
	return card

func _is_static_map_node_available(node_id: String) -> bool:
	if c.showing_prologue or c.narrative == null or c.map_layout == null:
		return false
	if node_id == c.narrative.current_node_id or c.narrative.visited_node_ids.has(node_id):
		return true
	var previous: Array = c.map_layout.previous_nodes(node_id)
	if previous.is_empty():
		return node_id == c.narrative.current_node_id
	for prev_id in previous:
		if c.narrative.visited_node_ids.has(prev_id):
			return true
	return false

func _static_map_marker(is_current: bool, is_visited: bool, is_available: bool) -> String:
	if is_current:
		return "▶"
	if is_visited:
		return "●"
	if is_available:
		return "◎"
	return "○"

func _render_fallback_route_strip() -> void:
	var route: Array = c.narrative.map_route()
	if route.is_empty():
		var empty_label := Label.new()
		empty_label.text = "地图路线未配置"
		c.map_box.add_child(empty_label)
		return
	for node_id in route:
		c.map_box.add_child(_build_map_node_card(node_id))

func _build_map_node_card(node_id: String) -> Control:
	var node: Dictionary = c.narrative.node_by_id(node_id)
	var node_type := str(node.get("type", ""))
	var is_current: bool = node_id == c.narrative.current_node_id and c.narrative.current_ending_id.is_empty() and not c.showing_prologue
	var is_visited: bool = c.narrative.visited_node_ids.has(node_id) and not c.showing_prologue
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
	type.text = "%s %s" % [_node_type_icon(node_type), c.narrative.node_type_label(node_type)]
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

func format_node(node: Dictionary) -> String:
	return _format_node(node)

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
