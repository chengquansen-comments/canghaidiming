extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func compute_ordered_preview() -> Dictionary:
	if c.player == null or c.enemy == null:
		return {"has_preview": false}
	var p_intent: IntentData = c.draft_player_intent if c.draft_player_intent != null else c.player_intent
	var e_intent: IntentData = c.enemy_intent
	var has_preview: bool = c.draft_player_has_position or p_intent != null or e_intent != null
	if not has_preview:
		return {"has_preview": false}
	var sim: Dictionary = ordered_preview_simulation(p_intent, e_intent)
	return {
		"has_preview": true,
		"player_subjective": int(sim.get("player_subjective", c.player.position)),
		"enemy_subjective": int(sim.get("enemy_subjective", c.enemy.position)),
		"player_final": clampi(int(sim.get("player_final", sim.get("player_subjective", c.player.position))), 0, c.GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(int(sim.get("enemy_final", sim.get("enemy_subjective", c.enemy.position))), 0, c.GRID_SLOT_COUNT - 1),
		"player_text": "",
		"enemy_text": "",
		"sim": sim,
		"source": "CombatResolver-sequenced"
	}

func ordered_preview_simulation(p_intent: IntentData, e_intent: IntentData) -> Dictionary:
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var p_subjective: int = intent_target_position(true, p_intent)
	var e_subjective: int = intent_target_position(false, e_intent)
	var p_final: int = c.player.position
	var e_final: int = c.enemy.position
	var p_facing: String = c.player.facing
	var e_facing: String = c.enemy.facing
	var p_hp_delta := 0
	var e_hp_delta := 0
	var p_momentum_delta := 0
	var e_momentum_delta := 0
	var p_range_result := CombatResolver.RANGE_NONE
	var e_range_result := CombatResolver.RANGE_NONE
	var order: Array[String] = c._preview_resolution_order(p_intent, e_intent)
	var steps: Array[Dictionary] = []
	var player_move_applied := false
	var enemy_move_applied := false
	var preview_ended := false
	for side: String in order:
		if preview_ended:
			break
		if side == "player":
			var before_move: int = p_final
			p_final = intent_target_position(true, p_intent)
			p_facing = intent_target_facing(true, p_intent)
			p_subjective = p_final
			player_move_applied = true
			steps.append({"side": "player", "phase": "move", "from": before_move, "to": p_final, "facing": p_facing})
			if p_card != null:
				var result_p: Dictionary = resolve_one_preview_step(true, p_card, p_final, e_final, p_facing, e_facing)
				p_range_result = str(result_p.get("range", CombatResolver.RANGE_NONE))
				e_hp_delta += int(result_p.get("target_hp_delta", 0))
				e_momentum_delta += int(result_p.get("target_momentum_delta", 0))
				p_momentum_delta += int(result_p.get("actor_momentum_delta", 0))
				steps.append(effect_step("player", p_card, result_p))
				var before_effect_move_p: int = p_final
				var before_effect_move_e: int = e_final
				p_final = int(result_p.get("actor_final", p_final))
				e_final = int(result_p.get("target_final", e_final))
				steps.append({"side": "player", "phase": "effect_move", "actor_from": before_effect_move_p, "actor_to": p_final, "target_from": before_effect_move_e, "target_to": e_final, "range": p_range_result})
				preview_ended = bool(result_p.get("will_die", false))
		else:
			if c.state_machine != null and c.state_machine.is_reactive_mode() and c.enemy.momentum > 0 and c.enemy.momentum + e_momentum_delta <= 0:
				enemy_move_applied = true
				steps.append({"side": "enemy", "phase": "interrupted", "reason": "reactive_break"})
				continue
			var before_enemy_move: int = e_final
			e_final = intent_target_position(false, e_intent)
			e_facing = intent_target_facing(false, e_intent)
			e_subjective = e_final
			enemy_move_applied = true
			steps.append({"side": "enemy", "phase": "move", "from": before_enemy_move, "to": e_final, "facing": e_facing})
			if e_card != null:
				var result_e: Dictionary = resolve_one_preview_step(false, e_card, e_final, p_final, e_facing, p_facing)
				e_range_result = str(result_e.get("range", CombatResolver.RANGE_NONE))
				p_hp_delta += int(result_e.get("target_hp_delta", 0))
				p_momentum_delta += int(result_e.get("target_momentum_delta", 0))
				e_momentum_delta += int(result_e.get("actor_momentum_delta", 0))
				steps.append(effect_step("enemy", e_card, result_e))
				var before_effect_move_e2: int = e_final
				var before_effect_move_p2: int = p_final
				e_final = int(result_e.get("actor_final", e_final))
				p_final = int(result_e.get("target_final", p_final))
				steps.append({"side": "enemy", "phase": "effect_move", "actor_from": before_effect_move_e2, "actor_to": e_final, "target_from": before_effect_move_p2, "target_to": p_final, "range": e_range_result})
				preview_ended = bool(result_e.get("will_die", false))
	if not player_move_applied and c.draft_player_has_position:
		var before_player_fallback: int = p_final
		p_final = intent_target_position(true, p_intent)
		p_facing = intent_target_facing(true, p_intent)
		p_subjective = p_final
		steps.append({"side": "player", "phase": "move", "from": before_player_fallback, "to": p_subjective, "facing": p_facing})
	if not enemy_move_applied and e_intent != null and e_intent.target_position >= 0 and not (c.state_machine != null and c.state_machine.is_reactive_mode() and c.enemy.momentum > 0 and c.enemy.momentum + e_momentum_delta <= 0):
		var before_enemy_fallback: int = e_final
		e_final = intent_target_position(false, e_intent)
		e_facing = intent_target_facing(false, e_intent)
		e_subjective = e_final
		steps.append({"side": "enemy", "phase": "move", "from": before_enemy_fallback, "to": e_subjective, "facing": e_facing})
	if p_card == null:
		p_final = p_subjective
	if e_card == null:
		e_final = e_subjective
	return {
		"player_subjective": p_subjective,
		"enemy_subjective": e_subjective,
		"player_final": clampi(p_final, 0, c.GRID_SLOT_COUNT - 1),
		"enemy_final": clampi(e_final, 0, c.GRID_SLOT_COUNT - 1),
		"player_hp_delta": p_hp_delta,
		"enemy_hp_delta": e_hp_delta,
		"player_momentum_delta": p_momentum_delta,
		"enemy_momentum_delta": e_momentum_delta,
		"player_range_result": p_range_result,
		"enemy_range_result": e_range_result,
		"order": order,
		"steps": steps
	}

func effect_step(side: String, card: CardData, result: Dictionary) -> Dictionary:
	return {
		"side": side,
		"phase": "effect",
		"card": card.display_name,
		"range": str(result.get("range", CombatResolver.RANGE_NONE)),
		"requires_hit_check": card.requires_hit_check(),
		"damage": int(result.get("damage", 0)),
		"break": int(result.get("break", 0)),
		"gain": int(result.get("gain", 0)),
		"guard": int(result.get("guard", 0)),
		"will_break": bool(result.get("will_break", false)),
		"will_die": bool(result.get("will_die", false)),
		"was_back_hit": bool(result.get("was_back_hit", false)),
		"back_hit_turn_to": str(result.get("back_hit_turn_to", "")),
		"shoushi_rank": int(result.get("shoushi_rank", 0)),
		"shoushi_combo_count": int(result.get("shoushi_combo_count", 0)),
		"shoushi_multiplier": int(result.get("shoushi_multiplier", 1)),
		"shoushi_triggered": bool(result.get("shoushi_triggered", false)),
		"shoushi_mode": str(result.get("shoushi_mode", ShoushiComboRules.CURRENT_MODE))
	}

func intent_target_position(is_player_side: bool, intent: IntentData) -> int:
	if is_player_side:
		return clampi(c._player_preview_position(), 0, c.GRID_SLOT_COUNT - 1)
	if intent != null and intent.target_position >= 0:
		return clampi(intent.target_position, 0, c.GRID_SLOT_COUNT - 1)
	return clampi(c.enemy.position, 0, c.GRID_SLOT_COUNT - 1)

func intent_target_facing(is_player_side: bool, intent: IntentData) -> String:
	if is_player_side:
		return c._player_preview_facing()
	if intent != null and (intent.target_facing == "left" or intent.target_facing == "right"):
		return intent.target_facing
	return c._enemy_preview_facing()

func intent_move_delta(is_player_side: bool, intent: IntentData) -> int:
	if is_player_side:
		return intent_target_position(true, intent) - c.player.position
	return intent_target_position(false, intent) - c.enemy.position

func resolve_one_preview_step(is_player_side: bool, card: CardData, actor_pos: int, target_pos: int, actor_facing: String, target_facing: String, actor_override: Dictionary = {}, target_override: Dictionary = {}, combo_state: Dictionary = {}) -> Dictionary:
	var actor: Fighter = c.player if is_player_side else c.enemy
	var target: Fighter = c.enemy if is_player_side else c.player
	var actor_state: Dictionary = {
		"hp": int(actor_override.get("hp", actor.hp)),
		"momentum": int(actor_override.get("momentum", actor.momentum)),
		"guard": int(actor_override.get("guard", actor.guard_points)),
		"position": actor_pos,
		"facing": actor_facing,
		"broken": bool(actor_override.get("broken", actor.is_broken()))
	}
	var target_state: Dictionary = {
		"hp": int(target_override.get("hp", target.hp)),
		"momentum": int(target_override.get("momentum", target.momentum)),
		"guard": int(target_override.get("guard", target.guard_points)),
		"position": target_pos,
		"facing": target_facing,
		"broken": bool(target_override.get("broken", target.is_broken()))
	}
	var order: Array[String] = ["player"]
	var sim: Dictionary = CombatResolver.resolve_exchange(actor_state, target_state, card, null, order)
	var range_result := str(sim.get("player_range_result", CombatResolver.RANGE_NONE))
	var combo_result := ShoushiComboRules.evaluate_action_state(
		int(combo_state.get("previous_rank", actor.last_effective_shoushi_rank if actor != null else 0)),
		int(combo_state.get("combo_count", actor.shoushi_combo_count if actor != null else 0)),
		card,
		range_result,
		false
	)
	var effective_card: CardData = card.duplicate_card()
	if bool(combo_result.get("is_effective", false)):
		effective_card = ShoushiComboRules.build_effective_card(card, int(combo_result.get("multiplier", 1)))
		sim = CombatResolver.resolve_exchange(actor_state, target_state, effective_card, null, order)
	var target_hp_delta: int = int(sim.get("enemy_hp_delta", 0))
	var target_momentum_delta: int = int(sim.get("enemy_momentum_delta", 0))
	var actor_momentum_delta: int = int(sim.get("player_momentum_delta", 0))
	var actor_guard_delta: int = int(sim.get("player_guard_delta", 0))
	var damage_value: int = absi(target_hp_delta) if target_hp_delta < 0 else 0
	var break_value: int = absi(target_momentum_delta) if target_momentum_delta < 0 else 0
	var guard_value: int = actor_guard_delta if actor_guard_delta > 0 else int(effective_card.guard)
	var base_damage: int = int(CombatResolver.resolve_card_effect(
		effective_card,
		range_result,
		bool(actor_state.get("broken", false)),
		bool(target_state.get("broken", false)),
		0
	).get("damage", 0))
	var blocked_value: int = maxi(base_damage - damage_value, 0)
	var will_die := int(target_state.get("hp", 0)) > 0 and int(target_state.get("hp", 0)) + target_hp_delta <= 0
	var will_break := int(target_state.get("momentum", 0)) > 0 and int(target_state.get("momentum", 0)) + target_momentum_delta <= 0
	var was_back_hit := false
	var back_hit_turn_to := ""
	if not is_player_side and (range_result == CombatResolver.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == CombatResolver.RANGE_GRAZE)) and (damage_value > 0 or break_value > 0):
		was_back_hit = preview_back_hit(target_pos, target_facing, actor_pos)
		back_hit_turn_to = preview_facing_toward(target_pos, actor_pos) if was_back_hit else ""
	return {
		"range": range_result,
		"damage": damage_value,
		"break": break_value,
		"gain": actor_momentum_delta if actor_momentum_delta > 0 else 0,
		"guard": guard_value,
		"blocked": blocked_value,
		"actor_hp_delta": int(sim.get("player_hp_delta", 0)),
		"target_hp_delta": target_hp_delta,
		"actor_momentum_delta": actor_momentum_delta,
		"target_momentum_delta": target_momentum_delta,
		"actor_guard_delta": actor_guard_delta,
		"target_guard_delta": int(sim.get("enemy_guard_delta", 0)),
		"actor_final": int(sim.get("player_final", actor_pos)),
		"target_final": int(sim.get("enemy_final", target_pos)),
		"will_die": will_die,
		"will_break": will_break,
		"was_back_hit": was_back_hit,
		"back_hit_turn_to": back_hit_turn_to,
		"shoushi_rank": int(combo_result.get("rank", 0)),
		"shoushi_combo_count": int(combo_result.get("combo_count", 0)),
		"shoushi_multiplier": int(combo_result.get("multiplier", 1)),
		"shoushi_triggered": bool(combo_result.get("triggered", false)),
		"shoushi_mode": str(ShoushiComboRules.CURRENT_MODE),
		"shoushi_enabled": bool(combo_result.get("enabled", false)),
		"shoushi_should_reset": bool(combo_result.get("should_reset", false))
	}

func preview_back_hit(defender_pos: int, defender_facing: String, attacker_pos: int) -> bool:
	if attacker_pos > defender_pos:
		return defender_facing == "left"
	if attacker_pos < defender_pos:
		return defender_facing == "right"
	return false

func preview_facing_toward(actor_pos: int, target_pos: int) -> String:
	if target_pos > actor_pos:
		return "right"
	if target_pos < actor_pos:
		return "left"
	return ""

func resolver_preview_state(is_player: bool, intent: IntentData) -> Dictionary:
	var fighter: Fighter = c.player if is_player else c.enemy
	if fighter == null:
		return {"hp": 0, "momentum": 0, "guard": 0, "position": 0, "facing": "right", "broken": false}
	var pos: int = fighter.position
	var facing: String = fighter.facing
	if is_player:
		pos = c._player_preview_position()
		facing = c._player_preview_facing()
	else:
		if intent != null and intent.target_position >= 0:
			pos = intent.target_position
		facing = intent_target_facing(false, intent)
	return {"hp": fighter.hp, "momentum": fighter.momentum, "guard": fighter.guard_points, "position": pos, "facing": facing, "broken": fighter.is_broken()}
