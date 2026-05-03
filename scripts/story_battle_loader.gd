extends RefCounted
class_name StoryBattleLoader

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")
const EnemySetLoader = preload("res://scripts/enemy_set_loader.gd")

const STORY_BATTLES_JSON_PATH := "res://data/story_battles.json"
const FIGHTER_TEMPLATES_TABLE := "fighter_templates"
const STORY_DECK_SETS_TABLE := "story_deck_sets"
const FIGHTER_STAT_SETS_TABLE := "fighter_stat_sets"
const STORY_ENCOUNTERS_TABLE := "story_encounters"
const FIGHTER_TEMPLATES_INDEX := "fighter_templates_by_id"
const STORY_DECK_SETS_INDEX := "story_deck_sets_by_id"
const FIGHTER_STAT_SETS_INDEX := "fighter_stat_sets_by_id"
const STORY_ENCOUNTERS_INDEX := "story_encounters_by_id"
const MODE_SYMMETRIC_ID := "symmetric"
const MODE_REACTIVE_ID := "reactive"

static var _story_battles_cache: Dictionary = {}
static var _story_battles_cache_loaded := false


static func load_encounters() -> Array[Dictionary]:
	return _table_rows(STORY_ENCOUNTERS_TABLE)


static func find_encounter(encounter_id: String) -> Dictionary:
	return _row_by_id(STORY_ENCOUNTERS_INDEX, encounter_id)


static func build_card_catalog(fighter_catalog: Dictionary, reward_pool: Array) -> Dictionary:
	var catalog: Dictionary = {}
	for fighter_id in fighter_catalog.keys():
		var data = fighter_catalog[fighter_id]
		if data == null:
			continue
		for card in data.starting_deck:
			if card is CardData:
				catalog[card.id] = card
	for card in reward_pool:
		if card is CardData:
			catalog[card.id] = card
	return catalog


static func build_story_battle(encounter_id: String, card_catalog: Dictionary) -> Dictionary:
	var encounter: Dictionary = find_encounter(encounter_id)
	if encounter.is_empty():
		push_warning("StoryBattleLoader: encounter not found: %s" % encounter_id)
		return {}
	var player_data: FighterData = build_fighter_data(
		str(encounter.get("player_template_id", "")),
		str(encounter.get("player_deck_id", "")),
		str(encounter.get("player_stat_set_id", "")),
		card_catalog,
		true
	)
	var opponent_data: FighterData = build_fighter_data(
		str(encounter.get("opponent_template_id", "")),
		str(encounter.get("opponent_deck_id", "")),
		str(encounter.get("opponent_stat_set_id", "")),
		card_catalog,
		false
	)
	if player_data == null or opponent_data == null:
		push_warning("StoryBattleLoader: story battle has null fighter data: %s" % encounter_id)
		return {}
	return {
		"encounter": encounter,
		"player_data": player_data,
		"opponent_data": opponent_data,
		"settlement_mode": str(encounter.get("settlement_mode", MODE_REACTIVE_ID))
	}


static func build_fighter_data(template_id: String, deck_id: String, stat_set_id: String, card_catalog: Dictionary, is_player_side: bool) -> FighterData:
	var template: Dictionary = _row_by_id(FIGHTER_TEMPLATES_INDEX, template_id)
	var deck_set: Dictionary = _row_by_id(STORY_DECK_SETS_INDEX, deck_id)
	var stat_set: Dictionary = _row_by_id(FIGHTER_STAT_SETS_INDEX, stat_set_id)
	if template.is_empty():
		push_warning("StoryBattleLoader: fighter template not found: %s" % template_id)
		return null
	if deck_set.is_empty():
		push_warning("StoryBattleLoader: story deck not found: %s" % deck_id)
		return null
	if stat_set.is_empty():
		push_warning("StoryBattleLoader: stat set not found: %s" % stat_set_id)
		return null
	var preferred: PackedInt32Array = _preferred_distances_for_weapon(str(template.get("weapon_style", "")))
	var deck_text: String = str(deck_set.get("deck", ""))
	var deck_errors: Array[String] = _deck_validation_errors(deck_id, deck_text, card_catalog)
	if not deck_errors.is_empty():
		for error: String in deck_errors:
			push_warning("StoryBattleLoader: %s" % error)
		return null
	var deck: Array[CardData] = EnemySetLoader.parse_deck(deck_text, card_catalog)
	var default_position: int = _to_int(template.get("default_position", "2" if is_player_side else "6"), 2 if is_player_side else 6)
	var default_facing: String = str(template.get("default_facing", "right" if is_player_side else "left"))
	return FighterData.new(
		str(template.get("fighter_template_id", template_id)),
		str(template.get("display_name", template_id)),
		str(template.get("weapon_style", "")),
		_to_int(stat_set.get("max_hp", "20"), 20),
		_to_int(stat_set.get("max_momentum", "6"), 6),
		_to_int(stat_set.get("starting_momentum", "5"), 5),
		_to_int(stat_set.get("starting_realm", "1"), 1),
		preferred,
		deck,
		_to_int(stat_set.get("qinggong", "1"), 1),
		default_position,
		default_facing
	)


