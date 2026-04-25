extends "res://scripts/battle_controller_visual_hot_tuning.gd"

const CombatResolver = preload("res://scripts/combat_resolver.gd")
const PREVIEW_GHOST_ALPHA := 0.80
const PREVIEW_GHOST_OVERLAP_ALPHA := 0.00
const PLAYER_START_POSITION := 2
const ENEMY_START_POSITION := 6
const PLAYER_START_FACING := "right"
const ENEMY_START_FACING := "left"

func _show_role_selection() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	if overlay_scrim != null:
		overlay_scrim.visible = true
	if overlay_panel != null:
		overlay_panel.visible = true
	if overlay_title != null:
		overlay_title.text = "选择兵器"
	if overlay_body != null:
		overlay_body.text = "选择本局操控角色。"
	_clear_role_buttons()
	_add_role_button("spearman", "枪手")
	_add_role_button("blademaster", "刀客")

func _clear_role_buttons() -> void:
	if overlay_actions == null:
		return
	for child in overlay_actions.get_children():
		child.queue_free()

func _add_role_button(role_id: String, title: String) -> void:
	if overlay_actions == null:
		return
	var selected_role_id: String = role_id
	var button := Button.new()
	button.text = title
	button.pressed.connect(func() -> void:
		_select_role_and_start(selected_role_id)
	)
	overlay_actions.add_child(button)

func _select_role_and_start(role_id: String) -> void:
	if not fighter_catalog.has(role_id):
		role_id = "spearman"
	player_role_id = role_id
	print("[role-select] selected=", player_role_id)
	if overlay_scrim != null:
		overlay_scrim.visible = false
	if overlay_panel != null:
		overlay_panel.visible = false
	_clear_actor_runtime(true)
	_clear_actor_runtime(false)
	_start_session(player_role_id)
	_enforce_selected_player_role()

func _enforce_selected_player_role() -> void:
	if player_role_id == "" or not fighter_catalog.has(player_role_id):
		return
	var enemy_role_id: String = "blademaster" if player_role_id == "spearman" else "spearman"
	var should_rebuild_player: bool = player == null or player.data == null or player.data.id != player_role_id or player.position != PLAYER_START_POSITION or player.facing != PLAYER_START_FACING
	if should_rebuild_player:
		print("[role-select] correcting player fighter to ", player_role_id, " on player side")
		var player_data: FighterData = _side_fighter_data(fighter_catalog[player_role_id], true)
		player = Fighter.new(player_data)
		player.set_session_realm(fighter_catalog[player_role_id].starting_realm)
		player.reset_for_battle(HAND_SIZE)
	if fighter_catalog.has(enemy_role_id):
		var should_rebuild_enemy: bool = enemy == null or enemy.data == null or enemy.data.id != enemy_role_id or enemy.position != ENEMY_START_POSITION or enemy.facing != ENEMY_START_FACING
		if should_rebuild_enemy:
			var enemy_data: FighterData = _side_fighter_data(fighter_catalog[enemy_role_id], false)
			enemy = Fighter.new(enemy_data)
			enemy.set_session_realm(ENEMY_SESSION_REALM)
			enemy.reset_for_battle(HAND_SIZE)
	state_machine.update_distance_from_positions(player, enemy)
	_clear_actor_runtime(true)
	_clear_actor_runtime(false)
	_ensure_actor_animation_runtimes()
	_refresh_ui()

func _side_fighter_data(source: FighterData, is_player_side: bool) -> FighterData:
	var side_position: int = PLAYER_START_POSITION if is_player_side else ENEMY_START_POSITION
	var side_facing: String = PLAYER_START_FACING if is_player_side else ENEMY_START_FACING
	return FighterData.new(
		source.id,
		source.display_name,
		source.weapon_name,
		source.max_hp,
		source.max_momentum,
		source.starting_momentum,
		source.starting_realm,
		source.preferred_distances,
		source.starting_deck,
		source.qinggong,
		side_position,
		side_facing
	)

func _refresh_preview_ghosts() -> void:
	_ensure_preview_ghosts()
	if player_preview_ghost == null or enemy_preview_ghost == null or player_preview_label == null or enemy_preview_label == null:
		return
	if player == null or enemy == null or not battle_active:
		_set_preview_ghosts_visible(false)
		return
	var preview: Dictionary = _compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		_set_preview_ghosts_visible(false)
		return
	var player_final: int = int(preview.get("player_final", player.position))
	var enemy_final: int = int(preview.get("enemy_final", enemy.position))
	player_preview_ghost.texture = player_sprite.texture if player_sprite != null else null
	enemy_preview_ghost.texture = enemy_sprite.texture if enemy_sprite != null else null
	player_preview_ghost.position = _slot_top_left(player_final, true)
	enemy_preview_ghost.position = _slot_top_left(enemy_final, false)
	player_preview_ghost.modulate = _preview_ghost_modulate(true, player_final == player.position)
	enemy_preview_ghost.modulate = _preview_ghost_modulate(false, enemy_final == enemy.position)
	player_preview_label.text = ""
	enemy_preview_label.text = ""
	player_preview_label.visible = false
	enemy_preview_label.visible = false
	_set_preview_ghosts_visible(true)

func _preview_ghost_modulate(is_player: bool, overlaps_real_actor: bool) -> Color:
	var alpha: float = PREVIEW_GHOST_OVERLAP_ALPHA if overlaps_real_actor else PREVIEW_GHOST_ALPHA
	if overlaps_real_actor:
		return Color(1.0, 1.0, 1.0, alpha)
	return Color(0.55, 0.78, 1.0, alpha) if is_player else Color(1.0, 0.64, 0.48, alpha)

func _compute_ordered_preview() -> Dictionary:
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var has_preview: bool = draft_player_has_position or p_card != null or e_card != null
	if not has_preview:
		return {"has_preview": false}
	var p_state: Dictionary = _resolver_preview_state(true, p_intent)
	var e_state: Dictionary = _resolver_preview_state(false, e_intent)
	var order: Array[String] = _preview_resolution_order(p_intent, e_intent)
	var sim: Dictionary = CombatResolver.resolve_exchange(p_state, e_state, p_card, e_card, order)
	return {
		"has_preview": true,
		"player_final": clampi(int(sim.get("player_final", p_state.get("position", 0))), 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(int(sim.get("enemy_final", e_state.get("position", 0))), 0, GRID_SLOT_COUNT - 1),
		"player_text": "",
		"enemy_text": "",
		"source": "CombatResolver"
	}

func _resolver_preview_state(is_player: bool, intent: IntentData) -> Dictionary:
	var fighter: Fighter = player if is_player else enemy
	if fighter == null:
		return {"hp": 0, "momentum": 0, "guard": 0, "position": 0, "facing": "right", "broken": false}
	var pos: int = fighter.position
	var facing: String = fighter.facing
	if is_player:
		pos = _player_preview_position()
		facing = _player_preview_facing()
	else:
		if intent != null and intent.target_position >= 0:
			pos = intent.target_position
		facing = _enemy_preview_facing()
	return {
		"hp": fighter.hp,
		"momentum": fighter.momentum,
		"guard": fighter.guard_points,
		"position": pos,
		"facing": facing,
		"broken": fighter.is_broken()
	}
