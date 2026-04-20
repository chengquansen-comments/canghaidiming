extends RefCounted
class_name Fighter

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")

var data: FighterData
var hp: int
var momentum: int
var realm: int
var session_realm: int
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []


func _init(p_data: FighterData) -> void:
	data = p_data
	hp = data.max_hp
	momentum = data.starting_momentum
	session_realm = data.starting_realm
	realm = session_realm
	reset_for_battle()


func reset_for_battle(hand_size: int = 4) -> void:
	hp = data.max_hp
	momentum = data.starting_momentum
	realm = session_realm
	draw_pile = data.clone_deck()
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()
	draw_to(hand_size)


func draw_to(target_size: int) -> void:
	while hand.size() < target_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())


func discard_cards(cards: Array[CardData]) -> void:
	for card in cards:
		var index: int = hand.find(card)
		if index >= 0:
			discard_pile.append(hand[index])
			hand.remove_at(index)


func add_card_to_deck(card: CardData) -> void:
	data.starting_deck.append(card.duplicate_card())


func get_session_deck() -> Array[CardData]:
	return data.clone_deck()


func replace_cards_in_session_deck(first_index: int, second_index: int, replacement: CardData) -> bool:
	if first_index == second_index:
		return false
	if first_index < 0 or second_index < 0:
		return false
	if first_index >= data.starting_deck.size() or second_index >= data.starting_deck.size():
		return false
	var lower := mini(first_index, second_index)
	var upper := maxi(first_index, second_index)
	data.starting_deck.remove_at(upper)
	data.starting_deck.remove_at(lower)
	data.starting_deck.append(replacement.duplicate_card())
	return true


func upgrade_realm() -> bool:
	if session_realm >= 3:
		return false
	session_realm += 1
	realm = session_realm
	return true


func set_session_realm(value: int) -> void:
	session_realm = maxi(value, 1)
	realm = session_realm


func recover_momentum(amount: int) -> int:
	var before := momentum
	momentum = clampi(momentum + amount, 0, data.max_momentum)
	return momentum - before


func spend_momentum(amount: int) -> bool:
	if amount > momentum:
		return false
	momentum -= amount
	return true


func preferred_text() -> String:
	var chunks: Array[String] = []
	for value in data.preferred_distances:
		chunks.append(str(value))
	return " / ".join(chunks)
