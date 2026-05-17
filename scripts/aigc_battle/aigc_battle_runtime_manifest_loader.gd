extends RefCounted
class_name AigcBattleRuntimeManifestLoader

const ACTIVE_PROFILE_PATH := "res://data/aigc_battle/runtime/active_profile.json"
const RELEASE_CHANNELS_DIR := "res://data/aigc_battle/release_channels/"
const DUNGEON_BATTLE_SLOT_POOL_PATH := "res://data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/battle_slot_pool.json"
const DUNGEON_ENEMY_DECK_POOL_PATH := "res://data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/enemy_deck_pool.json"
const DUNGEON_CARD_POOL_PATH := "res://data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/card_pool.json"
const DUNGEON_REWARD_PLAN_POOL_PATH := "res://data/aigc_battle/generated/dungeon_progression_v1_3/packs/dungeon_pool_pack_001/reward_plan_pool.json"

static var _loaded := false
static var _last_error := ""
static var _active_profile: Dictionary = {}
static var _runtime_manifest: Dictionary = {}
static var _cards_by_id: Dictionary = {}
static var _decks_by_id: Dictionary = {}
static var _slots_by_id: Dictionary = {}
static var _rewards_by_id: Dictionary = {}
static var _mapping_by_key: Dictionary = {}
static var _mapping_by_encounter: Dictionary = {}


static func load_active_manifest() -> bool:
	_loaded = false
	_last_error = ""
	_active_profile.clear()
	_runtime_manifest.clear()
	_cards_by_id.clear()
	_decks_by_id.clear()
	_slots_by_id.clear()
	_rewards_by_id.clear()
	_mapping_by_key.clear()
	_mapping_by_encounter.clear()

	_active_profile = _read_json_dict(ACTIVE_PROFILE_PATH)
	if _active_profile.is_empty():
		_last_error = "active_profile.json not found or invalid"
		return false
	var runtime_manifest_path := _normalize_runtime_path(str(_active_profile.get("runtime_manifest_path", "")))
	if runtime_manifest_path.is_empty():
		_last_error = "runtime_manifest_path is empty"
		return false
	_runtime_manifest = _read_json_dict(runtime_manifest_path)
	if _runtime_manifest.is_empty():
		_last_error = "runtime_manifest.json not found or invalid"
		return false
	_build_indexes()
	_loaded = true
	return true


static func is_loaded() -> bool:
	return _loaded


static func get_last_error() -> String:
	return _last_error


static func has_generated_loadout(formal_encounter_id: String, formal_battle_id: String = "") -> bool:
	return not get_generated_loadout(formal_encounter_id, formal_battle_id).is_empty()


static func has_generated_reward(formal_encounter_id: String, formal_battle_id: String = "") -> bool:
	return not get_generated_reward(formal_encounter_id, formal_battle_id).is_empty()


static func has_runtime_primitive(primitive_id: String) -> bool:
	if not _loaded and not load_active_manifest():
		return false
	return get_runtime_primitives().has(primitive_id)


static func get_runtime_primitives() -> Array:
	if not _loaded and not load_active_manifest():
		return []
	return (_runtime_manifest.get("runtime_primitives", []) as Array).duplicate()


static func get_reward_by_plan_id(reward_plan_id: String) -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	if reward_plan_id.is_empty():
		_last_error = "reward_plan_id is empty"
		return {}
	if not _rewards_by_id.has(reward_plan_id):
		_last_error = "reward_plan_id not found: %s" % reward_plan_id
		return {}
	return (_rewards_by_id.get(reward_plan_id, {}) as Dictionary).duplicate(true)


static func get_generated_reward(formal_encounter_id: String, formal_battle_id: String = "") -> Dictionary:
	var loadout := get_generated_loadout(formal_encounter_id, formal_battle_id)
	if loadout.is_empty():
		return {}
	var reward = loadout.get("reward", {})
	if reward is Dictionary:
		return (reward as Dictionary).duplicate(true)
	return {}


