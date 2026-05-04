extends "res://scripts/battle_controller_visual_hot_tuning_state.gd"

# Extracted hot tuning card and fighter collection layer.

func _all_runtime_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for key in fighter_catalog.keys():
		var data: FighterData = fighter_catalog[key]
		if data == null:
			continue
		for deck_card: CardData in data.starting_deck:
			if deck_card != null:
				cards.append(deck_card)
	for reward_card: CardData in reward_pool:
		if reward_card != null:
			cards.append(reward_card)
	_collect_fighter_cards(player, cards)
	_collect_fighter_cards(enemy, cards)
	return cards

func _collect_fighter_cards(fighter: Fighter, cards: Array[CardData]) -> void:
	if fighter == null:
		return
	for hand_card: CardData in fighter.hand:
		if hand_card != null:
			cards.append(hand_card)
	for draw_card: CardData in fighter.draw_pile:
		if draw_card != null:
			cards.append(draw_card)
	for discard_card: CardData in fighter.discard_pile:
		if discard_card != null:
			cards.append(discard_card)

func _fighter_label(fighter: Fighter, fallback: String) -> String:
	if fighter != null and fighter.data != null and not fighter.data.display_name.is_empty():
		return fighter.data.display_name
	return fallback

func _style_for_fighter(fighter: Fighter, fallback: String) -> String:
	if fighter == null or fighter.data == null:
		return fallback
	var weapon := fighter.data.weapon_name
	if weapon.findn("枪") >= 0 or weapon.findn("spear") >= 0:
		return "spear"
	return "blade"

func _preferred_for_fighter(fighter: Fighter, style: String) -> Array:
	if fighter != null and fighter.data != null and fighter.data.preferred_distances.size() > 0:
		var out: Array[int] = []
		for distance in fighter.data.preferred_distances:
			out.append(int(distance))
		return out
	return [3, 4, 5] if style == "spear" else [0, 1, 2]
