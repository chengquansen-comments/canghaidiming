extends "res://scripts/battle_controller_visual_narrative_context_player_profile.gd"

# Narrative context loadout layer.
const GeneratedBattleDomainAdapter := preload("res://scripts/generated_battle_domain_adapter.gd")
const GeneratedMapRouteDomainAdapter := preload("res://scripts/generated_map_route_domain_adapter.gd")
const GeneratedBattleFlowAdapter := preload("res://scripts/generated_battle_flow_adapter.gd")
const GeneratedNodeRouteFlowAdapter := preload("res://scripts/generated_node_route_flow_adapter.gd")
const GeneratedPlayerNodeSelectionAdapter := preload("res://scripts/generated_player_node_selection_adapter.gd")
const GeneratedNodeBattleEntryAdapter := preload("res://scripts/generated_node_battle_entry_adapter.gd")
const GeneratedNodeBattleStartAdapter := preload("res://scripts/generated_node_battle_start_adapter.gd")
const GeneratedPlayableBattleEntryAdapter := preload("res://scripts/generated_playable_battle_entry_adapter.gd")
const GeneratedContentPlayerVisibleDebugPanel := preload("res://scripts/generated_content_player_visible_debug_panel.gd")

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
	var override_player_profile := NarrativeBattleContext.should_override_player_profile()
	var settlement_mode: String = str(story_battle.get("settlement_mode", BattleStateMachineScript.MODE_REACTIVE_ID))
	var manifest_encounter: Dictionary = _dict(manifest_context.get("encounter", {}))
	var manifest_enemy: Dictionary = _dict(manifest_context.get("enemy", {}))
	var enemy_id: String = str(enemy_config.get("id", manifest_context.get("enemy_id", encounter_config.get("opponent_template_id", ""))))
	var enemy_source: String = str(enemy_config.get("enemy_source", "enemy_manifest" if not manifest_enemy.is_empty() else "story_battles"))
	var generated_domain := _resolve_generated_battle_domain_candidate(source_node_id)
	var generated_map_route_domain := _resolve_generated_map_route_domain_candidate(source_node_id)
	var generated_battle_flow_payload := _resolve_generated_battle_flow_payload(source_node_id)
	var generated_node_candidate := _resolve_generated_node_candidate(source_node_id)
	var generated_node_candidate_pool_count := _resolve_generated_node_candidate_pool_count()
	var generated_player_node_pool := _resolve_generated_player_node_pool()
	var generated_player_node_pool_count := generated_player_node_pool.size()
	var generated_player_node_selection_enabled := generated_player_node_pool_count > 0
	var selected_generated_node_payload := _resolve_selected_generated_node_payload(source_node_id)
	var selected_generated_node_id := _resolve_selected_generated_node_id(source_node_id)
	var generated_battle_entry_payload := _resolve_generated_battle_entry_payload(selected_generated_node_id, source_node_id)
	var generated_battle_entry_available := bool(generated_battle_entry_payload.get("can_enter_battle", false))
	var generated_battle_start_payload := _resolve_generated_battle_start_payload(selected_generated_node_id, source_node_id)
	var generated_battle_start_available := bool(generated_battle_start_payload.get("can_initialize_battle_context", false))
	var generated_battle_start_source := str(generated_battle_start_payload.get("battle_start_source", "legacy"))
	var generated_playable_battle_entry := _resolve_generated_playable_battle_entry(selected_generated_node_id, source_node_id)
	var generated_battle_context := _resolve_generated_battle_context(generated_playable_battle_entry)
	var generated_enemy_deck_id := str(generated_battle_context.get("generated_enemy_deck_id", ""))
	var generated_card_pool_count := int(generated_battle_context.get("generated_card_pool_count", 0))
	var generated_reward_plan_id := str(generated_battle_context.get("generated_reward_plan_id", ""))
	var generated_narrative_keys: Array = generated_battle_context.get("generated_narrative_keys", []) if generated_battle_context.get("generated_narrative_keys", []) is Array else []
	var generated_route_gates: Array = generated_battle_context.get("generated_route_gates", []) if generated_battle_context.get("generated_route_gates", []) is Array else []
	var generated_player_visible_status := GeneratedContentPlayerVisibleDebugPanel.new().build_visible_status_payload({
		"selected_generated_node_id": selected_generated_node_id,
		"source_node_id": source_node_id,
		"generated_enemy_deck_id": generated_enemy_deck_id,
		"generated_card_pool_count": generated_card_pool_count,
		"generated_reward_plan_id": generated_reward_plan_id,
		"generated_narrative_keys": generated_narrative_keys,
		"generated_route_gates": generated_route_gates,
		"generated_playable_battle_entry": generated_playable_battle_entry,
	})
	var generated_player_visible_entry_available := bool(generated_player_visible_status.get("generated_content_enabled", false))
	if bool(generated_domain.get("apply_enemy_deck", false)):
		enemy_config["generated_enemy_deck_candidate"] = generated_domain.get("enemy_deck", {})
		enemy_config["enemy_source"] = str(generated_domain.get("enemy_formal_source", enemy_source))
		enemy_source = str(enemy_config.get("enemy_source", enemy_source))
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
		"generated_battle_domain_candidate": generated_domain,
		"generated_battle_runtime_loadout_candidate": generated_domain.get("battle_runtime_loadout_candidate", {}),
		"generated_map_route_domain_candidate": generated_map_route_domain,
		"generated_map_route_runtime_candidate": generated_map_route_domain.get("map_route_runtime_candidate", {}),
		"generated_battle_flow_payload": generated_battle_flow_payload,
		"generated_node_candidate": generated_node_candidate,
		"generated_node_candidate_pool_count": generated_node_candidate_pool_count,
		"generated_player_node_pool": generated_player_node_pool,
		"generated_player_node_pool_count": generated_player_node_pool_count,
		"generated_player_node_selection_enabled": generated_player_node_selection_enabled,
		"selected_generated_node_payload": selected_generated_node_payload,
		"selected_generated_node_id": selected_generated_node_id,
		"generated_battle_entry_payload": generated_battle_entry_payload,
		"generated_battle_entry_available": generated_battle_entry_available,
		"generated_battle_start_payload": generated_battle_start_payload,
		"generated_battle_start_available": generated_battle_start_available,
		"generated_battle_start_source": generated_battle_start_source,
		"generated_playable_battle_entry": generated_playable_battle_entry,
		"generated_battle_context": generated_battle_context,
		"generated_enemy_deck_id": generated_enemy_deck_id,
		"generated_card_pool_count": generated_card_pool_count,
		"generated_reward_plan_id": generated_reward_plan_id,
		"generated_narrative_keys": generated_narrative_keys,
		"generated_route_gates": generated_route_gates,
		"generated_player_visible_status": generated_player_visible_status,
		"generated_player_visible_entry_available": generated_player_visible_entry_available,
		"settlement_mode": settlement_mode,
		"debug_source": "NarrativeBattleContext + StoryBattleLoader + enemy_manifest + battle_scene_manifest"
	}

