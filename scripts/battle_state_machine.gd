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
	# Phase 2: lower realm declares first, higher realm reads visible intent and declares later.
	if player.realm < enemy.realm:
		return PackedStringArray([player.data.id, enemy.data.id])
	if player.realm > enemy.realm:
		return PackedStringArray([enemy.data.id, player.data.id])
	if player_tie_advantage:
		return PackedStringArray([enemy.data.id, player.data.id])
	return PackedStringArray([player.data.id, enemy.data.id])


func get_resolution_order(player: Fighter, enemy: Fighter, player_intent: IntentData, enemy_intent: IntentData) -> Array[IntentData]:
	# Phase 3: 先机 overrides realm order, then same-realm alternates by tie advantage.
	if player_intent.has_senki() and not enemy_intent.has_senki():
		return [player_intent, enemy_intent]
	if enemy_intent.has_senki() and not player_intent.has_senki():
		return [enemy_intent, player_intent]
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

	if card.distance_delta != 0:
		var old_distance := current_distance
		current_distance = clampi(current_distance + card.distance_delta, 1, 3)
		if current_distance == old_distance:
			lines.append("距离已到边界，无法继续后退或逼近。")
		else:
			lines.append("距离 %+d，变为 %d。" % [card.distance_delta, current_distance])

	if card.damage > 0:
		if card.is_usable_at(current_distance):
			target.hp = maxi(target.hp - card.damage, 0)
			lines.append("%s 命中，造成 %d 伤害。" % [card.display_name, card.damage])
		else:
			lines.append("%s 因距离 %d 不合式，未能命中。" % [card.display_name, current_distance])

	return lines


func finish_round(player: Fighter, enemy: Fighter) -> void:
	phase = BattlePhase.DECLARE if player.hp > 0 and enemy.hp > 0 else BattlePhase.RESULT
	if player.realm == enemy.realm:
		player_tie_advantage = not player_tie_advantage
	round_index += 1


func tie_rule_text(player: Fighter, enemy: Fighter) -> String:
	if player.realm != enemy.realm:
		return "当前非同武境，按武境高低处理识机权。"
	return "同武境轮流：本回合%s占识机权与先发权。" % ("玩家" if player_tie_advantage else "敌方")
