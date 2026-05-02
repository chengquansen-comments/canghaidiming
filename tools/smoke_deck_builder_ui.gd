extends SceneTree

const MainVisual := preload("res://scenes/MainVisual.tscn")


func _init() -> void:
	var errors: Array[String] = []
	var node := MainVisual.instantiate()
	root.add_child(node)
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", "spearman")
	await process_frame
	node.call("_open_battle_deck_builder")
	await process_frame
	if node.get("overlay_panel") == null or not bool(node.get("overlay_panel").visible):
		errors.append("deck builder overlay did not open")
	var player = node.get("player")
	if player == null:
		errors.append("player missing")
	else:
		var slots: Array = player.get_battle_deck_slots()
		if slots.size() != 4:
			errors.append("expected 4 fixed deck slots")
		elif (slots[0] as Array).size() != 8 or not (slots[1] as Array).is_empty():
			errors.append("initial slot state should be first deck filled and other decks empty")
		node.call("_open_deck_slot_detail", 1)
		node.call("_add_library_card_to_current_deck", "spear_mid_thrust")
		node.call("_add_library_card_to_current_deck", "spear_mid_thrust")
		node.call("_add_library_card_to_current_deck", "spear_mid_thrust")
		var second_slot: Array = player.get_battle_deck_slot(1)
		if second_slot.size() != 2:
			errors.append("same card copy limit should stop at 2")
		node.call("_remove_deck_slot_card", 1, 0)
		second_slot = player.get_battle_deck_slot(1)
		if second_slot.size() != 1:
			errors.append("clicking deck card should remove it")
	node.call("_open_battle_summary")
	await process_frame
	if node.get("overlay_panel") == null or not bool(node.get("overlay_panel").visible):
		errors.append("normal overlay did not reopen after deck builder")
	var title_label = node.get("overlay_title")
	if title_label != null and str(title_label.text) != "战斗摘要":
		errors.append("normal overlay title should recover after deck builder")
	node.queue_free()
	await process_frame
	if errors.is_empty():
		print("[deck-builder-ui] OK")
		quit(0)
	else:
		for error in errors:
			push_error("[deck-builder-ui] %s" % error)
		quit(1)
