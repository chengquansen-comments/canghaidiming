extends SceneTree

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")


func _init() -> void:
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_request("enc_prologue_master_rescue", "prologue_master_rescue", "prologue_master_rescue")
	var packed: PackedScene = load("res://scenes/MainVisual.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", "master_veteran")
	await process_frame
	var loadout: Dictionary = node.get("battle_loadout")
	var player = node.get("player")
	var enemy = node.get("enemy")
	if player == null:
		push_error("Expected prologue master player")
		quit(1)
		return
	if enemy == null:
		push_error("Expected prologue enemy")
		quit(1)
		return
	if str(loadout.get("enemy_source", "")) != "enemy_manifest":
		push_error("Expected enemy_manifest loadout, got %s" % str(loadout.get("enemy_source", "")))
		quit(1)
		return
	if str(player.data.id) != "master_veteran":
		push_error("Expected master_veteran, got %s" % str(player.data.id))
		quit(1)
		return
	if int(player.data.max_hp) != 48 or int(player.data.max_momentum) != 12 or int(player.realm) != 4 or int(player.qinggong) != 3:
		push_error("Master stats mismatch: hp=%s momentum=%s realm=%s qinggong=%s" % [str(player.data.max_hp), str(player.data.max_momentum), str(player.realm), str(player.qinggong)])
		quit(1)
		return
	var meta_path: String = node.call("_actor_meta_path_for", player, false) if node.has_method("_actor_meta_path_for") else ""
	if meta_path != "res://assets/pixel_battle/actors/master_veteran/master_veteran.meta.json":
		push_error("Expected master_veteran actor meta, got %s" % meta_path)
		quit(1)
		return
	if str(enemy.data.id) != "enemy_blademaster_prologue_raider":
		push_error("Expected enemy_blademaster_prologue_raider, got %s" % str(enemy.data.id))
		quit(1)
		return
	if str(enemy.data.display_name) != "袭村倭寇刀手" or str(enemy.data.weapon_name) != "倭刀":
		push_error("Enemy manifest identity mismatch: %s / %s" % [str(enemy.data.display_name), str(enemy.data.weapon_name)])
		quit(1)
		return
	if int(enemy.data.max_hp) != 24 or int(enemy.data.max_momentum) != 10 or int(enemy.momentum) != 3:
		push_error("Enemy manifest stats mismatch: hp=%s momentum=%s/%s" % [str(enemy.data.max_hp), str(enemy.momentum), str(enemy.data.max_momentum)])
		quit(1)
		return
	var enemy_meta_path: String = node.call("_actor_meta_path_for", enemy, true) if node.has_method("_actor_meta_path_for") else ""
	if enemy_meta_path != "res://assets/pixel_battle/actors/enemy_blademaster/enemy_blademaster.meta.json":
		push_error("Expected enemy_blademaster actor meta, got %s" % enemy_meta_path)
		quit(1)
		return
	print("Prologue master loadout smoke: OK")
	quit(0)
