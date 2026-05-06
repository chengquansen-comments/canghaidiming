extends RefCounted

# Pure confirm-state helper for strategic network-map nodes.
#
# Keep this file free of UI creation, scene switching, narrative result
# application, and graph mutation. It answers only:
# - can the selected node be confirmed?
# - why is a node blocked?
# - what confirm metadata should formatter / UI receive?

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")


static func confirm_meta(graph: Dictionary, node: Dictionary) -> Dictionary:
	return {
		"enabled": selected_can_confirm(graph),
		"reason": block_reason(node),
	}


static func selected_can_confirm(graph: Dictionary) -> bool:
	if bool(graph.get("map_complete", false)):
		return false
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if node.is_empty():
		return false
	var available := StrategicNetworkMapRuntime.valid_available_ids(graph, graph.get("available_node_ids", []))
	if not available.has(selected_id):
		return false
	return node_can_confirm(node)


static func node_can_confirm(node: Dictionary) -> bool:
	var state := str(node.get("state", "locked"))
	if not (state == "available" or state == "start"):
		return false
	if StrategicNetworkBattleBridge.is_combat_node(node):
		var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
		if not bool(request.get("enabled", false)):
			return false
	return true


static func block_reason(node: Dictionary) -> String:
	var state := str(node.get("state", "locked"))
	match state:
		"locked":
			return "未解锁。"
		"unreachable":
			return "当前路线不可达。"
		"completed":
			return "已完成，不可重复执行。"
		"available", "start":
			if StrategicNetworkBattleBridge.is_combat_node(node):
				var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
				if not bool(request.get("enabled", false)):
					return str(request.get("blocked_reason", "该 combat_pool 暂未接入战斗。"))
			return ""
	return "当前节点不可前往。"
