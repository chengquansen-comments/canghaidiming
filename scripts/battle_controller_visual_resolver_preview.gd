extends "res://scripts/battle_controller_visual_hot_tuning.gd"

const CombatResolver = preload("res://scripts/combat_resolver.gd")
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
	if player == null or enemy == null:
		return {"has_preview": false}
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var has_preview: bool = draft_player_has_position or p_intent != null or e_intent != null
	if not has_preview:
		return {"has_preview": false}
	var sim: Dictionary = _ordered_preview_simulation(p_intent, e_intent)
	return {
		"has_preview": true,
		"player_subjective": int(sim.get("player_subjective", player.position)),
		"enemy_subjective": int(sim.get("enemy_subjective", enemy.position)),
		"player_final": clampi(int(sim.get("player_final", sim.get("player_subjective", player.position))), 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(int(sim.get("enemy_final", sim.get("enemy_subjective", enemy.position))), 0, GRID_SLOT_COUNT - 1),
		"player_text": "",
		"enemy_text": "",
		"sim": sim,
		"source": "CombatResolver-sequenced"
	}

func _ordered_preview_simulation(p_intent: IntentData, e_intent: IntentData) -> Dictionary:
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var p_subjective: int = _intent_target_position(true, p_intent)
	var e_subjective: int = _intent_target_position(false, e_intent)
	var p_final: int = player.position
	var e_final: int = enemy.position
	var p_facing: String = player.facing
	var e_facing: String = enemy.facing
	var p_hp_delta := 0
	var e_hp_delta := 0
	var p_momentum_delta := 0
	var e_momentum_delta := 0
	var p_range_result := CombatResolver.RANGE_NONE
	var e_range_result := CombatResolver.RANGE_NONE
	var order: Array[String] = _preview_resolution_order(p_intent, e_intent)
	var steps: Array[Dictionary] = []
	var player_move_applied := false
	var enemy_move_applied := false
	var preview_ended := false
	for side: String in order:
		if preview_ended:
			break
		if side == "player":
			var before_move: int = p_final
			p_final = _intent_target_position(true, p_intent)
			p_facing = _intent_target_facing(true, p_intent)
			p_subjective = p_final
			player_move_applied = true
			steps.append({"side": "player", "phase": "move", "from": before_move, "to": p_final, "facing": p_facing})
			if p_card != null:
				var result_p: Dictionary = _resolve_one_preview_step(true, p_card, p_final, e_final, p_facing, e_facing)
				p_range_result = str(result_p.get("range", CombatResolver.RANGE_NONE))
				e_hp_delta += int(result_p.get("target_hp_delta", 0))
				e_momentum_delta += int(result_p.get("target_momentum_delta", 0))
				p_momentum_delta += int(result_p.get("actor_momentum_delta", 0))
				steps.append(_effect_step("player", p_card, result_p))
				var before_effect_move_p: int = p_final
				var before_effect_move_e: int = e_final
				p_final = int(result_p.get("actor_final", p_final))
				e_final = int(result_p.get("target_final", e_final))
				steps.append({"side": "player", "phase": "effect_move", "actor_from": before_effect_move_p, "actor_to": p_final, "target_from": before_effect_move_e, "target_to": e_final, "range": p_range_result})
				preview_ended = bool(result_p.get("will_die", false))
		else:
			if state_machine != null and state_machine.is_reactive_mode() and enemy.momentum > 0 and enemy.momentum + e_momentum_delta <= 0:
				enemy_move_applied = true
				steps.append({"side": "enemy", "phase": "interrupted", "reason": "reactive_break"})
				continue
			var before_enemy_move: int = e_final
			e_final = _intent_target_position(false, e_intent)
			e_facing = _intent_target_facing(false, e_intent)
			e_subjective = e_final
			enemy_move_applied = true
			steps.append({"side": "enemy", "phase": "move", "from": before_enemy_move, "to": e_final, "facing": e_facing})
			if e_card != null:
				var result_e: Dictionary = _resolve_one_preview_step(false, e_card, e_final, p_final, e_facing, p_facing)
				e_range_result = str(result_e.get("range", CombatResolver.RANGE_NONE))
				p_hp_delta += int(result_e.get("target_hp_delta", 0))
				p_momentum_delta += int(result_e.get("target_momentum_delta", 0))
				e_momentum_delta += int(result_e.get("actor_momentum_delta", 0))
				steps.append(_effect_step("enemy", e_card, result_e))
				var before_effect_move_e2: int = e_final
				var before_effect_move_p2: int = p_final
				e_final = int(result_e.get("actor_final", e_final))
				p_final = int(result_e.get("target_final", p_final))
				steps.append({"side": "enemy", "phase": "effect_move", "actor_from": before_effect_move_e2, "actor_to": e_final, "target_from": before_effect_move_p2, "target_to": p_final, "range": e_range_result})
				preview_ended = bool(result_e.get("will_die", false))
	if not player_move_applied and draft_player_has_position:
		var before_player_fallback: int = p_final
		p_final = _intent_target_position(true, p_intent)
		p_facing = _intent_target_facing(true, p_intent)
		p_subjective = p_final
		steps.append({"side": "player", "phase": "move", "from": before_player_fallback, "to": p_subjective, "facing": p_facing})
	if not enemy_move_applied and e_intent != null and e_intent.target_position >= 0 and not (state_machine != null and state_machine.is_reactive_mode() and enemy.momentum > 0 and enemy.momentum + e_momentum_delta <= 0):
		var before_enemy_fallback: int = e_final
		e_final = _intent_target_position(false, e_intent)
		e_facing = _intent_target_facing(false, e_intent)
		e_subjective = e_final
		steps.append({"side": "enemy", "phase": "move", "from": before_enemy_fallback, "to": e_subjective, "facing": e_facing})
	if p_card == null:
		p_final = p_subjective
	if e_card == null:
		e_final = e_subjective
	return {
		"player_subjective": p_subjective,
		"enemy_subjective": e_subjective,
		"player_final": clampi(p_final, 0, GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(e_final, 0, GRID_SLOT_COUNT - 1),
		"player_hp_delta": p_hp_delta,
		"enemy_hp_delta": e_hp_delta,
		"player_momentum_delta": p_momentum_delta,
		"enemy_momentum_delta": e_momentum_delta,
		"player_range_result": p_range_result,
		"enemy_range_result": e_range_result,
		"order": order,
		"steps": steps
	}

func _effect_step(side: String, card: CardData, result: Dictionary) -> Dictionary:
	return {
		"side": side,
		"phase": "effect",
		"card": card.display_name,
		"range": str(result.get("range", CombatResolver.RANGE_NONE)),
		"damage": int(result.get("damage", 0)),
		"break": int(result.get("break", 0)),
		"gain": int(result.get("gain", 0)),
		"will_break": bool(result.get("will_break", false)),
		"will_die": bool(result.get("will_die", false)),
		"was_back_hit": bool(result.get("was_back_hit", false)),
		"back_hit_turn_to": str(result.get("back_hit_turn_to", ""))
	}

func _intent_target_position(is_player_side: bool, intent: IntentData) -> int:
	if is_player_side:
		return clampi(_player_preview_position(), 0, GRID_SLOT_COUNT - 1)
	if intent != null and intent.target_position >= 0:
		return clampi(intent.target_position, 0, GRID_SLOT_COUNT - 1)
	return clampi(enemy.position, 0, GRID_SLOT_COUNT - 1)

func _intent_target_facing(is_player_side: bool, intent: IntentData) -> String:
	if is_player_side:
		return _player_preview_facing()
	if intent != null and (intent.target_facing == "left" or intent.target_facing == "right"):
		return intent.target_facing
	return _enemy_preview_facing()

func _intent_move_delta(is_player_side: bool, intent: IntentData) -> int:
	if is_player_side:
		return _intent_target_position(true, intent) - player.position
	return _intent_target_position(false, intent) - enemy.position

func _resolve_one_preview_step(is_player_side: bool, card: CardData, actor_pos: int, target_pos: int, actor_facing: String, target_facing: String) -> Dictionary:
	var actor: Fighter = player if is_player_side else enemy
	var target: Fighter = enemy if is_player_side else player
	var actor_state: Dictionary = {
		"hp": actor.hp,
		"momentum": actor.momentum,
		"guard": actor.guard_points,
		"position": actor_pos,
		"facing": actor_facing,
		"broken": actor.is_broken()
	}
	var target_state: Dictionary = {
		"hp": target.hp,
		"momentum": target.momentum,
		"guard": target.guard_points,
		"position": target_pos,
		"facing": target_facing,
		"broken": target.is_broken()
	}
	var order: Array[String] = []
	order.append("player")
	var sim: Dictionary = CombatResolver.resolve_exchange(actor_state, target_state, card, null, order)
	var range_result := str(sim.get("player_range_result", CombatResolver.RANGE_NONE))
	var target_hp_delta: int = int(sim.get("enemy_hp_delta", 0))
	var target_momentum_delta: int = int(sim.get("enemy_momentum_delta", 0))
	var actor_momentum_delta: int = int(sim.get("player_momentum_delta", 0))
	var damage_value: int = absi(target_hp_delta) if target_hp_delta < 0 else 0
	var break_value: int = absi(target_momentum_delta) if target_momentum_delta < 0 else 0
	var will_die := target.hp > 0 and target.hp + target_hp_delta <= 0
	var will_break := target.momentum > 0 and target.momentum + target_momentum_delta <= 0
	var was_back_hit := false
	var back_hit_turn_to := ""
	if not is_player_side and (range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)) and (damage_value > 0 or break_value > 0):
		was_back_hit = _preview_back_hit(target_pos, target_facing, actor_pos)
		back_hit_turn_to = _preview_facing_toward(target_pos, actor_pos) if was_back_hit else ""
	return {
		"range": range_result,
		"damage": damage_value,
		"break": break_value,
		"gain": actor_momentum_delta if actor_momentum_delta > 0 else 0,
		"actor_hp_delta": int(sim.get("player_hp_delta", 0)),
		"target_hp_delta": target_hp_delta,
		"actor_momentum_delta": actor_momentum_delta,
		"target_momentum_delta": target_momentum_delta,
		"actor_final": int(sim.get("player_final", actor_pos)),
		"target_final": int(sim.get("enemy_final", target_pos)),
		"will_die": will_die,
		"will_break": will_break,
		"was_back_hit": was_back_hit,
		"back_hit_turn_to": back_hit_turn_to
	}

func _preview_back_hit(defender_pos: int, defender_facing: String, attacker_pos: int) -> bool:
	if attacker_pos > defender_pos:
		return defender_facing == "left"
	if attacker_pos < defender_pos:
		return defender_facing == "right"
	return false

func _preview_facing_toward(actor_pos: int, target_pos: int) -> String:
	if target_pos > actor_pos:
		return "right"
	if target_pos < actor_pos:
		return "left"
	return ""

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
		facing = _intent_target_facing(false, intent)
	return {"hp": fighter.hp, "momentum": fighter.momentum, "guard": fighter.guard_points, "position": pos, "facing": facing, "broken": fighter.is_broken()}

func _effect_preview_text() -> String:
	if player == null or enemy == null or state_machine == null:
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var sim: Dictionary = _ordered_preview_simulation(p_intent, e_intent)
	var lines: Array[String] = []
	lines.append("[font_size=18][b]效果预览[/b][/font_size]")
	lines.append("行动顺序：%s" % _order_text(sim.get("order", [])))
	lines.append("我方招式：%s" % (p_card.display_name if p_card != null else "待命"))
	lines.append("敌方招式：%s" % (e_card.display_name if e_card != null else "待命"))
	lines.append("")
	lines.append("[b]顺序结算预览[/b]")
	for step: Dictionary in sim.get("steps", []):
		lines.append(_step_text(step))
	lines.append("")
	lines.append("[b]最终汇总[/b]")
	lines.append("我方：伤%d / 势-%d / 主观 %s / 最终 %s" % [absi(int(sim.get("player_hp_delta", 0))) if int(sim.get("player_hp_delta", 0)) < 0 else 0, absi(int(sim.get("player_momentum_delta", 0))) if int(sim.get("player_momentum_delta", 0)) < 0 else 0, _slot_label(int(sim.get("player_subjective", player.position))), _slot_label(int(sim.get("player_final", player.position)))])
	lines.append("敌方：伤%d / 势-%d / 主观 %s / 最终 %s" % [absi(int(sim.get("enemy_hp_delta", 0))) if int(sim.get("enemy_hp_delta", 0)) < 0 else 0, absi(int(sim.get("enemy_momentum_delta", 0))) if int(sim.get("enemy_momentum_delta", 0)) < 0 else 0, _slot_label(int(sim.get("enemy_subjective", enemy.position))), _slot_label(int(sim.get("enemy_final", enemy.position)))])
	return "\n".join(lines)

func _order_text(order_value) -> String:
	var order: Array = order_value
	var parts: Array[String] = []
	for side in order:
		parts.append("我方" if str(side) == "player" else "敌方")
	return " → ".join(parts)

func _step_text(step: Dictionary) -> String:
	var side_text := "我方" if str(step.get("side", "player")) == "player" else "敌方"
	var phase := str(step.get("phase", ""))
	if phase == "move":
		var facing_text := "朝右" if str(step.get("facing", "")) == "right" else "朝左" if str(step.get("facing", "")) == "left" else ""
		return "%s目标：%s → %s %s" % [side_text, _slot_label(int(step.get("from", 0))), _slot_label(int(step.get("to", 0))), facing_text]
	if phase == "effect":
		var range_result := str(step.get("range", CombatResolver.RANGE_NONE))
		if range_result == CombatResolver.RANGE_MISS_FACING or range_result == CombatResolver.RANGE_MISS_RANGE:
			return "%s招式：%s / 未命中，无伤害无削势" % [side_text, str(step.get("card", "待命"))]
		var extra := ""
		if bool(step.get("will_break", false)):
			extra += " / 破势"
		if bool(step.get("was_back_hit", false)):
			extra += " / 背击"
		return "%s招式：%s / %s / 伤%d / 势-%d%s" % [side_text, str(step.get("card", "待命")), _range_text(range_result), int(step.get("damage", 0)), int(step.get("break", 0)), extra]
	if phase == "effect_move":
		var actor_from := int(step.get("actor_from", 0))
		var actor_to := int(step.get("actor_to", actor_from))
		var target_from := int(step.get("target_from", 0))
		var target_to := int(step.get("target_to", target_from))
		if actor_from == actor_to and target_from == target_to:
			return "%s招式位移：无" % side_text
		return "%s招式位移：自身 %s → %s；目标 %s → %s" % [side_text, _slot_label(actor_from), _slot_label(actor_to), _slot_label(target_from), _slot_label(target_to)]
	return "%s：无" % side_text

func _range_text(range_result: String) -> String:
	match range_result:
		CombatResolver.RANGE_HIT:
			return "命中"
		CombatResolver.RANGE_GRAZE:
			return "擦中" if CombatResolver.ENABLE_GRAZE else "距离未中"
		CombatResolver.RANGE_MISS_FACING:
			return "朝向未中"
		CombatResolver.RANGE_MISS_RANGE:
			return "距离未中"
		_:
			return "生效"
