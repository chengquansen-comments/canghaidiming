extends RefCounted

const DEFAULT_LAYER_COUNT := 10
const MIN_LANES := 2
const MAX_LANES := 4
const FIRST_LAYER_NODES := 1
const FINAL_LAYER_MIN_NODES := 1
const FINAL_LAYER_MAX_NODES := 2
const MAP_WIDTH := 900.0
const MAP_HEIGHT := 420.0
const LEFT_MARGIN := 60.0
const TOP_MARGIN := 60.0
const MAX_OUTGOING_PER_NODE := 3
const MAX_EDGES_PER_LAYER_PAIR := 5

static func generate_network_map(config: Dictionary, state: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, seed)
	var layer_count := DEFAULT_LAYER_COUNT
	var pool: Array = config.get("node_pool", [])
	var nodes: Array = []
	var node_ids_by_layer: Array = []
	var used_node_counts: Dictionary = {}
	var used_groups: Dictionary = {}
	for layer in range(layer_count):
		var node_count := _node_count_for_layer(layer, layer_count, rng)
		var layer_ids: Array[String] = []
		for lane in range(node_count):
			var picked := _pick_pool_node(pool, state, layer, used_node_counts, used_groups, rng)
			var graph_id := "L%d_N%d" % [layer, lane]
			var node := _build_graph_node(graph_id, layer, lane, node_count, layer_count, picked, rng)
			nodes.append(node)
			layer_ids.append(graph_id)
		node_ids_by_layer.append(layer_ids)
	_connect_layers(nodes, node_ids_by_layer, rng)
	apply_initial_node_states(nodes)
	var available_ids := _initial_available_node_ids(nodes)
	var selected_node_id: String = str(available_ids[0]) if not available_ids.is_empty() else ""
	var graph := {
		"run_id": "run_%d" % seed,
		"seed": seed,
		"layer_count": layer_count,
		"current_layer": 0,
		"current_node_id": "",
		"selected_node_id": selected_node_id,
		"completed_node_ids": [],
		"available_node_ids": available_ids,
		"pending_map_node_id": "",
		"pending_result_text": "",
		"pending_effects": {},
		"nodes": nodes,
	}
	for warning_text in validate_network_map(graph):
		push_warning(warning_text)
	return graph

static func summarize_network_map(graph: Dictionary) -> String:
	var nodes: Array = graph.get("nodes", [])
	var edge_count := 0
	var non_final_nodes := 0
	var outgoing_total := 0
	var combat_count := 0
	var fallback_count := 0
	var layer_count := int(graph.get("layer_count", 0))
	var layer_node_counts := _layer_node_counts(graph)
	var layer_edge_counts := _layer_edge_counts(graph)
	for variant in nodes:
		if not (variant is Dictionary):
			continue
		var node := variant as Dictionary
		var outgoing_size := (node.get("outgoing", []) as Array).size()
		edge_count += outgoing_size
		if int(node.get("layer", 0)) < layer_count - 1:
			non_final_nodes += 1
			outgoing_total += outgoing_size
		if _node_is_combat(node):
			combat_count += 1
		if bool(node.get("debug_fallback", false)):
			fallback_count += 1
	var avg_outgoing := 0.0
	if non_final_nodes > 0:
		avg_outgoing = float(outgoing_total) / float(non_final_nodes)
	var available := ",".join(_string_array(graph.get("available_node_ids", [])))
	return "network_map seed=%d layers=%d nodes=%d edges=%d avg_outgoing=%.2f combat=%d fallback=%d available=%s layer_nodes=%s layer_edges=%s" % [
		int(graph.get("seed", 0)),
		layer_count,
		nodes.size(),
		edge_count,
		avg_outgoing,
		combat_count,
		fallback_count,
		available,
		",".join(_string_array(layer_node_counts)),
		",".join(_string_array(layer_edge_counts)),
	]

static func validate_network_map(graph: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	var nodes: Array = graph.get("nodes", [])
	var layer_count := int(graph.get("layer_count", 0))
	var by_id: Dictionary = {}
	var seen: Dictionary = {}
	for item in nodes:
		if not (item is Dictionary):
			warnings.append("network_map validate: non-dictionary node")
			continue
		var node := item as Dictionary
		var node_id := str(node.get("map_graph_id", ""))
		if node_id.is_empty():
			warnings.append("network_map validate: node with empty map_graph_id")
			continue
		if seen.has(node_id):
			warnings.append("network_map validate: duplicate map_graph_id %s" % node_id)
		seen[node_id] = true
		by_id[node_id] = node
	for item in nodes:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		var node_id := str(node.get("map_graph_id", ""))
		var layer := int(node.get("layer", 0))
		var outgoing: Array = node.get("outgoing", [])
		var incoming: Array = node.get("incoming", [])
		if layer < layer_count - 1 and outgoing.is_empty():
			warnings.append("network_map validate: non-final node has no outgoing: %s" % node_id)
		if layer > 0 and incoming.is_empty():
			warnings.append("network_map validate: non-start node has no incoming: %s" % node_id)
		for to_id_variant in outgoing:
			var to_id := str(to_id_variant)
			if not by_id.has(to_id):
				warnings.append("network_map validate: %s outgoing missing target %s" % [node_id, to_id])
		for from_id_variant in incoming:
			var from_id := str(from_id_variant)
			if not by_id.has(from_id):
				warnings.append("network_map validate: %s incoming missing source %s" % [node_id, from_id])
	for available_variant in graph.get("available_node_ids", []):
		var available_id := str(available_variant)
		if not by_id.has(available_id):
			warnings.append("network_map validate: available id missing node %s" % available_id)
	var selected_id := str(graph.get("selected_node_id", ""))
	if not selected_id.is_empty() and not by_id.has(selected_id):
		warnings.append("network_map validate: selected id missing node %s" % selected_id)
	return warnings

static func apply_initial_node_states(nodes: Array) -> void:
	for variant in nodes:
		if not (variant is Dictionary):
			continue
		var node := variant as Dictionary
		if int(node.get("layer", 0)) == 0 and int(node.get("lane", -1)) == 0:
			node["state"] = "available"
		else:
			node["state"] = "locked"

static func _node_count_for_layer(layer: int, layer_count: int, rng: RandomNumberGenerator) -> int:
	if layer == 0:
		return FIRST_LAYER_NODES
	if layer == layer_count - 1:
		return rng.randi_range(FINAL_LAYER_MIN_NODES, FINAL_LAYER_MAX_NODES)
	return rng.randi_range(MIN_LANES, MAX_LANES)

static func _region_for_layer(layer: int) -> int:
	if layer <= 2:
		return 1
	if layer <= 5:
		return 2
	if layer <= 8:
		return 3
	return 4

static func _pick_pool_node(pool: Array, state: Dictionary, layer: int, used_node_counts: Dictionary, used_groups: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var region := _region_for_layer(layer)
	var strict := _collect_candidates(pool, state, region, used_node_counts, used_groups, false, false, false)
	if not strict.is_empty():
		return _weighted_pick_and_mark(strict, used_node_counts, used_groups, rng)
	var relaxed_group := _collect_candidates(pool, state, region, used_node_counts, used_groups, true, false, false)
	if not relaxed_group.is_empty():
		push_warning("network_map: relax unique_group in layer %d" % layer)
		return _weighted_pick_and_mark(relaxed_group, used_node_counts, used_groups, rng)
	var relaxed_max := _collect_candidates(pool, state, region, used_node_counts, used_groups, true, true, false)
	if not relaxed_max.is_empty():
		push_warning("network_map: relax max_per_run in layer %d" % layer)
		return _weighted_pick_and_mark(relaxed_max, used_node_counts, used_groups, rng)
	var relaxed_region := _collect_candidates(pool, state, region, used_node_counts, used_groups, true, true, true)
	if not relaxed_region.is_empty():
		push_warning("network_map: relax region in layer %d" % layer)
		return _weighted_pick_and_mark(relaxed_region, used_node_counts, used_groups, rng)
	push_warning("network_map: no candidates in layer %d, using fallback" % layer)
	return _debug_fallback_pool_node(layer)

static func _collect_candidates(pool: Array, state: Dictionary, region: int, used_node_counts: Dictionary, used_groups: Dictionary, relax_group: bool, relax_max_per_run: bool, relax_region: bool) -> Array:
	var candidates: Array = []
	for item in pool:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		if not relax_region and (int(node.get("region_min", 1)) > region or int(node.get("region_max", 4)) < region):
			continue
		if not _passes_numeric_requirements(node, state):
			continue
		var node_id := str(node.get("node_id", ""))
		if node_id.is_empty():
			continue
		var used_count := int(used_node_counts.get(node_id, 0))
		var max_per_run: int = max(1, int(node.get("max_per_run", 1)))
		if not relax_max_per_run:
			if used_count >= max_per_run:
				continue
			if not bool(node.get("can_repeat", false)) and used_count > 0:
				continue
		var group := str(node.get("unique_group", ""))
		if not relax_group and not group.is_empty() and used_groups.has(group):
			continue
		candidates.append(node)
	return candidates

static func _passes_numeric_requirements(node: Dictionary, state: Dictionary) -> bool:
	if int(state.get("military_merit", 0)) < int(node.get("min_military_merit", 0)):
		return false
	var max_military := int(node.get("max_military_merit", -1))
	if max_military >= 0 and int(state.get("military_merit", 0)) > max_military:
		return false
	if int(state.get("case_clues", 0)) < int(node.get("min_case_clues", 0)):
		return false
	if int(state.get("clean_reputation", 0)) < int(node.get("min_clean_reputation", 0)):
		return false
	var max_reputation := int(node.get("max_clean_reputation", -1))
	if max_reputation >= 0 and int(state.get("clean_reputation", 0)) > max_reputation:
		return false
	if int(state.get("martial_level", 1)) < int(node.get("min_martial_level", 1)):
		return false
	return true

static func _weighted_pick_and_mark(candidates: Array, used_node_counts: Dictionary, used_groups: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var picked := _weighted_pick(candidates, rng)
	var node_id := str(picked.get("node_id", ""))
	if not node_id.is_empty():
		used_node_counts[node_id] = int(used_node_counts.get(node_id, 0)) + 1
	var group := str(picked.get("unique_group", ""))
	if not group.is_empty():
		used_groups[group] = true
	return picked

static func _weighted_pick(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for variant in candidates:
		if not (variant is Dictionary):
			continue
		var node := variant as Dictionary
		total += max(1, int(node.get("weight", 1)))
	if total <= 0:
		return (candidates[0] as Dictionary).duplicate(true)
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for variant in candidates:
		if not (variant is Dictionary):
			continue
		var node := variant as Dictionary
		cursor += max(1, int(node.get("weight", 1)))
		if roll <= cursor:
			return node.duplicate(true)
	return (candidates[0] as Dictionary).duplicate(true)

static func _build_graph_node(graph_id: String, layer: int, lane: int, layer_node_count: int, layer_count: int, pool_node: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var layer_gap := MAP_WIDTH / float(max(1, layer_count - 1))
	var lane_gap := MAP_HEIGHT / float(layer_node_count + 1)
	var x := LEFT_MARGIN + float(layer) * layer_gap
	var y := TOP_MARGIN + float(lane + 1) * lane_gap
	if layer_node_count > 1 and layer > 0 and layer < layer_count - 1:
		y += rng.randf_range(-14.0, 14.0)
	var effects := _dict(pool_node.get("effects", {}))
	var combat := _dict(pool_node.get("combat", {}))
	var tags := _tags_array(pool_node.get("tags", []))
	return {
		"map_graph_id": graph_id,
		"pool_node_id": str(pool_node.get("node_id", "")),
		"layer": layer,
		"lane": lane,
		"x": x,
		"y": y,
		"title": str(pool_node.get("title", "临时军情")),
		"node_type": str(pool_node.get("node_type", "military")),
		"primary_line": str(pool_node.get("primary_line", "military")),
		"secondary_line": str(pool_node.get("secondary_line", "")),
		"preview_text": str(pool_node.get("preview_text", "")),
		"result_text": str(pool_node.get("result_text", "")),
		"effects": effects,
		"tags": tags,
		"combat": combat,
		"combat_pool_id": str(pool_node.get("combat_pool_id", "")),
		"encounter_id": str(pool_node.get("encounter_id", "")),
		"battle_id": str(pool_node.get("battle_id", "")),
		"enemy_martial_level": int(pool_node.get("enemy_martial_level", 0)),
		"recommended_martial_min": int(pool_node.get("recommended_martial_min", 0)),
		"recommended_martial_max": int(pool_node.get("recommended_martial_max", 0)),
		"debug_fallback": bool(pool_node.get("debug_fallback", false)),
		"outgoing": [],
		"incoming": [],
		"state": "locked",
	}

static func _dict(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _tags_array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	var text := str(value)
	if text.is_empty():
		return []
	var separator := "|" if text.find("|") >= 0 else ("," if text.find(",") >= 0 else ";")
	var parts := text.split(separator, false)
	var tags: Array[String] = []
	for item in parts:
		var tag := str(item).strip_edges()
		if not tag.is_empty():
			tags.append(tag)
	return tags

static func _connect_layers(nodes: Array, node_ids_by_layer: Array, rng: RandomNumberGenerator) -> void:
	var by_id := _nodes_by_graph_id(nodes)
	for layer in range(max(0, node_ids_by_layer.size() - 1)):
		var from_ids: Array = node_ids_by_layer[layer]
		var to_ids: Array = node_ids_by_layer[layer + 1]
		var edges := 0
		for from_id_variant in from_ids:
			var from_id := str(from_id_variant)
			var to_id := _nearest_lane_id(from_id, to_ids, by_id)
			if _connect_if_possible(by_id, from_id, to_id):
				edges += 1
		for to_id_variant in to_ids:
			var to_id := str(to_id_variant)
			var to_node: Dictionary = by_id.get(to_id, {}) as Dictionary
			if not (to_node is Dictionary):
				continue
			if ((to_node as Dictionary).get("incoming", []) as Array).is_empty():
				var from_id := _nearest_lane_id(to_id, from_ids, by_id)
				if edges < MAX_EDGES_PER_LAYER_PAIR and _connect_if_possible(by_id, from_id, to_id):
					edges += 1
		var extra_edges := rng.randi_range(0, 2)
		while extra_edges > 0 and edges < MAX_EDGES_PER_LAYER_PAIR and not from_ids.is_empty() and not to_ids.is_empty():
			var from_id := str(from_ids[rng.randi_range(0, from_ids.size() - 1)])
			var to_id := str(to_ids[rng.randi_range(0, to_ids.size() - 1)])
			if _connect_if_possible(by_id, from_id, to_id):
				edges += 1
				extra_edges -= 1
			else:
				extra_edges -= 1

static func _nodes_by_graph_id(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for variant in nodes:
		if not (variant is Dictionary):
			continue
		var node := variant as Dictionary
		var node_id := str(node.get("map_graph_id", ""))
		if not node_id.is_empty():
			result[node_id] = node
	return result

static func _nearest_lane_id(origin_id: String, candidate_ids: Array, by_id: Dictionary) -> String:
	if candidate_ids.is_empty():
		return ""
	var origin: Dictionary = by_id.get(origin_id, {}) as Dictionary
	if not (origin is Dictionary):
		return str(candidate_ids[0])
	var origin_lane := int((origin as Dictionary).get("lane", 0))
	var best := str(candidate_ids[0])
	var best_distance := 999999
	for candidate_variant in candidate_ids:
		var candidate_id := str(candidate_variant)
		var candidate: Dictionary = by_id.get(candidate_id, {}) as Dictionary
		if not (candidate is Dictionary):
			continue
		var distance := absi(int((candidate as Dictionary).get("lane", 0)) - origin_lane)
		if distance < best_distance:
			best_distance = distance
			best = candidate_id
	return best

static func _connect_if_possible(by_id: Dictionary, from_id: String, to_id: String) -> bool:
	if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
		return false
	var from_node_variant = by_id.get(from_id, {})
	var to_node_variant = by_id.get(to_id, {})
	if not (from_node_variant is Dictionary) or not (to_node_variant is Dictionary):
		return false
	var from_node := from_node_variant as Dictionary
	var to_node := to_node_variant as Dictionary
	var outgoing: Array = from_node.get("outgoing", [])
	if outgoing.size() >= MAX_OUTGOING_PER_NODE:
		return false
	if to_id in outgoing:
		return false
	outgoing.append(to_id)
	from_node["outgoing"] = outgoing
	var incoming: Array = to_node.get("incoming", [])
	if not (from_id in incoming):
		incoming.append(from_id)
	to_node["incoming"] = incoming
	return true

static func _initial_available_node_ids(nodes: Array) -> Array:
	var available: Array[String] = []
	for variant in nodes:
		if not (variant is Dictionary):
			continue
		var node := variant as Dictionary
		if str(node.get("state", "")) == "available":
			available.append(str(node.get("map_graph_id", "")))
	return available

static func _debug_fallback_pool_node(layer: int) -> Dictionary:
	return {
		"node_id": "debug_network_fallback_L%d" % layer,
		"title": "临时军情",
		"node_type": "military",
		"primary_line": "military",
		"secondary_line": "",
		"preview_text": "海图此处缺一枚节点。",
		"result_text": "你暂且记下一笔军情。",
		"effects": {"military_merit": 1},
		"tags": ["debug", "fallback"],
		"combat": {},
		"combat_pool_id": "",
		"encounter_id": "",
		"battle_id": "",
		"enemy_martial_level": 0,
		"recommended_martial_min": 0,
		"recommended_martial_max": 0,
		"debug_fallback": true,
	}

static func _node_is_combat(node: Dictionary) -> bool:
	var node_type := str(node.get("node_type", ""))
	return node_type.begins_with("combat_") \
		or not str(node.get("combat_pool_id", "")).is_empty() \
		or not str(node.get("encounter_id", "")).is_empty() \
		or not str(node.get("battle_id", "")).is_empty()

static func _layer_node_counts(graph: Dictionary) -> Array[String]:
	var layer_count := int(graph.get("layer_count", 0))
	var counts: Array[int] = []
	for _i in range(layer_count):
		counts.append(0)
	for item in graph.get("nodes", []):
		if item is Dictionary:
			var node := item as Dictionary
			var layer := int(node.get("layer", -1))
			if layer >= 0 and layer < counts.size():
				counts[layer] += 1
	var result: Array[String] = []
	for count in counts:
		result.append(str(count))
	return result

static func _layer_edge_counts(graph: Dictionary) -> Array[String]:
	var layer_count := int(graph.get("layer_count", 0))
	var counts: Array[int] = []
	for _i in range(max(0, layer_count - 1)):
		counts.append(0)
	for item in graph.get("nodes", []):
		if item is Dictionary:
			var node := item as Dictionary
			var layer := int(node.get("layer", -1))
			if layer >= 0 and layer < counts.size():
				counts[layer] += (node.get("outgoing", []) as Array).size()
	var result: Array[String] = []
	for count in counts:
		result.append(str(count))
	return result

static func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	return result
