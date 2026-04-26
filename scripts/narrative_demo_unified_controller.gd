extends "res://scripts/narrative_demo_choice_combat_controller.gd"

# Unifies prologue and normal nodes:
# segments -> narrative choice -> optional combat -> result -> continue.

var showing_prologue_choice_result: bool = false
var prologue_choice_result_text: String = ""
var prologue_choice_result_delta_text: String = ""

func _render_prologue() -> void:
	var prologue: Dictionary = _prologue_data()
	title_label.text = str(prologue.get("title", "《大明之沧海嘀鸣》"))
	status_label.text = "序章 %d/%d" % [step_index + 1, _prologue_steps_count()]
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