static func validate_all(card_catalog: Dictionary) -> Dictionary:
	var payload: Dictionary = _load_story_battles_json()
	var validation: Dictionary = payload.get("validation", {}).duplicate(true)
	if validation.is_empty():
		validation = {
			"ok": false,
			"errors": ["story_battles.json is missing validation metadata"],
			"warnings": [],
			"counts": {
				"templates": _table_rows(FIGHTER_TEMPLATES_TABLE).size(),
				"decks": _table_rows(STORY_DECK_SETS_TABLE).size(),
				"stats": _table_rows(FIGHTER_STAT_SETS_TABLE).size(),
				"encounters": _table_rows(STORY_ENCOUNTERS_TABLE).size()
			}
		}
	var errors: Array = []
	for error in validation.get("errors", []):
		errors.append(str(error))
	for deck_row: Dictionary in _table_rows(STORY_DECK_SETS_TABLE):
		var deck_id: String = str(deck_row.get("story_deck_id", ""))
		for error: String in _deck_validation_errors(deck_id, str(deck_row.get("deck", "")), card_catalog):
			errors.append(error)
	for encounter_row: Dictionary in _table_rows(STORY_ENCOUNTERS_TABLE):
		var encounter_id: String = str(encounter_row.get("encounter_id", ""))
		var policy: String = str(encounter_row.get("intent_visibility_policy", BattleIntentVisibility.POLICY_FULL))
		if not BattleIntentVisibility.is_valid_policy(policy):
			errors.append("story_encounters.%s has invalid intent_visibility_policy: %s" % [encounter_id, policy])
	validation["errors"] = errors
	validation["ok"] = bool(validation.get("ok", false)) and errors.is_empty()
	return validation


static func format_validation_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	var counts: Dictionary = report.get("counts", {})
	lines.append("StoryBattle data validation: %s" % ("OK" if bool(report.get("ok", false)) else "FAILED"))
	lines.append("templates=%d decks=%d stats=%d encounters=%d" % [int(counts.get("templates", 0)), int(counts.get("decks", 0)), int(counts.get("stats", 0)), int(counts.get("encounters", 0))])
	for err in report.get("errors", []):
		lines.append("ERROR: %s" % str(err))
	for warning in report.get("warnings", []):
		lines.append("WARN: %s" % str(warning))
	return "\n".join(lines)


static func _preferred_distances_for_weapon(weapon_style: String) -> PackedInt32Array:
	match weapon_style:
		"spearman":
			return PackedInt32Array([2, 3])
		"blademaster":
			return PackedInt32Array([1, 2])
		_:
			return PackedInt32Array([1, 2, 3])


static func _deck_validation_errors(deck_id: String, deck_text: String, card_catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var card_count := 0
	for entry in deck_text.split(",", false):
		var token: String = entry.strip_edges()
		if token == "":
			continue
		var pieces: PackedStringArray = token.split(":", false)
		var card_id: String = pieces[0].strip_edges()
		if card_id == "":
			errors.append("story_deck_sets.%s has empty card id" % deck_id)
			continue
		var count := 1
		if pieces.size() >= 2:
			var count_text: String = pieces[1].strip_edges()
			if count_text == "" or not count_text.is_valid_int():
				errors.append("story_deck_sets.%s has invalid count for card %s: %s" % [deck_id, card_id, count_text])
				continue
			count = int(count_text)
		if count <= 0:
			errors.append("story_deck_sets.%s has non-positive count for card %s: %d" % [deck_id, card_id, count])
			continue
		if not card_catalog.has(card_id):
			errors.append("story_deck_sets.%s references missing card id: %s" % [deck_id, card_id])
			continue
		if not (card_catalog[card_id] is CardData):
			errors.append("story_deck_sets.%s references non-CardData catalog value: %s" % [deck_id, card_id])
			continue
		card_count += count
	if card_count <= 0:
		errors.append("story_deck_sets.%s resolves to an empty deck" % deck_id)
	return errors


static func _table_rows(table_name: String) -> Array[Dictionary]:
	var payload: Dictionary = _load_story_battles_json()
	var tables: Dictionary = payload.get("tables", {})
	var source = tables.get(table_name, [])
	if not (source is Array):
		push_warning("StoryBattleLoader: JSON table is not an array: %s" % table_name)
		return []
	var rows: Array[Dictionary] = []
	for item in source:
		if item is Dictionary:
			rows.append(item)
	return rows


static func _row_by_id(index_name: String, value: String) -> Dictionary:
	var payload: Dictionary = _load_story_battles_json()
	var indexes: Dictionary = payload.get("indexes", {})
	var index: Dictionary = indexes.get(index_name, {})
	return index.get(value, {})


static func _load_story_battles_json() -> Dictionary:
	if _story_battles_cache_loaded:
		return _story_battles_cache
	_story_battles_cache_loaded = true
	if not FileAccess.file_exists(STORY_BATTLES_JSON_PATH):
		push_warning("StoryBattleLoader: JSON file not found: %s" % STORY_BATTLES_JSON_PATH)
		return {}
	var file := FileAccess.open(STORY_BATTLES_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("StoryBattleLoader: cannot open JSON file: %s" % STORY_BATTLES_JSON_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_story_battles_cache = parsed
	else:
		push_warning("StoryBattleLoader: JSON root must be an object: %s" % STORY_BATTLES_JSON_PATH)
	return _story_battles_cache


static func _to_int(value, fallback: int) -> int:
	var text: String = str(value).strip_edges()
	if text == "" or not text.is_valid_int():
		return fallback
	return int(text)
