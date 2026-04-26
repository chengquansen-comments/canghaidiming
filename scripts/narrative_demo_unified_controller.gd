extends "res://scripts/narrative_demo_choice_combat_controller.gd"

# Unifies prologue and normal nodes:
# segments -> narrative choice -> optional combat -> result -> continue.

var showing_prologue_choice_result: bool = false
var prologue_choice_result_text: String = ""
var prologue_choice_result_delta_text: String = ""

func _render_prologue() -> void:
	var step_data: Dictionary = _prologue_step_data(step_index)
	title_label.text = _prologue_display_title(step_data)
	status_label.text = _prologue_display_status(step_data)
	map_label.text = ""
	scene_label.text = _format_scene_text(_prologue_scene_hint())
	_render_visual("", _prologue_visual_hint())

	if showing_prologue_choice_result:
		body_label.text = "%s\n\n[b]%s[/b]" % [prologue_choice_result_text, prologue_choice_result_delta_text]
		if not last_hint.is_empty():
			body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
		vars_label.text = _vars_text()
		_add_placeholder(map_buttons_box, "")
		_add_placeholder(combat_buttons_box, "")
		_add_button(choices_box, "继续", _on_continue_after_prologue_choice_result)
		return

	body_label.text = _prologue_step_text(step_index)
	if step_index == PROLOGUE_CAREER_STEP:
		body_label.text += "\n\n[b]%s[/b]" % _career_prompt_text()
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_placeholder(map_buttons_box, "")
	_add_placeholder(combat_buttons_box, "")

	if step_index == PROLOGUE_CAREER_STEP:
		for i in range(CAREERS.size()):
			_add_career_button(CAREERS[i], i)
		return

	if _prologue_step_has_combat(step_index):
		_add_prologue_combat_choice()
		return

	_add_button(choices_box, "继续", _on_continue_prologue)

func _prologue_display_title(step_data: Dictionary) -> String:
	var step_title := str(step_data.get("title", ""))
	if not step_title.is_empty():
		return step_title
	return str(step_data.get("id", "prologue"))

func _prologue_display_status(step_data: Dictionary) -> String:
	var column := str(step_data.get("column", ""))
	var step_type := str(step_data.get("type", ""))
	if not column.is_empty() and not step_type.is_empty():
		return "%s / %s" % [column, step_type]
	if not column.is_empty():
		return column
	if not step_type.is_empty():
		return step_type
	return str(step_data.get("id", "prologue"))

func _prologue_map_title() -> String:
	var steps := _prologue_steps()
	if not steps.is_empty() and steps[0] is Dictionary:
		var first_step := steps[0] as Dictionary
		var title := str(first_step.get("title", ""))
		if not title.is_empty():
			return title
		return str(first_step.get("id", "prologue"))
	return "prologue"

func _current_world_map_title() -> String:
	if in_prologue:
		return _prologue_map_title()
	var node: Dictionary = _node_data_at(node_index)
	return str(node.get("title", ""))

func _world_map_total_count() -> int:
	return MVP_NODE_IDS.size() + 1

func _world_map_current_index() -> int:
	return 0 if in_prologue else node_index + 1

func _world_map_title_at(map_index: int) -> String:
	if map_index == 0:
		return _prologue_map_title()
	var node: Dictionary = _node_data_at(map_index - 1)
	return str(node.get("title", ""))

func _world_map_marker_for_index(index: int) -> String:
	var current := _world_map_current_index()
	if index == current:
		return "◆ 当前"
	if index < current:
		return "● 已过"
	if index == current + 1:
		return "◎ 可前往"
	return "○ 未开放"

func _refresh_world_map() -> void:
	if world_map_layer == null or world_map_panel == null or world_map_nodes_row == null:
		return
	world_map_panel.visible = true
	if world_map_status_label != null:
		world_map_status_label.text = "海疆行军图｜当前：%s｜军功 %d｜清望 %d｜旧案 %d" % [_current_world_map_title(), jun_gong, qing_wang, clues]
	for child: Node in world_map_nodes_row.get_children():
		child.queue_free()
	for i in range(_world_map_total_count()):
		if i > 0:
			world_map_nodes_row.add_child(_make_world_map_line(i))
		world_map_nodes_row.add_child(_make_world_map_node_button(i))

func _make_world_map_node_button(index: int) -> Button:
	var btn := Button.new()
	btn.text = "%s\n%s" % [_world_map_marker_for_index(index), _world_map_title_at(index)]
	btn.custom_minimum_size = Vector2(116, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = index > _world_map_current_index() + 1
	btn.pressed.connect(_on_world_map_node_pressed.bind(index))
	return btn

func _on_world_map_node_pressed(map_index: int) -> void:
	if map_index == 0:
		last_hint = "地图节点：序章。"
		_render()
		return
	_on_map_node_pressed(map_index - 1)

func _add_prologue_combat_choice() -> void:
	var combat: Dictionary = _prologue_combat_data(PROLOGUE_MASTER_RESCUE_STEP)
	var choice := {
		"label": str(combat.get("button", "换我。")),
		"preview": "胜利后：旧案线索 +1",
		"result": str(combat.get("post", "敌人还没死透。\n他吐出一个字：军……\n箭到了。")),
		"effects": {VAR_CASE_CLUES: 1},
		"combat": {
			"enabled": true,
			"encounter_id": str(combat.get("encounter_id", "enc_prologue_master_rescue")),
			"battle_id": str(combat.get("battle_id", "prologue_master_rescue"))
		}
	}
	var btn := Button.new()
	btn.text = "%s\n%s" % [str(choice.get("label", "换我。")), str(choice.get("preview", "胜利后：旧案线索 +1"))]
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_prologue_combat_choice.bind(choice))
	choices_box.add_child(btn)

func _on_prologue_combat_choice(choice: Dictionary) -> void:
	_store_pending_choice("prologue_master_rescue", choice)
	var combat: Dictionary = choice.get("combat", {})
	NarrativeBattleContext.set_request(
		str(combat.get("encounter_id", "enc_prologue_master_rescue")),
		"prologue_master_rescue",
		str(combat.get("battle_id", "prologue_master_rescue"))
	)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id: String = NarrativeBattleContext.source_node_id
	var result: String = NarrativeBattleContext.last_result
	if source_id == "prologue_master_rescue":
		in_prologue = true
		step_index = PROLOGUE_MASTER_RESCUE_STEP
		if result == "win":
			var pending_choice := _load_pending_choice()
			var effects := _choice_effects(pending_choice)
			_apply_canonical_effects(effects)
			prologue_choice_result_text = str(pending_choice.get("result", "敌人还没死透。\n他吐出一个字：军……\n箭到了。"))
			prologue_choice_result_delta_text = _format_effect_delta(effects)
			showing_prologue_choice_result = true
			last_hint = "序章战斗胜利：请确认战后结果。"
		else:
			last_hint = "序章战斗返回：当前 Demo 按师父救场继续推进。"
		NarrativeBattleContext.clear()
		_clear_pending_choice()
		return
	super._consume_battle_result_if_needed()

func _on_continue_after_prologue_choice_result() -> void:
	showing_prologue_choice_result = false
	prologue_choice_result_text = ""
	prologue_choice_result_delta_text = ""
	step_index = PROLOGUE_AFTER_MASTER_BATTLE_STEP
	last_hint = ""
	_render()

func _restart() -> void:
	showing_prologue_choice_result = false
	prologue_choice_result_text = ""
	prologue_choice_result_delta_text = ""
	super._restart()
