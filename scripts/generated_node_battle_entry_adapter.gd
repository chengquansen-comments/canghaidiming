extends RefCounted
class_name GeneratedNodeBattleEntryAdapter

const NODE_SELECTION_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const BATTLE_FLOW_ADAPTER := preload("res://scripts/generated_battle_flow_adapter.gd")
const FALLBACK_POLICY := "legacy"


func get_legacy_battle_entry_fallback(battle_slot_id: String) -> Dictionary:
	return {
		"node_id": "",
		"battle_slot_id": battle_slot_id,
		"entry_source": "legacy",
		"battle_flow_payload_available": false,
		"enemy_deck_id": "",
		"enemy_deck_source": "legacy",
		"card_pool_count": 0,
		"reward_plan_id": "",
		"reward_source": "legacy",
		"narrative_key_count": 0,
		"route_gate_count": 0,
		"fallback_policy": FALLBACK_POLICY,
		"can_enter_battle": false,
		"legacy_fallback_available": true,
	}


func build_battle_entry_from_battle_slot(battle_slot_id: String) -> Dictionary:
	var payload := BATTLE_FLOW_ADAPTER.new().build_generated_battle_flow_payload(battle_slot_id)
	if str(payload.get("battle_slot_source", "legacy")) == "legacy":
		return get_legacy_battle_entry_fallback(battle_slot_id)
	var entry := {
		"node_id": "generated_node_%s" % battle_slot_id,
		"battle_slot_id": battle_slot_id,
		"entry_source": "content_engine",
		"battle_flow_payload_available": true,
		"enemy_deck_id": str(payload.get("enemy_deck_id", "")),
		"enemy_deck_source": str(payload.get("enemy_deck_source", "legacy")),
		"card_pool_count": int(payload.get("card_pool_count", 0)),
		"reward_plan_id": str(payload.get("reward_plan_id", "")),
		"reward_source": str(payload.get("reward_source", "legacy")),
		"narrative_key_count": int(payload.get("narrative_key_count", 0)),
		"route_gate_count": int(payload.get("route_gate_count", 0)),
		"fallback_policy": FALLBACK_POLICY,
		"can_enter_battle": true,
		"legacy_fallback_available": true,
	}
	if not validate_generated_battle_entry(entry):
		return get_legacy_battle_entry_fallback(battle_slot_id)
	return entry


func build_battle_entry_from_generated_node(node_id: String) -> Dictionary:
	var selected := NODE_SELECTION_ADAPTER.new().select_generated_node(node_id)
	if str(selected.get("node_source", "legacy")) != "content_engine":
		return get_legacy_battle_entry_fallback(str(selected.get("battle_slot_id", "")))
	var slot := str(selected.get("battle_slot_id", ""))
	return build_battle_entry_from_battle_slot(slot)


func get_selected_generated_node_battle_entry(node_id: String) -> Dictionary:
	return build_battle_entry_from_generated_node(node_id)


func validate_generated_battle_entry(entry: Dictionary) -> bool:
	if str(entry.get("entry_source", "legacy")) != "content_engine":
		return false
	if not bool(entry.get("battle_flow_payload_available", false)):
		return false
	if str(entry.get("enemy_deck_id", "")).is_empty():
		return false
	if int(entry.get("card_pool_count", 0)) <= 0:
		return false
	if int(entry.get("narrative_key_count", 0)) <= 0:
		return false
	if int(entry.get("route_gate_count", 0)) <= 0:
		return false
	if str(entry.get("fallback_policy", "")) != FALLBACK_POLICY:
		return false
	if not bool(entry.get("can_enter_battle", false)):
		return false
	return true
