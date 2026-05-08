extends RefCounted
class_name GeneratedBattleDomainAdapter

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const ENEMY_DECKS_PATH := "res://data/runtime_preview/content_engine/enemy_decks.preview.json"
const CARD_POOL_PATH := "res://data/runtime_preview/content_engine/card_pool.preview.json"
const WHITELIST_BATTLE_SLOT := "prologue_01"
const FALLBACK_POLICY := "legacy"


func build_generated_battle_domain_candidate(battle_slot_id: String) -> Dictionary:
	if battle_slot_id != WHITELIST_BATTLE_SLOT:
		return {
			"battle_slot_id": battle_slot_id,
			"enabled": false,
			"formal_source": "legacy",
			"enemy_deck": {},
			"card_pool": {},
			"fallback_policy": FALLBACK_POLICY,
		}

	var bridge = BRIDGE.new()
	if not bridge.is_enabled_for_battle_slot(battle_slot_id):
		return {
			"battle_slot_id": battle_slot_id,
			"enabled": false,
			"formal_source": "legacy",
			"enemy_deck": {},
			"card_pool": {},
			"fallback_policy": FALLBACK_POLICY,
			"notes": "bridge_not_enabled",
		}

	var bundle: Dictionary = bridge.get_full_content_bundle_for_battle_slot(battle_slot_id)
	var enemy_deck := get_enemy_deck_for_battle_slot(battle_slot_id, bundle)
	var card_pool := get_card_pool_for_battle_slot(battle_slot_id, bundle)
	return {
		"battle_slot_id": battle_slot_id,
		"enabled": true,
		"formal_source": "content_engine_candidate",
		"enemy_deck": enemy_deck,
		"card_pool": card_pool,
		"fallback_policy": FALLBACK_POLICY,
		"bridge_bundle": bundle,
	}


func get_enemy_deck_for_battle_slot(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	if battle_slot_id != WHITELIST_BATTLE_SLOT:
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "non_whitelist_legacy"}
	var bundle := bridge_bundle
	if bundle.is_empty():
		bundle = BRIDGE.new().get_full_content_bundle_for_battle_slot(battle_slot_id)
	if bundle.is_empty():
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "bundle_missing"}
	var domains: Dictionary = _dict(bundle.get("domains", {}))
	var candidate: Dictionary = _dict(domains.get("enemy_deck", {}))
	if not bool(candidate.get("candidate_available", false)):
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "bridge_enemy_deck_unavailable"}
	var deck_id := str(candidate.get("candidate_id", ""))
	if deck_id.is_empty():
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "deck_id_missing"}

	var preview := _read_json_dict(ENEMY_DECKS_PATH)
	var decks: Array = _arr(preview.get("enemy_decks", []))
	for item in decks:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var deck: Dictionary = item
		if str(deck.get("deck_id", "")) != deck_id:
			continue
		var card_ids: Array = _arr(deck.get("card_ids", []))
		return {
			"candidate_available": true,
			"deck_id": deck_id,
			"card_ids": card_ids.duplicate(),
			"card_count": int(deck.get("card_count", card_ids.size())),
			"fallback_policy": FALLBACK_POLICY,
			"formal_source": "content_engine",
			"notes": "bridge_preview_enemy_deck_candidate",
		}

	return {
		"candidate_available": false,
		"deck_id": deck_id,
		"fallback_policy": FALLBACK_POLICY,
		"notes": "deck_not_found_in_preview",
	}


func get_card_pool_for_battle_slot(battle_slot_id: String, bridge_bundle: Dictionary = {}) -> Dictionary:
	if battle_slot_id != WHITELIST_BATTLE_SLOT:
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "non_whitelist_legacy"}
	var bundle := bridge_bundle
	if bundle.is_empty():
		bundle = BRIDGE.new().get_full_content_bundle_for_battle_slot(battle_slot_id)
	if bundle.is_empty():
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "bundle_missing"}
	var domains: Dictionary = _dict(bundle.get("domains", {}))
	var candidate: Dictionary = _dict(domains.get("card_pool", {}))
	if not bool(candidate.get("candidate_available", false)):
		return {"candidate_available": false, "fallback_policy": FALLBACK_POLICY, "notes": "bridge_card_pool_unavailable"}

	var preview := _read_json_dict(CARD_POOL_PATH)
	var cards: Array = _arr(preview.get("cards", []))
	var validation := validate_card_pool_candidate(cards)
	return {
		"candidate_available": true,
		"candidate_id": str(candidate.get("candidate_id", "")),
		"candidate_count": cards.size(),
		"cards": cards,
		"compatible_cards": validation.get("compatible_cards", []),
		"unsupported_fields": validation.get("unsupported_fields", []),
		"fallback_policy": FALLBACK_POLICY,
		"formal_source": "content_engine_candidate",
		"notes": "card_pool_candidate_readonly_no_carddata_write",
	}


func validate_card_pool_candidate(cards: Array) -> Dictionary:
	var supported_keys := {
		"card_id": true,
		"display_name": true,
		"domain_tag": true,
		"core_style": true,
		"core_mechanic": true,
		"rarity": true,
		"energy_cost": true,
		"stance_req": true,
		"effect_text": true,
		"tags": true,
	}
	var unsupported := {}
	var compatible_cards: Array = []
	for item in cards:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = item
		var cleaned := {}
		for key_variant in card.keys():
			var key := str(key_variant)
			if supported_keys.has(key):
				cleaned[key] = card[key_variant]
			else:
				unsupported[key] = true
		compatible_cards.append(cleaned)
	var unsupported_list: Array = unsupported.keys()
	unsupported_list.sort()
	return {
		"compatible_cards": compatible_cards,
		"unsupported_fields": unsupported_list,
	}


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []
