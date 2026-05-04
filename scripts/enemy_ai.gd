extends RefCounted
class_name EnemyAI

const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const HiddenMoveData = preload("res://scripts/hidden_move_data.gd")
const FeintData = preload("res://scripts/feint_data.gd")

var manifest_intent_weights: Dictionary = {}
var manifest_phase_behaviors: Array = []
var manifest_behavior_source := "builtin"

func set_manifest_behavior(intent_weights: Dictionary, phase_behaviors: Array) -> void:
	manifest_intent_weights = intent_weights.duplicate(true)
	manifest_phase_behaviors = phase_behaviors.duplicate(true)
	manifest_behavior_source = "enemy_manifest" if not manifest_intent_weights.is_empty() or not manifest_phase_behaviors.is_empty() else "builtin"

func clear_manifest_behavior() -> void:
	manifest_intent_weights.clear()
	manifest_phase_behaviors.clear()
	manifest_behavior_source = "builtin"

func choose_intent(enemy: Fighter, opponent: Fighter, current_distance: int, opponent_visible_intent: IntentData) -> IntentData:
	if enemy.is_broken():
		var stagger := IntentData.from_card(enemy, CardData.new("staggered", "崩势硬直", "崩势未稳，无法行动", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0))
		_assign_best_stance(stagger, enemy, opponent, stagger.actual_card)
		return stagger

	var chosen: CardData = _pick_best_card(enemy, enemy.hand, enemy.momentum, current_distance, opponent_visible_intent)
	if chosen == null and not enemy.hand.is_empty():
		for fallback in enemy.hand:
			if _can_play_card(enemy, fallback):
				chosen = fallback
				break
	if chosen == null:
		var idle := IntentData.from_card(enemy, CardData.new("idle", "不动", "没有合适的招式时保持架势。", 0, 8, 0, CardData.ROLE_GUARD, 0, 0, 0, 0))
		_assign_best_stance(idle, enemy, opponent, idle.actual_card)
		return idle

	if _should_use_hidden_move(enemy, opponent) and enemy.hand.size() >= 2:
		var hidden := _build_simple_hidden_move(enemy, enemy.hand, enemy.momentum, chosen)
		if hidden != null:
			var hidden_intent := IntentData.from_hidden_move(enemy, hidden, [hidden.feint.display_card, hidden.real_card])
			_assign_best_stance(hidden_intent, enemy, opponent, hidden.real_card)
			return hidden_intent

	var intent := IntentData.from_card(enemy, chosen)
	_assign_best_stance(intent, enemy, opponent, chosen)
	return intent


func _can_play_card(fighter: Fighter, card: CardData) -> bool:
	return card.momentum_cost <= fighter.momentum


func _pick_best_card(enemy: Fighter, cards: Array[CardData], current_momentum: int, current_distance: int, opponent_visible_intent: IntentData) -> CardData:
	var best_card: CardData = null
	var best_score := -9999.0
	for card in cards:
		if card.momentum_cost > current_momentum or not _can_play_card(enemy, card):
			continue
		var score := float(_base_card_score(enemy, card, current_distance, opponent_visible_intent))
		score += _manifest_intent_score(enemy, card, opponent_visible_intent)
		score += _manifest_phase_score(enemy, card)
		if score > best_score:
			best_score = score
			best_card = card
	return best_card

func _base_card_score(enemy: Fighter, card: CardData, current_distance: int, opponent_visible_intent: IntentData) -> int:
	var score := 0
	if card.is_feint_card():
		score += card.gain_momentum * 2 + card.break_momentum * 2
	if card.is_damage_card():
		score += card.damage
		if card.is_usable_at(current_distance):
			score += 4
		else:
			score -= 4
	if card.is_guard_card():
		score += card.guard
		if opponent_visible_intent != null and opponent_visible_intent.actual_card != null and opponent_visible_intent.actual_card.damage > 0:
			score += 2
	if card.has_tag("先机"):
		score += 3
	if opponent_visible_intent != null and opponent_visible_intent.has_senki() and card.has_tag("先机"):
		score += 2
	return score

func _manifest_intent_score(enemy: Fighter, card: CardData, opponent_visible_intent: IntentData) -> float:
	if manifest_intent_weights.is_empty():
		return 0.0
	var score := 0.0
	if card.is_feint_card():
		score += float(manifest_intent_weights.get("gain_posture", 0.0)) * float(card.gain_momentum) * 10.0
		score += float(manifest_intent_weights.get("break_posture", 0.0)) * float(card.break_momentum) * 10.0
	if card.is_damage_card():
		score += float(manifest_intent_weights.get("attack", 0.0)) * float(card.damage) * 4.0
	if card.is_guard_card():
		score += float(manifest_intent_weights.get("guard", 0.0)) * float(card.guard) * 4.0
		if opponent_visible_intent != null and opponent_visible_intent.actual_card != null and opponent_visible_intent.actual_card.damage > 0:
			score += float(manifest_intent_weights.get("guard", 0.0)) * 6.0
	if _card_has_feint_signal(card):
		score += float(manifest_intent_weights.get("feint", 0.0)) * 12.0
	return score

