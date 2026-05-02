extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const CASES := [
	{"id": "true_resolution", "military_merit": 14, "clean_reputation": 10, "case_clues": 12, "martial_level": 6},
	{"id": "court_exposure", "military_merit": 14, "clean_reputation": 1, "case_clues": 10, "martial_level": 5},
	{"id": "reputation_redress", "military_merit": 3, "clean_reputation": 6, "case_clues": 6, "martial_level": 3},
	{"id": "military_reputation", "military_merit": 9, "clean_reputation": 6, "case_clues": 0, "martial_level": 4},
	{"id": "military_promotion", "military_merit": 9, "clean_reputation": 0, "case_clues": 0, "martial_level": 3},
	{"id": "private_truth", "military_merit": 0, "clean_reputation": 2, "case_clues": 7, "martial_level": 3},
	{"id": "isolated_evidence", "military_merit": 0, "clean_reputation": 0, "case_clues": 7, "martial_level": 3},
	{"id": "martial_survival", "military_merit": 0, "clean_reputation": 0, "case_clues": 0, "martial_level": 7},
	{"id": "surface_pirate", "military_merit": 0, "clean_reputation": 0, "case_clues": 0, "martial_level": 1},
]

func _init() -> void:
	var config := StrategicMapGenerator.load_config()
	if config.is_empty():
		push_error("Strategic map config missing")
		quit(1)
		return
	var rules: Array = config.get("final_boss_rules", [])
	if rules.size() != 9:
		push_error("Expected 9 final boss rules, got %d" % rules.size())
		quit(1)
		return
	for item in CASES:
		var expected := str(item.get("id", ""))
		var state := StrategicMapState.default_state()
		state["military_merit"] = int(item.get("military_merit", 0))
		state["clean_reputation"] = int(item.get("clean_reputation", 0))
		state["case_clues"] = int(item.get("case_clues", 0))
		state["martial_level"] = int(item.get("martial_level", 1))
		var boss := StrategicMapGenerator.select_final_boss(config, state)
		var actual := str(boss.get("boss_variant_id", ""))
		if actual != expected:
			push_error("Expected %s, got %s with state %s" % [expected, actual, StrategicMapState.summary_text(state)])
			quit(1)
			return
	print("Strategic map final boss matrix smoke: OK")
	quit(0)
