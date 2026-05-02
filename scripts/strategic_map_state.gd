extends RefCounted

const INITIAL_MARTIAL_LEVEL := 1
const INITIAL_HP := 20
const INITIAL_QINGGONG := 1
const INITIAL_MAX_POSTURE := 3
const MAX_QINGGONG := 4
const MAX_POSTURE := 10
const PLAYER_LOADOUT_SIZE := 8
const MILITARY_TIER_THRESHOLDS := [0, 2, 5, 9, 14, 20]
const MILITARY_TIER_TITLES := ["白身", "小旗", "总旗", "百户", "副千户", "千户"]
const REPUTATION_TIER_THRESHOLDS := [0, 2, 5, 9, 13]
const REPUTATION_TIER_TITLES := ["无名", "乡里可信", "义声初起", "江湖有名", "众望所归"]

static func default_state() -> Dictionary:
	return {
		"active": false,
		"completed": false,
		"seed": 1701,
		"region_index": 0,
		"layer_index": 0,
		"selected_nodes": [],
		"current_map": {},
		"military_merit": 0,
		"clean_reputation": 0,
		"case_clues": 0,
		"martial_level": INITIAL_MARTIAL_LEVEL,
		"owned_card_ids": [],
		"selected_loadout_ids": [],
		"deck_slots": [],
		"active_deck_index": 0,
		"last_node_result": "",
		"final_boss": {},
	}

