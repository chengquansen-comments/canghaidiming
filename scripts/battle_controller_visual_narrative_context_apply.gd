extends "res://scripts/battle_controller_visual_narrative_context_debug_text.gd"

# Narrative context apply layer.

func _apply_battle_background(loadout: Dictionary) -> void:
	var scene_config: Dictionary = _dict(loadout.get("scene_config", {}))
	var bg_path: String = str(scene_config.get("background", ""))
	if background_texture == null:
		return
	background_texture.texture = null
	background_texture.visible = true
	background_texture.scale = Vector2.ONE
	background_texture.position = Vector2.ZERO
	background_texture.modulate = Color.WHITE
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		var tex: Texture2D = _safe_load_texture(bg_path)
		if tex != null:
			background_texture.texture = tex

func _refresh_narrative_debug_labels() -> void:
	if enemy_config_strip != null:
		enemy_config_strip.text = _enemy_full_config_text()
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()
	if battle_mapping_label != null:
		battle_mapping_label.text = _mapping_debug_text()
	if enemy_config_label != null:
		enemy_config_label.text = _enemy_config_debug_text()

func _apply_fighter_config(fighter, config: Dictionary) -> void:
	if fighter == null or config.is_empty():
		return
	fighter.data.id = str(config.get("id", fighter.data.id))
	fighter.data.display_name = str(config.get("display_name", config.get("name", fighter.data.display_name)))
	fighter.data.weapon_name = str(config.get("weapon", fighter.data.weapon_name))
	fighter.data.max_hp = int(config.get("max_hp", fighter.data.max_hp))
	fighter.data.max_momentum = int(config.get("max_posture", config.get("max_momentum", fighter.data.max_momentum)))
	fighter.data.starting_momentum = clampi(int(config.get("start_posture", config.get("momentum", fighter.data.starting_momentum))), 0, fighter.data.max_momentum)
	fighter.data.starting_realm = int(config.get("realm", fighter.data.starting_realm))
	fighter.data.qinggong = maxi(1, int(config.get("qinggong", fighter.data.qinggong)))
	fighter.data.starting_position = clampi(int(config.get("starting_position", config.get("position", fighter.data.starting_position))), 0, 8)
	fighter.data.starting_facing = "left" if str(config.get("starting_facing", config.get("facing", fighter.data.starting_facing))) == "left" else "right"
	fighter.data.preferred_distances = _packed_ints(config.get("preferred", []))
	fighter.data.starting_deck = _cards_from_configs(config.get("deck", []))
	if fighter == player:
		fighter.set_battle_deck_limit(PLAYER_BATTLE_DECK_SIZE)
		var deck_slots: Array = config.get("deck_slots", [])
		if not deck_slots.is_empty():
			fighter.set_battle_deck_slots(deck_slots, int(config.get("active_deck_index", 0)))
			_sanitize_player_battle_deck_selection()
		var selected_cards := _cards_from_card_ids(config.get("selected_loadout_ids", []))
		if deck_slots.is_empty() and selected_cards.is_empty():
			selected_cards = _cards_from_configs(config.get("selected_loadout", []))
		if deck_slots.is_empty() and selected_cards.is_empty():
			fighter.reset_battle_deck_to_default()
		elif deck_slots.is_empty():
			fighter.set_selected_battle_deck(selected_cards)
			_sanitize_player_battle_deck_selection()
			if fighter.get_battle_deck_size() < PLAYER_BATTLE_DECK_SIZE:
				_auto_fill_player_battle_deck()
	else:
		fighter.set_battle_deck_limit(0)
		fighter.reset_battle_deck_to_default()
	fighter.hp = clampi(int(config.get("hp", fighter.data.max_hp)), 0, fighter.data.max_hp)
	fighter.momentum = fighter.data.starting_momentum
	fighter.session_realm = fighter.data.starting_realm
	fighter.realm = fighter.session_realm
	fighter.qinggong = maxi(1, fighter.data.qinggong)
	fighter.position = fighter.data.starting_position
	fighter.facing = fighter.data.starting_facing
	fighter.draw_pile = fighter.get_battle_deck()
	fighter.discard_pile.clear()
	fighter.hand.clear()
	while fighter.hand.size() < HAND_SIZE and not fighter.draw_pile.is_empty():
		fighter.hand.append(fighter.draw_pile.pop_front())