static func get_opening_pressure(formal_encounter_id: String, formal_battle_id: String = "") -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	var loadout := get_generated_loadout(formal_encounter_id, formal_battle_id)
	if loadout.is_empty():
		return {}
	var opening_pressure = loadout.get("opening_pressure", {})
	if opening_pressure is Dictionary:
		return (opening_pressure as Dictionary).duplicate(true)
	_last_error = "opening_pressure missing for: %s|%s" % [formal_encounter_id, formal_battle_id]
	return {}


static func get_weapon_followup(formal_encounter_id: String, formal_battle_id: String = "") -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	var loadout := get_generated_loadout(formal_encounter_id, formal_battle_id)
	if loadout.is_empty():
		return {}
	var weapon_followup = loadout.get("weapon_followup", {})
	if weapon_followup is Dictionary:
		return (weapon_followup as Dictionary).duplicate(true)
	_last_error = "weapon_followup missing for: %s|%s" % [formal_encounter_id, formal_battle_id]
	return {}


static func get_clue_pressure(formal_encounter_id: String, formal_battle_id: String = "") -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	var loadout := get_generated_loadout(formal_encounter_id, formal_battle_id)
	if loadout.is_empty():
		return {}
	var clue_pressure = loadout.get("clue_pressure", {})
	if clue_pressure is Dictionary:
		return (clue_pressure as Dictionary).duplicate(true)
	_last_error = "clue_pressure missing for: %s|%s" % [formal_encounter_id, formal_battle_id]
	return {}


static func get_generated_loadout(formal_encounter_id: String, formal_battle_id: String = "") -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	var mapping := _find_mapping(formal_encounter_id, formal_battle_id)
	var loadout := _build_manifest_loadout(
		_runtime_manifest,
		_cards_by_id,
		_decks_by_id,
		_slots_by_id,
		_rewards_by_id,
		mapping,
		formal_encounter_id,
		formal_battle_id,
		"active_profile"
	)
	if not loadout.is_empty():
		return loadout
	loadout = _get_dungeon_pool_generated_loadout(formal_encounter_id, formal_battle_id)
	if not loadout.is_empty():
		return loadout
	loadout = _get_release_fallback_generated_loadout(formal_encounter_id, formal_battle_id)
	if not loadout.is_empty():
		return loadout
	_last_error = "generated loadout mapping not found: %s|%s" % [formal_encounter_id, formal_battle_id]
	return {}


static func get_manifest_summary() -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	return {
		"mechanic_profile_id": str(_runtime_manifest.get("mechanic_profile_id", "")),
		"content_pack_id": str(_runtime_manifest.get("content_pack_id", "")),
		"target_sequence_id": str(_runtime_manifest.get("target_sequence_id", "")),
		"runtime_primitives": (_runtime_manifest.get("runtime_primitives", []) as Array).duplicate(),
		"runtime_primitive_summary": (_runtime_manifest.get("runtime_primitive_summary", {}) as Dictionary).duplicate(true),
		"formal_sequence_mapping_count": (_runtime_manifest.get("formal_sequence_mapping", []) as Array).size(),
		"battle_slot_count": (_runtime_manifest.get("battle_slots", []) as Array).size(),
		"enemy_deck_count": (_runtime_manifest.get("enemy_decks", []) as Array).size(),
		"card_count": (_runtime_manifest.get("cards", []) as Array).size(),
		"reward_count": (_runtime_manifest.get("rewards", []) as Array).size(),
	}


static func get_active_profile_summary() -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	return _active_profile.duplicate(true)


static func get_release_channel(channel_id: String) -> Dictionary:
	if channel_id.is_empty():
		return {}
	var path := "%s%s_release.json" % [RELEASE_CHANNELS_DIR, channel_id]
	return _read_json_dict(path)


