extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func effect_preview_text() -> String:
	if c.player == null or c.enemy == null or c.state_machine == null:
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var p_intent: IntentData = c.draft_player_intent if c.draft_player_intent != null else c.player_intent
	var e_intent: IntentData = c.enemy_intent
	var p_card: CardData = p_intent.actual_card if p_intent != null else null
	var e_card: CardData = e_intent.actual_card if e_intent != null else null
	var sim: Dictionary = c._ordered_preview_simulation(p_intent, e_intent)
	var lines: Array[String] = []
	lines.append("[font_size=18][b]效果预览[/b][/font_size]")
	lines.append("行动顺序：%s" % order_text(sim.get("order", [])))
	lines.append("我方招式：%s" % (p_card.display_name if p_card != null else "待命"))
	lines.append("敌方招式：%s" % (e_card.display_name if e_card != null else "待命"))
	lines.append("")
	lines.append("[b]顺序结算预览[/b]")
	for step: Dictionary in sim.get("steps", []):
		lines.append(step_text(step))
	lines.append("")
	lines.append("[b]最终汇总[/b]")
	lines.append("我方：伤%d / 势-%d / 主观 %s / 最终 %s" % [absi(int(sim.get("player_hp_delta", 0))) if int(sim.get("player_hp_delta", 0)) < 0 else 0, absi(int(sim.get("player_momentum_delta", 0))) if int(sim.get("player_momentum_delta", 0)) < 0 else 0, c._slot_label(int(sim.get("player_subjective", c.player.position))), c._slot_label(int(sim.get("player_final", c.player.position)))])
	lines.append("敌方：伤%d / 势-%d / 主观 %s / 最终 %s" % [absi(int(sim.get("enemy_hp_delta", 0))) if int(sim.get("enemy_hp_delta", 0)) < 0 else 0, absi(int(sim.get("enemy_momentum_delta", 0))) if int(sim.get("enemy_momentum_delta", 0)) < 0 else 0, c._slot_label(int(sim.get("enemy_subjective", c.enemy.position))), c._slot_label(int(sim.get("enemy_final", c.enemy.position)))])
	return "\n".join(lines)

func order_text(order_value) -> String:
	var order: Array = order_value
	var parts: Array[String] = []
	for side in order:
		parts.append("我方" if str(side) == "player" else "敌方")
	return " → ".join(parts)

func step_text(step: Dictionary) -> String:
	var side_text := "我方" if str(step.get("side", "player")) == "player" else "敌方"
	var phase := str(step.get("phase", ""))
	if phase == "move":
		var facing_text := "朝右" if str(step.get("facing", "")) == "right" else "朝左" if str(step.get("facing", "")) == "left" else ""
		return "%s目标：%s → %s %s" % [side_text, c._slot_label(int(step.get("from", 0))), c._slot_label(int(step.get("to", 0))), facing_text]
	if phase == "effect":
		var range_result := str(step.get("range", CombatResolver.RANGE_NONE))
		if range_result == CombatResolver.RANGE_MISS_FACING or range_result == CombatResolver.RANGE_MISS_RANGE:
			return "%s招式：%s / 未命中，无伤害无削势" % [side_text, str(step.get("card", "待命"))]
		var parts: Array[String] = []
		var requires_hit_check := bool(step.get("requires_hit_check", true))
		parts.append("%s招式：%s" % [side_text, str(step.get("card", "待命"))])
		parts.append(range_text(range_result) if requires_hit_check else "生效")
		var damage := int(step.get("damage", 0))
		var break_value := int(step.get("break", 0))
		var guard := int(step.get("guard", 0))
		var gain := int(step.get("gain", 0))
		if damage > 0:
			parts.append("伤%d" % damage)
		if break_value > 0:
			parts.append("势-%d" % break_value)
		if guard > 0:
			parts.append("格挡%d" % guard)
		if gain > 0:
			parts.append("势+%d" % gain)
		var extra := ""
		if bool(step.get("will_break", false)):
			extra += " / 破势"
		if bool(step.get("was_back_hit", false)):
			extra += " / 背击"
		if int(step.get("shoushi_multiplier", 1)) > 1:
			extra += " / 收式%s" % ShoushiComboRules.combo_brief_text(int(step.get("shoushi_combo_count", 0)), int(step.get("shoushi_multiplier", 1)))
		return "%s%s" % [" / ".join(parts), extra]
	if phase == "effect_move":
		var actor_from := int(step.get("actor_from", 0))
		var actor_to := int(step.get("actor_to", actor_from))
		var target_from := int(step.get("target_from", 0))
		var target_to := int(step.get("target_to", target_from))
		if actor_from == actor_to and target_from == target_to:
			return "%s招式位移：无" % side_text
		return "%s招式位移：自身 %s → %s；目标 %s → %s" % [side_text, c._slot_label(actor_from), c._slot_label(actor_to), c._slot_label(target_from), c._slot_label(target_to)]
	return "%s：无" % side_text

func range_text(range_result: String) -> String:
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
