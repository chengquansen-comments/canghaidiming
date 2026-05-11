extends "res://scripts/battle_controller_visual_narrative_context_player_profile.gd"

const AigcBattleRuntimeManifestLoader := preload("res://scripts/aigc_battle/aigc_battle_runtime_manifest_loader.gd")

# Narrative context loadout layer.

var last_loadout_source := ""
var last_generated_battle_slot_id := ""
var last_generated_deck_id := ""
var last_content_pack_id := ""
var last_reward_source := ""
var last_reward_plan_id := ""
var last_generated_reward_visible := false
var last_generated_reward_claimed := false
var last_formal_progression_continues := false
var last_release_channel := ""
var last_release_profile_id := ""
var last_release_content_pack_id := ""
var last_release_runtime_manifest_path := ""
var last_formal_entry_uses_release_pack := false
var last_formal_entry_fallback_used := false
var last_formal_entry_generated_loadout_count := 0
var last_formal_entry_fallback_loadout_count := 0
var last_runtime_primitives: Array = []
var last_opening_pressure_source := ""
var last_opening_pressure_enemy_momentum_bonus := 0
var last_opening_pressure_enemy_block_bonus := 0
var last_opening_pressure_applied := false
var last_opening_pressure_applied_fields: Array = []
var last_weapon_followup_enabled := false
var last_weapon_followup_expected_chain_count := 0
var last_weapon_followup_primary_weapon_style := ""
var last_weapon_followup_pressure_level := ""
var last_weapon_followup_triggered := false
var last_weapon_followup_trigger_count := 0
var last_weapon_followup_bonus_applied := {}
var last_weapon_followup_applied_fields: Array = []
var last_weapon_followup_card_id := ""
var last_weapon_followup_group := ""
var last_weapon_followup_trigger := ""
var last_weapon_followup_error := ""
var _runtime_generated_card_meta := {}
var _runtime_last_card_by_side := {}
var _runtime_turn_count := 0
var _runtime_cards_played_count := 0
var _runtime_enemy_cards_played_count := 0
var _runtime_damage_dealt := 0
var _runtime_damage_taken := 0
var _runtime_block_gained := 0
var _runtime_momentum_gained := 0
var _runtime_momentum_broken := 0
var _runtime_player_hp_start := 0
var _runtime_enemy_hp_start := 0
var _runtime_player_card_ids_played: Array = []
var _runtime_enemy_card_ids_played: Array = []
var last_telemetry_written := false
var last_telemetry_path := ""
var last_telemetry_error := ""
var last_telemetry_event_profile_id := ""
var last_telemetry_event_battle_slot_id := ""
var last_telemetry_event_deck_id := ""

func _reset_last_loadout_resolution() -> void:
	last_loadout_source = ""
	last_generated_battle_slot_id = ""
	last_generated_deck_id = ""
	last_content_pack_id = ""
	last_reward_source = ""
	last_reward_plan_id = ""
	last_generated_reward_visible = false
	last_generated_reward_claimed = false
	last_formal_progression_continues = false
	last_release_channel = ""
	last_release_profile_id = ""
	last_release_content_pack_id = ""
	last_release_runtime_manifest_path = ""
	last_formal_entry_uses_release_pack = false
	last_formal_entry_fallback_used = false
	last_formal_entry_generated_loadout_count = 0
	last_formal_entry_fallback_loadout_count = 0
	last_runtime_primitives.clear()
	last_opening_pressure_source = ""
	last_opening_pressure_enemy_momentum_bonus = 0
	last_opening_pressure_enemy_block_bonus = 0
	last_opening_pressure_applied = false
	last_opening_pressure_applied_fields.clear()
	last_weapon_followup_enabled = false
	last_weapon_followup_expected_chain_count = 0
	last_weapon_followup_primary_weapon_style = ""
	last_weapon_followup_pressure_level = ""
	last_weapon_followup_triggered = false
	last_weapon_followup_trigger_count = 0
	last_weapon_followup_bonus_applied = {}
	last_weapon_followup_applied_fields.clear()
	last_weapon_followup_card_id = ""
	last_weapon_followup_group = ""
	last_weapon_followup_trigger = ""
	last_weapon_followup_error = ""
	_runtime_generated_card_meta = {}
	_runtime_last_card_by_side = {}
	_runtime_turn_count = 0
	_runtime_cards_played_count = 0
	_runtime_enemy_cards_played_count = 0
	_runtime_damage_dealt = 0
	_runtime_damage_taken = 0
	_runtime_block_gained = 0
	_runtime_momentum_gained = 0
	_runtime_momentum_broken = 0
	_runtime_player_hp_start = 0
	_runtime_enemy_hp_start = 0
	_runtime_player_card_ids_played.clear()
	_runtime_enemy_card_ids_played.clear()
	last_telemetry_written = false
	last_telemetry_path = ""
	last_telemetry_error = ""
	last_telemetry_event_profile_id = ""
	last_telemetry_event_battle_slot_id = ""
	last_telemetry_event_deck_id = ""

func _get_generated_manifest_loadout(encounter_id: String, battle_id: String) -> Dictionary:
	if encounter_id.is_empty():
		return {}
	if not AigcBattleRuntimeManifestLoader.load_active_manifest():
		return {}
	return AigcBattleRuntimeManifestLoader.get_generated_loadout(encounter_id, battle_id)

func _apply_generated_manifest_enemy_config(enemy_config: Dictionary, generated_loadout: Dictionary) -> Dictionary:
	if enemy_config.is_empty() or generated_loadout.is_empty():
		return enemy_config
	enemy_config["deck"] = generated_loadout.get("cards", [])
	enemy_config["enemy_role"] = str(generated_loadout.get("enemy_role", enemy_config.get("enemy_role", "")))
	enemy_config["difficulty_tier"] = str(generated_loadout.get("difficulty_tier", enemy_config.get("difficulty_tier", "")))
	enemy_config["generated_battle_slot_id"] = str(generated_loadout.get("generated_battle_slot_id", ""))
	enemy_config["generated_deck_id"] = str(generated_loadout.get("generated_deck_id", ""))
	enemy_config["content_pack_id"] = str(generated_loadout.get("content_pack_id", ""))
	enemy_config["enemy_source"] = "generated_manifest"
	return enemy_config

func _story_battle_for_encounter(encounter_id: String) -> Dictionary:
	var catalog: Dictionary = _story_loader_card_catalog()
	return NarrativeStoryBattleLoader.build_story_battle(encounter_id, catalog)

func _enemy_manifest_context_for_encounter(encounter_id: String) -> Dictionary:
	var manifest: Dictionary = _read_json_dict(ENEMY_MANIFEST_PATH)
	if manifest.is_empty():
		return {}
	var encounters: Dictionary = _dict(manifest.get("encounters", {}))
	var manifest_encounter: Dictionary = _dict(encounters.get(encounter_id, {}))
	if manifest_encounter.is_empty():
		return {}
	var enemy_id: String = str(manifest_encounter.get("enemy_id", ""))
	var enemies: Dictionary = _dict(manifest.get("enemies", {}))
	var manifest_enemy: Dictionary = _dict(enemies.get(enemy_id, {}))
	return {
		"enemy_id": enemy_id,
		"encounter": manifest_encounter,
		"enemy": manifest_enemy
	}

func _apply_enemy_manifest_to_story_config(story_config: Dictionary, manifest_context: Dictionary) -> Dictionary:
	if story_config.is_empty():
		return story_config
	var manifest_enemy: Dictionary = _dict(manifest_context.get("enemy", {}))
	if manifest_enemy.is_empty():
		return story_config
	var enemy_id: String = str(manifest_context.get("enemy_id", manifest_enemy.get("enemy_id", story_config.get("id", ""))))
	story_config["id"] = enemy_id
	story_config["enemy_id"] = enemy_id
	story_config["name"] = str(manifest_enemy.get("display_name", story_config.get("name", enemy_id)))
	story_config["display_name"] = str(manifest_enemy.get("display_name", story_config.get("display_name", story_config.get("name", enemy_id))))
	story_config["weapon"] = str(manifest_enemy.get("weapon", story_config.get("weapon", "")))
	story_config["role_sheet"] = str(manifest_enemy.get("role_sheet", story_config.get("role_sheet", "")))
	story_config["max_hp"] = int(manifest_enemy.get("max_hp", story_config.get("max_hp", 20)))
	story_config["hp"] = int(story_config.get("max_hp", 20))
	story_config["max_momentum"] = int(manifest_enemy.get("max_posture", manifest_enemy.get("max_momentum", story_config.get("max_momentum", 10))))
	story_config["momentum"] = int(manifest_enemy.get("start_posture", manifest_enemy.get("momentum", story_config.get("momentum", 4))))
	story_config["realm"] = int(manifest_enemy.get("realm", story_config.get("realm", 1)))
	story_config["qinggong"] = int(manifest_enemy.get("qinggong", story_config.get("qinggong", 1)))
	return story_config

func _apply_narrative_battle_overrides(enemy_config: Dictionary) -> Dictionary:
	var overrides := NarrativeBattleContext.get_battle_overrides()
	enemy_config = _apply_combat_enemy_pool_override(enemy_config, overrides)
	var enemy_martial_level := int(overrides.get("enemy_martial_level", 0))
	if enemy_martial_level > 0:
		enemy_config = _apply_enemy_martial_stats(enemy_config, enemy_martial_level)
		enemy_config["enemy_martial_level"] = enemy_martial_level
	var combat_pool_id := str(overrides.get("combat_pool_id", ""))
	if not combat_pool_id.is_empty():
		enemy_config["combat_pool_id"] = combat_pool_id
	return enemy_config

func _apply_combat_enemy_pool_override(enemy_config: Dictionary, overrides: Dictionary) -> Dictionary:
	var combat_pool_id := str(overrides.get("combat_pool_id", ""))
	if combat_pool_id.is_empty():
		return enemy_config
	var enemy_martial_level := int(overrides.get("enemy_martial_level", 0))
	var strategic_config := _read_json_dict(STRATEGIC_MAP_CONFIG_PATH)
	var pools: Dictionary = _dict(strategic_config.get("combat_enemy_pools", {}))
	var entries: Array = pools.get(combat_pool_id, [])
	var eligible: Array[Dictionary] = []
	for item in entries:
		if not (item is Dictionary):
			continue
		var entry := item as Dictionary
		if enemy_martial_level > 0:
			if enemy_martial_level < int(entry.get("martial_min", 1)) or enemy_martial_level > int(entry.get("martial_max", 999)):
				continue
		eligible.append(entry)
	if eligible.is_empty():
		return enemy_config
	var selected := _weighted_pool_entry(eligible, _combat_pool_seed(combat_pool_id, enemy_martial_level))
	if selected.is_empty():
		return enemy_config
	var deck_id := str(selected.get("opponent_deck_id", ""))
	var template_id := str(selected.get("opponent_template_id", ""))
	var data = NarrativeStoryBattleLoader.build_fighter_data(template_id, deck_id, "normal", _story_loader_card_catalog(), false)
	if data == null:
		return enemy_config
	enemy_config = _fighter_data_to_config(data)
	enemy_config["id"] = str(selected.get("pool_entry_id", template_id))
	enemy_config["enemy_id"] = str(selected.get("pool_entry_id", template_id))
	enemy_config["display_name"] = str(selected.get("display_name", enemy_config.get("display_name", "")))
	enemy_config["name"] = str(selected.get("display_name", enemy_config.get("name", "")))
	enemy_config["enemy_family"] = str(selected.get("enemy_family", ""))
	enemy_config["combat_pool_id"] = combat_pool_id
	enemy_config["combat_pool_entry_id"] = str(selected.get("pool_entry_id", ""))
	enemy_config["enemy_source"] = "combat_enemy_pool"
	enemy_config["hp_bonus"] = int(selected.get("hp_bonus", 0))
	enemy_config["max_momentum_bonus"] = int(selected.get("max_momentum_bonus", 0))
	enemy_config["starting_momentum_bonus"] = int(selected.get("starting_momentum_bonus", 0))
	enemy_config["qinggong_bonus"] = int(selected.get("qinggong_bonus", 0))
	return enemy_config

func _apply_enemy_martial_stats(enemy_config: Dictionary, martial_level: int) -> Dictionary:
	var strategic_config := _read_json_dict(STRATEGIC_MAP_CONFIG_PATH)
	var stats_by_level: Dictionary = _dict(strategic_config.get("enemy_martial_stats", {}))
	var stats: Dictionary = _dict(stats_by_level.get(str(martial_level), {}))
	if stats.is_empty():
		enemy_config["realm"] = martial_level
		return enemy_config
	var hp_bonus := int(enemy_config.get("hp_bonus", 0))
	var max_momentum_bonus := int(enemy_config.get("max_momentum_bonus", 0))
	var starting_momentum_bonus := int(enemy_config.get("starting_momentum_bonus", 0))
	var qinggong_bonus := int(enemy_config.get("qinggong_bonus", 0))
	var max_momentum := maxi(1, int(stats.get("max_momentum", enemy_config.get("max_momentum", 6))) + max_momentum_bonus)
	var momentum := clampi(int(stats.get("starting_momentum", enemy_config.get("momentum", 3))) + starting_momentum_bonus, 0, max_momentum)
	enemy_config["max_hp"] = maxi(1, int(stats.get("max_hp", enemy_config.get("max_hp", 20))) + hp_bonus)
	enemy_config["hp"] = int(enemy_config.get("max_hp", 20))
	enemy_config["max_momentum"] = max_momentum
	enemy_config["max_posture"] = max_momentum
	enemy_config["momentum"] = momentum
	enemy_config["start_posture"] = momentum
	enemy_config["realm"] = martial_level
	enemy_config["qinggong"] = maxi(1, int(stats.get("qinggong", enemy_config.get("qinggong", 1))) + qinggong_bonus)
	return enemy_config

