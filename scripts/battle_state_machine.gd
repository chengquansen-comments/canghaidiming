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


func update_distance_from_positions(player: Fighter, enemy: Fighter) -> int:
	if player == null or enemy == null:
		return current_distance
	current_distance = absi(enemy.position - player.position)
	return current_distance


func direction_toward(actor_pos: int, target_pos: int, fallback_facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if fallback_facing == "right" else -1


func apply_self_move(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount == 0:
		return
	var dir := direction_toward(actor.position, target.position, actor.facing)
	if amount > 0:
		actor.position += dir
	else:
		actor.position -= dir
	actor.position = clampi(actor.position, 0, 8)


func apply_push_target(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount <= 0:
		return
	var dir := direction_toward(actor.position, target.position, actor.facing)
	target.position += dir * amount
	target.position = clampi(target.position, 0, 8)


func apply_pull_target(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount <= 0:
		return
	var dir := direction_toward(actor.position, target.position, actor.facing)
	target.position -= dir * amount
	target.position = clampi(target.position, 0, 8)


func face_target(actor: Fighter, target: Fighter) -> void:
	if target.position > actor.position:
		actor.facing = "right"
	elif target.position < actor.position:
		actor.facing = "left"


func apply_card_movement(card: CardData, actor: Fighter, target: Fighter, range_result: String) -> void:
	var can_move := false
	match card.move_condition:
		CardData.MOVE_ALWAYS:
			can_move = true
		CardData.MOVE_ON_HIT:
			can_move = range_result == RANGE_HIT
		_:
			can_move = false
	if not can_move:
		return
	if card.target_push_after > 0:
		apply_push_target(actor, target, card.target_push_after)
	elif card.target_pull_after > 0:
		apply_pull_target(actor, target, card.target_pull_after)
	elif card.self_move_after != 0:
		apply_self_move(actor, target, card.self_move_after)
	face_target(actor, target)
	face_target(target, actor)
	update_distance_from_positions(actor, target)


func is_facing_target(actor: Fighter, target: Fighter) -> bool:
	if actor == null or target == null:
		return true
	if actor.position == target.position:
		return true
	if target.position > actor.position:
		return actor.facing == "right"
	return actor.facing == "left"


func evaluate_card_range(card: CardData, actor: Fighter, target: Fighter) -> String:
	if card == null or not card.requires_hit_check():
		return RANGE_HIT
	if card.requires_facing and not card.has_tag("回身") and not is_facing_target(actor, target):
		return RANGE_MISS_FACING
	var distance := absi(target.position - actor.position)
	if card.is_usable_at(distance):
		return RANGE_HIT
	var distance_gap := 0
	if distance < card.min_distance:
		distance_gap = card.min_distance - distance
	else:
		distance_gap = distance - card.max_distance
	if distance_gap == 1:
		return RANGE_GRAZE
	return RANGE_MISS_RANGE


func resolve_intent(intent: IntentData, actor: Fighter, target: Fighter) -> Array[String]:
	var lines: Array[String] = []
	if actor.hp <= 0:
		return lines

	var card: CardData = intent.actual_card
	lines.append("%s 施展 [b]%s[/b]。" % [actor.data.display_name, card.display_name])

	var range_result := RANGE_HIT

	if card.requires_hit_check():
		range_result = evaluate_card_range(card, actor, target)
		if range_result == RANGE_MISS_FACING:
			lines.append("背向目标未命中。")
			return lines
		if range_result == RANGE_MISS_RANGE:
			lines.append("距离不合未命中。")
			return lines

	if range_result == RANGE_HIT:
		target.apply_damage(card.damage)
		target.reduce_momentum(card.break_momentum)
		actor.add_momentum(card.gain_momentum)

	apply_card_movement(card, actor, target, range_result)

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
