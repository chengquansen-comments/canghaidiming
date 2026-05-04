extends "res://scripts/battle_controller_visual_break_preview.gd"

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const BattleStateMachineScript := preload("res://scripts/battle_state_machine.gd")
const NarrativeStoryBattleLoader := preload("res://scripts/story_battle_loader.gd")
const DEFAULT_NARRATIVE_SCENE := "res://scenes/NarrativeDemo.tscn"
const ENEMY_MANIFEST_PATH := "res://data/enemy_manifest.json"
const NARRATIVE_BATTLE_SCENE_MANIFEST_PATH := "res://data/battle_scene_manifest.json"
const STRATEGIC_MAP_CONFIG_PATH := "res://data/strategic_map.json"
const NARRATIVE_FALLBACK_BATTLE_ID := "fallback"

var narrative_debug_layer: CanvasLayer
var enemy_config_strip: Label
var narrative_debug_box: VBoxContainer
var narrative_context_label: Label
var battle_mapping_label: Label
var enemy_config_label: Label
var battle_result_label: Label
var recommended_start_button: Button
var continue_narrative_button: Button
var last_result_debug_text: String = ""
var result_recorded: bool = false
var narrative_numbers_applied: bool = false
var narrative_auto_start_attempted: bool = false
var battle_loadout: Dictionary = {}
var battle_loadout_applied: bool = false
var battle_loadout_error: String = ""
# Narrative context foundation layer.

func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func _dict(value) -> Dictionary:
	if value is Dictionary:
		return value
	return {}

func _story_loader_card_catalog() -> Dictionary:
	return NarrativeStoryBattleLoader.build_card_catalog(fighter_catalog, reward_pool)

func _fighter_data_to_config(data) -> Dictionary:
	if data == null:
		return {}
	return {
		"id": data.id,
		"name": data.display_name,
		"display_name": data.display_name,
		"weapon": data.weapon_name,
		"max_hp": data.max_hp,
		"hp": data.max_hp,
		"max_momentum": data.max_momentum,
		"momentum": data.starting_momentum,
		"realm": data.starting_realm,
		"qinggong": data.qinggong,
		"position": data.starting_position,
		"facing": data.starting_facing,
		"preferred": Array(data.preferred_distances),
		"deck": data.clone_deck()
	}

func _weighted_pool_entry(entries: Array[Dictionary], seed_value: int) -> Dictionary:
	if entries.is_empty():
		return {}
	var total := 0
	for entry in entries:
		total += maxi(1, int(entry.get("weight", 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for entry in entries:
		cursor += maxi(1, int(entry.get("weight", 1)))
		if roll <= cursor:
			return entry.duplicate(true)
	return entries[0].duplicate(true)

func _combat_pool_seed(combat_pool_id: String, enemy_martial_level: int) -> int:
	var key := "%s|%s|%s|%d" % [
		combat_pool_id,
		str(NarrativeBattleContext.source_node_id),
		str(NarrativeBattleContext.battle_id),
		enemy_martial_level,
	]
	return int(abs(key.hash()))

func _player_deck_id_for_profile(role_id: String, profile: Dictionary) -> String:
	var wins := int(profile.get("battles_won", 0))
	if role_id == "spearman":
		return "player_spear_advanced" if wins >= 6 else "player_spear_start"
	return "player_blade_start"

func _card_id_array(value) -> Array[String]:
	var ids: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var card_id := str(item)
			if not card_id.is_empty():
				ids.append(card_id)
	elif value is String:
		var card_id := str(value)
		if not card_id.is_empty():
			ids.append(card_id)
	return ids

func _packed_ints(values: Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for value_variant in values:
		result.append(int(value_variant))
	return result

func _deck_summary(deck: Array) -> String:
	var chunks: Array[String] = []
	for config_variant in deck:
		if config_variant is CardData:
			var card: CardData = config_variant
			chunks.append("%s[耗%d/伤%d/守%d/势+%d/破%d/距%d-%d]" % [card.display_name, card.momentum_cost, card.damage, card.guard, card.gain_momentum, card.break_momentum, card.min_distance, card.max_distance])
			continue
		var config: Dictionary = config_variant
		chunks.append("%s[耗%d/伤%d/守%d/势+%d/破%d/距%d-%d]" % [str(config.get("name", "")), int(config.get("cost", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("min", 0)), int(config.get("max", 0))])
	return "；".join(chunks)

func _set_battle_result_debug_text(text: String) -> void:
	if text == last_result_debug_text:
		return
	last_result_debug_text = text
	battle_result_label.text = text

func _get_narrative_result() -> String:
	if player == null or enemy == null:
		return "win"
	if player.hp > 0 and enemy.hp <= 0:
		return "win"
	if player.hp <= 0 and enemy.hp > 0:
		return "lose"
	if player.hp <= 0 and enemy.hp <= 0:
		return "draw"
	return "win"

func _method_accepts_arg_count(method_name: String, arg_count: int) -> bool:
	for method_info_variant in get_method_list():
		var method_info: Dictionary = method_info_variant
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() == arg_count
	return false