static func _build_manifest_loadout(manifest: Dictionary, cards_by_id: Dictionary, decks_by_id: Dictionary, slots_by_id: Dictionary, rewards_by_id: Dictionary, mapping: Dictionary, formal_encounter_id: String, formal_battle_id: String, release_channel: String) -> Dictionary:
	if mapping.is_empty():
		return {}
	var slot_id := str(mapping.get("generated_battle_slot_id", ""))
	var deck_id := str(mapping.get("generated_deck_id", ""))
	var reward_plan_id := str(mapping.get("reward_plan_id", ""))
	var slot: Dictionary = slots_by_id.get(slot_id, {}) as Dictionary
	var deck: Dictionary = decks_by_id.get(deck_id, {}) as Dictionary
	var reward: Dictionary = rewards_by_id.get(reward_plan_id, {}) as Dictionary
	if slot.is_empty() or deck.is_empty():
		return {}
	var cards: Array = []
	for card_id_variant in deck.get("card_ids", []):
		var card_id := str(card_id_variant)
		if cards_by_id.has(card_id):
			cards.append((cards_by_id.get(card_id, {}) as Dictionary).duplicate(true))
	return {
		"loadout_source": "generated_manifest",
		"generated_content_source": "runtime_manifest",
		"release_channel": release_channel,
		"mechanic_profile_id": str(manifest.get("mechanic_profile_id", "")),
		"content_pack_id": str(manifest.get("content_pack_id", "")),
		"formal_encounter_id": formal_encounter_id,
		"formal_battle_id": str(mapping.get("formal_battle_id", formal_battle_id)),
		"generated_battle_slot_id": slot_id,
		"generated_deck_id": deck_id,
		"reward_plan_id": reward_plan_id,
		"enemy_role": str(slot.get("enemy_role", deck.get("enemy_role", ""))),
		"difficulty_tier": str(slot.get("difficulty_tier", deck.get("difficulty_tier", ""))),
		"runtime_primitives": (slot.get("runtime_primitives", []) as Array).duplicate(),
		"opening_pressure": (slot.get("opening_pressure", {}) as Dictionary).duplicate(true),
		"weapon_followup": (slot.get("weapon_followup", {}) as Dictionary).duplicate(true),
		"clue_pressure": (slot.get("clue_pressure", {}) as Dictionary).duplicate(true),
		"followup_chain_count": int(deck.get("followup_chain_count", 0)),
		"followup_card_count": int(deck.get("followup_card_count", 0)),
		"followup_density": float(deck.get("followup_density", 0.0)),
		"followup_groups": (deck.get("followup_groups", []) as Array).duplicate(),
		"player_wujing_cap": int(slot.get("player_wujing_cap", 0)),
		"max_enemy_wujing": int(slot.get("max_enemy_wujing", 0)),
		"weapon_loadout": (slot.get("weapon_loadout", deck.get("weapon_loadout", [])) as Array).duplicate(),
		"dual_weapon_enabled": bool(slot.get("dual_weapon_enabled", deck.get("dual_weapon_enabled", false))),
		"primary_weapon_style": str(deck.get("primary_weapon_style", "")),
		"secondary_weapon_style": str(deck.get("secondary_weapon_style", "")),
		"primary_weapon_ratio": float(deck.get("primary_weapon_ratio", 0.0)),
		"secondary_weapon_ratio": float(deck.get("secondary_weapon_ratio", 0.0)),
		"generic_ratio": float(deck.get("generic_ratio", 0.0)),
		"max_required_wujing": int(deck.get("max_required_wujing", 0)),
		"max_closing_form_tier": int(deck.get("max_closing_form_tier", 0)),
		"dual_weapon_synergy_count": int(deck.get("dual_weapon_synergy_count", 0)),
		"martial_realm_stage": str(slot.get("martial_realm_stage", "")),
		"realm_pressure_level": str(slot.get("realm_pressure_level", "")),
		"card_ids": (deck.get("card_ids", []) as Array).duplicate(),
		"cards": cards,
		"reward_source": "generated_manifest",
		"reward": reward.duplicate(true),
	}


