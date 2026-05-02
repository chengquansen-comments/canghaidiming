extends SceneTree

func _init() -> void:
	var packed := load("res://scenes/NarrativeDemo.tscn")
	if not (packed is PackedScene):
		push_error("NarrativeDemo is not a PackedScene")
		quit(1)
		return
	var scene := (packed as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var strategic_state: Dictionary = scene.get("strategic_state")
	strategic_state["active"] = true
	strategic_state["completed"] = false
	strategic_state["final_boss"] = {
		"title": "海门真收束",
		"ending_flag": "true_resolution",
	}
	scene.set("strategic_state", strategic_state)
	var context = load("res://scripts/narrative_battle_context.gd")
	context.set_request("enc_boss_ext_wakou_leader", "strategic_final_boss", "boss_ext_wakou_leader", true)
	context.set_result("win")
	scene.call("_consume_battle_result_if_needed")
	await process_frame
	var selected := str(scene.get("selected_ending_flag"))
	if selected != "true_resolution":
		push_error("Expected selected ending true_resolution, got %s" % selected)
		quit(1)
		return
	var title_label = scene.get("title_label")
	if title_label == null or not str(title_label.text).contains("海门真收束"):
		push_error("Final strategic ending was not rendered, title=%s" % (str(title_label.text) if title_label != null else "<null>"))
		quit(1)
		return
	var catalog: Array = scene.call("_ending_catalog")
	if catalog.size() != 9:
		push_error("Expected 9 ending catalog entries, got %d" % catalog.size())
		quit(1)
		return
	print("Strategic map final ending render smoke: OK")
	quit(0)
