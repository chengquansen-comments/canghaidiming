extends SceneTree

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")


func _init() -> void:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	var packed: PackedScene = load("res://scenes/MainVisual.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if not node.has_method("_select_story_encounter_and_start"):
		push_error("Battle test controller missing _select_story_encounter_and_start")
		quit(1)
		return
	node.call("_select_story_encounter_and_start", "enc_beach_ambush")
	await process_frame
	if node.has_method("_start_battle"):
		node.call("_start_battle")
	await process_frame
	if not bool(node.get("battle_active")):
		push_error("Battle did not start from battle test list")
		quit(1)
		return
	if node.has_method("_on_continue_narrative_pressed"):
		node.call("_on_continue_narrative_pressed")
	await process_frame
	_assert_battle_test_overlay(node, "continue")
	NarrativeBattleContext.set_request("enc_beach_ambush", "stale_story_node")
	node.call("_select_story_encounter_and_start", "enc_beach_ambush")
	await process_frame
	if node.has_method("_start_battle"):
		node.call("_start_battle")
	await process_frame
	if node.has_method("_on_battle_result_confirm_pressed"):
		node.call("_on_battle_result_confirm_pressed")
	await process_frame
	_assert_battle_test_overlay(node, "result confirm with stale narrative context")
	print("Battle test return smoke: OK")
	quit(0)


func _assert_battle_test_overlay(node: Node, label: String) -> void:
	var overlay_title = node.get("overlay_title")
	var overlay_panel = node.get("overlay_panel")
	if overlay_title == null or str(overlay_title.text) != "战斗测试":
		push_error("Expected return to battle test title after %s, got %s" % [label, str(overlay_title.text if overlay_title != null else "null")])
		quit(1)
		return
	if overlay_panel == null or not bool(overlay_panel.visible):
		push_error("Expected battle test overlay to be visible after %s" % label)
		quit(1)
		return