static func _get_release_fallback_generated_loadout(formal_encounter_id: String, formal_battle_id: String) -> Dictionary:
	var current_release := get_release_channel("current")
	var fallback_path := str(current_release.get("fallback_runtime_manifest_path", ""))
	var release_channel := "current_fallback"
	if fallback_path.is_empty():
		var fallback_release := get_release_channel("fallback")
		fallback_path = str(fallback_release.get("runtime_manifest_path", ""))
		release_channel = "fallback"
	if fallback_path.is_empty():
		return {}
	var manifest := _read_json_dict(_normalize_runtime_path(fallback_path))
	if manifest.is_empty():
		return {}
	var indexes := _build_manifest_indexes(manifest)
	var mapping := _find_mapping_in_indexes(
		indexes.get("mapping_by_key", {}) as Dictionary,
		indexes.get("mapping_by_encounter", {}) as Dictionary,
		formal_encounter_id,
		formal_battle_id
	)
	return _build_manifest_loadout(
		manifest,
		indexes.get("cards_by_id", {}) as Dictionary,
		indexes.get("decks_by_id", {}) as Dictionary,
		indexes.get("slots_by_id", {}) as Dictionary,
		indexes.get("rewards_by_id", {}) as Dictionary,
		mapping,
		formal_encounter_id,
		formal_battle_id,
		release_channel
	)


static func _get_dungeon_pool_generated_loadout(formal_encounter_id: String, formal_battle_id: String) -> Dictionary:
	var slot_pool := _read_json_dict(DUNGEON_BATTLE_SLOT_POOL_PATH)
	var deck_pool := _read_json_dict(DUNGEON_ENEMY_DECK_POOL_PATH)
	var card_pool := _read_json_dict(DUNGEON_CARD_POOL_PATH)
	var reward_pool := _read_json_dict(DUNGEON_REWARD_PLAN_POOL_PATH)
	if slot_pool.is_empty() or deck_pool.is_empty() or card_pool.is_empty() or reward_pool.is_empty():
		return {}
	var slot := _find_dungeon_slot(slot_pool.get("battle_slots", []), formal_encounter_id, formal_battle_id)
	if slot.is_empty():
		return {}
	var deck := _find_by_id(deck_pool.get("enemy_decks", []), "enemy_deck_id", str(slot.get("enemy_deck_id", "")))
	if deck.is_empty():
		return {}
	var reward := _find_by_id(reward_pool.get("reward_plans", []), "reward_plan_id", str(slot.get("reward_plan_id", "")))
	var cards_by_id := _index_by_id(card_pool.get("cards", []), "card_id")
	var cards: Array = []
	for card_id_variant in deck.get("card_ids", []):
		var card_id := str(card_id_variant)
		if cards_by_id.has(card_id):
			cards.append(_dungeon_card_to_runtime_card(cards_by_id.get(card_id, {}) as Dictionary))
	return {
		"loadout_source": "generated_manifest",
		"generated_content_source": "aigc_dungeon_pool",
		"release_channel": "dungeon_node_materializer",
		"mechanic_profile_id": "dungeon_progression_v1_3",
		"content_pack_id": str(slot_pool.get("content_pool_pack_id", "dungeon_pool_pack_001")),
		"formal_encounter_id": formal_encounter_id,
		"formal_battle_id": str(slot.get("compatible_battle_id", formal_battle_id)),
		"generated_battle_slot_id": str(slot.get("battle_slot_id", "")),
		"generated_deck_id": str(deck.get("enemy_deck_id", "")),
		"reward_plan_id": str(slot.get("reward_plan_id", "")),
		"enemy_role": str(slot.get("enemy_archetype", deck.get("enemy_archetype", ""))),
		"enemy_weapon": _weapon_label_for_cards(cards),
		"difficulty_tier": str(slot.get("deck_tier", deck.get("deck_tier", ""))),
		"runtime_primitives": [],
		"opening_pressure": {},
		"weapon_followup": {},
		"clue_pressure": {},
		"followup_chain_count": 0,
		"followup_card_count": 0,
		"followup_density": 0.0,
		"followup_groups": [],
		"player_wujing_cap": int(slot.get("expected_player_realm", 0)),
		"max_enemy_wujing": int(slot.get("expected_player_realm", 0)),
		"weapon_loadout": [],
		"dual_weapon_enabled": false,
		"primary_weapon_style": _primary_weapon_style_for_cards(cards),
		"secondary_weapon_style": "",
		"primary_weapon_ratio": 1.0,
		"secondary_weapon_ratio": 0.0,
		"generic_ratio": 0.0,
		"max_required_wujing": int(deck.get("expected_player_realm", slot.get("expected_player_realm", 0))),
		"max_closing_form_tier": 0,
		"dual_weapon_synergy_count": 0,
		"martial_realm_stage": str(slot.get("stage", "")),
		"realm_pressure_level": str(slot.get("battle_type", "")),
		"card_ids": (deck.get("card_ids", []) as Array).duplicate(),
		"cards": cards,
		"reward_source": "generated_manifest",
		"reward": reward.duplicate(true),
		"encounter_tier": str(slot.get("stage", "")),
		"encounter_kind": str(slot.get("battle_type", "")),
	}


