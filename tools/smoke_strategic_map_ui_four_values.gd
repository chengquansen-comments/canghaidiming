extends SceneTree

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const BANNED_VISIBLE_WORDS := ["证据"]

func _init() -> void:
	var packed := load("res://scenes/NarrativeDemo.tscn")
	if not (packed is PackedScene):
		push_error("NarrativeDemo is not a PackedScene")
		quit(1)
		return
	var scene := (packed as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_start_strategic_map", "ui smoke")
	await process_frame
	if not _assert_visible_four_value_ui(scene, "map entry"):
		quit(1)
		return
	if not _walk_to_final_gate(scene):
		quit(1)
		return
	await process_frame
	if not _assert_visible_four_value_ui(scene, "final gate"):
		quit(1)
		return
	print("Strategic map UI four-value smoke: OK")
	quit(0)

func _walk_to_final_gate(scene: Node) -> bool:
	for _step in range(12):
		var state: Dictionary = scene.get("strategic_state")
		var map_data: Dictionary = state.get("current_map", {})
		var layer := StrategicMapGenerator.current_layer(map_data, int(state.get("region_index", 0)), int(state.get("layer_index", 0)))
		var choices: Array = layer.get("choices", [])
		if choices.is_empty():
			push_error("UI smoke route hit empty choices before final gate")
			return false
		var picked: Dictionary = choices[0]
		scene.call("_apply_strategic_node", picked)
		if str(picked.get("node_type", "")).begins_with("combat_"):
			state = StrategicMapState.apply_battle_win(scene.get("strategic_state"))
			scene.set("strategic_state", state)
		scene.call("_advance_strategic_cursor")
	scene.call("_render")
	return true

func _assert_visible_four_value_ui(scene: Node, label: String) -> bool:
	var visible := _collect_text(scene, ["title_label", "status_label", "map_label", "scene_label", "body_label", "vars_label"])
	for word in BANNED_VISIBLE_WORDS:
		if visible.contains(word):
			push_error("%s visible UI still contains banned word '%s': %s" % [label, word, visible])
			return false
	for word in ["军功", "清望", "旧案", "武境"]:
		if not visible.contains(word):
			push_error("%s visible UI missing four-value word '%s': %s" % [label, word, visible])
			return false
	return true

func _collect_text(scene: Node, property_names: Array[String]) -> String:
	var parts: Array[String] = []
	for property_name in property_names:
		var value = scene.get(property_name)
		if value is Label or value is RichTextLabel or value is Button:
			parts.append(str(value.text))
	return "\n".join(parts)
