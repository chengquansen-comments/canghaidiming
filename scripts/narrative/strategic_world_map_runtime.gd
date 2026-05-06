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

static func refresh_current_layer(strategic_config: Dictionary, strategic_state: Dictionary) -> void:
	var map_data: Dictionary = strategic_state.get("current_map", {}) as Dictionary
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	var martial_level := int(strategic_state.get("martial_level", 1))
	if int(layer.get("generated_for_martial_level", -1)) == martial_level:
		return
	var seed_value := int(strategic_state.get("seed", 1701)) + region_index * 101 + layer_index * 17 + martial_level * 1009
	var refreshed := StrategicMapGenerator.refresh_layer(strategic_config, map_data, strategic_state, region_index, layer_index, seed_value)
	if refreshed.is_empty():
		return
	var regions: Array = map_data.get("regions", [])
	if region_index < 0 or region_index >= regions.size() or not (regions[region_index] is Dictionary):
		return
	var region := regions[region_index] as Dictionary
	var layers: Array = region.get("layers", [])
	if layer_index < 0 or layer_index >= layers.size():
		return
	layers[layer_index] = refreshed
	region["layers"] = layers
	regions[region_index] = region
	map_data["regions"] = regions
	strategic_state["current_map"] = map_data
	sync_runtime_state(strategic_state)

static func advance_cursor(strategic_state: Dictionary) -> bool:
	var cursor := StrategicMapGenerator.advance_cursor(
		strategic_state.get("current_map", {}),
		int(strategic_state.get("region_index", 0)),
		int(strategic_state.get("layer_index", 0))
	)
	strategic_state["region_index"] = int(cursor.get("region_index", 0))
	strategic_state["layer_index"] = int(cursor.get("layer_index", 0))
	sync_runtime_state(strategic_state)
	return StrategicMapGenerator.is_map_complete(
		strategic_state.get("current_map", {}),
		int(strategic_state.get("region_index", 0)),
		int(strategic_state.get("layer_index", 0))
	)

static func select_final_boss(strategic_config: Dictionary, strategic_state: Dictionary) -> Dictionary:
	return StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)

static func prepare_final_gate_state(strategic_config: Dictionary, strategic_state: Dictionary) -> Dictionary:
	var boss := select_final_boss(strategic_config, strategic_state)
	strategic_state["final_boss"] = boss
	strategic_state["is_world_map_active"] = false
	sync_runtime_state(strategic_state)
	return boss
