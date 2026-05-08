extends RefCounted
class_name GeneratedBattleFlowAdapter

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const BATTLE_ADAPTER := preload("res://scripts/generated_battle_domain_adapter.gd")
const MAP_ROUTE_ADAPTER := preload("res://scripts/generated_map_route_domain_adapter.gd")
const FALLBACK_POLICY := "legacy"


func is_generated_battle_flow_available(battle_slot_id: String) -> bool:
	if battle_slot_id == "":
		return false
	return BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id)


func get_legacy_fallback_payload(battle_slot_id: String) -> Dictionary:
	return {
		"battle_slot_id": battle_slot_id,
		"battle_slot_source": "legacy",
		"enemy_deck_id": "",
		"enemy_deck_source": "legacy",
		"card_pool_count": 0,
		"reward_plan_id": "",
		"reward_source": "legacy",
		"operation_node_count": 0,
		"narrative_key_count": 0,
		"route_gate_count": 0,
		"fallback_policy": FALLBACK_POLICY,
		"flow_source": "legacy",
		"legacy_fallback_available": true,
	}


func get_generated_battle_flow_candidate(battle_slot_id: String) -> Dictionary:
	if not is_generated_battle_flow_available(battle_slot_id):
		return get_legacy_fallback_payload(battle_slot_id)

	var battle_runtime := BATTLE_ADAPTER.new().build_generated_battle_runtime_loadout_candidate(battle_slot_id)
	var map_route_runtime := MAP_ROUTE_ADAPTER.new().build_generated_map_route_runtime_candidate(battle_slot_id)
	var bridge_bundle := BRIDGE.new().get_full_content_bundle_for_battle_slot(battle_slot_id)

	var reward_domain: Dictionary = {}
	var domains_v: Variant = bridge_bundle.get("domains", {})
	var domains: Dictionary = domains_v if typeof(domains_v) == TYPE_DICTIONARY else {}
	var reward_v: Variant = domains.get("reward", {})
	if typeof(reward_v) == TYPE_DICTIONARY:
		reward_domain = reward_v

	var enemy_deck_id := str(battle_runtime.get("enemy_deck_id", ""))
	var reward_plan_id := str((reward_domain as Dictionary).get("candidate_id", ""))
	var reward_source := "content_engine" if not reward_plan_id.is_empty() else "legacy"
	if reward_source == "legacy":
		reward_plan_id = ""

	return {
		"battle_slot_id": battle_slot_id,
		"battle_slot_source": "content_engine",
		"enemy_deck_id": enemy_deck_id,
		"enemy_deck_source": str(battle_runtime.get("enemy_deck_source", "legacy")),
		"card_pool_count": int(battle_runtime.get("card_pool_count", 0)),
		"reward_plan_id": reward_plan_id,
		"reward_source": reward_source,
		"operation_node_count": int(map_route_runtime.get("operation_node_count", 0)),
		"narrative_key_count": int(map_route_runtime.get("narrative_key_count", 0)),
		"route_gate_count": int(map_route_runtime.get("route_gate_count", 0)),
		"fallback_policy": FALLBACK_POLICY,
		"flow_source": "content_engine_candidate",
		"legacy_fallback_available": true,
	}


func build_generated_battle_flow_payload(battle_slot_id: String) -> Dictionary:
	if not is_generated_battle_flow_available(battle_slot_id):
		return get_legacy_fallback_payload(battle_slot_id)

	var payload := get_generated_battle_flow_candidate(battle_slot_id)
	if str(payload.get("enemy_deck_id", "")).is_empty():
		return get_legacy_fallback_payload(battle_slot_id)
	if int(payload.get("card_pool_count", 0)) <= 0:
		return get_legacy_fallback_payload(battle_slot_id)
	if int(payload.get("operation_node_count", 0)) <= 0:
		return get_legacy_fallback_payload(battle_slot_id)
	if int(payload.get("narrative_key_count", 0)) <= 0:
		return get_legacy_fallback_payload(battle_slot_id)
	if int(payload.get("route_gate_count", 0)) <= 0:
		return get_legacy_fallback_payload(battle_slot_id)
	return payload