func _resolve_pending_battle_loadout() -> void:
	if not NarrativeBattleContext.has_request():
		return
	battle_loadout = _resolve_battle_loadout()


func _resolve_generated_battle_domain_candidate(source_node_id: String) -> Dictionary:
	var adapter := GeneratedBattleDomainAdapter.new()
	var candidate: Dictionary = adapter.build_generated_battle_domain_candidate(source_node_id)
	var generated_enabled := bool(candidate.get("enabled", false))
	if not generated_enabled:
		return {
			"battle_slot_id": source_node_id,
			"generated_content_enabled": false,
			"apply_enemy_deck": false,
			"enemy_deck": {},
			"enemy_formal_source": "legacy",
			"card_pool": {},
			"card_pool_count": 0,
			"generated_battle_runtime_loadout_candidate": {
				"battle_slot_id": source_node_id,
				"loadout_candidate_available": false,
				"fallback_policy": "legacy",
				"loadout_source": "legacy",
				"enemy_deck_id": "",
				"enemy_deck_source": "legacy",
				"card_pool_count": 0,
				"compatible_card_count": 0,
				"unsupported_fields": [],
				"legacy_fallback_available": true,
			},
			"unsupported_fields": [],
			"fallback_policy": "legacy",
		}
	var enemy_deck: Dictionary = candidate.get("enemy_deck", {}) if candidate.get("enemy_deck", {}) is Dictionary else {}
	var card_pool: Dictionary = candidate.get("card_pool", {}) if candidate.get("card_pool", {}) is Dictionary else {}
	return {
		"battle_slot_id": source_node_id,
		"generated_content_enabled": bool(candidate.get("enabled", false)),
		"apply_enemy_deck": bool(enemy_deck.get("candidate_available", false)),
		"enemy_deck": enemy_deck,
		"enemy_formal_source": str(enemy_deck.get("formal_source", "legacy")),
		"card_pool": card_pool,
		"card_pool_count": int(card_pool.get("candidate_count", 0)),
		"generated_battle_runtime_loadout_candidate": candidate.get("battle_runtime_loadout_candidate", {}),
		"unsupported_fields": card_pool.get("unsupported_fields", []),
		"fallback_policy": str(candidate.get("fallback_policy", "legacy")),
	}


