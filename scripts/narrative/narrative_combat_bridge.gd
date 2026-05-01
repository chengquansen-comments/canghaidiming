extends RefCounted
class_name NarrativeCombatBridge

signal battle_requested(payload: Dictionary)
signal battle_finished(payload: Dictionary)

var pending_payload: Dictionary = {}

static func node_has_combat(node: Dictionary) -> bool:
	return node.has("combat") and typeof(node.get("combat", {})) == TYPE_DICTIONARY

static func build_payload(node_id: String, node: Dictionary) -> Dictionary:
	if not node_has_combat(node):
		return {}
	var combat: Dictionary = node.get("combat", {})
	var enemies: Array[String] = []
	var raw_enemies: Variant = combat.get("enemies", [])
	if typeof(raw_enemies) == TYPE_ARRAY:
		for item in raw_enemies:
			enemies.append(str(item))
	return {
		"node_id": node_id,
		"node_title": str(node.get("title", node_id)),
		"node_type": str(node.get("type", "")),
		"encounter_id": str(combat.get("encounter_id", "")),
		"battle_id": str(combat.get("battle_id", "")),
		"override_player_profile": bool(combat.get("override_player_profile", true)),
		"enemies": enemies,
		"status": "ready"
	}

func request_battle(node_id: String, node: Dictionary) -> Dictionary:
	pending_payload = build_payload(node_id, node)
	if pending_payload.is_empty():
		return {}
	pending_payload["status"] = "requested"
	battle_requested.emit(pending_payload)
	return pending_payload

func resolve_win(extra: Dictionary = {}) -> Dictionary:
	if pending_payload.is_empty():
		return {"status": "no_pending_battle"}
	var result := pending_payload.duplicate(true)
	result["status"] = "win"
	for key in extra.keys():
		result[key] = extra[key]
	pending_payload.clear()
	battle_finished.emit(result)
	return result

func resolve_loss(extra: Dictionary = {}) -> Dictionary:
	if pending_payload.is_empty():
		return {"status": "no_pending_battle"}
	var result := pending_payload.duplicate(true)
	result["status"] = "loss"
	for key in extra.keys():
		result[key] = extra[key]
	pending_payload.clear()
	battle_finished.emit(result)
	return result

func has_pending_battle() -> bool:
	return not pending_payload.is_empty()
