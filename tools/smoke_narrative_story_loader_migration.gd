extends SceneTree

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")


func _init() -> void:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 2,
		"battles_won": 1
	})
	NarrativeBattleContext.set_request("enc_beach_ambush", "smoke_story_loader", "first_act_beach_ambush")
	var packed: PackedScene = load("res://scenes/MainVisual.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", "spearman")
	await process_frame
	var loadout: Dictionary = node.get("battle_loadout")
	if str(loadout.get("enemy_source", "")) != "enemy_manifest":
		push_error("Expected enemy_manifest overlay, got %s" % str(loadout.get("enemy_source", "")))
		quit(1)
		return
	var story_encounter: Dictionary = loadout.get("story_encounter_config", {})
	if str(story_encounter.get("opponent_template_id", "")) != "prologue_spear_guard":
		push_error("Expected StoryBattleLoader encounter data, got %s" % str(story_encounter))
		quit(1)
		return
	var player = node.get("player")
	var enemy = node.get("enemy")
	if player == null or enemy == null:
		push_error("Expected player and enemy after recommended entry")
		quit(1)
		return
	if int(player.hp) != 22 or int(player.data.max_hp) != 22 or int(player.data.max_momentum) != 4 or int(player.qinggong) != 1:
		push_error("Player profile override failed: hp=%s max_hp=%s max_momentum=%s" % [str(player.hp), str(player.data.max_hp), str(player.data.max_momentum)])
		quit(1)
		return
	if str(enemy.data.id) != "enemy_spearman_beach_ambush":
		push_error("Unexpected enemy id: %s" % str(enemy.data.id))
		quit(1)
		return
	print("Narrative story JSON loader smoke: OK")
	quit(0)
