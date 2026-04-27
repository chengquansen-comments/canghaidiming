extends RefCounted
class_name StoryBattleLoader

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")
const EnemySetLoader = preload("res://scripts/enemy_set_loader.gd")

const BASE_DIR := "res://data/story_battles/"
const FIGHTER_TEMPLATES_PATH := BASE_DIR + "fighter_templates.tsv"
const STORY_DECK_SETS_PATH := BASE_DIR + "story_deck_sets.tsv"
const FIGHTER_STAT_SETS_PATH := BASE_DIR + "fighter_stat_sets.tsv"
const STORY_ENCOUNTERS_PATH := BASE_DIR + "story_encounters.tsv"
const MODE_SYMMETRIC_ID := "symmetric"
const MODE_REACTIVE_ID := "reactive"


static func load_encounters() -> Array[Dictionary]:
	return _read_tsv(STORY_ENCOUNTERS_PATH)


static func find_encounter(encounter_id: String) -> Dictionary:
	for row: Dictionary in load_encounters():
		if str(row.get("encounter_id", "")) == encounter_id:
			return row
	return {}


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
	return {
		"encounter": encounter,
		"player_data": player_data,
		"opponent_data": opponent_data,
		"settlement_mode": str(encounter.get("settlement_mode", MODE_SYMMETRIC_ID))
	}


static func build_fighter_data(template_id: String, deck_id: String, stat_set_id: String, card_catalog: Dictionary, is_player_side: bool) -> FighterData:
	var template: Dictionary = _find_row(FIGHTER_TEMPLATES_PATH, "fighter_template_id", template_id)
	var deck_set: Dictionary = _find_row(STORY_DECK_SETS_PATH, "story_deck_id", deck_id)
	var stat_set: Dictionary = _find_row(FIGHTER_STAT_SETS_PATH, "stat_set_id", stat_set_id)
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
	var deck: Array[CardData] = EnemySetLoader.parse_deck(str(deck_set.get("deck", "")), card_catalog)
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
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var template_ids: Dictionary = _id_index(_read_tsv(FIGHTER_TEMPLATES_PATH), "fighter_template_id", errors)
	var deck_ids: Dictionary = _id_index(_read_tsv(STORY_DECK_SETS_PATH), "story_deck_id", errors)
	var stat_ids: Dictionary = _id_index(_read_tsv(FIGHTER_STAT_SETS_PATH), "stat_set_id", errors)
	var encounter_ids: Dictionary = _id_index(_read_tsv(STORY_ENCOUNTERS_PATH), "encounter_id", errors)

	for deck_id in deck_ids.keys():
		var deck_row: Dictionary = deck_ids[deck_id]
		var template_id: String = str(deck_row.get("fighter_template_id", ""))
		if not template_ids.has(template_id):
			errors.append("story_deck_sets.%s references missing fighter_template_id: %s" % [deck_id, template_id])
		for card_id in _deck_card_ids(str(deck_row.get("deck", ""))):
			if not card_catalog.has(card_id):
				errors.append("story_deck_sets.%s references missing CardData.id: %s" % [deck_id, card_id])

	for stat_id in stat_ids.keys():
		var stat_row: Dictionary = stat_ids[stat_id]
		for field in ["max_hp", "max_momentum", "starting_momentum", "starting_realm", "qinggong"]:
			if not str(stat_row.get(field, "")).is_valid_int():
				errors.append("fighter_stat_sets.%s has non-int field %s=%s" % [stat_id, field, str(stat_row.get(field, ""))])

	for encounter_id in encounter_ids.keys():
		var encounter: Dictionary = encounter_ids[encounter_id]
		_validate_ref(errors, "story_encounters.%s.player_template_id" % encounter_id, template_ids, str(encounter.get("player_template_id", "")))
		_validate_ref(errors, "story_encounters.%s.opponent_template_id" % encounter_id, template_ids, str(encounter.get("opponent_template_id", "")))
		_validate_ref(errors, "story_encounters.%s.player_deck_id" % encounter_id, deck_ids, str(encounter.get("player_deck_id", "")))
		_validate_ref(errors, "story_encounters.%s.opponent_deck_id" % encounter_id, deck_ids, str(encounter.get("opponent_deck_id", "")))
		_validate_ref(errors, "story_encounters.%s.player_stat_set_id" % encounter_id, stat_ids, str(encounter.get("player_stat_set_id", "")))
		_validate_ref(errors, "story_encounters.%s.opponent_stat_set_id" % encounter_id, stat_ids, str(encounter.get("opponent_stat_set_id", "")))
		var mode: String = str(encounter.get("settlement_mode", MODE_SYMMETRIC_ID))
		if mode != MODE_SYMMETRIC_ID and mode != MODE_REACTIVE_ID:
			errors.append("story_encounters.%s has invalid settlement_mode: %s" % [encounter_id, mode])

		var player_deck: Dictionary = deck_ids.get(str(encounter.get("player_deck_id", "")), {})
		var opponent_deck: Dictionary = deck_ids.get(str(encounter.get("opponent_deck_id", "")), {})
		if not player_deck.is_empty() and str(player_deck.get("fighter_template_id", "")) != str(encounter.get("player_template_id", "")):
			warnings.append("story_encounters.%s player_deck_id template differs from player_template_id" % encounter_id)
		if not opponent_deck.is_empty() and str(opponent_deck.get("fighter_template_id", "")) != str(encounter.get("opponent_template_id", "")):
			warnings.append("story_encounters.%s opponent_deck_id template differs from opponent_template_id" % encounter_id)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"counts": {
			"templates": template_ids.size(),
			"decks": deck_ids.size(),
			"stats": stat_ids.size(),
			"encounters": encounter_ids.size()
		}
	}


