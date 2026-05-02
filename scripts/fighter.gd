extends RefCounted
class_name Fighter

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")

const CONTROL_NONE := "none"
const CONTROL_BROKEN := "broken_posture"
const BATTLE_DECK_SLOT_COUNT := 4
const BATTLE_DECK_CARD_COPY_LIMIT := 2

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
var position: int
var facing: String
var qinggong: int
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []
var selected_battle_deck: Array[CardData] = []
var battle_deck_slots: Array = []
var active_battle_deck_index := 0
var battle_deck_limit: int = 0


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
	position = data.starting_position
	facing = data.starting_facing
	qinggong = data.qinggong
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
	position = data.starting_position
	facing = data.starting_facing
	qinggong = data.qinggong
	draw_pile = get_battle_deck()
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


func set_battle_deck_limit(limit: int) -> void:
	battle_deck_limit = maxi(limit, 0)
	if battle_deck_limit > 0:
		_ensure_battle_deck_slots()
	if battle_deck_limit > 0 and selected_battle_deck.size() > battle_deck_limit:
		var trimmed: Array[CardData] = []
		for i in range(battle_deck_limit):
			trimmed.append(selected_battle_deck[i].duplicate_card())
		selected_battle_deck = trimmed
	if selected_battle_deck.is_empty():
		reset_battle_deck_to_default()


func reset_battle_deck_to_default() -> void:
	selected_battle_deck.clear()
	var default_deck := _default_limited_battle_deck()
	for card in default_deck:
		selected_battle_deck.append(card.duplicate_card())
	if battle_deck_limit > 0:
		_ensure_battle_deck_slots()
		active_battle_deck_index = 0
		battle_deck_slots[0] = _duplicate_cards(selected_battle_deck)


func get_selected_battle_deck() -> Array[CardData]:
	_sync_selected_from_active_slot()
	var result: Array[CardData] = []
	for card in selected_battle_deck:
		if card != null:
			result.append(card.duplicate_card())
	return result


func get_battle_deck() -> Array[CardData]:
	_sync_selected_from_active_slot()
	if selected_battle_deck.is_empty():
		if battle_deck_limit > 0:
			return _default_limited_battle_deck()
		return data.clone_deck()
	return get_selected_battle_deck()


func get_battle_deck_size() -> int:
	_sync_selected_from_active_slot()
	if selected_battle_deck.is_empty():
		if battle_deck_limit > 0:
			return _default_limited_battle_deck().size()
		return data.starting_deck.size()
	return selected_battle_deck.size()


func set_selected_battle_deck(cards: Array[CardData]) -> void:
	selected_battle_deck.clear()
	for card in cards:
		if card == null:
			continue
		if battle_deck_limit > 0 and selected_battle_deck.size() >= battle_deck_limit:
			break
		if battle_deck_limit > 0 and _card_count_in_cards(selected_battle_deck, card.id) >= BATTLE_DECK_CARD_COPY_LIMIT:
			continue
		selected_battle_deck.append(card.duplicate_card())
	if battle_deck_limit > 0:
		_ensure_battle_deck_slots()
		battle_deck_slots[active_battle_deck_index] = _duplicate_cards(selected_battle_deck)


func add_card_to_battle_deck(card: CardData, slot_index: int = -1) -> bool:
	if card == null:
		return false
	if battle_deck_limit <= 0:
		selected_battle_deck.append(card.duplicate_card())
		return true
	_ensure_battle_deck_slots()
	var target_index := _normalized_slot_index(slot_index)
	var deck: Array[CardData] = _slot_deck(target_index)
	if deck.size() >= battle_deck_limit:
		return false
	if _card_count_in_cards(deck, card.id) >= BATTLE_DECK_CARD_COPY_LIMIT:
		return false
	deck.append(card.duplicate_card())
	battle_deck_slots[target_index] = deck
	if target_index == active_battle_deck_index:
		selected_battle_deck = _duplicate_cards(deck)
	return true


