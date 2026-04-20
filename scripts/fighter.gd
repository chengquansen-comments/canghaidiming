extends RefCounted
class_name Fighter

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")

var data: FighterData
var hp: int
var momentum: int
var realm: int
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []


func _init(p_data: FighterData) -> void:
	data = p_data
	hp = data.max_hp
	momentum = data.starting_momentum
	realm = data.starting_realm
	reset_for_battle()


func reset_for_battle(hand_size: int = 4) -> void:
	hp = data.max_hp
	momentum = data.starting_momentum
	realm = data.starting_realm
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


func upgrade_realm() -> bool:
	if realm >= 3:
		return false
	realm += 1
	data.starting_realm = realm
	return true


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
