extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

func _init() -> void:
	if not await _assert_map_battle_return_to_final_gate():
		quit(1)
		return
	if not await _assert_final_boss_return_to_ending():
		quit(1)
		return
	print("Strategic map battle return ready smoke: OK")
	quit(0)

func _assert_map_battle_return_to_final_gate() -> bool:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_narrative_state()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 5,
		"battles_won": 4,
	})
	var config := StrategicMapGenerator.load_config()
	var state := StrategicMapState.default_state()
	state["active"] = true
	state["military_merit"] = 8
	state["clean_reputation"] = 4
	state["case_clues"] = 6
	state["martial_level"] = 5
	state["region_index"] = 3
	state["layer_index"] = 2
	state["current_map"] = StrategicMapGenerator.generate_map(config, state, 260501)
	NarrativeBattleContext.set_narrative_state({
		"step_index": 11,
		"node_index": 0,
		"jun_gong": 8,
		"qing_wang": 4,
		"clues": 6,
		"in_prologue": false,
		"career_selected": true,
		"last_hint": "",
		"strategic_state": state,
	})
	NarrativeBattleContext.set_request_from_combat({
		"enabled": true,
		"encounter_id": "enc_ch4_tide_bandits",
		"battle_id": "chapter4_tide_bandits",
		"override_player_profile": true,
		"combat_pool_id": "coastal_veteran",
		"recommended_martial_min": 5,
		"recommended_martial_max": 7,
		"enemy_martial_level": 4,
	}, "map_common_gate_surge_01")
	NarrativeBattleContext.set_result("win")
	var scene := _instantiate_narrative_scene()
	await process_frame
	await process_frame
	var title_label = scene.get("title_label")
	if title_label == null or str(title_label.text) != "海门收束":
		push_error("Map battle return did not render final gate, title=%s" % (str(title_label.text) if title_label != null else "<null>"))
		scene.queue_free()
		return false
	scene.queue_free()
	await process_frame
	return true

func _assert_final_boss_return_to_ending() -> bool:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_narrative_state()
	var state := StrategicMapState.default_state()
	state["active"] = true
	state["completed"] = false
	state["final_boss"] = {
		"title": "海门真收束",
		"ending_flag": "true_resolution",
	}
	NarrativeBattleContext.set_narrative_state({
		"step_index": 11,
		"node_index": 0,
		"jun_gong": 14,
		"qing_wang": 10,
		"clues": 12,
		"in_prologue": false,
		"career_selected": true,
		"last_hint": "",
		"strategic_state": state,
	})
	NarrativeBattleContext.set_request("enc_boss_ext_wakou_leader", "strategic_final_boss", "boss_ext_wakou_leader", true)
	NarrativeBattleContext.set_result("win")
	var scene := _instantiate_narrative_scene()
	await process_frame
	await process_frame
	var selected := str(scene.get("selected_ending_flag"))
	var title_label = scene.get("title_label")
	if selected != "true_resolution" or title_label == null or not str(title_label.text).contains("海门真收束"):
		push_error("Final boss return did not render ending, selected=%s title=%s" % [selected, str(title_label.text) if title_label != null else "<null>"])
		scene.queue_free()
		return false
	scene.queue_free()
	await process_frame
	return true

func _instantiate_narrative_scene() -> Node:
	var packed: PackedScene = load("res://scenes/NarrativeDemo.tscn")
	var scene := packed.instantiate()
	root.add_child(scene)
	return scene
