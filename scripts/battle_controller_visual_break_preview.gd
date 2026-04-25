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
	var p_hp_delta: int = 0
	var e_hp_delta: int = 0
	var p_momentum_delta: int = 0
	var e_momentum_delta: int = 0
	var p_running_momentum: int = player.momentum
	var e_running_momentum: int = enemy.momentum
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
			p_final = clampi(p_final + p_move_delta, 0, GRID_SLOT_COUNT - 1)
			p_subjective = p_final
			player_move_applied = true
			steps.append({"side": "player", "phase": "move", "from": before_move, "to": p_final})
			if p_card != null:
				var result_p: Dictionary = _resolve_one_preview_step(true, p_card, p_final, e_final)
				p_range_result = str(result_p.get("range", CombatResolver.RANGE_NONE))
				var target_m_delta: int = int(result_p.get("target_momentum_delta", 0))
				var actor_m_delta: int = int(result_p.get("actor_momentum_delta", 0))
				var before_enemy_momentum: int = e_running_momentum
				e_running_momentum = clampi(e_running_momentum + target_m_delta, 0, enemy.max_momentum)
				p_running_momentum = clampi(p_running_momentum + actor_m_delta, 0, player.max_momentum)
				var breaks_enemy: bool = before_enemy_momentum > 0 and e_running_momentum <= 0
				enemy_will_break = enemy_will_break or breaks_enemy
				e_hp_delta += int(result_p.get("target_hp_delta", 0))
				e_momentum_delta += target_m_delta
				p_momentum_delta += actor_m_delta
				steps.append({"side": "player", "phase": "effect", "card": p_card.display_name, "range": p_range_result, "damage": int(result_p.get("damage", 0)), "break": int(result_p.get("break", 0)), "gain": int(result_p.get("gain", 0)), "will_break": breaks_enemy})
				var before_effect_move_p: int = p_final
				var before_effect_move_e: int = e_final
				p_final = int(result_p.get("actor_final", p_final))
				e_final = int(result_p.get("target_final", e_final))
				steps.append({"side": "player", "phase": "effect_move", "actor_from": before_effect_move_p, "actor_to": p_final, "target_from": before_effect_move_e, "target_to": e_final, "range": p_range_result})
		else:
			var before_enemy_move: int = e_final
			e_final = clampi(e_final + e_move_delta, 0, GRID_SLOT_COUNT - 1)
			e_subjective = e_final
			enemy_move_applied = true
			steps.append({"side": "enemy", "phase": "move", "from": before_enemy_move, "to": e_final})
			if e_card != null:
				var result_e: Dictionary = _resolve_one_preview_step(false, e_card, e_final, p_final)
				e_range_result = str(result_e.get("range", CombatResolver.RANGE_NONE))
				var target_m_delta_e: int = int(result_e.get("target_momentum_delta", 0))
				var actor_m_delta_e: int = int(result_e.get("actor_momentum_delta", 0))
				var before_player_momentum: int = p_running_momentum
				p_running_momentum = clampi(p_running_momentum + target_m_delta_e, 0, player.max_momentum)
				e_running_momentum = clampi(e_running_momentum + actor_m_delta_e, 0, enemy.max_momentum)
				var breaks_player: bool = before_player_momentum > 0 and p_running_momentum <= 0
				player_will_break = player_will_break or breaks_player
				p_hp_delta += int(result_e.get("target_hp_delta", 0))
				p_momentum_delta += target_m_delta_e
				e_momentum_delta += actor_m_delta_e
				steps.append({"side": "enemy", "phase": "effect", "card": e_card.display_name, "range": e_range_result, "damage": int(result_e.get("damage", 0)), "break": int(result_e.get("break", 0)), "gain": int(result_e.get("gain", 0)), "will_break": breaks_player})
				var before_effect_move_e2: int = e_final
				var before_effect_move_p2: int = p_final
				e_final = int(result_e.get("actor_final", e_final))
				p_final = int(result_e.get("target_final", p_final))
				steps.append({"side": "enemy", "phase": "effect_move", "actor_from": before_effect_move_e2, "actor_to": e_final, "target_from": before_effect_move_p2, "target_to": p_final, "range": e_range_result})

	if not player_move_applied and draft_player_has_position:
		p_final = clampi(p_final + p_move_delta, 0, GRID_SLOT_COUNT - 1)
		p_subjective = p_final
		steps.append({"side": "player", "phase": "move", "from": player.position, "to": p_subjective})
	if not enemy_move_applied and e_intent != null and e_intent.target_position >= 0:
		e_final = clampi(e_final + e_move_delta, 0, GRID_SLOT_COUNT - 1)
		e_subjective = e_final
		steps.append({"side": "enemy", "phase": "move", "from": enemy.position, "to": e_subjective})
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
		"order": order,
		"steps": steps
	}

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
	var side_text: String = "我方" if str(step.get("side", "player")) == "player" else "敌方"
	var phase: String = str(step.get("phase", ""))
	if phase == "move":
		return "%s移动：%s → %s" % [side_text, _slot_label(int(step.get("from", 0))), _slot_label(int(step.get("to", 0)))]
	if phase == "effect":
		var range_result: String = str(step.get("range", CombatResolver.RANGE_NONE))
		if range_result == CombatResolver.RANGE_MISS_FACING or range_result == CombatResolver.RANGE_MISS_RANGE:
			return "%s招式：%s / 未命中，无伤害无削势" % [side_text, str(step.get("card", "待命"))]
		var break_text: String = " / 崩势" if bool(step.get("will_break", false)) else ""
		return "%s招式：%s / %s / 伤%d / 势-%d%s" % [side_text, str(step.get("card", "待命")), _range_text(range_result), int(step.get("damage", 0)), int(step.get("break", 0)), break_text]
	if phase == "effect_move":
		var actor_from: int = int(step.get("actor_from", 0))
		var actor_to: int = int(step.get("actor_to", actor_from))
		var target_from: int = int(step.get("target_from", 0))
		var target_to: int = int(step.get("target_to", target_from))
		if actor_from == actor_to and target_from == target_to:
			return "%s招式位移：无" % side_text
		return "%s招式位移：自身 %s → %s；目标 %s → %s" % [side_text, _slot_label(actor_from), _slot_label(actor_to), _slot_label(target_from), _slot_label(target_to)]
	return "%s：无" % side_text
