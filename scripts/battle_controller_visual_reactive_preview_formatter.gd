extends RefCounted

# Pure formatter/simulator helper for reactive settlement-mode threat preview.
#
# It does not mutate battle state, refresh UI, or play animations. The controller
# passes the current battle objects and draft intent state; this helper returns
# display text and preview dictionaries only.

static func threat_preview_text(
	state_machine,
	player,
	enemy,
	enemy_intent,
	draft_player_intent,
	draft_player_has_position: bool,
	draft_player_position: int,
	draft_player_facing: String,
	battle_slot_count: int
) -> String:
	if state_machine == null or not state_machine.is_reactive_mode():
		return ""
	if player == null or enemy == null or enemy_intent == null:
		return ""
	var result: Dictionary = resolution_preview(player, enemy, enemy_intent, draft_player_intent, draft_player_has_position, draft_player_position, draft_player_facing, battle_slot_count)
	var enemy_card: CardData = enemy_intent.actual_card
	var player_card: CardData = draft_player_intent.actual_card if draft_player_intent != null else null
	var lines: Array[String] = []
	lines.append("\n[font_size=18][b]反应式威胁摘要[/b][/font_size]")
	lines.append("敌方已落位：%s，当前距离 %d" % [_slot_label_safe(enemy.position), int(result.get("initial_distance", 0))])
	lines.append("我方响应：%s / %s / 伤%d / 势-%d" % [player_card.display_name if player_card != null else "未选招式", range_text_safe(str(result.get("player_range", CombatResolver.RANGE_NONE))), int(result.get("player_damage", 0)), int(result.get("player_break", 0))])
	if bool(result.get("will_interrupt", false)):
		lines.append("敌方威胁：%s / 已被崩势打断" % (enemy_card.display_name if enemy_card != null else "无"))
		lines.append("结果重点：预计打出崩势，敌方本回合攻击中断。")
	else:
		lines.append("敌方威胁：%s / %s / 伤%d / 势-%d / 结算距离 %d" % [enemy_card.display_name if enemy_card != null else "无", range_text_safe(str(result.get("enemy_range_after_player", CombatResolver.RANGE_NONE))), int(result.get("enemy_damage", 0)), int(result.get("enemy_break", 0)), int(result.get("final_distance_before_enemy", 0))])
		lines.append("结果重点：敌方将基于我方响应后的最终站位重新判定命中。")
	lines.append("最终预估：我方 %s；敌方 %s" % [_slot_label_safe(int(result.get("player_after_player_action", player.position))), _slot_label_safe(int(result.get("enemy_after_player_action", enemy.position)))])
	return "\n".join(lines)


static func resolution_preview(
	player,
	enemy,
	enemy_intent,
	draft_player_intent,
	draft_player_has_position: bool,
	draft_player_position: int,
	draft_player_facing: String,
	battle_slot_count: int
) -> Dictionary:
	var enemy_card: CardData = enemy_intent.actual_card if enemy_intent != null else null
	var player_card: CardData = draft_player_intent.actual_card if draft_player_intent != null else null
	var player_pos: int = _reactive_player_preview_position(player, draft_player_has_position, draft_player_position, battle_slot_count)
	var player_facing: String = _reactive_player_preview_facing(player, draft_player_facing)
	var player_after: int = player_pos
	var enemy_after: int = enemy.position
	var player_range: String = CombatResolver.RANGE_NONE
	var enemy_range_after_player: String = CombatResolver.RANGE_NONE
	var will_interrupt := false
	var player_damage := 0
	var player_break := 0
	var enemy_damage := 0
	var enemy_break := 0
	if player_card != null:
		var player_state: Dictionary = {"hp": player.hp, "momentum": player.momentum, "guard": player.guard_points, "position": player_pos, "facing": player_facing, "broken": player.is_broken()}
		var enemy_state: Dictionary = {"hp": enemy.hp, "momentum": enemy.momentum, "guard": enemy.guard_points, "position": enemy.position, "facing": enemy.facing, "broken": enemy.is_broken()}
		var sim: Dictionary = CombatResolver.resolve_exchange(player_state, enemy_state, player_card, null, ["player"])
		var enemy_hp_delta: int = int(sim.get("enemy_hp_delta", 0))
		var enemy_momentum_delta: int = int(sim.get("enemy_momentum_delta", 0))
		player_damage = absi(enemy_hp_delta) if enemy_hp_delta < 0 else 0
		player_break = absi(enemy_momentum_delta) if enemy_momentum_delta < 0 else 0
		player_range = str(sim.get("player_range_result", CombatResolver.RANGE_NONE))
		player_after = int(sim.get("player_final", player_pos))
		enemy_after = int(sim.get("enemy_final", enemy.position))
		will_interrupt = enemy.momentum > 0 and enemy.momentum + enemy_momentum_delta <= 0
	if enemy_card != null and not will_interrupt:
		var enemy_state_after: Dictionary = {"hp": enemy.hp, "momentum": enemy.momentum, "guard": enemy.guard_points, "position": enemy_after, "facing": enemy.facing, "broken": enemy.is_broken()}
		var player_state_after: Dictionary = {"hp": player.hp, "momentum": player.momentum, "guard": player.guard_points, "position": player_after, "facing": player_facing, "broken": player.is_broken()}
		var enemy_sim: Dictionary = CombatResolver.resolve_exchange(enemy_state_after, player_state_after, enemy_card, null, ["player"])
		var player_hp_delta: int = int(enemy_sim.get("enemy_hp_delta", 0))
		var player_momentum_delta: int = int(enemy_sim.get("enemy_momentum_delta", 0))
		enemy_damage = absi(player_hp_delta) if player_hp_delta < 0 else 0
		enemy_break = absi(player_momentum_delta) if player_momentum_delta < 0 else 0
		enemy_range_after_player = str(enemy_sim.get("player_range_result", CombatResolver.RANGE_NONE))
	return {
		"initial_distance": absi(enemy.position - player.position),
		"player_range": player_range,
		"player_damage": player_damage,
		"player_break": player_break,
		"will_interrupt": will_interrupt,
		"player_after_player_action": player_after,
		"enemy_after_player_action": enemy_after,
		"enemy_range_after_player": enemy_range_after_player,
		"enemy_damage": enemy_damage,
		"enemy_break": enemy_break,
		"final_distance_before_enemy": absi(enemy_after - player_after)
	}


static func range_text_safe(range_result: String) -> String:
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
			return "无"


static func _reactive_player_preview_position(player, draft_player_has_position: bool, draft_player_position: int, battle_slot_count: int) -> int:
	if draft_player_has_position:
		return clampi(draft_player_position, 0, battle_slot_count - 1)
	return player.position


static func _reactive_player_preview_facing(player, draft_player_facing: String) -> String:
	if draft_player_facing != "":
		return draft_player_facing
	return player.facing


static func _slot_label_safe(slot: int) -> String:
	var labels: Array[String] = ["零位", "一位", "二位", "三位", "四位", "五位", "六位", "七位", "八位"]
	if slot >= 0 and slot < labels.size():
		return labels[slot]
	return "%d位" % slot
