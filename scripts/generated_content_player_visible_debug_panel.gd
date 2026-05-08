extends RefCounted
class_name GeneratedContentPlayerVisibleDebugPanel


func build_visible_status_payload(loadout: Dictionary) -> Dictionary:
	var selected_node_id := str(loadout.get("selected_generated_node_id", ""))
	var battle_slot_id := str(loadout.get("source_node_id", ""))
	var enemy_deck_id := str(loadout.get("generated_enemy_deck_id", ""))
	var card_pool_count := int(loadout.get("generated_card_pool_count", 0))
	var reward_plan_id := str(loadout.get("generated_reward_plan_id", ""))
	var generated_entry: Dictionary = loadout.get("generated_playable_battle_entry", {}) if loadout.get("generated_playable_battle_entry", {}) is Dictionary else {}
	var enemy_domain: Dictionary = loadout.get("enemy_deck_domain", {}) if loadout.get("enemy_deck_domain", {}) is Dictionary else {}
	var generated_enabled := bool(generated_entry.get("can_start_playable_battle", false)) and not selected_node_id.is_empty()
	var narrative_keys: Array = loadout.get("generated_narrative_keys", []) if loadout.get("generated_narrative_keys", []) is Array else []
	var route_gates: Array = loadout.get("generated_route_gates", []) if loadout.get("generated_route_gates", []) is Array else []
	var narrative_key_count := int(generated_entry.get("narrative_key_count", narrative_keys.size()))
	var route_gate_count := int(generated_entry.get("route_gate_count", route_gates.size()))
	var fallback_policy := str(generated_entry.get("fallback_policy", "legacy"))
	var reward_source := str(generated_entry.get("reward_source", "legacy"))
	var player_input_ready := generated_enabled and card_pool_count > 0 and not enemy_deck_id.is_empty()
	var action_executed := bool(loadout.get("action_executed", player_input_ready))
	var reward_pending_available := generated_enabled
	var enemy_summary := "%s (%s)" % [enemy_deck_id, str(enemy_domain.get("formal_source", "content_engine"))]
	var compatible_card_count := int(loadout.get("compatible_card_count", 0))

	return {
		"generated_content_enabled": generated_enabled,
		"node_id": selected_node_id,
		"battle_slot_id": battle_slot_id,
		"enemy_deck_id": enemy_deck_id,
		"card_pool_count": card_pool_count,
		"reward_plan_id": reward_plan_id,
		"reward_source": reward_source,
		"enemy_summary": enemy_summary,
		"compatible_card_count": compatible_card_count,
		"narrative_key_count": narrative_key_count,
		"route_gate_count": route_gate_count,
		"player_input_ready": player_input_ready,
		"action_executed": action_executed,
		"reward_pending_available": reward_pending_available,
		"fallback_policy": fallback_policy,
		"legacy_fallback_available": true,
	}


func build_visible_status_text(payload: Dictionary) -> String:
	var enabled_text := "ON" if bool(payload.get("generated_content_enabled", false)) else "OFF"
	var action_text := "ready" if bool(payload.get("player_input_ready", false)) else ("executed" if bool(payload.get("action_executed", false)) else "legacy")
	return "Generated Content: %s\nNode: %s\nBattle Slot: %s\nEnemy Deck: %s\nEnemy Summary: %s\nCard Pool: %s\nReward: %s\nNarrative Keys: %s\nRoute Gates: %s\nAction/Input: %s\nReward Pending: %s\nFallback: %s" % [
		enabled_text,
		str(payload.get("node_id", "")),
		str(payload.get("battle_slot_id", "")),
		str(payload.get("enemy_deck_id", "")),
		str(payload.get("enemy_summary", "")),
		str(payload.get("card_pool_count", 0)),
		str(payload.get("reward_plan_id", "")),
		str(payload.get("narrative_key_count", 0)),
		str(payload.get("route_gate_count", 0)),
		action_text,
		str(payload.get("reward_pending_available", false)).to_lower(),
		str(payload.get("fallback_policy", "legacy")),
	]
