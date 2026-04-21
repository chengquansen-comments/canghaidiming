extends RefCounted
class_name Fighter

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")

const CONTROL_NONE := "none"
const CONTROL_BROKEN := "broken_posture"

var data: FighterData
var hp: int
var momentum: int
var realm: int
var session_realm: int
var guard_points: int
var control_state: String
var pending_control_state: String
var combo_window_active: bool
var pending_combo_window: bool
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []


func _init(p_data: FighterData) -> void:
	data = p_data
	hp = data.max_hp
	momentum = data.starting_momentum
	session_realm = data.starting_realm
	realm = session_realm
	guard_points = 0
	control_state = CONTROL_NONE
	pending_control_state = CONTROL_NONE
	combo_window_active = false
	pending_combo_window = false
	reset_for_battle()


func reset_for_battle(hand_size: int = 4) -> void:
	hp = data.max_hp
	momentum = data.starting_momentum
	realm = session_realm
	guard_points = 0
	control_state = CONTROL_NONE
	pending_control_state = CONTROL_NONE
	combo_window_active = false
	pending_combo_window = false
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


func set_control_state(value: String) -> void:
	control_state = value


func queue_broken_state() -> void:
	pending_control_state = CONTROL_BROKEN


func queue_combo_window() -> void:
	pending_combo_window = true


func activate_pending_round_state() -> void:
	control_state = pending_control_state
	pending_control_state = CONTROL_NONE
	combo_window_active = pending_combo_window
	pending_combo_window = false


func consume_combo_window() -> void:
	combo_window_active = false


func is_broken() -> bool:
	return control_state == CONTROL_BROKEN


func control_label() -> String:
	if control_state == CONTROL_BROKEN:
		return "崩势"
	return "无"


func combo_window_label() -> String:
	return "可触发" if combo_window_active else "无"


func reset_guard() -> void:
	guard_points = 0


func add_guard(amount: int) -> int:
	guard_points += maxi(amount, 0)
	return guard_points


func absorb_damage(amount: int) -> int:
	var incoming := maxi(amount, 0)
	var absorbed := mini(guard_points, incoming)
	guard_points -= absorbed
	return incoming - absorbed


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
