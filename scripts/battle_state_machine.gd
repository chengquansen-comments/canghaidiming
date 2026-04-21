extends RefCounted
class_name BattleStateMachine

const Fighter = preload("res://scripts/fighter.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const CardData = preload("res://scripts/card_data.gd")

enum BattlePhase {
	NODE_SELECTION,
	DECLARE,
	RESOLUTION,
	RESULT
}

var phase: BattlePhase = BattlePhase.NODE_SELECTION
var current_distance: int = 2
var round_index: int = 1
var player_tie_advantage := true


func reset_for_session() -> void:
	phase = BattlePhase.NODE_SELECTION
	current_distance = 2
	round_index = 1
	player_tie_advantage = true


func begin_battle(initial_distance: int = 2) -> void:
	phase = BattlePhase.DECLARE
	current_distance = clampi(initial_distance, 1, 3)
	round_index = 1


func get_declaration_order(player: Fighter, enemy: Fighter) -> PackedStringArray:
	if player.is_broken() and not enemy.is_broken():
		return PackedStringArray([player.data.id, enemy.data.id])
	if enemy.is_broken() and not player.is_broken():
		return PackedStringArray([enemy.data.id, player.data.id])
	if player.realm < enemy.realm:
		return PackedStringArray([player.data.id, enemy.data.id])
	if player.realm > enemy.realm:
		return PackedStringArray([enemy.data.id, player.data.id])
	if player_tie_advantage:
		return PackedStringArray([enemy.data.id, player.data.id])
	return PackedStringArray([player.data.id, enemy.data.id])


func get_resolution_order(player: Fighter, enemy: Fighter, player_intent: IntentData, enemy_intent: IntentData) -> Array[IntentData]:
	if player_intent.has_senki() and not enemy_intent.has_senki():
		return [player_intent, enemy_intent]
	if enemy_intent.has_senki() and not player_intent.has_senki():
		return [enemy_intent, player_intent]
	if player.is_broken() and not enemy.is_broken():
		return [enemy_intent, player_intent]
	if enemy.is_broken() and not player.is_broken():
		return [player_intent, enemy_intent]
	if player.realm > enemy.realm:
		return [player_intent, enemy_intent]
	if enemy.realm > player.realm:
		return [enemy_intent, player_intent]
	if player_tie_advantage:
		return [player_intent, enemy_intent]
	return [enemy_intent, player_intent]


func get_visible_intent_text(intent: IntentData, viewer: Fighter) -> String:
	if intent == null:
		return "未定"
	if intent.is_hidden() and not intent.can_hidden_be_read(viewer):
		return intent.get_visible_summary()
	return intent.get_actual_summary()


func resolve_intent(intent: IntentData, actor: Fighter, target: Fighter) -> Array[String]:
	var lines: Array[String] = []
	if actor.hp <= 0:
		return lines

	var card: CardData = intent.actual_card
	lines.append("%s 施展 [b]%s[/b]。" % [actor.data.display_name, card.display_name])
	if card.id == "idle":
		var gained := actor.recover_momentum(1)
		lines.append("%s 回观收势，恢复 %d 势。" % [actor.data.display_name, gained])
		return lines
	if card.id == "staggered":
		lines.append("%s 崩势未稳，本回合无法行动。" % actor.data.display_name)
		return lines

	if card.is_momentum_card():
		if card.gain_momentum > 0:
			var gained_momentum := actor.recover_momentum(card.gain_momentum)
			lines.append("%s 增己势 %d。" % [card.display_name, gained_momentum])
		if card.break_momentum > 0:
			var before_break := target.momentum
			target.momentum = maxi(target.momentum - card.break_momentum, 0)
			var actual_break := before_break - target.momentum
			lines.append("%s 削敌势 %d。" % [card.display_name, actual_break])
			if before_break > 0 and target.momentum == 0:
				target.queue_broken_state()
				actor.queue_combo_window()
				lines.append("%s 的势被打到 0，下回合将崩势硬直！" % target.data.display_name)
		return lines

	if card.is_guard_card():
		var guard_total := actor.add_guard(card.guard)
		lines.append("%s 立起 %d 格挡，当前护值 %d。" % [card.display_name, card.guard, guard_total])
		return lines

	if card.damage > 0:
		if card.is_usable_at(current_distance):
			var effective_damage := card.damage
			if target.is_broken():
				effective_damage *= 2
				lines.append("%s 处于崩势，所受伤害翻倍至 %d。" % [target.data.display_name, effective_damage])
			var remaining_damage := target.absorb_damage(effective_damage)
			var blocked := effective_damage - remaining_damage
			if blocked > 0:
				lines.append("%s 被格挡化去 %d。" % [card.display_name, blocked])
			if remaining_damage > 0:
				target.hp = maxi(target.hp - remaining_damage, 0)
				lines.append("%s 命中，造成 %d 伤害。" % [card.display_name, remaining_damage])
			else:
				lines.append("%s 被完全格挡。" % card.display_name)
		else:
			lines.append("%s 因距离 %d 不合式，未能命中。" % [card.display_name, current_distance])

	return lines


func finish_round(player: Fighter, enemy: Fighter) -> void:
	phase = BattlePhase.DECLARE if player.hp > 0 and enemy.hp > 0 else BattlePhase.RESULT
	player.reset_guard()
	enemy.reset_guard()
	player.activate_pending_round_state()
	enemy.activate_pending_round_state()
	if player.realm == enemy.realm:
		player_tie_advantage = not player_tie_advantage
	round_index += 1


func pressure_state_text(player: Fighter, enemy: Fighter) -> String:
	if player.is_broken() and enemy.combo_window_active:
		return "玩家崩势：本回合无法行动，且受击伤害翻倍；敌方拥有连招窗口。"
	if enemy.is_broken() and player.combo_window_active:
		return "敌方崩势：本回合无法行动，且受击伤害翻倍；玩家拥有连招窗口。"
	if player.is_broken():
		return "玩家崩势：本回合无法行动，且受击伤害翻倍。"
	if enemy.is_broken():
		return "敌方崩势：本回合无法行动，且受击伤害翻倍。"
	if player.combo_window_active:
		return "玩家持有连招窗口：下一招若符合已解锁套路，将自动连招。"
	if enemy.combo_window_active:
		return "敌方持有连招窗口：下一招若符合已解锁套路，将自动连招。"
	return "当前无人崩势，未出现释放窗口。"


func tie_rule_text(player: Fighter, enemy: Fighter) -> String:
	if player.realm != enemy.realm:
		return "当前非同武境，按武境高低处理识机权。"
	return "同武境轮流：本回合%s占识机权与先发权。" % ("玩家" if player_tie_advantage else "敌方")
