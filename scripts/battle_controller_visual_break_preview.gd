extends "res://scripts/battle_controller_visual_resolver_preview.gd"

# Thin wrapper for break-state preview correctness.
# It tracks running momentum so the effect preview can show when a hit will cause 崩势.

func _ordered_preview_simulation(p_intent: IntentData, e_intent: IntentData) -> Dictionary:
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var p_move_delta: int = _intent_move_delta(true, p_intent)
	var e_move_delta: int = _intent_move_delta(false, e_intent)
	var p_subjective: int = clampi(player.position + p_move_delta, 0, GRID_SLOT_COUNT - 1)
	var e_subjective: int = clampi(enemy.position + e_move_delta, 0, GRID_SLOT_COUNT - 1)
	var p_final: int = player.position
	var e_final: int = enemy.position
	var p_facing: String = player.facing
	var e_facing: String = enemy.facing
	var p_hp_delta: int = 0
	var e_hp_delta: int = 0
	var p_momentum_delta: int = 0
	var e_momentum_delta: int = 0
	var p_running_hp: int = player.hp
	var e_running_hp: int = enemy.hp
	var p_running_momentum: int = player.momentum
	var e_running_momentum: int = enemy.momentum
	var p_running_guard: int = player.guard_points
	var e_running_guard: int = enemy.guard_points
	var p_max_momentum: int = player.data.max_momentum if player != null and player.data != null else 0
	var e_max_momentum: int = enemy.data.max_momentum if enemy != null and enemy.data != null else 0
	var p_combo_rank: int = player.last_effective_shoushi_rank
	var e_combo_rank: int = enemy.last_effective_shoushi_rank
	var p_combo_count: int = player.shoushi_combo_count
	var e_combo_count: int = enemy.shoushi_combo_count
	var p_combo_multiplier := maxi(player.shoushi_combo_multiplier, 1)
	var e_combo_multiplier := maxi(enemy.shoushi_combo_multiplier, 1)
	var player_will_break: bool = false
	var enemy_will_break: bool = false
	var p_range_result: String = CombatResolver.RANGE_NONE
	var e_range_result: String = CombatResolver.RANGE_NONE
	var order: Array[String] = _preview_resolution_order(p_intent, e_intent)
	var steps: Array[Dictionary] = []
	var player_move_applied: bool = false
	var enemy_move_applied: bool = false

	for side: String in order:
		if side == "player":
			var before_move: int = p_final
			p_final = _intent_target_position(true, p_intent)
			p_facing = _intent_target_facing(true, p_intent)
			p_subjective = p_final
			player_move_applied = true
			steps.append({"side": "player", "phase": "move", "from": before_move, "to": p_final, "facing": p_facing})
			if p_card != null:
				var result_p: Dictionary = _resolve_one_preview_step(
					true,
					p_card,
					p_final,
					e_final,
					p_facing,
					e_facing,
					{"hp": p_running_hp, "momentum": p_running_momentum, "guard": p_running_guard, "broken": player.is_broken()},
					{"hp": e_running_hp, "momentum": e_running_momentum, "guard": e_running_guard, "broken": enemy.is_broken()},
					{"previous_rank": p_combo_rank, "combo_count": p_combo_count}
				)
				p_range_result = str(result_p.get("range", CombatResolver.RANGE_NONE))
				var target_m_delta: int = int(result_p.get("target_momentum_delta", 0))
				var actor_m_delta: int = int(result_p.get("actor_momentum_delta", 0))
				var actor_guard_delta: int = int(result_p.get("actor_guard_delta", 0))
				var target_guard_delta: int = int(result_p.get("target_guard_delta", 0))
				var blocked_value: int = int(result_p.get("blocked", 0))
				var before_enemy_momentum: int = e_running_momentum
				var before_player_momentum_gain: int = p_running_momentum
				var before_player_guard: int = p_running_guard
				var before_enemy_guard: int = e_running_guard
				var before_enemy_hp: int = e_running_hp
				e_running_momentum = clampi(e_running_momentum + target_m_delta, 0, e_max_momentum)
				p_running_momentum = clampi(p_running_momentum + actor_m_delta, 0, p_max_momentum)
				p_running_guard = maxi(p_running_guard + actor_guard_delta, 0)
				e_running_guard = maxi(e_running_guard + target_guard_delta - blocked_value, 0)
				e_running_hp = maxi(e_running_hp + int(result_p.get("target_hp_delta", 0)), 0)
				var breaks_enemy: bool = before_enemy_momentum > 0 and e_running_momentum <= 0
				enemy_will_break = enemy_will_break or breaks_enemy
				e_hp_delta += int(result_p.get("target_hp_delta", 0))
				e_momentum_delta += target_m_delta
				p_momentum_delta += actor_m_delta
				var step_p := _effect_step("player", p_card, result_p)
				step_p["will_break"] = breaks_enemy
				step_p["actor_momentum_before"] = before_player_momentum_gain
				step_p["actor_momentum_after"] = p_running_momentum
				step_p["target_momentum_before"] = before_enemy_momentum
				step_p["target_momentum_after"] = e_running_momentum
				step_p["actor_guard_before"] = before_player_guard
				step_p["actor_guard_after"] = p_running_guard
				step_p["target_guard_before"] = before_enemy_guard
				step_p["target_guard_after"] = e_running_guard
				step_p["target_hp_before"] = before_enemy_hp
				step_p["target_hp_after"] = e_running_hp
				steps.append(step_p)
				if bool(result_p.get("shoushi_enabled", ShoushiComboRules.is_enabled())):
					if bool(result_p.get("shoushi_should_reset", false)):
						p_combo_rank = 0
						p_combo_count = 0
						p_combo_multiplier = 1
					elif int(result_p.get("shoushi_combo_count", 0)) > 0:
						p_combo_rank = int(result_p.get("shoushi_rank", 0))
						p_combo_count = int(result_p.get("shoushi_combo_count", 0))
						p_combo_multiplier = int(result_p.get("shoushi_multiplier", 1))
				var before_effect_move_p: int = p_final
				var before_effect_move_e: int = e_final
				p_final = int(result_p.get("actor_final", p_final))
				e_final = int(result_p.get("target_final", e_final))
				steps.append({"side": "player", "phase": "effect_move", "actor_from": before_effect_move_p, "actor_to": p_final, "target_from": before_effect_move_e, "target_to": e_final, "range": p_range_result})
		else:
			if _preview_should_cancel_reactive_enemy_step(enemy_will_break):
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
				var result_e: Dictionary = _resolve_one_preview_step(
					false,
					e_card,
					e_final,
					p_final,
					e_facing,
					p_facing,
					{"hp": e_running_hp, "momentum": e_running_momentum, "guard": e_running_guard, "broken": enemy.is_broken()},
					{"hp": p_running_hp, "momentum": p_running_momentum, "guard": p_running_guard, "broken": player.is_broken()},
					{"previous_rank": e_combo_rank, "combo_count": e_combo_count}
				)
				e_range_result = str(result_e.get("range", CombatResolver.RANGE_NONE))
				var target_m_delta_e: int = int(result_e.get("target_momentum_delta", 0))
				var actor_m_delta_e: int = int(result_e.get("actor_momentum_delta", 0))
				var actor_guard_delta_e: int = int(result_e.get("actor_guard_delta", 0))
				var target_guard_delta_e: int = int(result_e.get("target_guard_delta", 0))
				var blocked_value_e: int = int(result_e.get("blocked", 0))
				var before_player_momentum: int = p_running_momentum
				var before_enemy_momentum_gain: int = e_running_momentum
				var before_enemy_guard_gain: int = e_running_guard
				var before_player_guard: int = p_running_guard
				var before_player_hp: int = p_running_hp
				p_running_momentum = clampi(p_running_momentum + target_m_delta_e, 0, p_max_momentum)
				e_running_momentum = clampi(e_running_momentum + actor_m_delta_e, 0, e_max_momentum)
				e_running_guard = maxi(e_running_guard + actor_guard_delta_e, 0)
				p_running_guard = maxi(p_running_guard + target_guard_delta_e - blocked_value_e, 0)
				p_running_hp = maxi(p_running_hp + int(result_e.get("target_hp_delta", 0)), 0)
				var breaks_player: bool = before_player_momentum > 0 and p_running_momentum <= 0
				player_will_break = player_will_break or breaks_player
				p_hp_delta += int(result_e.get("target_hp_delta", 0))
				p_momentum_delta += target_m_delta_e
				e_momentum_delta += actor_m_delta_e
				var step_e := _effect_step("enemy", e_card, result_e)
				step_e["will_break"] = breaks_player
				step_e["actor_momentum_before"] = before_enemy_momentum_gain
				step_e["actor_momentum_after"] = e_running_momentum
				step_e["target_momentum_before"] = before_player_momentum
				step_e["target_momentum_after"] = p_running_momentum
				step_e["actor_guard_before"] = before_enemy_guard_gain
				step_e["actor_guard_after"] = e_running_guard
				step_e["target_guard_before"] = before_player_guard
				step_e["target_guard_after"] = p_running_guard
				step_e["target_hp_before"] = before_player_hp
				step_e["target_hp_after"] = p_running_hp
				steps.append(step_e)
				if bool(result_e.get("shoushi_enabled", ShoushiComboRules.is_enabled())):
					if bool(result_e.get("shoushi_should_reset", false)):
						e_combo_rank = 0
						e_combo_count = 0
						e_combo_multiplier = 1
					elif int(result_e.get("shoushi_combo_count", 0)) > 0:
						e_combo_rank = int(result_e.get("shoushi_rank", 0))
						e_combo_count = int(result_e.get("shoushi_combo_count", 0))
						e_combo_multiplier = int(result_e.get("shoushi_multiplier", 1))
				var before_effect_move_e2: int = e_final
				var before_effect_move_p2: int = p_final
				e_final = int(result_e.get("actor_final", e_final))
				p_final = int(result_e.get("target_final", p_final))
				steps.append({"side": "enemy", "phase": "effect_move", "actor_from": before_effect_move_e2, "actor_to": e_final, "target_from": before_effect_move_p2, "target_to": p_final, "range": e_range_result})

	if not player_move_applied and draft_player_has_position:
		var before_player_fallback: int = p_final
		p_final = _intent_target_position(true, p_intent)
		p_facing = _intent_target_facing(true, p_intent)
		p_subjective = p_final
		steps.append({"side": "player", "phase": "move", "from": before_player_fallback, "to": p_subjective, "facing": p_facing})
	if not enemy_move_applied and e_intent != null and e_intent.target_position >= 0 and not _preview_should_cancel_reactive_enemy_step(enemy_will_break):
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
		"player_will_break": player_will_break,
		"enemy_will_break": enemy_will_break,
		"player_momentum_final": p_running_momentum,
		"enemy_momentum_final": e_running_momentum,
		"player_guard_final": p_running_guard,
		"enemy_guard_final": e_running_guard,
		"player_shoushi_rank": p_combo_rank,
		"enemy_shoushi_rank": e_combo_rank,
		"player_shoushi_combo_count": p_combo_count,
		"enemy_shoushi_combo_count": e_combo_count,
		"player_shoushi_multiplier": p_combo_multiplier,
		"enemy_shoushi_multiplier": e_combo_multiplier,
		"order": order,
		"steps": steps
	}

