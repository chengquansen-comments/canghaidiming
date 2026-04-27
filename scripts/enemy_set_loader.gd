extends RefCounted
class_name EnemySetLoader

const FighterData = preload("res://scripts/fighter_data.gd")
const CardData = preload("res://scripts/card_data.gd")

const MANIFEST_PATH := "res://data/enemy_sets/enemy_sets_manifest.tsv"
const ENEMY_SET_DIR := "res://data/enemy_sets/"


static func load_manifest(path: String = MANIFEST_PATH) -> Array[Dictionary]:
	return _read_tsv(path)


static func load_enabled_manifest(path: String = MANIFEST_PATH) -> Array[Dictionary]:
	var rows: Array[Dictionary] = load_manifest(path)
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:
		if str(row.get("enabled", "1")) != "0":
			result.append(row)
	return result


static func find_set_row(set_id: String, manifest_path: String = MANIFEST_PATH) -> Dictionary:
	for row: Dictionary in load_enabled_manifest(manifest_path):
		if str(row.get("set_id", "")) == set_id:
			return row
	return {}


static func load_enemy_set(set_id: String, manifest_path: String = MANIFEST_PATH) -> Array[Dictionary]:
	var row: Dictionary = find_set_row(set_id, manifest_path)
	if row.is_empty():
		push_warning("EnemySetLoader: enemy set not found: %s" % set_id)
		return []
	var file_name: String = str(row.get("file", ""))
	if file_name == "":
		push_warning("EnemySetLoader: enemy set has empty file: %s" % set_id)
		return []
	return _read_tsv(ENEMY_SET_DIR + file_name)


static func load_first_enemy_data(set_id: String, card_catalog: Dictionary, manifest_path: String = MANIFEST_PATH) -> FighterData:
	var rows: Array[Dictionary] = load_enemy_set(set_id, manifest_path)
	if rows.is_empty():
		return null
	return enemy_row_to_fighter_data(rows[0], card_catalog)


static func enemy_row_to_fighter_data(row: Dictionary, card_catalog: Dictionary) -> FighterData:
	var enemy_id: String = str(row.get("enemy_id", "enemy"))
	var display_name: String = str(row.get("display_name", enemy_id))
	var weapon_style: String = str(row.get("weapon_style", ""))
	var max_hp: int = _to_int(row.get("max_hp", "20"), 20)
	var max_momentum: int = _to_int(row.get("max_momentum", "6"), 6)
	var starting_momentum: int = _to_int(row.get("starting_momentum", "5"), 5)
	var starting_realm: int = _to_int(row.get("starting_realm", "1"), 1)
	var qinggong: int = _to_int(row.get("qinggong", "1"), 1)
	var start_position: int = _to_int(row.get("start_position", "6"), 6)
	var start_facing: String = str(row.get("start_facing", "left"))
	var preferred_distances: PackedInt32Array = parse_preferred_distances(str(row.get("preferred_distances", "")))
	var deck: Array[CardData] = parse_deck(str(row.get("deck", "")), card_catalog)
	return FighterData.new(enemy_id, display_name, weapon_style, max_hp, max_momentum, starting_momentum, starting_realm, preferred_distances, deck, qinggong, start_position, start_facing)


static func parse_preferred_distances(text: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	for part in text.split(",", false):
		var token: String = part.strip_edges()
		if token != "":
			result.append(_to_int(token, 0))
	return result


static func parse_deck(text: String, card_catalog: Dictionary) -> Array[CardData]:
	var result: Array[CardData] = []
	for entry in text.split(",", false):
		var token: String = entry.strip_edges()
		if token == "":
			continue
		var pieces: PackedStringArray = token.split(":", false)
		var card_id: String = pieces[0].strip_edges()
		var count: int = 1
		if pieces.size() >= 2:
			count = maxi(_to_int(pieces[1], 1), 0)
		if not card_catalog.has(card_id):
			push_warning("EnemySetLoader: card id not found in catalog: %s" % card_id)
			continue
		var card_value = card_catalog[card_id]
		if not (card_value is CardData):
			push_warning("EnemySetLoader: card catalog value is not CardData: %s" % card_id)
			continue
		var card: CardData = card_value
		for i in range(count):
			result.append(card.duplicate_card())
	return result


static func row_label(row: Dictionary) -> String:
	return "%s（%s）" % [str(row.get("display_name", row.get("set_id", "unknown"))), str(row.get("set_id", ""))]


static func _read_tsv(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		push_warning("EnemySetLoader: TSV file not found: %s" % path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("EnemySetLoader: cannot open TSV file: %s" % path)
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
			var key: String = headers[h].strip_edges()
			var value: String = values[h].strip_edges() if h < values.size() else ""
			row[key] = value
		rows.append(row)
	return rows


static func _to_int(value, fallback: int) -> int:
	var text: String = str(value).strip_edges()
	if text == "":
		return fallback
	if not text.is_valid_int():
		return fallback
	return int(text)