func remove_battle_deck_card(index: int, slot_index: int = -1) -> bool:
	if battle_deck_limit <= 0:
		if index < 0 or index >= selected_battle_deck.size():
			return false
		selected_battle_deck.remove_at(index)
		return true
	_ensure_battle_deck_slots()
	var target_index := _normalized_slot_index(slot_index)
	var deck: Array[CardData] = _slot_deck(target_index)
	if index < 0 or index >= deck.size():
		return false
	deck.remove_at(index)
	battle_deck_slots[target_index] = deck
	if target_index == active_battle_deck_index:
		selected_battle_deck = _duplicate_cards(deck)
	return true


func get_battle_deck_slots() -> Array:
	_ensure_battle_deck_slots()
	var result: Array = []
	for slot in battle_deck_slots:
		result.append(_duplicate_cards(slot as Array))
	return result


func set_battle_deck_slots(slots: Array, active_index: int = 0) -> void:
	battle_deck_slots.clear()
	for i in range(BATTLE_DECK_SLOT_COUNT):
		var source: Array = slots[i] if i < slots.size() and slots[i] is Array else []
		battle_deck_slots.append(_sanitize_slot_deck(source))
	active_battle_deck_index = clampi(active_index, 0, BATTLE_DECK_SLOT_COUNT - 1)
	selected_battle_deck = _slot_deck(active_battle_deck_index)


func set_active_battle_deck_index(index: int) -> void:
	_ensure_battle_deck_slots()
	active_battle_deck_index = clampi(index, 0, BATTLE_DECK_SLOT_COUNT - 1)
	selected_battle_deck = _slot_deck(active_battle_deck_index)


func get_active_battle_deck_index() -> int:
	_ensure_battle_deck_slots()
	return active_battle_deck_index


func get_battle_deck_slot(index: int) -> Array[CardData]:
	_ensure_battle_deck_slots()
	return _slot_deck(_normalized_slot_index(index))


func replace_cards_in_session_deck(first_index: int, second_index: int, replacement: CardData) -> bool:
	if first_index == second_index:
		return false
	if first_index < 0 or second_index < 0:
		return false
	if first_index >= data.starting_deck.size() or second_index >= data.starting_deck.size():
		return false
	var first_id := data.starting_deck[first_index].id
	var second_id := data.starting_deck[second_index].id
	var lower := mini(first_index, second_index)
	var upper := maxi(first_index, second_index)
	data.starting_deck.remove_at(upper)
	data.starting_deck.remove_at(lower)
	data.starting_deck.append(replacement.duplicate_card())
	_replace_selected_cards_after_fusion(first_id, second_id, replacement)
	return true


func _replace_selected_cards_after_fusion(first_id: String, second_id: String, replacement: CardData) -> void:
	if battle_deck_limit > 0:
		_ensure_battle_deck_slots()
		for i in range(battle_deck_slots.size()):
			var deck: Array[CardData] = _slot_deck(i)
			var removed := _remove_one_card_from_array(deck, first_id)
			removed = _remove_one_card_from_array(deck, second_id) or removed
			if removed and replacement != null and deck.size() < battle_deck_limit and _card_count_in_cards(deck, replacement.id) < BATTLE_DECK_CARD_COPY_LIMIT:
				deck.append(replacement.duplicate_card())
			battle_deck_slots[i] = deck
		selected_battle_deck = _slot_deck(active_battle_deck_index)
		return
	if selected_battle_deck.is_empty():
		return
	var removed := _remove_one_selected_card(first_id)
	removed = _remove_one_selected_card(second_id) or removed
	if removed and replacement != null:
		add_card_to_battle_deck(replacement)


func _remove_one_selected_card(card_id: String) -> bool:
	for i in range(selected_battle_deck.size()):
		var card: CardData = selected_battle_deck[i]
		if card != null and card.id == card_id:
			selected_battle_deck.remove_at(i)
			return true
	return false


