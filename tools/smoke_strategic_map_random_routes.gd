extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const SEED_START := 1701
const SEED_COUNT := 80

func _init() -> void:
	var config := StrategicMapGenerator.load_config()
	if config.is_empty():
		push_error("Strategic map config missing")
		quit(1)
		return
	var boss_counts := {}
	for i in range(SEED_COUNT):
		var seed := SEED_START + i
		var state := StrategicMapState.default_state()
		state["active"] = true
		var map_data := StrategicMapGenerator.generate_map(config, state, seed)
		if not _validate_visible_map(map_data, seed):
			quit(1)
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 97 + 13
		for region_index in range(4):
			for layer_index in range(3):
				var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
				var choices: Array = layer.get("choices", [])
				var picked: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
				state = StrategicMapState.apply_effects(state, picked.get("effects", {}))
				if str(picked.get("node_type", "")).begins_with("combat_"):
					state = StrategicMapState.apply_battle_win(state)
		var boss := StrategicMapGenerator.select_final_boss(config, state)
		var boss_id := str(boss.get("boss_variant_id", ""))
		boss_counts[boss_id] = int(boss_counts.get(boss_id, 0)) + 1
	if int(boss_counts.get("surface_pirate", 0)) >= SEED_COUNT:
		push_error("Random routes all fell back to surface_pirate")
		quit(1)
		return
	print("Strategic map random route smoke: OK %s" % [str(boss_counts)])
	quit(0)

func _validate_visible_map(map_data: Dictionary, seed: int) -> bool:
	var visible_nodes := {}
	var regions: Array = map_data.get("regions", [])
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var layers: Array = region.get("layers", [])
		for layer_index in range(layers.size()):
			var layer: Dictionary = layers[layer_index]
			var choices: Array = layer.get("choices", [])
			if choices.size() != 3:
				push_error("Seed %d expected 3 choices at %d/%d, got %d" % [seed, region_index, layer_index, choices.size()])
				return false
			for item in choices:
				if not (item is Dictionary):
					push_error("Seed %d has non-dictionary choice" % seed)
					return false
				var node_id := str((item as Dictionary).get("node_id", ""))
				if visible_nodes.has(node_id):
					push_error("Seed %d repeated visible node: %s" % [seed, node_id])
					return false
				visible_nodes[node_id] = true
	return true