func _safe_refresh_runtime_ui() -> void:
	var refresh_methods: Array[String] = ["_refresh_ui", "_update_ui", "_render_battle", "_render_state", "_refresh_all", "_render"]
	for method_name: String in refresh_methods:
		if _method_accepts_arg_count(method_name, 0):
			callv(method_name, [])
			return

func _apply_runtime_primitives(loadout: Dictionary) -> void:
	last_runtime_primitives = (loadout.get("runtime_primitives", []) as Array).duplicate()
	last_opening_pressure_source = ""
	last_opening_pressure_enemy_momentum_bonus = 0
	last_opening_pressure_enemy_block_bonus = 0
	last_opening_pressure_applied = false
	last_opening_pressure_applied_fields.clear()
	last_weapon_followup_enabled = false
	last_weapon_followup_expected_chain_count = 0
	last_weapon_followup_primary_weapon_style = ""
	last_weapon_followup_pressure_level = ""
	last_weapon_followup_triggered = false
	last_weapon_followup_trigger_count = 0
	last_weapon_followup_bonus_applied = {}
	last_weapon_followup_applied_fields.clear()
	last_weapon_followup_card_id = ""
	last_weapon_followup_group = ""
	last_weapon_followup_trigger = ""
	last_weapon_followup_error = ""
	_runtime_generated_card_meta = {}
	if enemy == null:
		return
	if not last_runtime_primitives.has("opening_pressure"):
		return
	var opening_pressure: Dictionary = _dict(loadout.get("opening_pressure", {}))
	if opening_pressure.is_empty():
		return
	last_opening_pressure_source = str(opening_pressure.get("source", "runtime_manifest"))
	last_opening_pressure_enemy_momentum_bonus = int(opening_pressure.get("enemy_start_momentum_bonus", 0))
	last_opening_pressure_enemy_block_bonus = int(opening_pressure.get("enemy_start_block_bonus", 0))
	if last_opening_pressure_enemy_momentum_bonus > 0:
		var next_momentum := clampi(enemy.data.starting_momentum + last_opening_pressure_enemy_momentum_bonus, 0, enemy.data.max_momentum)
		enemy.data.starting_momentum = next_momentum
		enemy.momentum = next_momentum
		last_opening_pressure_applied_fields.append("enemy_start_momentum_bonus")
	if last_opening_pressure_enemy_block_bonus > 0:
		enemy.add_guard(last_opening_pressure_enemy_block_bonus)
		last_opening_pressure_applied_fields.append("enemy_start_block_bonus")
	last_opening_pressure_applied = not last_opening_pressure_applied_fields.is_empty()
	if last_runtime_primitives.has("weapon_followup"):
		var weapon_followup: Dictionary = _dict(loadout.get("weapon_followup", {}))
		last_weapon_followup_enabled = bool(weapon_followup.get("enabled", false))
		last_weapon_followup_expected_chain_count = int(weapon_followup.get("expected_chain_count", 0))
		last_weapon_followup_primary_weapon_style = str(weapon_followup.get("primary_weapon_style", ""))
		last_weapon_followup_pressure_level = str(weapon_followup.get("pressure_level", ""))
		for card_variant in loadout.get("cards", []):
			if not (card_variant is Dictionary):
				continue
			var card: Dictionary = card_variant
			var card_id := str(card.get("card_id", card.get("id", "")))
			if card_id.is_empty():
				continue
			_runtime_generated_card_meta[card_id] = {
				"followup_group": str(card.get("followup_group", "")),
				"followup_trigger": str(card.get("followup_trigger", "")),
				"followup_bonus": _dict(card.get("followup_bonus", {})),
				"followup_chain_role": str(card.get("followup_chain_role", "standalone")),
				"weapon_style": str(card.get("weapon_style", "")),
				"tags": (card.get("tags", []) as Array).duplicate(),
			}

