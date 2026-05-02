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
	if not scene.has_method("_start_strategic_map"):
		push_error("NarrativeDemo controller missing _start_strategic_map")
		quit(1)
		return
	scene.call("_start_strategic_map", "smoke")
	await process_frame
	var state = scene.get("strategic_state")
	if not (state is Dictionary) or not bool((state as Dictionary).get("active", false)):
		push_error("Strategic map did not become active")
		quit(1)
		return
	var map_data: Dictionary = (state as Dictionary).get("current_map", {})
	var regions: Array = map_data.get("regions", [])
	if regions.size() != 4:
		push_error("Strategic map entry generated invalid region count: %d" % regions.size())
		quit(1)
		return
	print("Strategic map narrative entry smoke: OK")
	quit(0)
