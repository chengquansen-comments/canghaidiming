extends RefCounted
class_name GeneratedNodeBattleStartAdapter

const ENTRY_ADAPTER := preload("res://scripts/generated_node_battle_entry_adapter.gd")
const FALLBACK_POLICY := "legacy"


func get_legacy_battle_start_fallback(battle_slot_id: String) -> Dictionary:
	return {
		"node_id": "",
		"battle_slot_id": battle_slot_id,
		"battle_start_source": "legacy",
		"battle_entry_available": false,
		"battle_flow_payload_available": false,
		"enemy_deck_id": "",
		"enemy_deck_source": "legacy",
		"card_pool_count": 0,
		"reward_plan_id": "",
		"reward_source": "legacy",
		"narrative_key_count": 0,
		"route_gate_count": 0,
		"fallback_policy": FALLBACK_POLICY,
		"can_initialize_battle_context": false,
		"legacy_fallback_available": true,
	}


func validate_battle_start_payload(payload: Dictionary) -> bool:
	if str(payload.get("battle_start_source", "legacy")) != "content_engine":
		return false
	if not bool(payload.get("battle_entry_available", false)):
		return false
	if not bool(payload.get("battle_flow_payload_available", false)):
		return false
	if str(payload.get("enemy_deck_id", "")).is_empty():
		return false
	if int(payload.get("card_pool_count", 0)) <= 0:
		return false
	if int(payload.get("narrative_key_count", 0)) <= 0:
		return false
	if int(payload.get("route_gate_count", 0)) <= 0:
		return false
	if str(payload.get("fallback_policy", "")) != FALLBACK_POLICY:
		return false
	if not bool(payload.get("can_initialize_battle_context", false)):
		return false
	return true


func build_battle_start_payload_from_entry(entry: Dictionary) -> Dictionary:
	if str(entry.get("entry_source", "legacy")) != "content_engine":
		return get_legacy_battle_start_fallback(str(entry.get("battle_slot_id", "")))
	var payload := {
		"node_id": str(entry.get("node_id", "")),
		"battle_slot_id": str(entry.get("battle_slot_id", "")),
		"battle_start_source": "content_engine",
		"battle_entry_available": true,
		"battle_flow_payload_available": bool(entry.get("battle_flow_payload_available", false)),
		"enemy_deck_id": str(entry.get("enemy_deck_id", "")),
		"enemy_deck_source": str(entry.get("enemy_deck_source", "legacy")),
		"card_pool_count": int(entry.get("card_pool_count", 0)),
		"reward_plan_id": str(entry.get("reward_plan_id", "")),
		"reward_source": str(entry.get("reward_source", "legacy")),
		"narrative_key_count": int(entry.get("narrative_key_count", 0)),
		"route_gate_count": int(entry.get("route_gate_count", 0)),
		"fallback_policy": FALLBACK_POLICY,
		"can_initialize_battle_context": bool(entry.get("can_enter_battle", false)),
		"legacy_fallback_available": true,
	}
	if not validate_battle_start_payload(payload):
		return get_legacy_battle_start_fallback(str(entry.get("battle_slot_id", "")))
	return payload


func build_battle_start_payload_from_generated_node(node_id: String) -> Dictionary:
	var entry := ENTRY_ADAPTER.new().build_battle_entry_from_generated_node(node_id)
	return build_battle_start_payload_from_entry(entry)
