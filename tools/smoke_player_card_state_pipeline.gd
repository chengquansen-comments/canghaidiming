extends SceneTree

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const CardData := preload("res://scripts/card_data.gd")


func _init() -> void:
	var errors: Array[String] = []
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	NarrativeBattleContext.set_player_profile({
		"role": "spearman",
		"career": "长枪武官",
		"weapon": "长枪",
		"martial_level": 1,
		"battles_won": 0,
	})
	_assert_initial_profile(errors)
	NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
	var profile := NarrativeBattleContext.get_player_profile()
	if not _has_card(profile.get("owned_card_ids", []), "spear_retreat_sting"):
		errors.append("martial level reward did not enter long-term card library")
	var state := StrategicMapState.default_state()
	state = StrategicMapState.sync_card_state_from_profile(state, profile)
	state = StrategicMapState.apply_card_rewards(state, ["reward_guard"])
	NarrativeBattleContext.set_player_card_state(state.get("owned_card_ids", []), state.get("selected_loadout_ids", []))
	NarrativeBattleContext.set_player_selected_loadout([
		"spear_mid_thrust",
		"spear_mid_thrust",
		"spear_line_press",
		"spear_line_press",
		"spear_focus",
		"spear_focus",
		"spear_guard_horse",
		"reward_guard",
	])
	await _assert_battle_loadout_uses_context(errors)
	NarrativeBattleContext.clear()
	NarrativeBattleContext.clear_player_profile()
	if errors.is_empty():
		print("[player-card-state-pipeline] OK")
		quit(0)
	else:
		_fail(errors)


func _assert_initial_profile(errors: Array[String]) -> void:
	var profile := NarrativeBattleContext.get_player_profile()
	var owned: Array = profile.get("owned_card_ids", [])
	var selected: Array = profile.get("selected_loadout_ids", [])
	var slots: Array = profile.get("deck_slots", [])
	if owned.size() != 4:
		errors.append("initial owned card library should contain 4 unique cards, got %d" % owned.size())
	if selected.size() != 8:
		errors.append("initial selected battle loadout should contain 8 cards, got %d" % selected.size())
	if slots.size() != 4:
		errors.append("initial deck slots should contain 4 fixed slots, got %d" % slots.size())


func _assert_battle_loadout_uses_context(errors: Array[String]) -> void:
	NarrativeBattleContext.set_request("enc_beach_ambush", "map_card_state_smoke", "first_act_beach_ambush", true)
	var packed: PackedScene = load("res://scenes/MainVisual.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	if node.has_method("_try_recommended_role_entry"):
		node.call("_try_recommended_role_entry", "spearman")
	await process_frame
	var player = node.get("player")
	if player == null:
		errors.append("battle scene did not initialize player")
	else:
		var library_ids := _card_ids(player.get_session_deck())
		var selected_ids := _card_ids(player.get_selected_battle_deck())
		if not _has_card(library_ids, "reward_guard"):
			errors.append("battle player library did not include map reward card")
		if selected_ids.size() != 8:
			errors.append("battle selected loadout should contain 8 cards, got %d" % selected_ids.size())
		if not _has_card(selected_ids, "reward_guard"):
			errors.append("battle selected loadout did not preserve context-selected reward card")
	root.remove_child(node)
	node.free()
	await process_frame


func _card_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for item in cards:
		if item is CardData:
			var card: CardData = item
			ids.append(card.id)
		elif item is Dictionary:
			var config: Dictionary = item
			ids.append(str(config.get("id", "")))
	return ids


func _has_card(cards, card_id: String) -> bool:
	if cards is Array or cards is PackedStringArray:
		for item in cards:
			if str(item) == card_id:
				return true
	return false


func _fail(errors: Array[String]) -> void:
	for error: String in errors:
		push_error("[player-card-state-pipeline] %s" % error)
	quit(1)