static func _find_dungeon_slot(slots_variant, formal_encounter_id: String, formal_battle_id: String) -> Dictionary:
	if not (slots_variant is Array):
		return {}
	for item in slots_variant:
		if not (item is Dictionary):
			continue
		var slot := item as Dictionary
		if str(slot.get("compatible_encounter_id", "")) != formal_encounter_id:
			continue
		if not formal_battle_id.is_empty() and str(slot.get("compatible_battle_id", "")) != formal_battle_id:
			continue
		return slot.duplicate(true)
	return {}


static func _dungeon_card_to_runtime_card(card: Dictionary) -> Dictionary:
	var card_type := str(card.get("card_type", "skill"))
	var runtime := {
		"card_id": str(card.get("card_id", "")),
		"id": str(card.get("card_id", "")),
		"name": str(card.get("name", card.get("card_id", "招式"))),
		"card_type": card_type,
		"weapon_style": str(card.get("weapon_style", "")),
		"style": str(card.get("weapon_style", "")),
		"cost": int(card.get("cost", 1)),
		"min": 1,
		"max": 3,
		"role": "guard",
		"gain": 0,
		"break": 0,
		"damage": 0,
		"guard": 0,
		"tags": (card.get("tags", []) as Array).duplicate(),
		"difficulty_tier": str(card.get("difficulty_tier", "")),
		"required_wujing": int(card.get("realm_requirement", 0)),
		"effect_summary": str(card.get("effect_summary", "")),
	}
	match card_type:
		"attack":
			runtime["role"] = "attack"
			runtime["damage"] = 4
			runtime["break"] = 1
		"defense":
			runtime["role"] = "guard"
			runtime["guard"] = 4
			runtime["gain"] = 1
		"movement":
			runtime["role"] = "feint"
			runtime["gain"] = 1
			runtime["min"] = 0
			runtime["max"] = 5
		_:
			runtime["role"] = "feint"
			runtime["gain"] = 1
	return runtime


static func _weapon_label_for_cards(cards: Array) -> String:
	var style := _primary_weapon_style_for_cards(cards)
	match style:
		"spear", "spearman":
			return "长枪"
		"blade", "blademaster":
			return "单刀"
		_:
			return "兵器"


static func _primary_weapon_style_for_cards(cards: Array) -> String:
	for item in cards:
		if item is Dictionary:
			var style := str((item as Dictionary).get("weapon_style", ""))
			if not style.is_empty() and style != "generic":
				return style
	return "generic"


static func _build_manifest_indexes(manifest: Dictionary) -> Dictionary:
	var indexes := {
		"cards_by_id": {},
		"decks_by_id": {},
		"slots_by_id": {},
		"rewards_by_id": {},
		"mapping_by_key": {},
		"mapping_by_encounter": {},
	}
	indexes["cards_by_id"] = _index_by_id(manifest.get("cards", []), "card_id", "id")
	indexes["decks_by_id"] = _index_by_id(manifest.get("enemy_decks", []), "deck_id")
	indexes["slots_by_id"] = _index_by_id(manifest.get("battle_slots", []), "battle_slot_id")
	indexes["rewards_by_id"] = _index_by_id(manifest.get("rewards", []), "reward_plan_id")
	var mapping_by_key: Dictionary = {}
	var mapping_by_encounter: Dictionary = {}
	for mapping_variant in manifest.get("formal_sequence_mapping", []):
		if not (mapping_variant is Dictionary):
			continue
		var mapping := mapping_variant as Dictionary
		var encounter_id := str(mapping.get("formal_encounter_id", ""))
		var battle_id := str(mapping.get("formal_battle_id", ""))
		mapping_by_key[_mapping_key(encounter_id, battle_id)] = mapping.duplicate(true)
		if not mapping_by_encounter.has(encounter_id):
			mapping_by_encounter[encounter_id] = mapping.duplicate(true)
	indexes["mapping_by_key"] = mapping_by_key
	indexes["mapping_by_encounter"] = mapping_by_encounter
	return indexes


