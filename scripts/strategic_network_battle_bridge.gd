extends RefCounted

# Pure battle-request helpers for strategic network-map nodes.
# Keep this file free of scene switching, UI creation, and result application.

const COMBAT_POOL_FALLBACK := {
	"spear_patrol": {
		"encounter_id": "enc_ch2_reed_ambush",
		"battle_id": "chapter2_reed_ambush",
	},
	"coastal_veteran": {
		"encounter_id": "enc_ch4_tide_bandits",
		"battle_id": "chapter4_tide_bandits",
	},
	"military_elite": {
		"encounter_id": "enc_ch3_escort_clash",
		"battle_id": "chapter3_escort_clash",
	},
	"old_case_elite": {
		"encounter_id": "enc_ch3_escort_clash",
		"battle_id": "chapter3_escort_clash",
	},
}

static func is_combat_node(node: Dictionary) -> bool:
	var node_type := str(node.get("node_type", ""))
	return node_type.begins_with("combat_") \
		or not str(node.get("combat_pool_id", "")).is_empty() \
		or not str(node.get("encounter_id", "")).is_empty() \
		or not str(node.get("battle_id", "")).is_empty()

static func combat_request_for_node(node: Dictionary) -> Dictionary:
	if not is_combat_node(node):
		return {
			"enabled": false,
			"blocked_reason": "该节点不是战斗节点。",
		}
	var encounter_id := str(node.get("encounter_id", ""))
	var battle_id := str(node.get("battle_id", ""))
	var combat_pool_id := str(node.get("combat_pool_id", ""))
	if (encounter_id.is_empty() or battle_id.is_empty()) and not combat_pool_id.is_empty():
		var fallback: Dictionary = COMBAT_POOL_FALLBACK.get(combat_pool_id, {}) as Dictionary
		if not fallback.is_empty():
			if encounter_id.is_empty():
				encounter_id = str(fallback.get("encounter_id", ""))
			if battle_id.is_empty():
				battle_id = str(fallback.get("battle_id", ""))
	if encounter_id.is_empty() or battle_id.is_empty():
		return {
			"enabled": false,
			"blocked_reason": combat_block_reason(node),
			"combat_pool_id": combat_pool_id,
			"encounter_id": encounter_id,
			"battle_id": battle_id,
			"recommended_martial_min": int(node.get("recommended_martial_min", 0)),
			"recommended_martial_max": int(node.get("recommended_martial_max", 0)),
			"enemy_martial_level": int(node.get("enemy_martial_level", 0)),
		}
	return {
		"enabled": true,
		"encounter_id": encounter_id,
		"battle_id": battle_id,
		"override_player_profile": true,
		"combat_pool_id": combat_pool_id,
		"recommended_martial_min": int(node.get("recommended_martial_min", 0)),
		"recommended_martial_max": int(node.get("recommended_martial_max", 0)),
		"enemy_martial_level": int(node.get("enemy_martial_level", 0)),
		"source_node_id": str(node.get("map_graph_id", "")),
		"source_battle_slot_id": str(node.get("source_battle_slot_id", node.get("battle_slot_id", ""))),
		"source_enemy_deck_id": str(node.get("source_enemy_deck_id", "")),
		"source_reward_plan_id": str(node.get("source_reward_plan_id", "")),
	}

static func combat_block_reason(node: Dictionary) -> String:
	var combat_pool_id := str(node.get("combat_pool_id", ""))
	var encounter_id := str(node.get("encounter_id", ""))
	var battle_id := str(node.get("battle_id", ""))
	if encounter_id.is_empty() and battle_id.is_empty() and combat_pool_id.is_empty():
		return "该战斗节点缺少 encounter_id / battle_id / combat_pool_id。"
	if not combat_pool_id.is_empty() and not COMBAT_POOL_FALLBACK.has(combat_pool_id) and (encounter_id.is_empty() or battle_id.is_empty()):
		return "该 combat_pool 暂未接入战斗：%s" % combat_pool_id
	if encounter_id.is_empty():
		return "该战斗节点缺少 encounter_id。"
	if battle_id.is_empty():
		return "该战斗节点缺少 battle_id。"
	return "该战斗暂未接入。"

static func final_boss_request(encounter_id: String, battle_id: String) -> Dictionary:
	if encounter_id.is_empty() or battle_id.is_empty():
		return {
			"enabled": false,
			"encounter_id": encounter_id,
			"battle_id": battle_id,
			"blocked_reason": "终局战缺少 encounter_id 或 battle_id。",
		}
	return {
		"enabled": true,
		"encounter_id": encounter_id,
		"battle_id": battle_id,
		"override_player_profile": true,
	}
