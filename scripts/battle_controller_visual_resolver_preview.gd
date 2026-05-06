extends "res://scripts/battle_controller_visual_hot_tuning.gd"

const CombatResolver = preload("res://scripts/combat_resolver.gd")
const ResolverPreviewRuntime = preload("res://scripts/visual/resolver_preview_runtime.gd")
const ResolverPreviewFormatter = preload("res://scripts/visual/resolver_preview_formatter.gd")
const PREVIEW_GHOST_ALPHA := 0.80
const PREVIEW_GHOST_OVERLAP_ALPHA := 0.00
const PLAYER_START_POSITION := 2
const ENEMY_START_POSITION := 6
const PLAYER_START_FACING := "right"
const ENEMY_START_FACING := "left"
const PLAYER_ARROW_COLOR := Color(0.55, 0.78, 1.0, 0.88)
const ENEMY_ARROW_COLOR := Color(1.0, 0.64, 0.48, 0.88)

var player_preview_arrow: Line2D
var enemy_preview_arrow: Line2D
var _resolver_preview_runtime
var _resolver_preview_formatter

func _preview_runtime():
	if _resolver_preview_runtime == null:
		_resolver_preview_runtime = ResolverPreviewRuntime.new(self)
	return _resolver_preview_runtime

func _preview_formatter():
	if _resolver_preview_formatter == null:
		_resolver_preview_formatter = ResolverPreviewFormatter.new(self)
	return _resolver_preview_formatter

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
	var enemy_role_id: String = "blademaster" if player_role_id == "spearman" or player_role_id == "master_veteran" else "spearman"
	var should_rebuild_player: bool = player == null or player.data == null or player.data.id != player_role_id or player.position != PLAYER_START_POSITION or player.facing != PLAYER_START_FACING
	if should_rebuild_player:
		print("[role-select] correcting player fighter to ", player_role_id, " on player side")
		var player_data: FighterData = _side_fighter_data(fighter_catalog[player_role_id], true)
		player = Fighter.new(player_data)
		player.set_session_realm(fighter_catalog[player_role_id].starting_realm)
		_prepare_player_battle_deck()
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
	return FighterData.new(source.id, source.display_name, source.weapon_name, source.max_hp, source.max_momentum, source.starting_momentum, source.starting_realm, source.preferred_distances, source.starting_deck, source.qinggong, side_position, side_facing)

func _refresh_preview_ghosts() -> void:
	_ensure_preview_ghosts()
	_ensure_preview_arrows()
	if player_preview_ghost == null or enemy_preview_ghost == null or player_preview_label == null or enemy_preview_label == null:
		return
	if player == null or enemy == null or not battle_active:
		_set_preview_ghosts_visible(false)
		_set_preview_arrows_visible(false)
		return
	var preview: Dictionary = _compute_ordered_preview()
	if not bool(preview.get("has_preview", false)):
		_set_preview_ghosts_visible(false)
		_set_preview_arrows_visible(false)
		return
	var player_subjective: int = int(preview.get("player_subjective", player.position))
	var enemy_subjective: int = int(preview.get("enemy_subjective", enemy.position))
	var player_final: int = int(preview.get("player_final", player_subjective))
	var enemy_final: int = int(preview.get("enemy_final", enemy_subjective))
	player_preview_ghost.texture = player_sprite.texture if player_sprite != null else null
	enemy_preview_ghost.texture = enemy_sprite.texture if enemy_sprite != null else null
	player_preview_ghost.position = _slot_top_left(player_subjective, true)
	enemy_preview_ghost.position = _slot_top_left(enemy_subjective, false)
	player_preview_ghost.modulate = _preview_ghost_modulate(true, player_subjective == player.position)
	enemy_preview_ghost.modulate = _preview_ghost_modulate(false, enemy_subjective == enemy.position)
	player_preview_label.text = ""
	enemy_preview_label.text = ""
	player_preview_label.visible = false
	enemy_preview_label.visible = false
	_set_preview_ghosts_visible(true)
	if _should_hide_player_preview_ghost():
		player_preview_ghost.visible = false
	_update_preview_arrow(player_preview_arrow, true, player_subjective, player_final)
	_update_preview_arrow(enemy_preview_arrow, false, enemy_subjective, enemy_final)