func _manifest_phase_score(enemy: Fighter, card: CardData) -> float:
	var phase: Dictionary = _active_phase_behavior(enemy)
	if phase.is_empty():
		return 0.0
	var bias := str(phase.get("intent_bias", ""))
	var score := 0.0
	match bias:
		"tutorial":
			if card.is_guard_card(): score += 1.0
			if card.is_damage_card(): score -= 1.0
		"desperate_attack", "burst_chain", "desperate_clue":
			if card.is_damage_card(): score += 8.0 + float(card.damage)
			if card.has_tag("线索"): score += 6.0
		"poke_pressure":
			if card.is_feint_card(): score += 4.0
			if card.is_damage_card(): score += 3.0
		"guard_then_poke", "guard_counter":
			if card.is_guard_card(): score += 6.0
			if card.has_tag("反击"): score += 5.0
		"counter_break":
			if card.break_momentum > 0: score += 6.0
			if card.has_tag("反击"): score += 5.0
		"feint_pressure":
			if _card_has_feint_signal(card): score += 6.0
			if card.break_momentum > 0: score += 3.0
		"fallback":
			if card.is_feint_card(): score += 1.0
		_:
			pass
	return score

func _active_phase_behavior(enemy: Fighter) -> Dictionary:
	if manifest_phase_behaviors.is_empty() or enemy == null or enemy.data.max_hp <= 0:
		return {}
	var hp_ratio := float(enemy.hp) / float(enemy.data.max_hp)
	var best: Dictionary = {}
	var best_threshold := 2.0
	for phase_variant in manifest_phase_behaviors:
		if not (phase_variant is Dictionary):
			continue
		var phase: Dictionary = phase_variant
		var threshold := float(phase.get("hp_below", 1.01))
		if hp_ratio <= threshold and threshold < best_threshold:
			best = phase
			best_threshold = threshold
	return best

func _should_use_hidden_move(enemy: Fighter, opponent: Fighter) -> bool:
	if enemy.realm <= opponent.realm:
		return false
	var feint_weight := float(manifest_intent_weights.get("feint", 0.0))
	if feint_weight > 0.0:
		return true
	var phase: Dictionary = _active_phase_behavior(enemy)
	var bias := str(phase.get("intent_bias", ""))
	return bias.find("feint") >= 0

func _card_has_feint_signal(card: CardData) -> bool:
	return card.has_tag("虚招") or card.has_tag("先机") or card.has_tag("线索")


func _assign_best_stance(intent: IntentData, enemy: Fighter, opponent: Fighter, card: CardData) -> void:
	var best_position := enemy.position
	var best_facing := _facing_toward(enemy.position, opponent.position, enemy.facing)
	var best_score := -9999
	for target_position in _candidate_positions(enemy, opponent):
		for target_facing in ["left", "right"]:
			var score := _stance_score(enemy, opponent, card, target_position, target_facing)
			if score > best_score:
				best_score = score
				best_position = target_position
				best_facing = target_facing
	intent.set_stance(best_position, best_facing)


func _candidate_positions(fighter: Fighter, opponent: Fighter = null) -> Array[int]:
	var result: Array[int] = []
	var start := clampi(fighter.position - fighter.qinggong, 0, 8)
	var finish := clampi(fighter.position + fighter.qinggong, 0, 8)
	for slot in range(start, finish + 1):
		if opponent != null and slot == opponent.position:
			continue
		result.append(slot)
	if result.is_empty():
		result.append(fighter.position)
	return result


func _stance_score(enemy: Fighter, opponent: Fighter, card: CardData, target_position: int, target_facing: String) -> int:
	var distance := absi(opponent.position - target_position)
	var score := 0
	if card != null and card.requires_hit_check():
		if distance >= card.min_distance and distance <= card.max_distance:
			score += 16
		elif absi(distance - card.min_distance) == 1 or absi(distance - card.max_distance) == 1:
			score += 5
		else:
			score -= 8
		if card.requires_facing and not card.has_tag("回身") and not _faces_position(target_position, target_facing, opponent.position):
			score -= 12
	for preferred in enemy.data.preferred_distances:
		score -= absi(distance - preferred)
	if target_facing == _facing_toward(target_position, opponent.position, target_facing):
		score += 2
	score -= absi(target_position - enemy.position)
	return score


func _faces_position(actor_position: int, actor_facing: String, target_position: int) -> bool:
	if actor_position == target_position:
		return true
	if target_position > actor_position:
		return actor_facing == "right"
	return actor_facing == "left"


func _facing_toward(actor_position: int, target_position: int, fallback: String) -> String:
	if target_position == actor_position:
		return fallback
	return "right" if target_position > actor_position else "left"


func _build_simple_hidden_move(enemy: Fighter, cards: Array[CardData], current_momentum: int, actual_card: CardData) -> HiddenMoveData:
	for candidate in cards:
		if candidate != actual_card and candidate.id != actual_card.id and candidate.momentum_cost <= current_momentum and candidate.role == actual_card.role and _can_play_card(enemy, candidate):
			var feint := FeintData.new(candidate)
			var hidden := HiddenMoveData.new(feint, actual_card)
			if hidden.is_valid():
				return hidden
	return null
