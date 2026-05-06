extends RefCounted

static func build_player_numbers(
	player_martial_level: int,
	player_hp: int,
	player_posture: int,
	initial_hp: int,
	initial_martial_level: int,
	initial_qinggong: int,
	max_qinggong: int,
	initial_max_posture: int,
	max_posture: int,
	heal_full: bool
) -> Dictionary:
	var level: int = max(initial_martial_level, player_martial_level)
	var max_hp: int = initial_hp + max(0, level - initial_martial_level) * 2
	var qinggong: int = clampi(initial_qinggong + int(max(0, level - initial_martial_level) / 3), initial_qinggong, max_qinggong)
	var posture_max: int = clampi(initial_max_posture + max(0, level - initial_martial_level), initial_max_posture, max_posture)
	var hp: int = player_hp
	var posture: int = player_posture
	if heal_full:
		hp = max_hp
		posture = posture_max
	else:
		hp = clampi(hp, 0, max_hp)
		posture = clampi(posture, 0, posture_max)
	return {
		"martial_level": level,
		"max_hp": max_hp,
		"hp": hp,
		"qinggong": qinggong,
		"max_posture": posture_max,
		"posture": posture
	}

static func martial_reward_cards_for_level(player_role: String, level: int) -> Array[String]:
	var rewards: Array[String] = []
	match player_role:
		"blademaster":
			match level:
				2: rewards.append("blade_press_break")
				3: rewards.append("blade_hook_pull")
				4: rewards.append("blade_body_press")
				5: rewards.append("reward_pull")
				6: rewards.append("reward_guard")
		_:
			match level:
				2: rewards.append("spear_retreat_sting")
				3: rewards.append("spear_step_thrust")
				4: rewards.append("reward_push")
				5: rewards.append("reward_guard")
				6: rewards.append("reward_pull")
	return rewards

static func grant_martial_rewards_between(player_role: String, owned_cards: Array[String], old_level: int, new_level: int, initial_martial_level: int) -> Array[String]:
	var result: Array[String] = owned_cards.duplicate()
	for level in range(max(initial_martial_level, old_level) + 1, max(old_level, new_level) + 1):
		for card_id: String in martial_reward_cards_for_level(player_role, level):
			if not card_id.is_empty():
				result.append(card_id)
	return unique_string_array(result)

static func default_owned_cards_for_role(role_id: String) -> Array[String]:
	var cards: Array[String] = []
	if role_id == "blademaster":
		cards.append_array(["blade_front_cut", "blade_chase_cut", "blade_breathe", "blade_press_break"])
	else:
		cards.append_array(["spear_mid_thrust", "spear_line_press", "spear_focus", "spear_guard_horse"])
	return cards

static func default_loadout_for_role(role_id: String, loadout_size: int) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in default_owned_cards_for_role(role_id):
		result.append(card_id)
		result.append(card_id)
	return first_card_ids(result, loadout_size)

static func default_deck_slots_from_loadout(loadout: Array[String], deck_slot_count: int, loadout_size: int, copy_limit: int, owned_card_ids: Array[String]) -> Array:
	var slots: Array = []
	slots.append(sanitize_deck_slot(loadout, owned_card_ids, loadout_size, copy_limit))
	for _i in range(deck_slot_count - 1):
		slots.append([])
	return slots

static func deck_slots_from_variant(value) -> Array:
	var slots: Array = []
	if value is Array:
		for slot_variant in value:
			slots.append(string_array(slot_variant))
	return slots

static func sanitize_deck_slot(card_ids: Array[String], owned_card_ids: Array[String], loadout_size: int, copy_limit: int) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in card_ids:
		if result.size() >= loadout_size:
			break
		if not (card_id in owned_card_ids):
			continue
		if card_id_count(result, card_id) >= copy_limit:
			continue
		result.append(card_id)
	return result

static func sanitize_player_card_state(
	player_role: String,
	owned_card_ids: Array[String],
	selected_loadout_ids: Array[String],
	deck_slots: Array,
	active_deck_index: int,
	loadout_size: int,
	deck_slot_count: int,
	copy_limit: int
) -> Dictionary:
	var owned: Array[String] = unique_string_array(owned_card_ids)
	if owned.is_empty() and not player_role.is_empty():
		owned = default_owned_cards_for_role(player_role)
	var slots: Array = deck_slots.duplicate(true)
	if slots.is_empty():
		slots = default_deck_slots_from_loadout(selected_loadout_ids, deck_slot_count, loadout_size, copy_limit, owned)
	var sanitized_slots: Array = []
	for i in range(deck_slot_count):
		var source: Array[String] = string_array(slots[i]) if i < slots.size() else []
		sanitized_slots.append(sanitize_deck_slot(source, owned, loadout_size, copy_limit))
	var active_index: int = clampi(active_deck_index, 0, deck_slot_count - 1)
	var selected: Array[String] = (sanitized_slots[active_index] as Array).duplicate()
	return {
		"owned_card_ids": owned,
		"selected_loadout_ids": selected,
		"deck_slots": sanitized_slots,
		"active_deck_index": active_index
	}

static func first_card_ids(card_ids: Array[String], count: int) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in card_ids:
		if result.size() >= count:
			break
		result.append(card_id)
	return result

static func unique_string_array(value) -> Array[String]:
	var result: Array[String] = []
	for item: String in string_array(value):
		if not (item in result):
			result.append(item)
	return result

static func string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	elif value is String:
		var text := str(value)
		if not text.is_empty():
			result.append(text)
	return result

static func card_id_count(cards: Array[String], card_id: String) -> int:
	var count := 0
	for item: String in cards:
		if item == card_id:
			count += 1
	return count

static func profile_debug_text(profile: Dictionary, loadout_size: int) -> String:
	return "玩家数据=%s｜职业=%s｜武器=%s｜HP=%d/%d｜势=%d/%d｜轻功=%d｜武境=%d｜胜场=%d｜牌库=%d｜启用牌组=%d｜入战=%d/%d" % [
		str(profile.get("role", "")),
		str(profile.get("career", "")),
		str(profile.get("weapon", "")),
		int(profile.get("hp", 0)),
		int(profile.get("max_hp", 0)),
		int(profile.get("posture", 0)),
		int(profile.get("max_posture", 0)),
		int(profile.get("qinggong", 0)),
		int(profile.get("martial_level", 0)),
		int(profile.get("battles_won", 0)),
		(profile.get("owned_card_ids", []) as Array).size(),
		int(profile.get("active_deck_index", 0)) + 1,
		(profile.get("selected_loadout_ids", []) as Array).size(),
		loadout_size
	]