func _ensure_preview_arrows() -> void:
	if player_preview_arrow == null:
		player_preview_arrow = _make_preview_arrow(PLAYER_ARROW_COLOR)
		stage_layer.add_child(player_preview_arrow)
	if enemy_preview_arrow == null:
		enemy_preview_arrow = _make_preview_arrow(ENEMY_ARROW_COLOR)
		stage_layer.add_child(enemy_preview_arrow)

func _make_preview_arrow(color: Color) -> Line2D:
	var line := Line2D.new()
	line.visible = false
	line.z_index = 18
	line.width = 5.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line

func _set_preview_arrows_visible(value: bool) -> void:
	if player_preview_arrow != null:
		player_preview_arrow.visible = value
	if enemy_preview_arrow != null:
		enemy_preview_arrow.visible = value

func _update_preview_arrow(line: Line2D, is_player_side: bool, from_slot: int, to_slot: int) -> void:
	if line == null:
		return
	if from_slot == to_slot:
		line.visible = false
		return
	var start: Vector2 = _preview_arrow_point(from_slot)
	var end: Vector2 = _preview_arrow_point(to_slot)
	var delta: Vector2 = end - start
	if delta.length() < 1.0:
		line.visible = false
		return
	var dir: Vector2 = delta.normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var head_len := 18.0
	var head_w := 10.0
	line.clear_points()
	line.add_point(start)
	line.add_point(end)
	line.add_point(end - dir * head_len + normal * head_w)
	line.add_point(end)
	line.add_point(end - dir * head_len - normal * head_w)
	line.visible = true

func _preview_arrow_point(slot: int) -> Vector2:
	return Vector2(_slot_center_x(clampi(slot, 0, GRID_SLOT_COUNT - 1)), GRID_STAGE_Y + GRID_SLOT_HEIGHT * 0.5)

func _preview_ghost_modulate(is_player: bool, overlaps_real_actor: bool) -> Color:
	var alpha: float = PREVIEW_GHOST_OVERLAP_ALPHA if overlaps_real_actor else PREVIEW_GHOST_ALPHA
	if overlaps_real_actor:
		return Color(1.0, 1.0, 1.0, alpha)
	return Color(0.55, 0.78, 1.0, alpha) if is_player else Color(1.0, 0.64, 0.48, alpha)

func _should_hide_player_preview_ghost() -> bool:
	return false

func _compute_ordered_preview() -> Dictionary:
	return _preview_runtime().compute_ordered_preview()

func _ordered_preview_simulation(p_intent: IntentData, e_intent: IntentData) -> Dictionary:
	return _preview_runtime().ordered_preview_simulation(p_intent, e_intent)

func _effect_step(side: String, card: CardData, result: Dictionary) -> Dictionary:
	return _preview_runtime().effect_step(side, card, result)

func _intent_target_position(is_player_side: bool, intent: IntentData) -> int:
	return _preview_runtime().intent_target_position(is_player_side, intent)

func _intent_target_facing(is_player_side: bool, intent: IntentData) -> String:
	return _preview_runtime().intent_target_facing(is_player_side, intent)

func _intent_move_delta(is_player_side: bool, intent: IntentData) -> int:
	return _preview_runtime().intent_move_delta(is_player_side, intent)

func _resolve_one_preview_step(is_player_side: bool, card: CardData, actor_pos: int, target_pos: int, actor_facing: String, target_facing: String, actor_override: Dictionary = {}, target_override: Dictionary = {}, combo_state: Dictionary = {}) -> Dictionary:
	return _preview_runtime().resolve_one_preview_step(is_player_side, card, actor_pos, target_pos, actor_facing, target_facing, actor_override, target_override, combo_state)

func _preview_back_hit(defender_pos: int, defender_facing: String, attacker_pos: int) -> bool:
	return _preview_runtime().preview_back_hit(defender_pos, defender_facing, attacker_pos)

func _preview_facing_toward(actor_pos: int, target_pos: int) -> String:
	return _preview_runtime().preview_facing_toward(actor_pos, target_pos)

func _resolver_preview_state(is_player: bool, intent: IntentData) -> Dictionary:
	return _preview_runtime().resolver_preview_state(is_player, intent)

func _effect_preview_text() -> String:
	return _preview_formatter().effect_preview_text()

func _order_text(order_value) -> String:
	return _preview_formatter().order_text(order_value)

func _step_text(step: Dictionary) -> String:
	return _preview_formatter().step_text(step)

func _range_text(range_result: String) -> String:
	return _preview_formatter().range_text(range_result)