func _preview_should_cancel_reactive_enemy_step(enemy_interrupted: bool) -> bool:
	if state_machine == null or not state_machine.is_reactive_mode():
		return false
	if enemy == null:
		return false
	return enemy_interrupted or enemy.pending_control_state == Fighter.CONTROL_BROKEN

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
	var p_break_text: String = " / 预期崩势" if bool(sim.get("player_will_break", false)) else ""
	var e_break_text: String = " / 预期崩势" if bool(sim.get("enemy_will_break", false)) else ""
	lines.append("我方：伤%d / 势-%d%s / 主观 %s / 最终 %s" % [absi(int(sim.get("player_hp_delta", 0))) if int(sim.get("player_hp_delta", 0)) < 0 else 0, absi(int(sim.get("player_momentum_delta", 0))) if int(sim.get("player_momentum_delta", 0)) < 0 else 0, p_break_text, _slot_label(int(sim.get("player_subjective", player.position))), _slot_label(int(sim.get("player_final", player.position)))])
	lines.append("敌方：伤%d / 势-%d%s / 主观 %s / 最终 %s" % [absi(int(sim.get("enemy_hp_delta", 0))) if int(sim.get("enemy_hp_delta", 0)) < 0 else 0, absi(int(sim.get("enemy_momentum_delta", 0))) if int(sim.get("enemy_momentum_delta", 0)) < 0 else 0, e_break_text, _slot_label(int(sim.get("enemy_subjective", enemy.position))), _slot_label(int(sim.get("enemy_final", enemy.position)))])
	return "\n".join(lines)

func _step_text(step: Dictionary) -> String:
	return super._step_text(step)
