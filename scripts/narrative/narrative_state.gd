extends RefCounted
class_name NarrativeState

const DEFAULT_DATA_PATH := "res://data/narrative/mvp_compressed_narrative.json"

var data: Dictionary = {}
var variables: Dictionary = {}
var flags: Dictionary = {}
var current_node_id: String = ""
var current_ending_id: String = ""
var prologue_index: int = 0
var last_result_text: String = ""

func load_from_path(path: String = DEFAULT_DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Narrative data missing: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open narrative data: %s" % path)
		return false
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Narrative data is not a Dictionary: %s" % path)
		return false
	data = parsed as Dictionary
	_reset_runtime_state()
	return true

func _reset_runtime_state() -> void:
	variables.clear()
	flags.clear()
	current_ending_id = ""
	last_result_text = ""
	prologue_index = 0
	var variable_defs: Dictionary = data.get("variables", {})
	for key in variable_defs.keys():
		var def: Dictionary = variable_defs.get(key, {})
		variables[key] = int(def.get("initial", 0))
	var map_data: Dictionary = data.get("map", {})
	current_node_id = str(map_data.get("start_node", ""))

func prologue_count() -> int:
	var steps: Array = data.get("prologue", [])
	return steps.size()

func has_next_prologue_step() -> bool:
	return prologue_index < prologue_count()

func current_prologue_step() -> Dictionary:
	var steps: Array = data.get("prologue", [])
	if prologue_index < 0 or prologue_index >= steps.size():
		return {}
	var step: Variant = steps[prologue_index]
	return step if typeof(step) == TYPE_DICTIONARY else {}

func advance_prologue() -> Dictionary:
	if not has_next_prologue_step():
		return {}
	var step := current_prologue_step()
	prologue_index += 1
	return step

func current_node() -> Dictionary:
	return node_by_id(current_node_id)

func node_by_id(node_id: String) -> Dictionary:
	var nodes: Dictionary = data.get("nodes", {})
	var node: Variant = nodes.get(node_id, {})
	return node if typeof(node) == TYPE_DICTIONARY else {}

func available_choices(node: Dictionary = {}) -> Array:
	var src := node if not node.is_empty() else current_node()
	var choices: Array = src.get("choices", [])
	var result: Array = []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if _choice_available(choice):
			result.append(choice)
	return result

func _choice_available(choice: Dictionary) -> bool:
	if choice.has("requires"):
		var requires: Dictionary = choice.get("requires", {})
		for key in requires.keys():
			if int(variables.get(key, 0)) < int(requires.get(key, 0)):
				return false
	if choice.has("requires_flag"):
		var flag_name := str(choice.get("requires_flag", ""))
		if flag_name.is_empty() or not bool(flags.get(flag_name, false)):
			return false
	return true

func choose(index: int) -> Dictionary:
	var node := current_node()
	var choices := available_choices(node)
	if index < 0 or index >= choices.size():
		return {"ok": false, "result": "无效选择。"}
	var choice: Dictionary = choices[index]
	_apply_choice(choice)
	last_result_text = str(choice.get("result", ""))
	if choice.has("ending"):
		current_ending_id = str(choice.get("ending", "silent_tide"))
		return {"ok": true, "choice": choice, "result": last_result_text, "ending": current_ending()}
	current_node_id = str(choice.get("next", current_node_id))
	return {"ok": true, "choice": choice, "result": last_result_text, "node": current_node()}

func _apply_choice(choice: Dictionary) -> void:
	var delta: Dictionary = choice.get("delta", {})
	for key in delta.keys():
		variables[key] = int(variables.get(key, 0)) + int(delta.get(key, 0))
	var flag_list: Array = choice.get("flags", [])
	for flag_value in flag_list:
		flags[str(flag_value)] = true

func current_ending() -> Dictionary:
	if current_ending_id.is_empty():
		return {}
	var endings: Dictionary = data.get("endings", {})
	var ending: Variant = endings.get(current_ending_id, {})
	return ending if typeof(ending) == TYPE_DICTIONARY else {}

func variable_label(key: String) -> String:
	var defs: Dictionary = data.get("variables", {})
	var def: Dictionary = defs.get(key, {})
	return str(def.get("label", key))

func variable_short_label(key: String) -> String:
	var defs: Dictionary = data.get("variables", {})
	var def: Dictionary = defs.get(key, {})
	return str(def.get("short_label", key))

func variables_text() -> String:
	var parts: Array[String] = []
	for key in variables.keys():
		parts.append("%s %d" % [variable_short_label(str(key)), int(variables.get(key, 0))])
	return " / ".join(parts)

func node_type_label(node_type: String) -> String:
	match node_type:
		"battle":
			return "普通战斗"
		"elite":
			return "精英战斗"
		"event":
			return "事件"
		"camp":
			return "营地"
		"relic":
			return "旧物"
		"boss":
			return "Boss"
		"ending_gate":
			return "结尾"
		_:
			return node_type
