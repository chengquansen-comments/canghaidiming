extends "res://scripts/narrative_demo_canonical_controller.gd"

# Phase 2 narrative flow:
# 1. Read node segments sentence by sentence.
# 2. Show narrative choices only after reading is complete.
# 3. If a choice has combat, start combat from that choice.
# 4. After victory, apply that choice's effects, show result sentence by sentence, then continue.
# 5. If a choice has no combat, apply effects immediately, show result sentence by sentence, then continue.
# 6. Boss nodes may use post-battle stance choices: read -> fight -> choose stance.

const META_PENDING_CHOICE_JSON := "canghai_pending_narrative_choice_json"
const META_PENDING_CHOICE_NODE := "canghai_pending_narrative_choice_node"
const META_PENDING_BOSS_NODE := "canghai_pending_boss_node"
const BOSS_NODE_ID := "wakou_boss"
const BOSS_ENCOUNTER_ID := "enc_wakou_boss"
const BOSS_BATTLE_ID := "first_act_wakou_boss"

var showing_choice_result: bool = false
var choice_result_text: String = ""
var choice_result_delta_text: String = ""
var choice_result_sentence_index: int = 0
var boss_battle_completed: bool = false

func _node_level_combat(node: Dictionary) -> Dictionary:
	var combat = node.get("combat", {})
	if combat is Dictionary and bool((combat as Dictionary).get("enabled", false)):
		return combat
	return {}

func _choice_effects(choice: Dictionary) -> Dictionary:
	var effects = choice.get("effects", {})
	if effects is Dictionary:
		return _normalize_effects(effects)
	return _normalize_effects({})

func _choice_combat(choice: Dictionary, node: Dictionary) -> Dictionary:
	if str(node.get("id", "")) == BOSS_NODE_ID and boss_battle_completed:
		return {}
	var combat = choice.get("combat", {})
	if combat is Dictionary and bool((combat as Dictionary).get("enabled", false)):
		return combat
	# Temporary compatibility: old node-level combat applies to every choice on that node.
	return _node_level_combat(node)

func _choice_triggers_combat(choice: Dictionary, node: Dictionary) -> bool:
	return not _choice_combat(choice, node).is_empty()

func _format_effect_delta(effects: Dictionary) -> String:
	var parts: Array[String] = []
	var military_merit := int(effects.get(VAR_MILITARY_MERIT, 0))
	var clean_reputation := int(effects.get(VAR_CLEAN_REPUTATION, 0))
	var case_clues := int(effects.get(VAR_CASE_CLUES, 0))
	if military_merit != 0:
		parts.append("军功 %+d" % military_merit)
	if clean_reputation != 0:
		parts.append("清望 %+d" % clean_reputation)
	if case_clues != 0:
		parts.append("旧案线索 %+d" % case_clues)
	if parts.is_empty():
		return "无资源变化"
	return " / ".join(parts)

func _choice_preview(choice: Dictionary, node: Dictionary) -> String:
	var preview := str(choice.get("preview", ""))
	if not preview.is_empty():
		return preview
	var prefix := "胜利后" if _choice_triggers_combat(choice, node) else "立即"
	if str(node.get("id", "")) == BOSS_NODE_ID and boss_battle_completed:
		prefix = "立场"
	return "%s：%s" % [prefix, _format_effect_delta(_choice_effects(choice))]

func _choice_result_segments() -> Array[String]:
	var segments: Array[String] = []
	_append_text_segments(segments, choice_result_text)
	if segments.is_empty():
		segments.append("")
	return segments

func _is_choice_result_complete() -> bool:
	var segments := _choice_result_segments()
	return choice_result_sentence_index >= segments.size() - 1

func _current_choice_result_text() -> String:
	var segments := _choice_result_segments()
	var safe_index = clamp(choice_result_sentence_index, 0, segments.size() - 1)
	return str(segments[safe_index])

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var node := _node_data_at(node_index)
	var node_id := str(node.get("id", ""))
	var btn := Button.new()
	btn.text = "%s\n%s" % [_choice_label(node_id, choice, index), _choice_preview(choice, node)]
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _on_choice(index: int) -> void:
	var node := _node_data_at(node_index)
	var node_id := str(node.get("id", ""))
	var choices := _configured_choices_for_node(node_id)
	if index < 0 or index >= choices.size() or not (choices[index] is Dictionary):
		return
	var choice: Dictionary = choices[index]
	if has_method("_record_choice_ending_flag"):
		_record_choice_ending_flag(choice)
	var combat := _choice_combat(choice, node)
	if not combat.is_empty():
		_store_pending_choice(node_id, choice)
		_save_narrative_state_to_context()
		NarrativeBattleContext.set_request_from_combat(combat, node_id)
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
		return
	_apply_choice_and_show_result(choice)