func _ensure_battle_deck_slots() -> void:
	if battle_deck_limit <= 0:
		return
	if battle_deck_slots.size() == BATTLE_DECK_SLOT_COUNT:
		active_battle_deck_index = clampi(active_battle_deck_index, 0, BATTLE_DECK_SLOT_COUNT - 1)
		if selected_battle_deck.is_empty() and not (battle_deck_slots[active_battle_deck_index] as Array).is_empty():
			selected_battle_deck = _slot_deck(active_battle_deck_index)
		return
	var existing_active := get_selected_battle_deck() if not selected_battle_deck.is_empty() else _default_limited_battle_deck()
	battle_deck_slots.clear()
	battle_deck_slots.append(_sanitize_slot_deck(existing_active))
	for _i in range(BATTLE_DECK_SLOT_COUNT - 1):
		battle_deck_slots.append([])
	active_battle_deck_index = 0
	selected_battle_deck = _slot_deck(active_battle_deck_index)


func _sync_selected_from_active_slot() -> void:
	if battle_deck_limit <= 0 or battle_deck_slots.is_empty():
		return
	active_battle_deck_index = clampi(active_battle_deck_index, 0, battle_deck_slots.size() - 1)
	selected_battle_deck = _slot_deck(active_battle_deck_index)


func _default_limited_battle_deck() -> Array[CardData]:
	var result: Array[CardData] = []
	if battle_deck_limit <= 0:
		return data.clone_deck()
	var unique_cards := _unique_session_cards()
	while result.size() < battle_deck_limit:
		var added := false
		for card in unique_cards:
			if result.size() >= battle_deck_limit:
				break
			if card != null and _card_count_in_cards(result, card.id) < BATTLE_DECK_CARD_COPY_LIMIT:
				result.append(card.duplicate_card())
				added = true
		if not added:
			break
	return result


func _unique_session_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}
	for card in data.starting_deck:
		if card == null or seen.has(card.id):
			continue
		seen[card.id] = true
		result.append(card.duplicate_card())
	return result


func _sanitize_slot_deck(cards: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for card_variant in cards:
		if not (card_variant is CardData):
			continue
		var card: CardData = card_variant
		if battle_deck_limit > 0 and result.size() >= battle_deck_limit:
			break
		if battle_deck_limit > 0 and _card_count_in_cards(result, card.id) >= BATTLE_DECK_CARD_COPY_LIMIT:
			continue
		result.append(card.duplicate_card())
	return result


func _slot_deck(index: int) -> Array[CardData]:
	if index < 0 or index >= battle_deck_slots.size() or not (battle_deck_slots[index] is Array):
		return []
	return _duplicate_cards(battle_deck_slots[index] as Array)


func _duplicate_cards(cards: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for card_variant in cards:
		if card_variant is CardData:
			result.append((card_variant as CardData).duplicate_card())
	return result


func _normalized_slot_index(slot_index: int) -> int:
	if slot_index < 0:
		return active_battle_deck_index
	return clampi(slot_index, 0, BATTLE_DECK_SLOT_COUNT - 1)


func _card_count_in_cards(cards: Array, card_id: String) -> int:
	var count := 0
	for card_variant in cards:
		if card_variant is CardData and (card_variant as CardData).id == card_id:
			count += 1
	return count


func _remove_one_card_from_array(cards: Array[CardData], card_id: String) -> bool:
	for i in range(cards.size()):
		var card: CardData = cards[i]
		if card != null and card.id == card_id:
			cards.remove_at(i)
			return true
	return false


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


func set_stance(target_position: int, target_facing: String) -> void:
	position = clampi(target_position, 0, 8)
	facing = "left" if target_facing == "left" else "right"


func preferred_text() -> String:
	var chunks: Array[String] = []
	for value in data.preferred_distances:
		chunks.append(str(value))
	return " / ".join(chunks)
