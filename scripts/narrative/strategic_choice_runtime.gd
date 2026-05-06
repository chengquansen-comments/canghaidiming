extends RefCounted

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")

static func current_choice(strategic_state: Dictionary, index: int) -> Dictionary:
	var layer := StrategicMapGenerator.current_layer(
		strategic_state.get("current_map", {}),
		int(strategic_state.get("region_index", 0)),
		int(strategic_state.get("layer_index", 0))
	)
	var choices: Array = layer.get("choices", [])
	if index < 0 or index >= choices.size() or not (choices[index] is Dictionary):
		return {}
	return choices[index] as Dictionary

static func pending_payload(node: Dictionary) -> Dictionary:
	return {
		"label": str(node.get("title", "")),
		"result": str(node.get("result_text", "")),
		"effects": node.get("effects", {}),
	}
