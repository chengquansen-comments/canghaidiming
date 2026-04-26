extends "res://scripts/narrative_demo_fragmented_controller.gd"

# Canonical narrative variable names for the MVP runtime.
# Internal legacy counters are kept as storage for compatibility with older controllers:
#   jun_gong  -> military_merit
#   qing_wang -> clean_reputation
#   clues     -> case_clues
const VAR_MILITARY_MERIT := "military_merit"
const VAR_CLEAN_REPUTATION := "clean_reputation"
const VAR_CASE_CLUES := "case_clues"
const VAR_SOLDIER_TRUST := "soldier_trust"

const LEGACY_VAR_ALIASES := {
	"jun_gong": VAR_MILITARY_MERIT,
	"qing_wang": VAR_CLEAN_REPUTATION,
	"clues": VAR_CASE_CLUES,
	"public_repute": VAR_CLEAN_REPUTATION,
	"case_clues": VAR_CASE_CLUES,
	"soldier_trust": VAR_SOLDIER_TRUST
}

func _canonical_state() -> Dictionary:
	return {
		VAR_MILITARY_MERIT: jun_gong,
		VAR_CLEAN_REPUTATION: qing_wang,
		VAR_CASE_CLUES: clues,
		VAR_SOLDIER_TRUST: 0
	}

func _normalize_effects(raw_effects: Dictionary) -> Dictionary:
	var normalized := {
		VAR_MILITARY_MERIT: 0,
		VAR_CLEAN_REPUTATION: 0,
		VAR_CASE_CLUES: 0,
		VAR_SOLDIER_TRUST: 0
	}
	for raw_key in raw_effects.keys():
		var key := str(raw_key)
		var canonical_key := str(LEGACY_VAR_ALIASES.get(key, key))
		if normalized.has(canonical_key):
			normalized[canonical_key] = int(normalized[canonical_key]) + int(raw_effects[raw_key])
	return normalized

func _apply_canonical_effects(effects: Dictionary) -> void:
	var normalized := _normalize_effects(effects)
	jun_gong += int(normalized[VAR_MILITARY_MERIT])
	qing_wang += int(normalized[VAR_CLEAN_REPUTATION])
	clues += int(normalized[VAR_CASE_CLUES])
	NarrativeBattleContext.apply_player_growth("choice", 0, 0, 0, false)

func _choice_effects_for_index(index: int) -> Dictionary:
	var node: Dictionary = NODES[node_index]
	var node_id := str(node.get("id", ""))
	var node_data := _node_config(node_id)
	var configured_choices = node_data.get("choices", [])
	if configured_choices is Array and index >= 0 and index < (configured_choices as Array).size():
		var configured = (configured_choices as Array)[index]
		if configured is Dictionary:
			var effects = (configured as Dictionary).get("effects", {})
			if effects is Dictionary:
				return _normalize_effects(effects)
	var static_choices: Array = node.get("choices", [])
	if index >= 0 and index < static_choices.size() and static_choices[index] is Dictionary:
		var choice: Dictionary = static_choices[index]
		return {
			VAR_MILITARY_MERIT: int(choice.get("dg", 0)),
			VAR_CLEAN_REPUTATION: int(choice.get("dq", 0)),
			VAR_CASE_CLUES: int(choice.get("dc", 0)),
			VAR_SOLDIER_TRUST: 0
		}
	return {VAR_MILITARY_MERIT: 0, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 0, VAR_SOLDIER_TRUST: 0}

func _add_choice_button(choice: Dictionary, index: int) -> void:
	var node: Dictionary = NODES[node_index]
	var node_id := str(node.get("id", ""))
	var effects := _choice_effects_for_index(index)
	var btn := Button.new()
	btn.text = "%s（军功 %+d / 清望 %+d / 旧案 %+d）" % [
		_choice_label(node_id, choice, index),
		int(effects[VAR_MILITARY_MERIT]),
		int(effects[VAR_CLEAN_REPUTATION]),
		int(effects[VAR_CASE_CLUES])
	]
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_choice.bind(index))
	choices_box.add_child(btn)

func _on_choice(index: int) -> void:
	var node: Dictionary = NODES[node_index]
	var static_choices: Array = node.get("choices", [])
	if index < 0:
		return
	if static_choices.size() > 0 and index >= static_choices.size():
		return
	_apply_canonical_effects(_choice_effects_for_index(index))
	if node_index < NODES.size() - 1:
		_advance_to_node(node_index + 1, "")
	else:
		_render_ending()

func _apply_choice_delta(choice: Dictionary) -> void:
	_apply_canonical_effects({
		VAR_MILITARY_MERIT: int(choice.get(VAR_MILITARY_MERIT, choice.get("dg", choice.get("jun_gong", 0)))),
		VAR_CLEAN_REPUTATION: int(choice.get(VAR_CLEAN_REPUTATION, choice.get("dq", choice.get("qing_wang", choice.get("public_repute", 0))))),
		VAR_CASE_CLUES: int(choice.get(VAR_CASE_CLUES, choice.get("dc", choice.get("clues", 0)))),
		VAR_SOLDIER_TRUST: int(choice.get(VAR_SOLDIER_TRUST, 0))
	})

func _reward_for_current_context(source_index: int) -> Dictionary:
	var context_reward := NarrativeBattleContext.get_enemy_config().get("reward", {})
	if context_reward is Dictionary and not (context_reward as Dictionary).is_empty():
		return _normalize_effects(context_reward)
	if source_index < 0 or source_index >= NODES.size():
		return {VAR_MILITARY_MERIT: 0, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 0, VAR_SOLDIER_TRUST: 0}
	var node: Dictionary = NODES[source_index]
	match str(node.get("type", "")):
		"普通战斗", "精英战斗":
			return {VAR_MILITARY_MERIT: 1, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 1, VAR_SOLDIER_TRUST: 0}
		"Boss":
			return {VAR_MILITARY_MERIT: 2, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 2, VAR_SOLDIER_TRUST: 0}
		_:
			return {VAR_MILITARY_MERIT: 1, VAR_CLEAN_REPUTATION: 0, VAR_CASE_CLUES: 0, VAR_SOLDIER_TRUST: 0}

func _apply_battle_result_reward(source_index: int) -> void:
	_apply_canonical_effects(_reward_for_current_context(source_index))

func _vars_text() -> String:
	return "军功 %d / 清望 %d / 旧案线索 %d" % [jun_gong, qing_wang, clues]

func _render_ending() -> void:
	title_label.text = "结局：潮声还在"
	status_label.text = "单局结算"
	map_label.text = _map_text()
	scene_label.text = _format_scene_text("结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。")
	_render_visual("", "结局图占位：上报 / 掩盖 / 私查 / 借势四类结局图后续接入。")
	body_label.text = "军功 %d / 清望 %d / 旧案线索 %d\n%s\n\n案卷缺页，潮声仍在。" % [jun_gong, qing_wang, clues, NarrativeBattleContext.player_profile_debug_text()]
	vars_label.text = _vars_text()
	_clear_dynamic_boxes()
	_add_placeholder(map_buttons_box, "单局已结束。")
	_add_placeholder(combat_buttons_box, "结局阶段无战斗。")
	_add_button(choices_box, "重开叙事", _restart)
	BattleFontHelper.enforce(self)

func _restart() -> void:
	step_index = 0
	node_index = 0
	jun_gong = 0
	qing_wang = 0
	clues = 0
	in_prologue = true
	career_selected = false
	last_hint = ""
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	_render()