func _apply_battle_loadout_once(loadout: Dictionary) -> void:
	if battle_loadout_applied:
		return
	if player == null or enemy == null:
		return
	var player_config: Dictionary = _dict(loadout.get("player_config", {}))
	var enemy_config: Dictionary = _dict(loadout.get("enemy_config", {}))
	if player_config.is_empty() or enemy_config.is_empty():
		battle_loadout_error = "BattleLoadout 缺少 player_config 或 enemy_config"
		return
	_apply_fighter_config(player, player_config)
	_apply_fighter_config(enemy, enemy_config)
	_clear_actor_runtime(true)
	_clear_actor_runtime(false)
	_apply_runtime_primitives(loadout)
	var active_profile_summary: Dictionary = AigcBattleRuntimeManifestLoader.get_active_profile_summary()
	var current_release: Dictionary = AigcBattleRuntimeManifestLoader.get_release_channel("current")
	var fallback_release: Dictionary = AigcBattleRuntimeManifestLoader.get_release_channel("fallback")
	last_release_profile_id = str(active_profile_summary.get("active_mechanic_profile_id", ""))
	last_release_content_pack_id = str(active_profile_summary.get("active_content_pack_id", ""))
	last_release_runtime_manifest_path = str(active_profile_summary.get("runtime_manifest_path", ""))
	last_release_channel = "active_profile"
	if last_release_profile_id == str(current_release.get("mechanic_profile_id", "")) and last_release_content_pack_id == str(current_release.get("content_pack_id", "")):
		last_release_channel = "current"
	elif last_release_profile_id == str(fallback_release.get("mechanic_profile_id", "")) and last_release_content_pack_id == str(fallback_release.get("content_pack_id", "")):
		last_release_channel = "fallback"
	last_formal_entry_uses_release_pack = str(loadout.get("loadout_source", "")) == "generated_manifest" and last_release_channel == "current"
	last_formal_entry_fallback_used = str(loadout.get("loadout_source", "")) != "generated_manifest"
	last_formal_entry_generated_loadout_count = 1 if str(loadout.get("loadout_source", "")) == "generated_manifest" else 0
	last_formal_entry_fallback_loadout_count = 0 if str(loadout.get("loadout_source", "")) == "generated_manifest" else 1
	_runtime_player_hp_start = player.hp
	_runtime_enemy_hp_start = enemy.hp
	if state_machine != null:
		var settlement_mode: String = str(loadout.get("settlement_mode", ""))
		if not settlement_mode.is_empty():
			state_machine.set_settlement_mode_id(settlement_mode)
			set("settlement_mode_id", settlement_mode)
		state_machine.update_distance_from_positions(player, enemy)
	_apply_battle_background(loadout)
	battle_loadout_applied = true
	narrative_numbers_applied = true
	last_reward_source = str(loadout.get("reward_source", "fallback"))
	last_reward_plan_id = str(loadout.get("reward_plan_id", ""))
	last_generated_reward_visible = false
	last_generated_reward_claimed = false
	last_formal_progression_continues = false
	_refresh_narrative_debug_labels()
	_set_battle_result_debug_text("BattleLoadout：来源=%s｜slot=%s｜deck=%s｜pack=%s" % [str(loadout.get("loadout_source", "")), str(loadout.get("generated_battle_slot_id", "")), str(loadout.get("generated_deck_id", "")), str(loadout.get("content_pack_id", ""))])
	_safe_refresh_runtime_ui()

func _load_narrative_battle_once() -> void:
	if battle_loadout_applied:
		return
	if not NarrativeBattleContext.has_request():
		return
	if player == null or enemy == null:
		return
	if battle_loadout.is_empty():
		battle_loadout = _resolve_battle_loadout()
	if battle_loadout.is_empty():
		return
	_apply_battle_loadout_once(battle_loadout)

func _apply_narrative_numbers_once() -> void:
	_load_narrative_battle_once()
