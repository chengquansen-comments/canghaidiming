extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

static func apply_node(strategic_state: Dictionary, node: Dictionary, fallback_merit: int, fallback_reputation: int, fallback_clues: int) -> Dictionary:
	var effects: Dictionary = node.get("effects", {}) as Dictionary
	var state := StrategicMapState.apply_effects(strategic_state, effects)
	_apply_story_beat_runtime_fields(state, node)
	var selected: Array = state.get("selected_nodes", [])
	selected.append(str(node.get("node_id", "")))
	state["selected_nodes"] = selected
	var result_text := str(node.get("result_text", ""))
	state["last_node_result"] = result_text
	state["current_world_map_node_id"] = str(node.get("node_id", ""))
	state["current_world_map_node_effects"] = effects.duplicate(true)
	return {
		"strategic_state": state,
		"military_merit": int(state.get("military_merit", fallback_merit)),
		"clean_reputation": int(state.get("clean_reputation", fallback_reputation)),
		"case_clues": int(state.get("case_clues", fallback_clues)),
		"last_hint": result_text,
	}


static func _apply_story_beat_runtime_fields(state: Dictionary, node: Dictionary) -> void:
	var beat_id := str(node.get("story_beat_id", ""))
	if beat_id.is_empty():
		return
	_append_unique(state, "triggered_story_beat_ids", beat_id)
	var exclusive_group := str(node.get("story_exclusive_group", ""))
	if not exclusive_group.is_empty():
		_append_unique(state, "story_exclusive_groups", exclusive_group)
	var cooldown_group := str(node.get("story_cooldown_group", ""))
	if not cooldown_group.is_empty():
		var cooldowns: Dictionary = (state.get("story_cooldowns", {}) as Dictionary).duplicate(true)
		cooldowns[cooldown_group] = max(0, int(node.get("story_cooldown_turns", 0)))
		state["story_cooldowns"] = cooldowns


static func _append_unique(state: Dictionary, field: String, value: String) -> void:
	var items: Array = state.get(field, [])
	if not (value in items):
		items.append(value)
	state[field] = items
