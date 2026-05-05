extends "res://scripts/battle_controller_visual_narrative_context_foundation.gd"

# Narrative context cards layer.

func _cards_from_configs(configs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for config_variant in configs:
		if config_variant is CardData:
			cards.append(config_variant.duplicate_card())
			continue
		var config: Dictionary = config_variant
		cards.append(CardData.new(str(config.get("id", "card")), str(config.get("name", "招式")), str(config.get("name", "")), int(config.get("min", 0)), int(config.get("max", 5)), int(config.get("cost", 1)), str(config.get("role", CardData.ROLE_GUARD)), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), PackedStringArray(config.get("tags", [])), str(config.get("style", "")), bool(config.get("facing", true)), 0, 0, 0, CardData.MOVE_NONE, int(config.get("shoushi_rank", config.get("rank", 1)))))
	return cards

func _cards_from_card_ids(card_ids) -> Array[CardData]:
	var cards: Array[CardData] = []
	var catalog: Dictionary = _story_loader_card_catalog()
	for card_id: String in _card_id_array(card_ids):
		if not catalog.has(card_id):
			push_warning("Narrative battle loadout: unknown player card id: %s" % card_id)
			continue
		var card_variant = catalog[card_id]
		if card_variant is CardData:
			cards.append((card_variant as CardData).duplicate_card())
	return cards

func _deck_slots_from_card_ids(value) -> Array:
	var slots: Array = []
	if value is Array:
		for slot_variant in value:
			slots.append(_cards_from_card_ids(slot_variant))
	return slots

func _card_ids_from_cards(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card_variant in cards:
		if card_variant is CardData:
			var card: CardData = card_variant
			if not card.id.is_empty():
				ids.append(card.id)
		elif card_variant is Dictionary:
			var config: Dictionary = card_variant
			var card_id := str(config.get("id", ""))
			if not card_id.is_empty():
				ids.append(card_id)
	return ids

func _card_id_slots_from_fighter(fighter) -> Array:
	var slots: Array = []
	if fighter == null:
		return slots
	for slot in fighter.get_battle_deck_slots():
		slots.append(_card_ids_from_cards(slot as Array))
	return slots