func _resolve_battle_loadout() -> Dictionary:
	battle_loadout_error = ""
	_reset_last_loadout_resolution()
	var encounter_id: String = str(NarrativeBattleContext.encounter_id)
	var source_node_id: String = str(NarrativeBattleContext.source_node_id)
	var context_battle_id: String = NarrativeBattleContext.get_battle_id()
	var battle_id: String = context_battle_id
	if battle_id.is_empty():
		battle_id = NARRATIVE_FALLBACK_BATTLE_ID
	var scene_manifest: Dictionary = _read_json_dict(NARRATIVE_BATTLE_SCENE_MANIFEST_PATH)
	var scene_config: Dictionary = _dict(scene_manifest.get(battle_id, scene_manifest.get(NARRATIVE_FALLBACK_BATTLE_ID, {})))
	var story_battle: Dictionary = _story_battle_for_encounter(encounter_id)
	if story_battle.is_empty():
		battle_loadout_error = "StoryBattleLoader 缺少 encounter_id=%s" % encounter_id
		return {}
	var encounter_config: Dictionary = _dict(story_battle.get("encounter", {}))
	var player_data = story_battle.get("player_data", null)
	var opponent_data = story_battle.get("opponent_data", null)
	if player_data == null or opponent_data == null:
		battle_loadout_error = "StoryBattleLoader 返回空 fighter data: %s" % encounter_id
		return {}
	var player_config: Dictionary = _fighter_data_to_config(player_data)
	var enemy_config: Dictionary = _fighter_data_to_config(opponent_data)
	var manifest_context: Dictionary = _enemy_manifest_context_for_encounter(encounter_id)
	enemy_config = _apply_enemy_manifest_to_story_config(enemy_config, manifest_context)
	enemy_config = _apply_narrative_battle_overrides(enemy_config)
	var profile: Dictionary = NarrativeBattleContext.get_player_profile()
	player_config = _apply_story_player_overrides(player_config, profile)
	var generated_loadout := _get_generated_manifest_loadout(encounter_id, battle_id)
	var generated_manifest_summary: Dictionary = AigcBattleRuntimeManifestLoader.get_manifest_summary() if not generated_loadout.is_empty() else {}
	if not generated_loadout.is_empty():
		enemy_config = _apply_generated_manifest_enemy_config(enemy_config, generated_loadout)
		last_loadout_source = "generated_manifest"
		last_generated_battle_slot_id = str(generated_loadout.get("generated_battle_slot_id", ""))
		last_generated_deck_id = str(generated_loadout.get("generated_deck_id", ""))
		last_content_pack_id = str(generated_loadout.get("content_pack_id", ""))
	else:
		last_loadout_source = "fallback_story_battle_loader"
	var override_player_profile := NarrativeBattleContext.should_override_player_profile()
	var settlement_mode: String = str(story_battle.get("settlement_mode", BattleStateMachineScript.MODE_REACTIVE_ID))
	var manifest_encounter: Dictionary = _dict(manifest_context.get("encounter", {}))
	var manifest_enemy: Dictionary = _dict(manifest_context.get("enemy", {}))
	var enemy_id: String = str(enemy_config.get("id", manifest_context.get("enemy_id", encounter_config.get("opponent_template_id", ""))))
	var enemy_source: String = str(enemy_config.get("enemy_source", "enemy_manifest" if not manifest_enemy.is_empty() else "story_battles"))
	return {
		"battle_id": battle_id,
		"encounter_id": encounter_id,
		"source_node_id": source_node_id,
		"override_player_profile": override_player_profile,
		"scene_config": scene_config,
		"encounter_config": manifest_encounter if not manifest_encounter.is_empty() else encounter_config,
		"story_encounter_config": encounter_config,
		"player_config": player_config,
		"enemy_config": enemy_config,
		"player_deck": player_config.get("deck", []),
		"enemy_deck": enemy_config.get("deck", []),
		"enemy_id": enemy_id,
		"enemy_source": enemy_source,
		"loadout_source": last_loadout_source,
		"generated_battle_slot_id": last_generated_battle_slot_id,
		"generated_deck_id": last_generated_deck_id,
		"content_pack_id": last_content_pack_id,
		"generated_reward": generated_loadout.get("reward", {}) if not generated_loadout.is_empty() else {},
		"reward_plan": generated_loadout.get("reward", {}) if not generated_loadout.is_empty() else {},
		"reward_plan_id": str(generated_loadout.get("reward_plan_id", "")) if not generated_loadout.is_empty() else "",
		"reward_source": str(generated_loadout.get("reward_source", "generated_manifest")) if not generated_loadout.is_empty() else "fallback",
		"mechanic_profile_id": str(generated_loadout.get("mechanic_profile_id", generated_manifest_summary.get("mechanic_profile_id", ""))) if not generated_loadout.is_empty() else "",
		"target_sequence_id": str(generated_manifest_summary.get("target_sequence_id", "")) if not generated_loadout.is_empty() else "",
		"sequence_position": int(generated_loadout.get("sequence_position", 0)) if not generated_loadout.is_empty() else 0,
		"encounter_tier": str(generated_loadout.get("encounter_tier", "")) if not generated_loadout.is_empty() else "",
		"encounter_kind": str(generated_loadout.get("encounter_kind", "")) if not generated_loadout.is_empty() else "",
		"target_power_min": int(generated_loadout.get("target_power_min", 0)) if not generated_loadout.is_empty() else 0,
		"target_power_max": int(generated_loadout.get("target_power_max", 0)) if not generated_loadout.is_empty() else 0,
			"deck_power_score": float(generated_loadout.get("deck_power_score", 0.0)) if not generated_loadout.is_empty() else 0.0,
			"runtime_primitives": generated_loadout.get("runtime_primitives", []) if not generated_loadout.is_empty() else [],
			"cards": generated_loadout.get("cards", []) if not generated_loadout.is_empty() else [],
			"weapon_followup": generated_loadout.get("weapon_followup", {}) if not generated_loadout.is_empty() else {},
			"followup_chain_count": int(generated_loadout.get("followup_chain_count", 0)) if not generated_loadout.is_empty() else 0,
			"followup_card_count": int(generated_loadout.get("followup_card_count", 0)) if not generated_loadout.is_empty() else 0,
			"followup_density": float(generated_loadout.get("followup_density", 0.0)) if not generated_loadout.is_empty() else 0.0,
			"followup_groups": generated_loadout.get("followup_groups", []) if not generated_loadout.is_empty() else [],
			"opening_pressure": generated_loadout.get("opening_pressure", {}) if not generated_loadout.is_empty() else {},
			"settlement_mode": settlement_mode,
			"debug_source": "NarrativeBattleContext + StoryBattleLoader + enemy_manifest + battle_scene_manifest + active_manifest"
		}

func _resolve_pending_battle_loadout() -> void:
	if not NarrativeBattleContext.has_request():
		return
	battle_loadout = _resolve_battle_loadout()
