extends "res://scripts/battle_controller_visual_hot_tuning_profile_collect.gd"

# Extracted hot tuning number profile snapshot layer.

func _snapshot_number_config(label: String) -> Dictionary:
	return {
		"schema_version": NUMBER_PROFILE_SCHEMA,
		"id": _new_number_config_id(),
		"name": label,
		"encounter_id": _current_tuning_encounter_id(),
		"player": _fighter_number_snapshot(player),
		"enemy": _fighter_number_snapshot(enemy),
		"player_deck": _deck_snapshot(player),
		"enemy_deck": _deck_snapshot(enemy),
		"cards": _card_number_snapshot(),
		"created_msec": Time.get_ticks_msec()
	}

func _fighter_number_snapshot(fighter: Fighter) -> Dictionary:
	if fighter == null or fighter.data == null:
		return {}
	return {
		"max_hp": fighter.data.max_hp,
		"hp": fighter.hp,
		"max_momentum": fighter.data.max_momentum,
		"momentum": fighter.momentum,
		"realm": fighter.realm,
		"qinggong": maxi(1, fighter.qinggong),
		"preferred": _preferred_for_fighter(fighter, _style_for_fighter(fighter, "spear")),
		"style": _style_for_fighter(fighter, "spear")
	}

func _card_number_snapshot() -> Dictionary:
	var result := {}
	for runtime_card: CardData in _all_runtime_cards():
		if runtime_card == null:
			continue
		result[runtime_card.id] = _card_numbers(runtime_card)
	return result

func _deck_snapshot(fighter: Fighter) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if fighter == null or fighter.data == null:
		return result
	var source_cards: Array[CardData] = fighter.data.starting_deck
	if source_cards.is_empty():
		source_cards = _export_cards(fighter)
	for card: CardData in source_cards:
		if card == null:
			continue
		result.append({
			"card_id": card.id,
			"name": card.display_name,
			"numbers": _card_numbers(card)
		})
	return result

func _card_numbers(card: CardData) -> Dictionary:
	return {
		"role": card.role,
		"weapon_style": card.weapon_style,
		"requires_facing": card.requires_facing,
		"min_distance": card.min_distance,
		"max_distance": card.max_distance,
		"momentum_cost": card.momentum_cost,
		"gain_momentum": card.gain_momentum,
		"break_momentum": card.break_momentum,
		"damage": card.damage,
		"guard": card.guard,
		"self_move_after": card.self_move_after,
		"target_push_after": card.target_push_after,
		"target_pull_after": card.target_pull_after,
		"move_condition": card.move_condition
	}

func _number_config_diff(base: Dictionary, candidate: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var base_enemy: Dictionary = base.get("enemy", {})
	var next_enemy: Dictionary = candidate.get("enemy", {})
	for field in ["max_hp", "max_momentum", "momentum", "realm", "qinggong"]:
		if int(base_enemy.get(field, 0)) != int(next_enemy.get(field, 0)):
			lines.append("敌%s %d→%d" % [field, int(base_enemy.get(field, 0)), int(next_enemy.get(field, 0))])
	var base_cards: Dictionary = base.get("cards", {})
	var next_cards: Dictionary = candidate.get("cards", {})
	for card_id in next_cards.keys():
		if not base_cards.has(card_id):
			continue
		var b: Dictionary = base_cards[card_id]
		var n: Dictionary = next_cards[card_id]
		var parts: Array[String] = []
		for field in ["momentum_cost", "gain_momentum", "break_momentum", "damage", "guard", "min_distance", "max_distance"]:
			if int(b.get(field, 0)) != int(n.get(field, 0)):
				parts.append("%s %d→%d" % [field, int(b.get(field, 0)), int(n.get(field, 0))])
		if not parts.is_empty():
			lines.append("%s: %s" % [card_id, ", ".join(parts)])
	_append_deck_diff(lines, base.get("player_deck", []), candidate.get("player_deck", []), "我方卡组")
	_append_deck_diff(lines, base.get("enemy_deck", []), candidate.get("enemy_deck", []), "敌方卡组")
	return lines

func _append_deck_diff(lines: Array[String], base_deck: Array, next_deck: Array, label: String) -> void:
	var base_counts := _deck_counts(base_deck)
	var next_counts := _deck_counts(next_deck)
	var all_ids := {}
	for id in base_counts.keys():
		all_ids[id] = true
	for id in next_counts.keys():
		all_ids[id] = true
	var parts: Array[String] = []
	for id in all_ids.keys():
		var before := int(base_counts.get(id, 0))
		var after := int(next_counts.get(id, 0))
		if before != after:
			parts.append("%s %d→%d" % [str(id), before, after])
	if not parts.is_empty():
		lines.append("%s：%s" % [label, ", ".join(parts)])

func _deck_counts(deck_entries: Array) -> Dictionary:
	var counts := {}
	for entry_variant in deck_entries:
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			var card_id := str(entry.get("card_id", entry.get("id", "")))
			if card_id != "":
				counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts
