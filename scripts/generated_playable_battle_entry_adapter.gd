extends RefCounted
class_name GeneratedPlayableBattleEntryAdapter

const NODE_SELECTION_ADAPTER := preload("res://scripts/generated_player_node_selection_adapter.gd")
const BATTLE_FLOW_ADAPTER := preload("res://scripts/generated_battle_flow_adapter.gd")
const FALLBACK_POLICY := "legacy"


func get_legacy_playable_entry_fallback(battle_slot_id: String) -> Dictionary:
	return {
		"node_id": "",
		"battle_slot_id": battle_slot_id,
		"playable_entry_source": "legacy",
		"can_start_playable_battle": false,
		"battle_context_initialized": false,
		"enemy_deck_id": "",
		"enemy_deck_source": "legacy",
		"card_pool_count": 0,
		"generated_card_pool_available": false,
		"reward_plan_id": "",
		"reward_source": "legacy",
		"narrative_key_count": 0,
		"route_gate_count": 0,
		"fallback_policy": FALLBACK_POLICY,
		"legacy_fallback_available": true,
	}


func validate_playable_battle_entry(entry: Dictionary) -> bool:
	if str(entry.get("playable_entry_source", "legacy")) != "content_engine":
		return false
	if not bool(entry.get("can_start_playable_battle", false)):
		return false
	if not bool(entry.get("battle_context_initialized", false)):
		return false
	if str(entry.get("enemy_deck_id", "")).is_empty():
		return false
	if int(entry.get("card_pool_count", 0)) <= 0:
		return false
	if not bool(entry.get("generated_card_pool_available", false)):
		return false
	if int(entry.get("narrative_key_count", 0)) <= 0:
		return false
	if int(entry.get("route_gate_count", 0)) <= 0:
		return false
	if str(entry.get("fallback_policy", "")) != FALLBACK_POLICY:
		return false
	return true


func build_playable_battle_entry_from_battle_slot(battle_slot_id: String) -> Dictionary:
	var flow := BATTLE_FLOW_ADAPTER.new().build_generated_battle_flow_payload(battle_slot_id)
	if str(flow.get("battle_slot_source", "legacy")) == "legacy":
		return get_legacy_playable_entry_fallback(battle_slot_id)
	var entry := {
		"node_id": "generated_node_%s" % battle_slot_id,
		"battle_slot_id": battle_slot_id,
		"playable_entry_source": "content_engine",
		"can_start_playable_battle": true,
		"battle_context_initialized": true,
		"enemy_deck_id": str(flow.get("enemy_deck_id", "")),
		"enemy_deck_source": str(flow.get("enemy_deck_source", "legacy")),
		"card_pool_count": int(flow.get("card_pool_count", 0)),
		"generated_card_pool_available": int(flow.get("card_pool_count", 0)) > 0,
		"reward_plan_id": str(flow.get("reward_plan_id", "")),
		"reward_source": str(flow.get("reward_source", "legacy")),
		"narrative_key_count": int(flow.get("narrative_key_count", 0)),
		"route_gate_count": int(flow.get("route_gate_count", 0)),
		"fallback_policy": FALLBACK_POLICY,
		"legacy_fallback_available": true,
	}
	if not validate_playable_battle_entry(entry):
		return get_legacy_playable_entry_fallback(battle_slot_id)
	return entry


func build_playable_battle_entry_from_node(node_id: String) -> Dictionary:
	var node := NODE_SELECTION_ADAPTER.new().select_generated_node(node_id)
	if str(node.get("node_source", "legacy")) != "content_engine":
		return get_legacy_playable_entry_fallback(str(node.get("battle_slot_id", "")))
	var slot := str(node.get("battle_slot_id", ""))
	return build_playable_battle_entry_from_battle_slot(slot)


func apply_generated_entry_to_battle_context(entry: Dictionary, context := {}) -> Dictionary:
	var out: Dictionary = context if context is Dictionary else {}
	if str(entry.get("playable_entry_source", "legacy")) != "content_engine":
		out["generated_battle_context_initialized"] = false
		out["generated_enemy_deck_id"] = ""
		out["generated_card_pool_count"] = 0
		out["generated_reward_plan_id"] = ""
		out["generated_reward_source"] = "legacy"
		out["generated_narrative_keys"] = []
		out["generated_route_gates"] = []
		out["fallback_policy"] = FALLBACK_POLICY
		return out
	out["generated_battle_context_initialized"] = true
	out["generated_enemy_deck_id"] = str(entry.get("enemy_deck_id", ""))
	out["generated_card_pool_count"] = int(entry.get("card_pool_count", 0))
	out["generated_reward_plan_id"] = str(entry.get("reward_plan_id", ""))
	out["generated_reward_source"] = str(entry.get("reward_source", "legacy"))
	out["generated_narrative_keys"] = ["key_hook_only", "count_%d" % int(entry.get("narrative_key_count", 0))]
	out["generated_route_gates"] = ["candidate_only", "count_%d" % int(entry.get("route_gate_count", 0))]
	out["fallback_policy"] = str(entry.get("fallback_policy", FALLBACK_POLICY))
	return out