func _apply_choice_and_show_result(choice: Dictionary) -> void:
	var effects := _choice_effects(choice)
	_apply_canonical_effects(effects)
	NarrativeBattleContext.apply_player_growth("choice", 0, 0, 0, false)
	choice_result_text = str(choice.get("result", ""))
	choice_result_delta_text = ""
	choice_result_sentence_index = 0
	showing_choice_result = true
	_save_narrative_state_to_context()
	_render()

func _store_pending_choice(node_id: String, choice: Dictionary) -> void:
	Engine.set_meta(META_PENDING_CHOICE_NODE, node_id)
	Engine.set_meta(META_PENDING_CHOICE_JSON, JSON.stringify(choice))

func _load_pending_choice() -> Dictionary:
	if not Engine.has_meta(META_PENDING_CHOICE_JSON):
		return {}
	var parsed = JSON.parse_string(str(Engine.get_meta(META_PENDING_CHOICE_JSON)))
	return parsed if parsed is Dictionary else {}

func _clear_pending_choice() -> void:
	if Engine.has_meta(META_PENDING_CHOICE_NODE):
		Engine.remove_meta(META_PENDING_CHOICE_NODE)
	if Engine.has_meta(META_PENDING_CHOICE_JSON):
		Engine.remove_meta(META_PENDING_CHOICE_JSON)

func _store_pending_boss_node(node_id: String) -> void:
	Engine.set_meta(META_PENDING_BOSS_NODE, node_id)

func _clear_pending_boss_node() -> void:
	if Engine.has_meta(META_PENDING_BOSS_NODE):
		Engine.remove_meta(META_PENDING_BOSS_NODE)

func _battle_growth_reward_for_source(source_index: int) -> Dictionary:
	if source_index < 0 or source_index >= MVP_NODE_IDS.size():
		return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": false}
	var node: Dictionary = _node_data_at(source_index)
	var combat := _node_level_combat(node)
	var encounter_id := str(combat.get("encounter_id", ""))
	if encounter_id.is_empty() and str(node.get("id", "")) == BOSS_NODE_ID:
		encounter_id = BOSS_ENCOUNTER_ID
	if has_method("_formal_reward_for_encounter"):
		return _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))
	return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": true}

func _apply_battle_growth(source_index: int) -> void:
	var growth := _battle_growth_reward_for_source(source_index)
	NarrativeBattleContext.apply_player_growth(
		"battle_win",
		int(growth.get("hp_gain", 0)),
		int(growth.get("posture_gain", 0)),
		int(growth.get("martial_gain", 0)),
		bool(growth.get("heal_full", true))
	)

func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id: String = NarrativeBattleContext.source_node_id
	var result: String = NarrativeBattleContext.last_result
	if source_id == PROLOGUE_MASTER_SOURCE_ID:
		in_prologue = true
		step_index = PROLOGUE_AFTER_MASTER_BATTLE_STEP
		if result == "win":
			clues += 1
			last_hint = "序章战斗胜利：师父斩敌，敌人临死吐出旧案线索。"
		else:
			last_hint = "序章战斗返回：当前 Demo 按师父救场继续推进。"
		NarrativeBattleContext.clear()
		_save_narrative_state_to_context()
		return
	for i in range(MVP_NODE_IDS.size()):
		if _node_id_at(i) == source_id:
			node_index = i
			in_prologue = false
			break
	if result == "win":
		_apply_battle_growth(node_index)
		if source_id == BOSS_NODE_ID:
			boss_battle_completed = true
			showing_choice_result = false
			choice_result_text = ""
			choice_result_delta_text = ""
			choice_result_sentence_index = 0
			last_hint = "首领倒下。现在决定这场战斗留下什么。"
		else:
			var pending_choice := _load_pending_choice()
			if pending_choice.is_empty():
				last_hint = "战斗胜利：未找到待结算选择，暂不推进。"
			else:
				var effects := _choice_effects(pending_choice)
				_apply_canonical_effects(effects)
				choice_result_text = str(pending_choice.get("result", "战斗胜利。"))
				choice_result_delta_text = ""
				choice_result_sentence_index = 0
				showing_choice_result = true
				last_hint = ""
	elif result == "lose":
		last_hint = "战斗失败：已返回剧情。当前暂不扣除资源，可重新选择。"
		showing_choice_result = false
	elif result == "draw":
		last_hint = "战斗同归于尽：已返回剧情。线索保留，可重新选择。"
		showing_choice_result = false
	else:
		last_hint = "战斗结果未知：已返回剧情。"
	NarrativeBattleContext.clear()
	_clear_pending_choice()
	_clear_pending_boss_node()
	node_sentence_index = _node_story_segments(_node_data_at(node_index)).size() - 1
	_save_narrative_state_to_context()

func _render_node() -> void:
	var node: Dictionary = _node_data_at(node_index)
	title_label.text = str(node.get("title", ""))
	status_label.text = "%s / %s" % [str(node.get("column", "")), str(node.get("type", ""))]
	map_label.text = ""
	scene_label.text = _format_scene_text(str(node.get("scene", "")))
	_render_visual(str(node.get("visual_path", "")), str(node.get("scene", "")))
	if showing_choice_result:
		body_label.text = _current_choice_result_text()
		vars_label.text = _vars_text()
		_add_safe_map_buttons()
		_add_placeholder(combat_buttons_box, "")
		_add_button(choices_box, "继续", _on_continue_after_choice_result)
		return
	body_label.text = _current_node_story_text(node)
	if not last_hint.is_empty() and _is_node_story_complete(node):
		body_label.text += "\n\n[i]%s[/i]" % _fragmented_hint(last_hint)
	vars_label.text = _vars_text()
	_add_safe_map_buttons()
	if not _is_node_story_complete(node):
		_add_placeholder(combat_buttons_box, "")
		_add_button(choices_box, "继续", _on_continue_node_sentence)
		return
	if str(node.get("id", "")) == BOSS_NODE_ID and not boss_battle_completed:
		_add_button(combat_buttons_box, "决战", _on_request_boss_battle)
		_add_placeholder(choices_box, "先击败首领。战后再决定立场。")
		return
	_add_placeholder(combat_buttons_box, "")
	var choices := _configured_choices_for_node(str(node.get("id", "")))
	for i in range(choices.size()):
		var choice: Dictionary = choices[i] if choices[i] is Dictionary else {}
		_add_choice_button(choice, i)

func _on_request_boss_battle() -> void:
	var node_id := _node_id_at(node_index)
	var node := _node_data_at(node_index)
	var combat := _node_level_combat(node)
	if combat.is_empty():
		combat = {"encounter_id": BOSS_ENCOUNTER_ID, "battle_id": BOSS_BATTLE_ID, "override_player_profile": true}
	_store_pending_boss_node(node_id)
	NarrativeBattleContext.set_request_from_combat(combat, node_id)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

func _on_continue_after_choice_result() -> void:
	if not _is_choice_result_complete():
		choice_result_sentence_index += 1
		_render()
		return
	showing_choice_result = false
	choice_result_text = ""
	choice_result_delta_text = ""
	choice_result_sentence_index = 0
	if _node_id_at(node_index) == BOSS_NODE_ID:
		boss_battle_completed = false
	if node_index < MVP_NODE_IDS.size() - 1:
		_advance_to_node(node_index + 1, "")
	else:
		_render_ending()

func _on_request_battle() -> void:
	# Retained only for legacy calls. Canonical MVP starts combat from a narrative choice.
	super._on_request_battle()

func _on_mock_battle_win() -> void:
	var choices := _configured_choices_for_node(_node_id_at(node_index))
	if not choices.is_empty() and choices[0] is Dictionary:
		_apply_choice_and_show_result(choices[0])

func _restart() -> void:
	step_index = 0
	node_index = 0
	node_sentence_index = 0
	showing_choice_result = false
	choice_result_text = ""
	choice_result_delta_text = ""
	choice_result_sentence_index = 0
	boss_battle_completed = false
	jun_gong = 0
	qing_wang = 0
	clues = 0
	in_prologue = true
	career_selected = false
	last_hint = ""
	_clear_pending_choice()
	_clear_pending_boss_node()
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	_clear_narrative_state_context()
	_render()