static func _index_by_id(items_variant, primary_key: String, fallback_key: String = "") -> Dictionary:
	var result: Dictionary = {}
	if not (items_variant is Array):
		return result
	for item in items_variant:
		if not (item is Dictionary):
			continue
		var data := item as Dictionary
		var item_id := str(data.get(primary_key, ""))
		if item_id.is_empty() and not fallback_key.is_empty():
			item_id = str(data.get(fallback_key, ""))
		if not item_id.is_empty():
			result[item_id] = data.duplicate(true)
	return result


static func _find_by_id(items_variant, id_field: String, id_value: String) -> Dictionary:
	if id_value.is_empty() or not (items_variant is Array):
		return {}
	for item in items_variant:
		if item is Dictionary and str((item as Dictionary).get(id_field, "")) == id_value:
			return (item as Dictionary).duplicate(true)
	return {}


static func _find_mapping_in_indexes(mapping_by_key: Dictionary, mapping_by_encounter: Dictionary, formal_encounter_id: String, formal_battle_id: String) -> Dictionary:
	var key := _mapping_key(formal_encounter_id, formal_battle_id)
	if mapping_by_key.has(key):
		return (mapping_by_key.get(key, {}) as Dictionary).duplicate(true)
	if mapping_by_encounter.has(formal_encounter_id):
		return (mapping_by_encounter.get(formal_encounter_id, {}) as Dictionary).duplicate(true)
	return {}


static func _build_indexes() -> void:
	for card_variant in _runtime_manifest.get("cards", []):
		if card_variant is Dictionary:
			var card := card_variant as Dictionary
			_cards_by_id[str(card.get("card_id", card.get("id", "")))] = card.duplicate(true)
	for deck_variant in _runtime_manifest.get("enemy_decks", []):
		if deck_variant is Dictionary:
			var deck := deck_variant as Dictionary
			_decks_by_id[str(deck.get("deck_id", ""))] = deck.duplicate(true)
	for slot_variant in _runtime_manifest.get("battle_slots", []):
		if slot_variant is Dictionary:
			var slot := slot_variant as Dictionary
			_slots_by_id[str(slot.get("battle_slot_id", ""))] = slot.duplicate(true)
	for reward_variant in _runtime_manifest.get("rewards", []):
		if reward_variant is Dictionary:
			var reward := reward_variant as Dictionary
			_rewards_by_id[str(reward.get("reward_plan_id", ""))] = reward.duplicate(true)
	for mapping_variant in _runtime_manifest.get("formal_sequence_mapping", []):
		if not (mapping_variant is Dictionary):
			continue
		var mapping := mapping_variant as Dictionary
		var encounter_id := str(mapping.get("formal_encounter_id", ""))
		var battle_id := str(mapping.get("formal_battle_id", ""))
		_mapping_by_key[_mapping_key(encounter_id, battle_id)] = mapping.duplicate(true)
		if not _mapping_by_encounter.has(encounter_id):
			_mapping_by_encounter[encounter_id] = mapping.duplicate(true)


static func _find_mapping(formal_encounter_id: String, formal_battle_id: String) -> Dictionary:
	var key := _mapping_key(formal_encounter_id, formal_battle_id)
	if _mapping_by_key.has(key):
		return (_mapping_by_key.get(key, {}) as Dictionary).duplicate(true)
	if _mapping_by_encounter.has(formal_encounter_id):
		return (_mapping_by_encounter.get(formal_encounter_id, {}) as Dictionary).duplicate(true)
	return {}


static func _mapping_key(formal_encounter_id: String, formal_battle_id: String) -> String:
	return "%s|%s" % [formal_encounter_id, formal_battle_id]


static func _normalize_runtime_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	if path.begins_with("data/"):
		return "res://%s" % path
	return path


static func _read_json_dict(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
