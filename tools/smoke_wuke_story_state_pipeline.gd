extends SceneTree

const CanonicalEffectsRuntime := preload("res://scripts/narrative/canonical_effects_runtime.gd")
const StrategicMapSessionRuntime := preload("res://scripts/narrative/strategic_map_session_runtime.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const NARRATIVE_PATH := "res://data/narrative_mvp_nodes.json"

const WUKE_NODE_EXPECTATIONS := {
	"wuke_elim_gu_chengyue_battle": {
		"flow_order": 40,
		"required_effects": {
			"route_bias_reputation": 1,
			"gu_trust": 1,
			"gu_identity_known": true,
			"public_reputation": 1,
		},
	},
	"wuke_elim_shen_zhaoye_battle": {
		"flow_order": 50,
		"required_effects": {
			"route_bias_military": 1,
			"shen_respect": 1,
			"military_rank_progress": 1,
		},
	},
	"wuke_elim_qi_heng_battle": {
		"flow_order": 60,
		"required_effects": {
			"route_bias_old_case": 1,
			"qi_trust": 1,
			"truth_progress": 1,
		},
	},
}


func _init() -> void:
	var data := _read_json_dict(NARRATIVE_PATH)
	if data.is_empty():
		push_error("Narrative MVP data missing")
		quit(1)
		return
	var nodes_by_id := _nodes_by_id(data.get("nodes", []))
	if not _validate_wuke_nodes(nodes_by_id):
		quit(1)
		return
	if not _validate_effect_runtime(nodes_by_id):
		quit(1)
		return
	print("Wuke story state pipeline smoke: OK")
	quit(0)


func _validate_wuke_nodes(nodes_by_id: Dictionary) -> bool:
	for node_id in WUKE_NODE_EXPECTATIONS.keys():
		if not nodes_by_id.has(node_id):
			push_error("Missing Wuke node: %s" % node_id)
			return false
		var node: Dictionary = nodes_by_id[node_id]
		var expected: Dictionary = WUKE_NODE_EXPECTATIONS[node_id]
		if int(node.get("flow_order", -1)) != int(expected.get("flow_order", -2)):
			push_error("Unexpected flow_order for %s" % node_id)
			return false
		var choices: Array = node.get("choices", [])
		if choices.is_empty() or not (choices[0] is Dictionary):
			push_error("Missing first choice for %s" % node_id)
			return false
		var effects: Dictionary = (choices[0] as Dictionary).get("effects", {})
		var required_effects: Dictionary = expected.get("required_effects", {})
		for key in required_effects.keys():
			if effects.get(key) != required_effects.get(key):
				push_error("Unexpected Wuke effect %s.%s expected=%s got=%s" % [node_id, str(key), str(required_effects.get(key)), str(effects.get(key))])
				return false
	var world_map: Dictionary = nodes_by_id.get("world_map_entry", {})
	if int(world_map.get("flow_order", -1)) <= int((WUKE_NODE_EXPECTATIONS["wuke_elim_qi_heng_battle"] as Dictionary).get("flow_order", 60)):
		push_error("world_map_entry must stay after Wuke battle nodes")
		return false
	return true


func _validate_effect_runtime(nodes_by_id: Dictionary) -> bool:
	var values := CanonicalEffectsRuntime.canonical_state(
		0,
		0,
		0,
		0,
		0,
		0,
		CanonicalEffectsRuntime.strategic_story_state_defaults()
	)
	for node_id in ["wuke_elim_gu_chengyue_battle", "wuke_elim_shen_zhaoye_battle", "wuke_elim_qi_heng_battle"]:
		var node: Dictionary = nodes_by_id[node_id]
		var choices: Array = node.get("choices", [])
		var effects: Dictionary = (choices[0] as Dictionary).get("effects", {})
		values = CanonicalEffectsRuntime.apply_effects_to_values(values, effects)
	if int(values.get("gu_trust", 0)) != 1 or not bool(values.get("gu_identity_known", false)):
		push_error("Gu Wuke story variables were not applied")
		return false
	if int(values.get("shen_respect", 0)) != 1 or int(values.get("route_bias_military", 0)) != 1:
		push_error("Shen Wuke story variables were not applied")
		return false
	if int(values.get("qi_trust", 0)) != 1 or int(values.get("truth_progress", 0)) != 1:
		push_error("Qi Wuke story variables were not applied")
		return false
	var strategic_state := StrategicMapState.default_state()
	strategic_state["military_merit"] = 7
	strategic_state["clean_reputation"] = 6
	strategic_state["case_clues"] = 5
	strategic_state["network_map"] = {"nodes": []}
	StrategicMapSessionRuntime.apply_story_state(strategic_state, values)
	if int(strategic_state.get("military_merit", 0)) != 7 or int(strategic_state.get("clean_reputation", 0)) != 6 or int(strategic_state.get("case_clues", 0)) != 5:
		push_error("Story route transfer must not overwrite base resource counters")
		return false
	if int(strategic_state.get("gu_trust", 0)) != 1 or not bool(strategic_state.get("gu_identity_known", false)):
		push_error("Story variables did not transfer into strategic_state")
		return false
	var graph: Dictionary = strategic_state.get("network_map", {})
	if int(graph.get("shen_respect", 0)) != 1 or int(graph.get("qi_trust", 0)) != 1:
		push_error("Story variables did not transfer into network_map mirror")
		return false
	return true


func _nodes_by_id(nodes_variant) -> Dictionary:
	var result: Dictionary = {}
	if not (nodes_variant is Array):
		return result
	for item in nodes_variant:
		if item is Dictionary:
			var node := item as Dictionary
			result[str(node.get("id", ""))] = node
	return result


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
