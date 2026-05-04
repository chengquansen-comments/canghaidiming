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
	if state_machine != null:
		var settlement_mode: String = str(loadout.get("settlement_mode", ""))
		if not settlement_mode.is_empty():
			state_machine.set_settlement_mode_id(settlement_mode)
			set("settlement_mode_id", settlement_mode)
		state_machine.update_distance_from_positions(player, enemy)
	_apply_battle_background(loadout)
	battle_loadout_applied = true
	narrative_numbers_applied = true
	_refresh_narrative_debug_labels()
	_set_battle_result_debug_text("BattleLoadout：已一次性应用敌我配置与背景。")
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

