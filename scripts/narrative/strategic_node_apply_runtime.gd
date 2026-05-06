extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

static func apply_node(strategic_state: Dictionary, node: Dictionary, fallback_merit: int, fallback_reputation: int, fallback_clues: int) -> Dictionary:
	var effects: Dictionary = node.get("effects", {}) as Dictionary
	var state := StrategicMapState.apply_effects(strategic_state, effects)
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
