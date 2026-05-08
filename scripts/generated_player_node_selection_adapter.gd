extends RefCounted
class_name GeneratedPlayerNodeSelectionAdapter

const NODE_ADAPTER := preload("res://scripts/generated_node_route_flow_adapter.gd")
const FLOW_ADAPTER := preload("res://scripts/generated_battle_flow_adapter.gd")
const FALLBACK_POLICY := "legacy"


func get_legacy_node_selection_fallback() -> Dictionary:
	return {
		"node_id": "",
		"battle_slot_id": "",
		"node_title_key": "node.legacy.fallback",
		"node_type": "legacy",
		"node_source": "legacy",
		"player_visible": false,
		"selectable": false,
		"battle_flow_payload_available": false,
		"reward_plan_id": "",
		"reward_source": "legacy",
		"enemy_deck_id": "",
		"card_pool_count": 0,
		"operation_node_count": 0,
		"narrative_key_count": 0,
		"route_gate_count": 0,
		"fallback_policy": FALLBACK_POLICY,
		"legacy_fallback_available": true,
	}


func get_player_visible_generated_nodes() -> Array[Dictionary]:
	return build_player_visible_generated_node_pool()


func build_player_visible_generated_node_pool() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pool: Array[Dictionary] = NODE_ADAPTER.new().build_generated_node_candidate_pool()
	for item in pool:
		var slot := str(item.get("battle_slot_id", ""))
		if slot.is_empty():
			continue
		out.append({
			"node_id": "generated_node_%s" % slot,
			"battle_slot_id": slot,
			"node_title_key": "generated.node.%s" % slot,
			"node_type": "generated_battle",
			"node_source": "content_engine",
			"player_visible": true,
			"selectable": true,
			"battle_flow_payload_available": bool(item.get("battle_flow_payload_available", false)),
			"reward_plan_id": str(item.get("reward_plan_id", "")),
			"reward_source": str(item.get("reward_source", "legacy")),
			"enemy_deck_id": str(item.get("enemy_deck_id", "")),
			"card_pool_count": int(item.get("card_pool_count", 0)),
			"operation_node_count": int(item.get("operation_node_count", 0)),
			"narrative_key_count": int(item.get("narrative_key_count", 0)),
			"route_gate_count": int(item.get("route_gate_count", 0)),
			"fallback_policy": str(item.get("fallback_policy", FALLBACK_POLICY)),
			"legacy_fallback_available": bool(item.get("legacy_fallback_available", true)),
		})
	return out


func select_generated_node(node_id: String) -> Dictionary:
	if node_id.is_empty():
		return get_legacy_node_selection_fallback()
	var pool := build_player_visible_generated_node_pool()
	for node in pool:
		if str(node.get("node_id", "")) == node_id:
			return node
	return get_legacy_node_selection_fallback()


func get_battle_flow_payload_for_node(node_id: String) -> Dictionary:
	var selected := select_generated_node(node_id)
	if str(selected.get("node_source", "legacy")) != "content_engine":
		return FLOW_ADAPTER.new().get_legacy_fallback_payload(str(selected.get("battle_slot_id", "")))
	var slot := str(selected.get("battle_slot_id", ""))
	if slot.is_empty():
		return FLOW_ADAPTER.new().get_legacy_fallback_payload("")
	return FLOW_ADAPTER.new().build_generated_battle_flow_payload(slot)
