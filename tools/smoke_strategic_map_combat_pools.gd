extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

func _init() -> void:
	var config := StrategicMapGenerator.load_config()
	if config.is_empty():
		push_error("Strategic map config missing")
		quit(1)
		return
	if not _validate_combat_node_pool(config):
		quit(1)
		return
	if not _validate_generated_combat_ranges(config):
		quit(1)
		return
	if not _validate_battle_context_overrides():
		quit(1)
		return
	if not await _validate_runtime_pool_loadout():
		quit(1)
		return
	print("Strategic map combat pool smoke: OK")
	quit(0)

func _validate_combat_node_pool(config: Dictionary) -> bool:
	var combat_count := 0
	for item in config.get("node_pool", []):
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		if not str(node.get("node_type", "")).begins_with("combat_"):
			continue
		combat_count += 1
		var node_id := str(node.get("node_id", ""))
		if str(node.get("combat_pool_id", "")).is_empty():
			push_error("%s missing combat_pool_id" % node_id)
			return false
		var recommended_min := int(node.get("recommended_martial_min", 0))
		var recommended_max := int(node.get("recommended_martial_max", 0))
		var enemy_martial := int(node.get("enemy_martial_level", 0))
		if recommended_min < 1:
			push_error("%s recommended_martial_min must be >= 1" % node_id)
			return false
		if recommended_max < recommended_min:
			push_error("%s recommended_martial_max must be >= min" % node_id)
			return false
		if enemy_martial < 1:
			push_error("%s enemy_martial_level must be >= 1" % node_id)
			return false
	if combat_count < 1:
		push_error("No combat nodes found")
		return false
	return true

func _validate_generated_combat_ranges(config: Dictionary) -> bool:
	for martial_level in range(1, 10):
		var state := StrategicMapState.default_state()
		state["active"] = true
		state["military_merit"] = 6
		state["clean_reputation"] = 4
		state["case_clues"] = 5
		state["martial_level"] = martial_level
		var map_data := StrategicMapGenerator.generate_map(config, state, 1900 + martial_level)
		var regions: Array = map_data.get("regions", [])
		for region_index in range(regions.size()):
			if not (regions[region_index] is Dictionary):
				continue
			var layers: Array = (regions[region_index] as Dictionary).get("layers", [])
			for layer_index in range(layers.size()):
				var layer := StrategicMapGenerator.refresh_layer(config, map_data, state, region_index, layer_index, 2300 + martial_level * 100 + region_index * 10 + layer_index)
				if layer.is_empty():
					push_error("Could not refresh layer region=%d layer=%d" % [region_index, layer_index])
					return false
				var choices: Array = (layer as Dictionary).get("choices", [])
				for choice in choices:
					if not (choice is Dictionary):
						continue
					var node := choice as Dictionary
					if not str(node.get("node_type", "")).begins_with("combat_"):
						continue
					var recommended_min := int(node.get("recommended_martial_min", 0))
					var recommended_max := int(node.get("recommended_martial_max", 0))
					if martial_level < recommended_min or martial_level > recommended_max:
						push_error("%s generated outside martial range: current=%d range=%d-%d" % [
							str(node.get("node_id", "")),
							martial_level,
							recommended_min,
							recommended_max,
						])
						return false
				layers[layer_index] = layer
			var region := regions[region_index] as Dictionary
			region["layers"] = layers
			regions[region_index] = region
			map_data["regions"] = regions
	return true

func _validate_battle_context_overrides() -> bool:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.set_request_from_combat({
		"enabled": true,
		"encounter_id": "enc_ch2_reed_ambush",
		"battle_id": "chapter2_reed_ambush",
		"override_player_profile": true,
		"combat_pool_id": "spear_patrol",
		"recommended_martial_min": 1,
		"recommended_martial_max": 3,
		"enemy_martial_level": 2,
	}, "map_common_salt_ambush_01")
	var overrides := NarrativeBattleContext.get_battle_overrides()
	if str(overrides.get("combat_pool_id", "")) != "spear_patrol":
		push_error("Battle context did not preserve combat_pool_id")
		return false
	if int(overrides.get("enemy_martial_level", 0)) != 2:
		push_error("Battle context did not preserve enemy_martial_level")
		return false
	NarrativeBattleContext.clear()
	return true

func _validate_runtime_pool_loadout() -> bool:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 2,
		"battles_won": 1,
	})
	NarrativeBattleContext.set_request_from_combat({
		"enabled": true,
		"encounter_id": "enc_ch2_reed_ambush",
		"battle_id": "chapter2_reed_ambush",
		"override_player_profile": true,
		"combat_pool_id": "spear_patrol",
		"recommended_martial_min": 1,
		"recommended_martial_max": 3,
		"enemy_martial_level": 2,
	}, "map_common_salt_ambush_01")
	var packed: PackedScene = load("res://scenes/MainVisual.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", "spearman")
	await process_frame
	var enemy = node.get("enemy")
	if enemy == null:
		push_error("Runtime combat pool loadout did not create enemy")
		node.queue_free()
		return false
	if int(enemy.data.starting_realm) != 2:
		push_error("Runtime combat pool enemy realm mismatch: %s" % str(enemy.data.starting_realm))
		node.queue_free()
		return false
	if int(enemy.data.max_hp) < 24 or int(enemy.data.max_hp) > 26:
		push_error("Runtime combat pool enemy hp mismatch: %s" % str(enemy.data.max_hp))
		node.queue_free()
		return false
	if int(enemy.data.max_momentum) != 7 or int(enemy.data.starting_momentum) != 4:
		push_error("Runtime combat pool enemy posture mismatch: %s/%s" % [str(enemy.data.starting_momentum), str(enemy.data.max_momentum)])
		node.queue_free()
		return false
	if str(enemy.data.id).is_empty() or not str(enemy.data.id).begins_with("spear_patrol_"):
		push_error("Runtime combat pool enemy id did not come from pool: %s" % str(enemy.data.id))
		node.queue_free()
		return false
	node.queue_free()
	await process_frame
	NarrativeBattleContext.clear()
	return true
