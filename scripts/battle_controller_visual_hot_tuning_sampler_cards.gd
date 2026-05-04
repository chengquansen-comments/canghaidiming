extends "res://scripts/battle_controller_visual_hot_tuning_sampler_core.gd"

# Extracted sampler card materialization layer.

func _cards_from_config(config: Dictionary, source_cards: Array[CardData], side: String = "") -> Array[CardData]:
	var deck_key := "%s_deck" % side
	if side != "" and config.has(deck_key):
		var deck_entries: Array = config.get(deck_key, [])
		if not deck_entries.is_empty():
			return _cards_from_deck_entries(deck_entries, source_cards)
	var cards: Array[CardData] = []
	var card_numbers: Dictionary = config.get("cards", {})
	for source: CardData in source_cards:
		if source == null:
			continue
		var copy := source.duplicate_card()
		if card_numbers.has(copy.id):
			_apply_card_numbers(copy, card_numbers[copy.id])
		cards.append(copy)
	return cards

func _cards_from_deck_entries(deck_entries: Array, source_cards: Array[CardData]) -> Array[CardData]:
	var cards: Array[CardData] = []
	var catalog := _card_catalog_by_id(source_cards)
	for entry_variant in deck_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var card_id := str(entry.get("card_id", entry.get("id", "")))
		var card: CardData = null
		if catalog.has(card_id):
			card = (catalog[card_id] as CardData).duplicate_card()
		else:
			card = _card_from_numbers(card_id, str(entry.get("name", card_id)), entry.get("numbers", {}))
		_apply_card_numbers(card, entry.get("numbers", {}))
		cards.append(card)
	return cards

func _card_catalog_by_id(extra_cards: Array[CardData] = []) -> Dictionary:
	var catalog := {}
	for card: CardData in extra_cards:
		if card != null and not catalog.has(card.id):
			catalog[card.id] = card
	for card: CardData in _all_runtime_cards():
		if card != null and not catalog.has(card.id):
			catalog[card.id] = card
	return catalog

func _card_from_numbers(card_id: String, display_name: String, numbers: Dictionary) -> CardData:
	return HotTuningCardDataScript.new(
		card_id,
		display_name,
		display_name,
		clampi(int(numbers.get("min_distance", 1)), 0, 8),
		clampi(int(numbers.get("max_distance", 3)), 0, 8),
		maxi(0, int(numbers.get("momentum_cost", 1))),
		str(numbers.get("role", CardData.ROLE_GUARD)),
		maxi(0, int(numbers.get("gain_momentum", 0))),
		maxi(0, int(numbers.get("break_momentum", 0))),
		maxi(0, int(numbers.get("damage", 0))),
		maxi(0, int(numbers.get("guard", 0))),
		PackedStringArray(),
		str(numbers.get("weapon_style", "")),
		bool(numbers.get("requires_facing", true)),
		clampi(int(numbers.get("self_move_after", 0)), -1, 1),
		clampi(int(numbers.get("target_push_after", 0)), 0, 1),
		clampi(int(numbers.get("target_pull_after", 0)), 0, 1),
		str(numbers.get("move_condition", CardData.MOVE_NONE))
	)

func _sampler_state_from_numbers(numbers: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"hp": int(numbers.get("max_hp", 24)),
		"max_momentum": int(numbers.get("max_momentum", 10)),
		"momentum": int(numbers.get("momentum", 6)),
		"realm": int(numbers.get("realm", 1)),
		"qinggong": maxi(1, int(numbers.get("qinggong", 1))),
		"position": int(fallback.get("position", 2)),
		"facing": str(fallback.get("facing", "right")),
		"style": str(numbers.get("style", "spear"))
	}

func _number_config_score(result: Dictionary, target: Dictionary) -> float:
	var target_win := float(target.get("player_win_rate", 0.55))
	var turn_target := float(target.get("turn_target", 7.0))
	var draw_weight := float(target.get("draw_weight", 0.5))
	return abs(float(result.get("player_win_rate", 0.0)) - target_win) * 3.0 + abs(float(result.get("avg_turns", 0.0)) - turn_target) / 10.0 + float(result.get("draw_rate", 0.0)) * draw_weight
