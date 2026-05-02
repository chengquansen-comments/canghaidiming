extends SceneTree

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const NarrativeMvpData := preload("res://scripts/narrative_mvp_data.gd")


func _init() -> void:
	if not await _assert_prologue_master_uses_data_override_flag():
		quit(1)
		return
	if not await _assert_player_battle_uses_data_override_flag():
		quit(1)
		return
	print("Narrative battle call override smoke: OK")
	quit(0)


func _assert_prologue_master_uses_data_override_flag() -> bool:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 5,
		"battles_won": 7
	})
	var step: Dictionary = NarrativeMvpData.get_prologue_step(6)
	var combat: Dictionary = step.get("combat", {})
	NarrativeBattleContext.set_request_from_combat(combat, "prologue_master_rescue")
	if NarrativeBattleContext.should_override_player_profile():
		push_error("Expected prologue combat override_player_profile=false from compiled data")
		return false
	var node := await _start_visual_battle("blademaster")
	var player = node.get("player")
	if player == null or str(player.data.id) != "master_veteran":
		push_error("Expected master_veteran from prologue data call, got %s" % str(player.data.id if player != null else "null"))
		return false
	if int(player.data.max_hp) != 48 or int(player.data.max_momentum) != 12:
		push_error("Prologue master was incorrectly overwritten by player profile: hp=%s momentum=%s" % [str(player.data.max_hp), str(player.data.max_momentum)])
		return false
	node.queue_free()
	await process_frame
	return true


func _assert_player_battle_uses_data_override_flag() -> bool:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 2,
		"battles_won": 1
	})
	var node_data: Dictionary = NarrativeMvpData.get_node("beach_ambush")
	var choices: Array = node_data.get("choices", [])
	var choice: Dictionary = choices[0] if not choices.is_empty() and choices[0] is Dictionary else {}
	var combat: Dictionary = choice.get("combat", {})
	NarrativeBattleContext.set_request_from_combat(combat, "beach_ambush")
	if not NarrativeBattleContext.should_override_player_profile():
		push_error("Expected player combat override_player_profile=true from compiled data")
		return false
	var node := await _start_visual_battle("spearman")
	var player = node.get("player")
	if player == null:
		push_error("Expected player after beach battle data call")
		return false
	if int(player.hp) != 22 or int(player.data.max_hp) != 22 or int(player.data.max_momentum) != 4 or int(player.qinggong) != 1:
		push_error("Player battle did not apply profile override: hp=%s max_hp=%s max_momentum=%s" % [str(player.hp), str(player.data.max_hp), str(player.data.max_momentum)])
		return false
	node.queue_free()
	await process_frame
	return true


func _start_visual_battle(role_id: String) -> Node:
	var packed: PackedScene = load("res://scenes/MainVisual.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", role_id)
	await process_frame
	return node
