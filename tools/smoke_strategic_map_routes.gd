extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const ROUTES := {
	"military": {
		"target_boss": "military_promotion",
		"score": {"military_merit": 10, "case_clues": -4, "clean_reputation": -2, "combat": 6},
	},
	"case": {
		"target_boss": "isolated_evidence",
		"score": {"case_clues": 10, "military_merit": -3, "clean_reputation": 5, "combat": 15},
	},
	"reputation": {
		"target_boss": "reputation_redress",
		"score": {"clean_reputation": 10, "case_clues": 5, "military_merit": 1, "combat": 12},
	},
}

func _init() -> void:
	var config := StrategicMapGenerator.load_config()
	if config.is_empty():
		push_error("Strategic map config missing")
		quit(1)
		return
	for route_id in ROUTES.keys():
		if not _run_route(config, route_id, ROUTES[route_id]):
			quit(1)
			return
	print("Strategic map route smoke: OK")
	quit(0)

func _run_route(config: Dictionary, route_id: String, route: Dictionary) -> bool:
	var state := StrategicMapState.default_state()
	state["active"] = true
	var map_data := StrategicMapGenerator.generate_map(config, state, 1701)
	for region_index in range(4):
		for layer_index in range(3):
			var refreshed := StrategicMapGenerator.refresh_layer(config, map_data, state, region_index, layer_index, 3100 + region_index * 100 + layer_index * 10 + int(state.get("martial_level", 1)))
			if not refreshed.is_empty() and not (refreshed.get("choices", []) as Array).is_empty():
				map_data = _replace_layer(map_data, region_index, layer_index, refreshed)
			var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
			var choices: Array = layer.get("choices", [])
			if choices.is_empty():
				push_error("%s route missing choices at %d/%d" % [route_id, region_index, layer_index])
				return false
			var picked := _pick_best_choice(choices, route.get("score", {}))
			if picked.is_empty():
				push_error("%s route could not pick a node" % route_id)
				return false
			state = StrategicMapState.apply_effects(state, picked.get("effects", {}))
			if str(picked.get("node_type", "")).begins_with("combat_"):
				state = StrategicMapState.apply_battle_win(state)
	var boss := StrategicMapGenerator.select_final_boss(config, state)
	var boss_id := str(boss.get("boss_variant_id", ""))
	var target := str(route.get("target_boss", ""))
	if boss_id != target:
		push_error("%s route expected boss %s, got %s with state %s" % [route_id, target, boss_id, str(state)])
		return false
	print("%s route: boss=%s state=%s" % [route_id, boss_id, StrategicMapState.summary_text(state)])
	return true

func _replace_layer(map_data: Dictionary, region_index: int, layer_index: int, layer: Dictionary) -> Dictionary:
	var regions: Array = map_data.get("regions", [])
	if region_index < 0 or region_index >= regions.size() or not (regions[region_index] is Dictionary):
		return map_data
	var region := regions[region_index] as Dictionary
	var layers: Array = region.get("layers", [])
	if layer_index < 0 or layer_index >= layers.size():
		return map_data
	layers[layer_index] = layer
	region["layers"] = layers
	regions[region_index] = region
	map_data["regions"] = regions
	return map_data

func _pick_best_choice(choices: Array, score_weights: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999
	for item in choices:
		if not (item is Dictionary):
			continue
		var node := item as Dictionary
		var score := _score_node(node, score_weights)
		if score > best_score:
			best_score = score
			best = node
	return best

func _score_node(node: Dictionary, score_weights: Dictionary) -> int:
	var effects: Dictionary = node.get("effects", {})
	var score := 0
	for key in ["military_merit", "case_clues", "clean_reputation"]:
		score += int(effects.get(key, 0)) * int(score_weights.get(key, 0))
	if str(node.get("node_type", "")).begins_with("combat_"):
		score += int(score_weights.get("combat", 0))
	return score
