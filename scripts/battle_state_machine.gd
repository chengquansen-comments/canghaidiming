extends RefCounted
class_name BattleStateMachine

const Fighter = preload("res://scripts/fighter.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const CardData = preload("res://scripts/card_data.gd")
const CombatResolver = preload("res://scripts/combat_resolver.gd")

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

const RANGE_HIT := "hit"
const RANGE_GRAZE := "graze"
const RANGE_MISS_RANGE := "miss_range"
const RANGE_MISS_FACING := "miss_facing"


func reset_for_session() -> void:
	phase = BattlePhase.NODE_SELECTION
	current_distance = 2
	round_index = 1
	player_tie_advantage = true


func begin_battle(initial_distance: int = 2) -> void:
	phase = BattlePhase.DECLARE
	current_distance = maxi(initial_distance, 0)
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


func update_distance_from_positions(player: Fighter, enemy: Fighter) -> int:
	if player == null or enemy == null:
		return current_distance
	current_distance = absi(enemy.position - player.position)
	return current_distance


func direction_toward(actor_pos: int, target_pos: int, fallback_facing: String) -> int:
	return CombatResolver.preview_dir(actor_pos, target_pos, fallback_facing)


func apply_self_move(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount == 0:
		return
	actor.position = CombatResolver.preview_self(actor.position, target.position, actor.facing, amount)


func apply_push_target(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount <= 0:
		return
	target.position = CombatResolver.preview_push(actor.position, target.position, actor.facing, amount)


func apply_pull_target(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount <= 0:
		return
	target.position = CombatResolver.preview_pull(actor.position, target.position, actor.facing, amount)


func face_target(actor: Fighter, target: Fighter) -> void:
	if target.position > actor.position:
		actor.facing = "right"
	elif target.position < actor.position:
		actor.facing = "left"


func apply_card_movement(card: CardData, actor: Fighter, target: Fighter, range_result: String) -> void:
	var actor_state: Dictionary = _fighter_to_resolver_state(actor)
	var target_state: Dictionary = _fighter_to_resolver_state(target)
	var moved: Dictionary = CombatResolver.apply_card_movement(card, true, actor.position, target.position, actor.facing, range_result, target.pending_control_state == Fighter.CONTROL_BROKEN)
	actor.position = int(moved.get("player", actor.position))
	target.position = int(moved.get("enemy", target.position))
	face_target(actor, target)
	face_target(target, actor)
	update_distance_from_positions(actor, target)


func is_facing_target(actor: Fighter, target: Fighter) -> bool:
	return CombatResolver.faces_target(actor.position, actor.facing, target.position)


func evaluate_card_range(card: CardData, actor: Fighter, target: Fighter) -> String:
	return CombatResolver.evaluate_range(card, actor.position, actor.facing, target.position)


func resolve_intent(intent: IntentData, actor: Fighter, target: Fighter) -> Array[String]:
	var lines: Array[String] = []
	if actor.hp <= 0:
		return lines

	var card: CardData = intent.actual_card
	lines.append("%s 施展 [b]%s[/b]。" % [actor.data.display_name, card.display_name])
	if card.id == "idle":
		lines.append("%s 本回合不出招。" % actor.data.display_name)
		return lines
	if card.id == "staggered":
		lines.append("%s 崩势未稳，本回合无法行动。" % actor.data.display_name)
		return lines

	var actor_state: Dictionary = _fighter_to_resolver_state(actor)
	var target_state: Dictionary = _fighter_to_resolver_state(target)
	var order: Array[String] = []
	order.append("player")
	var sim: Dictionary = CombatResolver.resolve_exchange(actor_state, target_state, card, null, order)
	var range_result: String = str(sim.get("player_range_result", RANGE_HIT))

	if card.is_guard_card():
		var guard_gain: int = int(sim.get("player_guard_delta", card.guard))
		var guard_total: int = actor.add_guard(guard_gain)
		lines.append("%s 立起 %d 格挡，当前护值 %d。" % [card.display_name, guard_gain, guard_total])
		_apply_resolved_positions(actor, target, sim)
		return lines

	if card.requires_hit_check():
		if range_result == RANGE_MISS_FACING:
			lines.append("%s 背向目标，未能命中。" % card.display_name)
			_apply_resolved_positions(actor, target, sim)
			return lines
		if range_result == RANGE_MISS_RANGE:
			lines.append("%s 因距离 %d 不合式，未能命中。" % [card.display_name, current_distance])
			_apply_resolved_positions(actor, target, sim)
			return lines
		if range_result == RANGE_GRAZE:
			lines.append("%s 距离 %d 略失准头，只擦中目标。" % [card.display_name, current_distance])

	var raw_damage: int = int(CombatResolver.resolve_card_effect(card, range_result, actor.is_broken(), target.is_broken(), 0).get("damage", 0))
	var final_damage: int = absi(int(sim.get("enemy_hp_delta", 0))) if int(sim.get("enemy_hp_delta", 0)) < 0 else 0
	var blocked: int = maxi(raw_damage - final_damage, 0)
	if blocked > 0:
		target.guard_points = maxi(target.guard_points - blocked, 0)
		lines.append("%s 被格挡化去 %d。" % [card.display_name, blocked])
	if raw_damage > 0:
		if target.is_broken():
			lines.append("%s 处于崩势，所受伤害翻倍至 %d。" % [target.data.display_name, raw_damage])
		if final_damage > 0:
			target.hp = maxi(target.hp - final_damage, 0)
			lines.append("%s 命中，造成 %d 伤害。" % [card.display_name, final_damage])
		else:
			lines.append("%s 被完全格挡。" % card.display_name)
	elif card.requires_hit_check() and range_result == RANGE_HIT:
		lines.append("%s 命中。" % card.display_name)

	var momentum_gain: int = int(sim.get("player_momentum_delta", 0))
	if momentum_gain > 0:
		var gained_momentum: int = actor.recover_momentum(momentum_gain)
		lines.append("%s 增己势 %d。" % [card.display_name, gained_momentum])
	var break_amount: int = absi(int(sim.get("enemy_momentum_delta", 0))) if int(sim.get("enemy_momentum_delta", 0)) < 0 else 0
	if break_amount > 0:
		var before_break: int = target.momentum
		target.momentum = maxi(target.momentum - break_amount, 0)
		var actual_break: int = before_break - target.momentum
		lines.append("%s 削敌势 %d。" % [card.display_name, actual_break])
		if before_break > 0 and target.momentum == 0:
			target.queue_broken_state()
			actor.queue_combo_window()
			lines.append("%s 的势被打到 0，下回合将崩势硬直！" % target.data.display_name)

	_apply_resolved_positions(actor, target, sim)
	return lines


func _fighter_to_resolver_state(fighter: Fighter) -> Dictionary:
	return {
		"hp": fighter.hp,
		"momentum": fighter.momentum,
		"guard": fighter.guard_points,
		"position": fighter.position,
		"facing": fighter.facing,
		"broken": fighter.is_broken()
	}


func _apply_resolved_positions(actor: Fighter, target: Fighter, sim: Dictionary) -> void:
	actor.position = int(sim.get("player_final", actor.position))
	target.position = int(sim.get("enemy_final", target.position))
	face_target(actor, target)
	face_target(target, actor)
	update_distance_from_positions(actor, target)


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