func _resolve_generated_map_route_domain_candidate(source_node_id: String) -> Dictionary:
	var adapter := GeneratedMapRouteDomainAdapter.new()
	var candidate: Dictionary = adapter.build_generated_map_route_candidate(source_node_id)
	var generated_enabled := bool(candidate.get("enabled", false))
	if not generated_enabled:
		return {
			"battle_slot_id": source_node_id,
			"generated_content_enabled": false,
			"battle_slot": {"formal_source": "legacy", "candidate_available": false, "candidate_count": 0},
			"operation_node": {"formal_source": "legacy", "candidate_available": false, "candidate_count": 0},
			"narrative": {"formal_source": "legacy", "candidate_available": false, "candidate_count": 0, "hook_only": true},
			"route_gate": {"formal_source": "legacy", "candidate_available": false, "candidate_count": 0, "writes_formal_flow": false},
			"map_route_runtime_candidate": {
				"battle_slot_id": source_node_id,
				"map_route_candidate_available": false,
				"battle_slot_candidate_id": "",
				"operation_node_count": 0,
				"narrative_key_count": 0,
				"route_gate_count": 0,
				"narrative_keys_only": true,
				"route_gate_writes_formal_flow": false,
				"fallback_policy": "legacy",
				"candidate_source": "legacy",
				"legacy_fallback_available": true,
			},
			"fallback_policy": "legacy",
		}
	var battle_slot: Dictionary = candidate.get("battle_slot", {}) if candidate.get("battle_slot", {}) is Dictionary else {}
	var operation_node: Dictionary = candidate.get("operation_node", {}) if candidate.get("operation_node", {}) is Dictionary else {}
	var narrative: Dictionary = candidate.get("narrative", {}) if candidate.get("narrative", {}) is Dictionary else {}
	var route_gate: Dictionary = candidate.get("route_gate", {}) if candidate.get("route_gate", {}) is Dictionary else {}
	return {
		"battle_slot_id": source_node_id,
		"generated_content_enabled": bool(candidate.get("enabled", false)),
		"battle_slot": battle_slot,
		"operation_node": operation_node,
		"narrative": narrative,
		"route_gate": route_gate,
		"map_route_runtime_candidate": candidate.get("map_route_runtime_candidate", {}),
		"fallback_policy": str(candidate.get("fallback_policy", "legacy")),
	}


func _resolve_generated_battle_flow_payload(source_node_id: String) -> Dictionary:
	var adapter := GeneratedBattleFlowAdapter.new()
	var payload: Dictionary = adapter.build_generated_battle_flow_payload(source_node_id)
	if payload.is_empty():
		return adapter.get_legacy_fallback_payload(source_node_id)
	return payload


func _resolve_generated_node_candidate(source_node_id: String) -> Dictionary:
	var adapter := GeneratedNodeRouteFlowAdapter.new()
	var candidate: Dictionary = adapter.build_generated_node_candidate(source_node_id)
	if candidate.is_empty():
		return adapter.get_legacy_node_fallback(source_node_id)
	return candidate


func _resolve_generated_node_candidate_pool_count() -> int:
	var adapter := GeneratedNodeRouteFlowAdapter.new()
	var pool: Array[Dictionary] = adapter.build_generated_node_candidate_pool()
	return pool.size()


func _resolve_generated_player_node_pool() -> Array[Dictionary]:
	var adapter := GeneratedPlayerNodeSelectionAdapter.new()
	return adapter.build_player_visible_generated_node_pool()


func _resolve_selected_generated_node_payload(source_node_id: String) -> Dictionary:
	var adapter := GeneratedPlayerNodeSelectionAdapter.new()
	var node_id := "generated_node_%s" % source_node_id
	return adapter.get_battle_flow_payload_for_node(node_id)


func _resolve_selected_generated_node_id(source_node_id: String) -> String:
	return "generated_node_%s" % source_node_id


func _resolve_generated_battle_entry_payload(selected_node_id: String, source_node_id: String) -> Dictionary:
	var adapter := GeneratedNodeBattleEntryAdapter.new()
	var entry: Dictionary = adapter.get_selected_generated_node_battle_entry(selected_node_id)
	if bool(entry.get("can_enter_battle", false)):
		return entry
	return adapter.get_legacy_battle_entry_fallback(source_node_id)


func _resolve_generated_battle_start_payload(selected_node_id: String, source_node_id: String) -> Dictionary:
	var adapter := GeneratedNodeBattleStartAdapter.new()
	var payload: Dictionary = adapter.build_battle_start_payload_from_generated_node(selected_node_id)
	if bool(payload.get("can_initialize_battle_context", false)):
		return payload
	return adapter.get_legacy_battle_start_fallback(source_node_id)


func _resolve_generated_playable_battle_entry(selected_node_id: String, source_node_id: String) -> Dictionary:
	var adapter := GeneratedPlayableBattleEntryAdapter.new()
	var entry: Dictionary = adapter.build_playable_battle_entry_from_node(selected_node_id)
	if bool(entry.get("can_start_playable_battle", false)):
		return entry
	return adapter.get_legacy_playable_entry_fallback(source_node_id)


func _resolve_generated_battle_context(entry: Dictionary) -> Dictionary:
	var adapter := GeneratedPlayableBattleEntryAdapter.new()
	return adapter.apply_generated_entry_to_battle_context(entry, {})
