extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const StrategicStoryBeatMapRuntime := preload("res://scripts/narrative/strategic_story_beat_map_runtime.gd")
const StrategicNodeApplyRuntime := preload("res://scripts/narrative/strategic_node_apply_runtime.gd")
const AigcStoryBeatRuntime := preload("res://scripts/narrative/aigc_story_beat_runtime.gd")


func _init() -> void:
	var config := StrategicMapGenerator.load_config()
	if config.is_empty():
		push_error("Strategic map config missing")
		quit(1)
		return
	var state := _seeded_story_state()
	var graph := StrategicNetworkMapGenerator.generate_network_map(config, state, 1702)
	var original_combat_nodes := _combat_nodes(graph)
	if original_combat_nodes.is_empty():
		push_error("Expected generated network map to contain combat nodes")
		quit(1)
		return
	graph = StrategicStoryBeatMapRuntime.materialize_story_beats(graph, state, 1702)
	if not _validate_story_materialization(graph):
		quit(1)
		return
	if not _validate_story_node_apply_records_runtime_fields(graph, state):
		quit(1)
		return
	if not _validate_combat_nodes_preserved(original_combat_nodes, graph):
		quit(1)
		return
	print("Strategic map story beat materialization smoke: OK story_nodes=%d combat_nodes=%d" % [
		StrategicStoryBeatMapRuntime.story_node_count(graph),
		_combat_nodes(graph).size(),
	])
	quit(0)


func _seeded_story_state() -> Dictionary:
	var state := StrategicMapState.default_state()
	state["active"] = true
	state["military_merit"] = 4
	state["clean_reputation"] = 3
	state["case_clues"] = 3
	state["martial_level"] = 3
	state["lightness_level"] = 1
	state["route_bias_military"] = 1
	state["route_bias_reputation"] = 1
	state["route_bias_old_case"] = 1
	state["shen_respect"] = 1
	state["gu_trust"] = 1
	state["gu_identity_known"] = true
	state["qi_trust"] = 1
	state["truth_progress"] = 1
	state["public_reputation"] = 1
	return state


func _validate_story_materialization(graph: Dictionary) -> bool:
	if not bool(graph.get("story_beat_materialized", false)):
		push_error("network_map was not marked story_beat_materialized")
		return false
	var story_nodes := _story_nodes(graph)
	if story_nodes.is_empty():
		push_error("No non-combat story beat nodes were materialized")
		return false
	var beat_index := _beat_index(AigcStoryBeatRuntime.load_pool())
	for node in story_nodes:
		var beat_id := str(node.get("story_beat_id", ""))
		if not beat_index.has(beat_id):
			push_error("Materialized node references missing story beat: %s" % beat_id)
			return false
		var beat: Dictionary = beat_index[beat_id] as Dictionary
		if str(node.get("preview_text", "")) != str(beat.get("preview_text", "")):
			push_error("Story node preview_text does not match beat: %s" % beat_id)
			return false
		if str(node.get("result_text", "")) != str(beat.get("result_text", "")):
			push_error("Story node result_text does not match beat: %s" % beat_id)
			return false
		if not (node.get("effects", {}) is Dictionary) or (node.get("effects", {}) as Dictionary).is_empty():
			push_error("Story node effects missing: %s" % beat_id)
			return false
		if not (node.get("story_requirements", {}) is Dictionary):
			push_error("Story node requirements were not copied: %s" % beat_id)
			return false
		if str(node.get("source_preview_text", "")).is_empty():
			push_error("Story node did not keep source_preview_text: %s" % beat_id)
			return false
	return true


func _validate_story_node_apply_records_runtime_fields(graph: Dictionary, state: Dictionary) -> bool:
	var story_nodes := _story_nodes(graph)
	if story_nodes.is_empty():
		return false
	var node := story_nodes[0] as Dictionary
	var applied := StrategicNodeApplyRuntime.apply_node(state, node, 0, 0, 0)
	var next_state: Dictionary = applied.get("strategic_state", {}) as Dictionary
	var beat_id := str(node.get("story_beat_id", ""))
	if not (beat_id in (next_state.get("triggered_story_beat_ids", []) as Array)):
		push_error("Applied story node did not record triggered_story_beat_ids")
		return false
	var exclusive_group := str(node.get("story_exclusive_group", ""))
	if not exclusive_group.is_empty() and not (exclusive_group in (next_state.get("story_exclusive_groups", []) as Array)):
		push_error("Applied story node did not record story_exclusive_groups")
		return false
	var cooldown_group := str(node.get("story_cooldown_group", ""))
	if not cooldown_group.is_empty() and int((next_state.get("story_cooldowns", {}) as Dictionary).get(cooldown_group, -1)) != int(node.get("story_cooldown_turns", 0)):
		push_error("Applied story node did not record story_cooldowns")
		return false
	return true


func _validate_combat_nodes_preserved(original_combat_nodes: Array, graph: Dictionary) -> bool:
	var current_by_id := _nodes_by_id(graph)
	for original in original_combat_nodes:
		var original_node := original as Dictionary
		var node_id := str(original_node.get("map_graph_id", ""))
		if not current_by_id.has(node_id):
			push_error("Combat node missing after materialization: %s" % node_id)
			return false
		var current: Dictionary = current_by_id[node_id] as Dictionary
		if not str(current.get("story_beat_id", "")).is_empty():
			push_error("Combat node should not receive story beat id: %s" % node_id)
			return false
		for field in ["combat_pool_id", "encounter_id", "battle_id", "enemy_martial_level"]:
			if str(current.get(field, "")) != str(original_node.get(field, "")):
				push_error("Combat node field changed: %s.%s" % [node_id, field])
				return false
	return true


func _story_nodes(graph: Dictionary) -> Array:
	var result: Array = []
	for item in graph.get("nodes", []):
		if item is Dictionary:
			var node := item as Dictionary
			if not _is_combat_node(node) and not str(node.get("story_beat_id", "")).is_empty():
				result.append(node)
	return result


func _combat_nodes(graph: Dictionary) -> Array:
	var result: Array = []
	for item in graph.get("nodes", []):
		if item is Dictionary and _is_combat_node(item as Dictionary):
			result.append((item as Dictionary).duplicate(true))
	return result


func _nodes_by_id(graph: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in graph.get("nodes", []):
		if item is Dictionary:
			var node := item as Dictionary
			result[str(node.get("map_graph_id", ""))] = node
	return result


func _beat_index(beats: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in beats:
		if item is Dictionary:
			var beat := item as Dictionary
			result[str(beat.get("story_beat_id", ""))] = beat
	return result


func _is_combat_node(node: Dictionary) -> bool:
	var node_type := str(node.get("node_type", ""))
	return node_type.begins_with("combat_") \
		or not str(node.get("combat_pool_id", "")).is_empty() \
		or not str(node.get("encounter_id", "")).is_empty() \
		or not str(node.get("battle_id", "")).is_empty()
