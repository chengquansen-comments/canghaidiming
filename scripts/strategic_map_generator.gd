extends RefCounted

const NODE_TYPE_ORDER := [
	"combat_common",
	"case",
	"military",
	"reputation",
	"combat_elite",
	"rest",
]
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicMapWukeGuard := preload("res://scripts/strategic_map_wuke_guard.gd")

static func load_config(path: String = "res://data/strategic_map.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func generate_map(config: Dictionary, state: Dictionary, seed_value: int = 1701) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var node_pool: Array = config.get("node_pool", [])
	var rules: Array = config.get("generation_rules", [])
	var used_groups: Dictionary = {}
	var used_nodes: Dictionary = {}
	var regions: Array = []
	for region_i in range(rules.size()):
		var rule: Dictionary = rules[region_i] if rules[region_i] is Dictionary else {}
		var region_number := region_i + 1
		var layers: Array = []
		var layer_count := int(rule.get("layer_count", 3))
		var choices_per_layer := int(rule.get("choices_per_layer", 3))
		for layer_i in range(layer_count):
			var preferred_type := _preferred_type_for_layer(region_i, layer_i)
			var projected_state := _projected_state_for_region(state, region_number)
			var choices := _pick_layer_choices(node_pool, projected_state, region_number, preferred_type, choices_per_layer, used_groups, used_nodes, rng)
			layers.append({
				"layer_index": layer_i,
				"preferred_type": preferred_type,
				"choices": choices,
			})
		regions.append({
			"region_id": str(rule.get("region_id", "region_%02d" % region_number)),
			"region_title": str(rule.get("region_title", "海疆区域 %d" % region_number)),
			"layers": layers,
		})
	return {
		"seed": seed_value,
		"regions": regions,
	}

static func select_final_boss(config: Dictionary, state: Dictionary) -> Dictionary:
	var rules: Array = config.get("final_boss_rules", [])
	for item in rules:
		if not (item is Dictionary):
			continue
		var rule := item as Dictionary
		if int(state.get("case_clues", 0)) < int(rule.get("required_case_clues", 0)):
			continue
		if int(state.get("military_merit", 0)) < int(rule.get("required_military_merit", 0)):
			continue
		if int(state.get("clean_reputation", 0)) < int(rule.get("required_clean_reputation", 0)):
			continue
		if int(state.get("martial_level", 1)) < int(rule.get("required_martial_level", 1)):
			continue
		return rule.duplicate(true)
	return {}

static func current_layer(map_data: Dictionary, region_index: int, layer_index: int) -> Dictionary:
	var regions: Array = map_data.get("regions", [])
	if region_index < 0 or region_index >= regions.size() or not (regions[region_index] is Dictionary):
		return {}
	var layers: Array = (regions[region_index] as Dictionary).get("layers", [])
	if layer_index < 0 or layer_index >= layers.size() or not (layers[layer_index] is Dictionary):
		return {}
	return layers[layer_index]

static func refresh_layer(config: Dictionary, map_data: Dictionary, state: Dictionary, region_index: int, layer_index: int, seed_value: int) -> Dictionary:
	var rules: Array = config.get("generation_rules", [])
	if region_index < 0 or region_index >= rules.size() or not (rules[region_index] is Dictionary):
		return {}
	var node_pool: Array = config.get("node_pool", [])
	var rule := rules[region_index] as Dictionary
	var choices_per_layer := int(rule.get("choices_per_layer", 3))
	var usage := _usage_before_layer(map_data, region_index, layer_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var preferred_type := _preferred_type_for_layer(region_index, layer_index)
	var choices := _pick_layer_choices(
		node_pool,
		state,
		region_index + 1,
		preferred_type,
		choices_per_layer,
		usage.get("used_groups", {}),
		usage.get("used_nodes", {}),
		rng
	)
	return {
		"layer_index": layer_index,
		"preferred_type": preferred_type,
		"generated_for_martial_level": int(state.get("martial_level", 1)),
		"choices": choices,
	}

static func current_region(map_data: Dictionary, region_index: int) -> Dictionary:
	var regions: Array = map_data.get("regions", [])
	if region_index < 0 or region_index >= regions.size() or not (regions[region_index] is Dictionary):
		return {}
	return regions[region_index]

static func is_map_complete(map_data: Dictionary, region_index: int, layer_index: int) -> bool:
	var regions: Array = map_data.get("regions", [])
	if region_index >= regions.size():
		return true
	if region_index == regions.size() - 1 and regions[region_index] is Dictionary:
		var layers: Array = (regions[region_index] as Dictionary).get("layers", [])
		return layer_index >= layers.size()
	return false

static func advance_cursor(map_data: Dictionary, region_index: int, layer_index: int) -> Dictionary:
	var next_region := region_index
	var next_layer := layer_index + 1
	var regions: Array = map_data.get("regions", [])
	if region_index >= 0 and region_index < regions.size() and regions[region_index] is Dictionary:
		var layers: Array = (regions[region_index] as Dictionary).get("layers", [])
		if next_layer >= layers.size():
			next_region += 1
			next_layer = 0
	return {"region_index": next_region, "layer_index": next_layer}

static func _preferred_type_for_layer(region_i: int, layer_i: int) -> String:
	var offset := (region_i * 2 + layer_i) % NODE_TYPE_ORDER.size()
	return NODE_TYPE_ORDER[offset]

static func _pick_layer_choices(node_pool: Array, state: Dictionary, region_number: int, preferred_type: String, count: int, used_groups: Dictionary, used_nodes: Dictionary, rng: RandomNumberGenerator) -> Array:
	var choices: Array = []
	_add_weighted_choice(choices, node_pool, state, region_number, preferred_type, used_groups, used_nodes, rng)
	for node_type in NODE_TYPE_ORDER:
		if choices.size() >= count:
			break
		if node_type == preferred_type:
			continue
		_add_weighted_choice(choices, node_pool, state, region_number, node_type, used_groups, used_nodes, rng)
	while choices.size() < count:
		if not _add_weighted_choice(choices, node_pool, state, region_number, "", used_groups, used_nodes, rng):
			break
	return choices

static func _add_weighted_choice(choices: Array, node_pool: Array, state: Dictionary, region_number: int, node_type: String, used_groups: Dictionary, used_nodes: Dictionary, rng: RandomNumberGenerator) -> bool:
	var candidates: Array = []
	for item in node_pool:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		if node_type != "" and str(node.get("node_type", "")) != node_type:
			continue
		if not _is_eligible(node, state, region_number, used_groups, used_nodes):
			continue
		if _contains_node(choices, str(node.get("node_id", ""))):
			continue
		candidates.append(node)
	if candidates.is_empty():
		return false
	var picked := _weighted_pick(candidates, rng)
	if picked.is_empty():
		return false
	choices.append(picked)
	_mark_used(picked, used_groups, used_nodes)
	return true

static func _is_eligible(node: Dictionary, state: Dictionary, region_number: int, used_groups: Dictionary, used_nodes: Dictionary) -> bool:
	if StrategicMapWukeGuard.is_wuke_map_node(node):
		return false
	if int(node.get("region_min", 1)) > region_number or int(node.get("region_max", 4)) < region_number:
		return false
	if int(state.get("military_merit", 0)) < int(node.get("min_military_merit", 0)):
		return false
	var max_military_merit := int(node.get("max_military_merit", -1))
	if max_military_merit >= 0 and int(state.get("military_merit", 0)) > max_military_merit:
		return false
	if int(state.get("case_clues", 0)) < int(node.get("min_case_clues", 0)):
		return false
	if int(state.get("clean_reputation", 0)) < int(node.get("min_clean_reputation", 0)):
		return false
	var max_clean_reputation := int(node.get("max_clean_reputation", -1))
	if max_clean_reputation >= 0 and int(state.get("clean_reputation", 0)) > max_clean_reputation:
		return false
	if int(state.get("martial_level", 1)) < int(node.get("min_martial_level", 1)):
		return false
	if str(node.get("node_type", "")).begins_with("combat_"):
		var martial_level := int(state.get("martial_level", 1))
		var recommended_min := int(node.get("recommended_martial_min", 0))
		var recommended_max := int(node.get("recommended_martial_max", 0))
		if recommended_min > 0 and martial_level < recommended_min:
			return false
		if recommended_max > 0 and martial_level > recommended_max:
			return false
	if not _passes_line_scope(node, state):
		return false
	var node_id := str(node.get("node_id", ""))
	var used_count := int(used_nodes.get(node_id, 0))
	if bool(node.get("can_repeat", false)) == false and used_count > 0:
		return false
	if used_count >= int(node.get("max_per_run", 1)):
		return false
	var group := str(node.get("unique_group", ""))
	if not group.is_empty() and used_groups.has(group):
		return false
	return true

static func _passes_line_scope(node: Dictionary, state: Dictionary) -> bool:
	var node_type := str(node.get("node_type", ""))
	var primary_line := str(node.get("primary_line", ""))
	if node_type == "military" or primary_line == "military":
		var current_military_tier := StrategicMapState.military_tier_for_merit(int(state.get("military_merit", 0)))
		var required_military_tier := StrategicMapState.military_tier_for_merit(int(node.get("min_military_merit", 0)))
		if current_military_tier < required_military_tier:
			return false
	if node_type == "reputation" or primary_line == "reputation":
		var current_reputation_tier := StrategicMapState.reputation_tier_for_value(int(state.get("clean_reputation", 0)))
		var required_reputation_tier := StrategicMapState.reputation_tier_for_value(int(node.get("min_clean_reputation", 0)))
		if current_reputation_tier < required_reputation_tier:
			return false
	return true

static func _projected_state_for_region(state: Dictionary, region_number: int) -> Dictionary:
	var projected := state.duplicate(true)
	var progress: int = max(0, region_number - 1)
	projected["military_merit"] = int(projected.get("military_merit", 0)) + progress * 2
	projected["case_clues"] = int(projected.get("case_clues", 0)) + progress * 2
	projected["clean_reputation"] = int(projected.get("clean_reputation", 0)) + progress
	projected["martial_level"] = int(projected.get("martial_level", 1)) + int(progress / 2)
	return projected

static func _weighted_pick(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for node in candidates:
		total += max(1, int((node as Dictionary).get("weight", 1)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for node in candidates:
		var weight = max(1, int((node as Dictionary).get("weight", 1)))
		cursor += weight
		if roll <= cursor:
			return (node as Dictionary).duplicate(true)
	return (candidates[0] as Dictionary).duplicate(true)

static func _contains_node(choices: Array, node_id: String) -> bool:
	for item in choices:
		if item is Dictionary and str((item as Dictionary).get("node_id", "")) == node_id:
			return true
	return false

static func _mark_used(node: Dictionary, used_groups: Dictionary, used_nodes: Dictionary) -> void:
	var node_id := str(node.get("node_id", ""))
	if not node_id.is_empty():
		used_nodes[node_id] = int(used_nodes.get(node_id, 0)) + 1
	var group := str(node.get("unique_group", ""))
	if not group.is_empty():
		used_groups[group] = true

static func _usage_before_layer(map_data: Dictionary, region_index: int, layer_index: int) -> Dictionary:
	var used_groups: Dictionary = {}
	var used_nodes: Dictionary = {}
	var regions: Array = map_data.get("regions", [])
	for region_i in range(regions.size()):
		if region_i > region_index:
			break
		if not (regions[region_i] is Dictionary):
			continue
		var layers: Array = (regions[region_i] as Dictionary).get("layers", [])
		for layer_i in range(layers.size()):
			if region_i == region_index and layer_i >= layer_index:
				break
			if not (layers[layer_i] is Dictionary):
				continue
			var choices: Array = (layers[layer_i] as Dictionary).get("choices", [])
			for choice in choices:
				if choice is Dictionary:
					_mark_used(choice as Dictionary, used_groups, used_nodes)
	return {"used_groups": used_groups, "used_nodes": used_nodes}
