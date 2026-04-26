extends RefCounted
class_name NarrativeEnemyManifest

const DATA_PATH := "res://data/enemy_manifest.json"

static var cached_data: Dictionary = {}
static var loaded: bool = false
static var attempted: bool = false

static func get_data() -> Dictionary:
	if not attempted:
		_load()
	return cached_data

static func is_loaded() -> bool:
	if not attempted:
		_load()
	return loaded

static func _load() -> void:
	attempted = true
	loaded = false
	cached_data.clear()
	if not FileAccess.file_exists(DATA_PATH):
		return
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		cached_data = parsed
		loaded = true

static func get_encounter(encounter_id: String) -> Dictionary:
	var data: Dictionary = get_data()
	var encounters_variant = data.get("encounters", {})
	if encounters_variant is Dictionary:
		var encounters: Dictionary = encounters_variant
		var encounter_variant = encounters.get(encounter_id, encounters.get("fallback", {}))
		if encounter_variant is Dictionary:
			return encounter_variant
	return {}

static func get_enemy(enemy_id: String) -> Dictionary:
	var data: Dictionary = get_data()
	var enemies_variant = data.get("enemies", {})
	if enemies_variant is Dictionary:
		var enemies: Dictionary = enemies_variant
		var enemy_variant = enemies.get(enemy_id, enemies.get("enemy_spearman_fallback", {}))
		if enemy_variant is Dictionary:
			return enemy_variant
	return {}

static func get_mapping(encounter_id: String, fallback_battle_id: String = "fallback") -> Dictionary:
	var encounter: Dictionary = get_encounter(encounter_id)
	if encounter.is_empty():
		return {}
	var enemy_id: String = str(encounter.get("enemy_id", "enemy_spearman_fallback"))
	var enemy_config: Dictionary = get_enemy(enemy_id)
	var mapping: Dictionary = {}
	mapping["battle_id"] = str(encounter.get("battle_id", fallback_battle_id))
	mapping["player_role"] = str(encounter.get("player_role", "spearman"))
	mapping["enemy_role"] = str(encounter.get("enemy_role", enemy_config.get("role_sheet", "enemy_spearman")))
	mapping["enemy_family"] = str(encounter.get("enemy_family", "spearman"))
	mapping["difficulty"] = str(encounter.get("difficulty", "fallback"))
	mapping["label"] = str(encounter.get("label", encounter_id))
	mapping["enemy_config"] = enemy_config
	return mapping
