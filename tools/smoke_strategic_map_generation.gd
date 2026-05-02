extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

func _init() -> void:
	var config := StrategicMapGenerator.load_config()
	if config.is_empty():
		push_error("Strategic map config missing")
		quit(1)
		return
	var state := StrategicMapState.default_state()
	state["active"] = true
	state["military_merit"] = 4
	state["clean_reputation"] = 3
	state["case_clues"] = 3
	state["martial_level"] = 2
	var map_data := StrategicMapGenerator.generate_map(config, state, 1701)
	if not _validate_case_sources(config):
		quit(1)
		return
	var regions: Array = map_data.get("regions", [])
	if regions.size() != 4:
		push_error("Expected 4 regions, got %d" % regions.size())
		quit(1)
		return
	var layer_count := 0
	for region in regions:
		if not (region is Dictionary):
			push_error("Region is not a Dictionary")
			quit(1)
			return
		var layers: Array = (region as Dictionary).get("layers", [])
		if layers.size() != 3:
			push_error("Expected 3 layers in %s, got %d" % [str((region as Dictionary).get("region_id", "")), layers.size()])
			quit(1)
			return
		for layer in layers:
			layer_count += 1
			var choices: Array = (layer as Dictionary).get("choices", [])
			if choices.size() != 3:
				push_error("Expected 3 choices, got %d" % choices.size())
				quit(1)
				return
	var boss := StrategicMapGenerator.select_final_boss(config, state)
	if boss.is_empty():
		push_error("Final boss rule selection returned empty")
		quit(1)
		return
	print("Strategic map generation smoke: OK regions=%d layers=%d boss=%s" % [regions.size(), layer_count, str(boss.get("boss_variant_id", ""))])
	quit(0)

func _validate_case_sources(config: Dictionary) -> bool:
	var sources := {
		"source_fragment": false,
		"source_military": false,
		"source_reputation": false,
		"source_military_blocked": false,
		"source_reputation_blocked": false,
	}
	var node_pool: Array = config.get("node_pool", [])
	for item in node_pool:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		if str(node.get("node_type", "")) != "case":
			continue
		var tags: Array = node.get("tags", [])
		for source in sources.keys():
			if source in tags:
				sources[source] = true
	for source in sources.keys():
		if not bool(sources[source]):
			push_error("Missing strategic case source: %s" % source)
			return false
	return true