static func apply_effects(state: Dictionary, effects: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	for key in ["military_merit", "clean_reputation", "case_clues"]:
		next_state[key] = int(next_state.get(key, 0)) + int(effects.get(key, 0))
	next_state["military_merit"] = max(0, int(next_state.get("military_merit", 0)))
	next_state["clean_reputation"] = max(0, int(next_state.get("clean_reputation", 0)))
	next_state["case_clues"] = max(0, int(next_state.get("case_clues", 0)))
	next_state["martial_level"] = max(INITIAL_MARTIAL_LEVEL, int(next_state.get("martial_level", INITIAL_MARTIAL_LEVEL)))
	if effects.has("card_rewards"):
		next_state = apply_card_rewards(next_state, effects.get("card_rewards", []))
	else:
		next_state = _sanitize_card_state(next_state)
	return next_state

static func apply_battle_win(state: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var next_state := state.duplicate(true)
	next_state["martial_level"] = max(INITIAL_MARTIAL_LEVEL, int(next_state.get("martial_level", INITIAL_MARTIAL_LEVEL)) + 1)
	if not profile.is_empty():
		next_state = sync_card_state_from_profile(next_state, profile)
	else:
		next_state = _sanitize_card_state(next_state)
	return next_state

static func sync_card_state_from_profile(state: Dictionary, profile: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	if profile.has("owned_card_ids"):
		next_state["owned_card_ids"] = _string_array(profile.get("owned_card_ids", []))
	if profile.has("selected_loadout_ids"):
		next_state["selected_loadout_ids"] = _string_array(profile.get("selected_loadout_ids", []))
	if profile.has("deck_slots"):
		next_state["deck_slots"] = _deck_slots_from_variant(profile.get("deck_slots", []))
	if profile.has("active_deck_index"):
		next_state["active_deck_index"] = int(profile.get("active_deck_index", 0))
	return _sanitize_card_state(next_state)

static func apply_card_rewards(state: Dictionary, rewards) -> Dictionary:
	var next_state := state.duplicate(true)
	var owned := _string_array(next_state.get("owned_card_ids", []))
	for card_id: String in _string_array(rewards):
		if not card_id.is_empty():
			owned.append(card_id)
	next_state["owned_card_ids"] = owned
	return _sanitize_card_state(next_state)

static func max_hp_for_martial(martial_level: int) -> int:
	return INITIAL_HP + max(0, martial_level - INITIAL_MARTIAL_LEVEL) * 2

static func qinggong_for_martial(martial_level: int) -> int:
	return clampi(INITIAL_QINGGONG + int(max(0, martial_level - INITIAL_MARTIAL_LEVEL) / 3), INITIAL_QINGGONG, MAX_QINGGONG)

static func max_posture_for_martial(martial_level: int) -> int:
	return clampi(INITIAL_MAX_POSTURE + max(0, martial_level - INITIAL_MARTIAL_LEVEL), INITIAL_MAX_POSTURE, MAX_POSTURE)

static func player_numbers_for_martial(martial_level: int) -> Dictionary:
	var level = max(INITIAL_MARTIAL_LEVEL, martial_level)
	return {
		"max_hp": max_hp_for_martial(level),
		"hp": max_hp_for_martial(level),
		"qinggong": qinggong_for_martial(level),
		"max_posture": max_posture_for_martial(level),
		"posture": max_posture_for_martial(level),
		"martial_level": level,
	}

static func military_tier_for_merit(military_merit: int) -> int:
	return _tier_for_value(max(0, military_merit), MILITARY_TIER_THRESHOLDS)

static func military_title_for_merit(military_merit: int) -> String:
	var tier := military_tier_for_merit(military_merit)
	return str(MILITARY_TIER_TITLES[clampi(tier, 0, MILITARY_TIER_TITLES.size() - 1)])

static func reputation_tier_for_value(clean_reputation: int) -> int:
	return _tier_for_value(max(0, clean_reputation), REPUTATION_TIER_THRESHOLDS)

static func reputation_title_for_value(clean_reputation: int) -> String:
	var tier := reputation_tier_for_value(clean_reputation)
	return str(REPUTATION_TIER_TITLES[clampi(tier, 0, REPUTATION_TIER_TITLES.size() - 1)])

static func next_military_threshold(military_merit: int) -> int:
	return _next_threshold(max(0, military_merit), MILITARY_TIER_THRESHOLDS)

static func next_reputation_threshold(clean_reputation: int) -> int:
	return _next_threshold(max(0, clean_reputation), REPUTATION_TIER_THRESHOLDS)

static func event_scope_text(node: Dictionary) -> String:
	var node_type := str(node.get("node_type", ""))
	if node_type == "case":
		return _case_source_label(node)
	if node_type == "military":
		return "官职事件：%s" % _military_scope_label(node)
	if node_type == "reputation":
		return "江湖事件：%s" % _reputation_scope_label(node)
	if str(node.get("primary_line", "")) == "military":
		return "官职牵连：%s" % _military_scope_label(node)
	if str(node.get("primary_line", "")) == "reputation":
		return "江湖牵连：%s" % _reputation_scope_label(node)
	return ""

static func summary_text(state: Dictionary) -> String:
	var martial_level := int(state.get("martial_level", INITIAL_MARTIAL_LEVEL))
	var numbers := player_numbers_for_martial(martial_level)
	var military_merit := int(state.get("military_merit", 0))
	var clean_reputation := int(state.get("clean_reputation", 0))
	var owned_cards := _string_array(state.get("owned_card_ids", []))
	var selected_cards := _string_array(state.get("selected_loadout_ids", []))
	return "军功 %d（%s）｜清望 %d（%s）｜旧案 %d｜武境 %d｜HP %d｜轻功 %d｜势上限 %d｜牌库 %d｜入战 %d/%d" % [
		military_merit,
		military_title_for_merit(military_merit),
		clean_reputation,
		reputation_title_for_value(clean_reputation),
		int(state.get("case_clues", 0)),
		martial_level,
		int(numbers.get("max_hp", INITIAL_HP)),
		int(numbers.get("qinggong", INITIAL_QINGGONG)),
		int(numbers.get("max_posture", INITIAL_MAX_POSTURE)),
		owned_cards.size(),
		selected_cards.size(),
		PLAYER_LOADOUT_SIZE,
	]

static func _sanitize_card_state(state: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	var owned := _unique_string_array(next_state.get("owned_card_ids", []))
	var selected := _string_array(next_state.get("selected_loadout_ids", []))
	var deck_slots := _deck_slots_from_variant(next_state.get("deck_slots", []))
	var active_index := int(next_state.get("active_deck_index", 0))
	var sanitized := _sanitize_deck_slot(selected, owned)
	next_state["owned_card_ids"] = owned
	if deck_slots.is_empty():
		deck_slots.append(sanitized)
	while deck_slots.size() < 4:
		deck_slots.append([])
	var sanitized_slots: Array = []
	for i in range(4):
		sanitized_slots.append(_sanitize_deck_slot(_string_array(deck_slots[i]), owned))
	active_index = clampi(active_index, 0, 3)
	next_state["deck_slots"] = sanitized_slots
	next_state["active_deck_index"] = active_index
	next_state["selected_loadout_ids"] = (sanitized_slots[active_index] as Array).duplicate()
	return next_state

static func _sanitize_deck_slot(card_ids: Array[String], owned: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in card_ids:
		if result.size() >= PLAYER_LOADOUT_SIZE:
			break
		if not (card_id in owned):
			continue
		if _card_id_count(result, card_id) >= 2:
			continue
		result.append(card_id)
	return result

static func _deck_slots_from_variant(value) -> Array:
	var slots: Array = []
	if value is Array:
		for slot_variant in value:
			slots.append(_string_array(slot_variant))
	return slots

static func _string_array(value) -> Array[String]:
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

static func _unique_string_array(value) -> Array[String]:
	var result: Array[String] = []
	for item: String in _string_array(value):
		if not (item in result):
			result.append(item)
	return result

static func _card_id_count(cards: Array[String], card_id: String) -> int:
	var count := 0
	for item: String in cards:
		if item == card_id:
			count += 1
	return count

static func _tier_for_value(value: int, thresholds: Array) -> int:
	var tier := 0
	for i in range(thresholds.size()):
		if value >= int(thresholds[i]):
			tier = i
	return tier

static func _next_threshold(value: int, thresholds: Array) -> int:
	for threshold in thresholds:
		if value < int(threshold):
			return int(threshold)
	return -1

static func _military_scope_label(node: Dictionary) -> String:
	var min_title := military_title_for_merit(int(node.get("min_military_merit", 0)))
	var max_value := int(node.get("max_military_merit", -1))
	if max_value < 0:
		return "%s起" % min_title
	return "%s至%s" % [min_title, military_title_for_merit(max_value)]

static func _reputation_scope_label(node: Dictionary) -> String:
	var min_title := reputation_title_for_value(int(node.get("min_clean_reputation", 0)))
	var max_value := int(node.get("max_clean_reputation", -1))
	if max_value < 0:
		return "%s起" % min_title
	return "%s至%s" % [min_title, reputation_title_for_value(max_value)]

static func _case_source_label(node: Dictionary) -> String:
	var tags: Array = node.get("tags", [])
	if "source_military_blocked" in tags:
		return "旧案来源：军门失真"
	if "source_reputation_blocked" in tags:
		return "旧案来源：民间受阻"
	if "source_military" in tags:
		return "旧案来源：军门"
	if "source_reputation" in tags:
		return "旧案来源：民间"
	if "source_fragment" in tags:
		return "旧案来源：碎片"
	return "旧案来源：痕迹"
