extends RefCounted

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")

static func sync_runtime_state(strategic_state: Dictionary) -> void:
	var map_data: Dictionary = strategic_state.get("current_map", {}) as Dictionary
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var region := StrategicMapGenerator.current_region(map_data, region_index)
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	var generated_nodes: Array[String] = []
	var choices: Array = layer.get("choices", [])
	for choice_variant in choices:
		if choice_variant is Dictionary:
			generated_nodes.append(str((choice_variant as Dictionary).get("node_id", "")))
	strategic_state["current_region_id"] = str(region.get("region_id", ""))
	strategic_state["current_region_layer"] = layer_index + 1
	strategic_state["world_map_generated_nodes"] = generated_nodes
	strategic_state["world_map_completed_nodes"] = (strategic_state.get("selected_nodes", []) as Array).duplicate(true)
	strategic_state["is_world_map_active"] = bool(strategic_state.get("active", false))

static func find_node(strategic_config: Dictionary, node_id: String) -> Dictionary:
	var node_pool: Array = strategic_config.get("node_pool", [])
	for item in node_pool:
		if item is Dictionary and str((item as Dictionary).get("node_id", "")) == node_id:
			return (item as Dictionary).duplicate(true)
	return {}

static func node_triggers_combat(node: Dictionary) -> bool:
	return str(node.get("node_type", "")).begins_with("combat_") and not str(node.get("encounter_id", "")).is_empty()
