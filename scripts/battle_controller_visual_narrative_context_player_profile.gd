extends "res://scripts/battle_controller_visual_narrative_context_cards.gd"

# Narrative context player profile layer.

func _player_role_config_from_story_sets(role_id: String, profile: Dictionary) -> Dictionary:
	var template_id := "player_blademaster" if role_id == "blademaster" else "player_spearman"
	var deck_id := _player_deck_id_for_profile(role_id, profile)
	var data = NarrativeStoryBattleLoader.build_fighter_data(template_id, deck_id, "player_start", _story_loader_card_catalog(), true)
	return _fighter_data_to_config(data)

func _apply_story_player_overrides(base_config: Dictionary, profile: Dictionary) -> Dictionary:
	if base_config.is_empty():
		return base_config
	if not NarrativeBattleContext.should_override_player_profile():
		return base_config
	var overrides: Dictionary = NarrativeBattleContext.get_battle_overrides()
	var temp_role_id: String = str(overrides.get("temporary_player_role", "")).strip_edges()
	if temp_role_id == "spearman" or temp_role_id == "blademaster":
		var temp_owned_card_ids: Array[String] = []
		var temp_selected_loadout_ids: Array[String] = []
		if temp_role_id == "blademaster":
			temp_owned_card_ids = ["blade_front_cut", "blade_chase_cut", "blade_breathe", "blade_press_break"]
			temp_selected_loadout_ids = ["blade_front_cut", "blade_front_cut", "blade_chase_cut", "blade_chase_cut", "blade_breathe", "blade_breathe", "blade_press_break", "blade_press_break"]
		else:
			temp_owned_card_ids = ["spear_mid_thrust", "spear_line_press", "spear_focus", "spear_guard_horse"]
			temp_selected_loadout_ids = ["spear_mid_thrust", "spear_mid_thrust", "spear_line_press", "spear_line_press", "spear_focus", "spear_focus", "spear_guard_horse", "spear_guard_horse"]
		var temp_profile := {
			"role": temp_role_id,
			"career": str(overrides.get("temporary_player_career", "武科出身")),
			"weapon": str(overrides.get("temporary_player_weapon", "长枪" if temp_role_id == "spearman" else "腰刀")),
			"martial_level": 1,
			"battles_won": 0,
			"max_hp": int(base_config.get("max_hp", 20)),
			"hp": int(base_config.get("hp", base_config.get("max_hp", 20))),
			"max_posture": int(base_config.get("max_momentum", 6)),
			"posture": int(base_config.get("momentum", 5)),
			"qinggong": int(base_config.get("qinggong", 1)),
			"owned_card_ids": temp_owned_card_ids,
			"selected_loadout_ids": temp_selected_loadout_ids,
		}
		profile = temp_profile
	if profile.is_empty():
		return base_config
	var role_id: String = str(profile.get("role", ""))
	if role_id == "blademaster" or role_id == "spearman":
		var role_config: Dictionary = _player_role_config_from_story_sets(role_id, profile)
		if not role_config.is_empty():
			base_config = role_config
	var owned_cards := _cards_from_card_ids(profile.get("owned_card_ids", []))
	if not owned_cards.is_empty():
		base_config["deck"] = owned_cards
	var selected_loadout_ids := _card_id_array(profile.get("selected_loadout_ids", []))
	if not selected_loadout_ids.is_empty():
		base_config["selected_loadout_ids"] = selected_loadout_ids
	var deck_slots := _deck_slots_from_card_ids(profile.get("deck_slots", []))
	if not deck_slots.is_empty():
		base_config["deck_slots"] = deck_slots
		base_config["active_deck_index"] = int(profile.get("active_deck_index", 0))
	base_config["name"] = str(profile.get("career", base_config.get("name", "")))
	base_config["display_name"] = str(profile.get("career", base_config.get("display_name", base_config.get("name", ""))))
	base_config["weapon"] = str(profile.get("weapon", base_config.get("weapon", "")))
	base_config["max_hp"] = int(profile.get("max_hp", base_config.get("max_hp", 20)))
	base_config["hp"] = clampi(int(profile.get("hp", base_config.get("hp", base_config.get("max_hp", 20)))), 0, int(base_config.get("max_hp", 20)))
	base_config["max_momentum"] = int(profile.get("max_posture", profile.get("max_momentum", base_config.get("max_momentum", 6))))
	base_config["momentum"] = int(profile.get("posture", profile.get("momentum", base_config.get("momentum", 5))))
	base_config["realm"] = int(profile.get("martial_level", base_config.get("realm", 1)))
	base_config["qinggong"] = clampi(int(profile.get("qinggong", base_config.get("qinggong", 1))), 1, 4)
	base_config["position"] = int(base_config.get("position", 2))
	base_config["facing"] = str(base_config.get("facing", "right"))
	return base_config

