extends RefCounted
class_name GeneratedNodeRouteFlowAdapter

const BRIDGE := preload("res://scripts/generated_content_runtime_bridge.gd")
const FLOW_ADAPTER := preload("res://scripts/generated_battle_flow_adapter.gd")
const MAP_ROUTE_ADAPTER := preload("res://scripts/generated_map_route_domain_adapter.gd")
const FALLBACK_POLICY := "legacy"


func is_generated_node_available(battle_slot_id: String) -> bool:
	if battle_slot_id == "":
		return false
	return BRIDGE.new().is_enabled_for_battle_slot(battle_slot_id)


func get_legacy_node_fallback(battle_slot_id: String) -> Dictionary:
	return {
		"battle_slot_id": battle_slot_id,
		"node_source": "legacy",
		"battle_flow_payload_available": false,
		"enemy_deck_id": "",
		"card_pool_count": 0,
		"reward_plan_id": "",
		"reward_source": "legacy",
		"operation_node_count": 0,
		"narrative_key_count": 0,
		"route_gate_count": 0,
		"narrative_keys_only": true,
		"route_gate_writes_formal_flow": false,
		"fallback_policy": FALLBACK_POLICY,
		"legacy_fallback_available": true,
	}


func get_generated_node_candidate(battle_slot_id: String) -> Dictionary:
	if not is_generated_node_available(battle_slot_id):
		return get_legacy_node_fallback(battle_slot_id)

	var battle_flow := FLOW_ADAPTER.new().build_generated_battle_flow_payload(battle_slot_id)
	var map_route := MAP_ROUTE_ADAPTER.new().build_generated_map_route_runtime_candidate(battle_slot_id)
	if str(battle_flow.get("battle_slot_source", "legacy")) == "legacy":
		return get_legacy_node_fallback(battle_slot_id)

	return {
		"battle_slot_id": battle_slot_id,
		"node_source": "content_engine_candidate",
		"battle_flow_payload_available": true,
		"enemy_deck_id": str(battle_flow.get("enemy_deck_id", "")),
		"card_pool_count": int(battle_flow.get("card_pool_count", 0)),
		"reward_plan_id": str(battle_flow.get("reward_plan_id", "")),
		"reward_source": str(battle_flow.get("reward_source", "legacy")),
		"operation_node_count": int(battle_flow.get("operation_node_count", 0)),
		"narrative_key_count": int(battle_flow.get("narrative_key_count", 0)),
		"route_gate_count": int(battle_flow.get("route_gate_count", 0)),
		"narrative_keys_only": bool(map_route.get("narrative_keys_only", true)),
		"route_gate_writes_formal_flow": bool(map_route.get("route_gate_writes_formal_flow", false)),
		"fallback_policy": FALLBACK_POLICY,
		"legacy_fallback_available": true,
	}


func build_generated_node_candidate(battle_slot_id: String) -> Dictionary:
	if not is_generated_node_available(battle_slot_id):
		return get_legacy_node_fallback(battle_slot_id)
	var candidate := get_generated_node_candidate(battle_slot_id)
	if str(candidate.get("enemy_deck_id", "")).is_empty():
		return get_legacy_node_fallback(battle_slot_id)
	if int(candidate.get("card_pool_count", 0)) <= 0:
		return get_legacy_node_fallback(battle_slot_id)
	if int(candidate.get("operation_node_count", 0)) <= 0:
		return get_legacy_node_fallback(battle_slot_id)
	if int(candidate.get("narrative_key_count", 0)) <= 0:
		return get_legacy_node_fallback(battle_slot_id)
	if int(candidate.get("route_gate_count", 0)) <= 0:
		return get_legacy_node_fallback(battle_slot_id)
	return candidate


func build_generated_node_candidate_pool() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var manifest := BRIDGE.new().load_manifest()
	if manifest.is_empty():
		return out
	var slots_v: Variant = manifest.get("whitelist_battle_slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return out
	for slot_v in slots_v:
		var slot := str(slot_v)
		if slot.is_empty():
			continue
		var candidate := build_generated_node_candidate(slot)
		if str(candidate.get("node_source", "legacy")) == "legacy":
			continue
		out.append(candidate)
	return out
