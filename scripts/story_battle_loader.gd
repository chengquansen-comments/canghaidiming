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
		"settlement_mode": str(encounter.get("settlement_mode", "symmetric"))
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