static func format_validation_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	var counts: Dictionary = report.get("counts", {})
	lines.append("StoryBattle TSV validation: %s" % ("OK" if bool(report.get("ok", false)) else "FAILED"))
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


static func _find_row(path: String, key: String, value: String) -> Dictionary:
	for row: Dictionary in _read_tsv(path):
		if str(row.get(key, "")) == value:
			return row
	return {}


static func _id_index(rows: Array[Dictionary], id_key: String, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var id: String = str(row.get(id_key, ""))
		if id == "":
			errors.append("missing id field: %s" % id_key)
			continue
		if result.has(id):
			errors.append("duplicate id %s=%s" % [id_key, id])
			continue
		result[id] = row
	return result


static func _deck_card_ids(deck_text: String) -> PackedStringArray:
	var result := PackedStringArray()
	for entry in deck_text.split(",", false):
		var token: String = entry.strip_edges()
		if token == "":
			continue
		var pieces: PackedStringArray = token.split(":", false)
		var card_id: String = pieces[0].strip_edges()
		if card_id != "":
			result.append(card_id)
	return result


static func _validate_ref(errors: Array[String], label: String, index: Dictionary, value: String) -> void:
	if value == "":
		errors.append("%s is empty" % label)
		return
	if not index.has(value):
		errors.append("%s references missing id: %s" % [label, value])


static func _read_tsv(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		push_warning("StoryBattleLoader: TSV file not found: %s" % path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("StoryBattleLoader: cannot open TSV file: %s" % path)
		return []
	var content: String = file.get_as_text()
	var lines: PackedStringArray = content.split("\n", false)
	if lines.is_empty():
		return []
	var headers: PackedStringArray = lines[0].strip_edges().split("\t", false)
	var rows: Array[Dictionary] = []
	for i in range(1, lines.size()):
		var line: String = lines[i].strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var values: PackedStringArray = line.split("\t", false)
		var row: Dictionary = {}
		for h in range(headers.size()):
			var k: String = headers[h].strip_edges()
			row[k] = values[h].strip_edges() if h < values.size() else ""
		rows.append(row)
	return rows


static func _to_int(value, fallback: int) -> int:
	var text: String = str(value).strip_edges()
	if text == "" or not text.is_valid_int():
		return fallback
	return int(text)
