extends RefCounted
class_name AigcBattleRuntimeManifestLoader

const ACTIVE_PROFILE_PATH := "res://data/aigc_battle/runtime/active_profile.json"
const RELEASE_CHANNELS_DIR := "res://data/aigc_battle/release_channels/"

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
	if not _loaded and not load_active_manifest():
		return {}
	var mapping := _find_mapping(formal_encounter_id, formal_battle_id)
	if mapping.is_empty():
		_last_error = "generated reward mapping not found: %s|%s" % [formal_encounter_id, formal_battle_id]
		return {}
	return get_reward_by_plan_id(str(mapping.get("reward_plan_id", "")))


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


static func get_generated_loadout(formal_encounter_id: String, formal_battle_id: String = "") -> Dictionary:
	if not _loaded and not load_active_manifest():
		return {}
	var mapping := _find_mapping(formal_encounter_id, formal_battle_id)
	if mapping.is_empty():
		_last_error = "generated loadout mapping not found: %s|%s" % [formal_encounter_id, formal_battle_id]
		return {}
	var slot_id := str(mapping.get("generated_battle_slot_id", ""))
	var deck_id := str(mapping.get("generated_deck_id", ""))
	var reward_plan_id := str(mapping.get("reward_plan_id", ""))
	var slot: Dictionary = _slots_by_id.get(slot_id, {})
	var deck: Dictionary = _decks_by_id.get(deck_id, {})
	var reward: Dictionary = get_reward_by_plan_id(reward_plan_id)
	if slot.is_empty() or deck.is_empty():
		_last_error = "generated slot or deck missing for: %s|%s" % [formal_encounter_id, formal_battle_id]
		return {}
	var cards: Array = []
	for card_id_variant in deck.get("card_ids", []):
		var card_id := str(card_id_variant)
		if _cards_by_id.has(card_id):
			cards.append((_cards_by_id.get(card_id, {}) as Dictionary).duplicate(true))
	return {
		"loadout_source": "generated_manifest",
		"mechanic_profile_id": str(_runtime_manifest.get("mechanic_profile_id", "")),
		"content_pack_id": str(_runtime_manifest.get("content_pack_id", "")),
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
		"followup_chain_count": int(deck.get("followup_chain_count", 0)),
		"followup_card_count": int(deck.get("followup_card_count", 0)),
		"followup_density": float(deck.get("followup_density", 0.0)),
		"followup_groups": (deck.get("followup_groups", []) as Array).duplicate(),
		"card_ids": (deck.get("card_ids", []) as Array).duplicate(),
		"cards": cards,
		"reward_source": "generated_manifest",
		"reward": reward.duplicate(true),
	}


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
