extends RefCounted
class_name EnemyAI

const Fighter = preload("res://scripts/fighter.gd")
const CardData = preload("res://scripts/card_data.gd")
const IntentData = preload("res://scripts/intent_data.gd")
const HiddenMoveData = preload("res://scripts/hidden_move_data.gd")
const FeintData = preload("res://scripts/feint_data.gd")

func choose_intent(enemy: Fighter, opponent: Fighter, current_distance: int, opponent_visible_intent: IntentData) -> IntentData:
	var chosen: CardData = _pick_best_card(enemy.hand, enemy.momentum, current_distance, opponent_visible_intent)
	if chosen == null and not enemy.hand.is_empty():
		for fallback in enemy.hand:
			if fallback.momentum_cost <= enemy.momentum:
				chosen = fallback
				break
	if chosen == null:
		return IntentData.from_card(enemy, CardData.new("idle", "观势", "收束架势，回观来路", 1, 3, 0, CardData.ROLE_MOMENTUM, 1, 0, 0, 0))

	if enemy.realm > opponent.realm and enemy.hand.size() >= 2:
		var hidden := _build_simple_hidden_move(enemy.hand, enemy.momentum, chosen)
		if hidden != null:
			return IntentData.from_hidden_move(enemy, hidden, [hidden.feint.display_card, hidden.real_card])

	return IntentData.from_card(enemy, chosen)


func _pick_best_card(cards: Array[CardData], current_momentum: int, current_distance: int, opponent_visible_intent: IntentData) -> CardData:
	var best_card: CardData = null
	var best_score := -9999
	for card in cards:
		if card.momentum_cost > current_momentum:
			continue
		var score := 0
		if card.is_momentum_card():
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
		if score > best_score:
			best_score = score
			best_card = card
	return best_card


func _build_simple_hidden_move(cards: Array[CardData], current_momentum: int, actual_card: CardData) -> HiddenMoveData:
	for candidate in cards:
		if candidate != actual_card and candidate.id != actual_card.id and candidate.momentum_cost <= current_momentum and candidate.role == actual_card.role:
			var feint := FeintData.new(candidate)
			var hidden := HiddenMoveData.new(feint, actual_card)
			if hidden.is_valid():
				return hidden
	return null
