extends RefCounted

# Pure battle-result helper for strategic network-map nodes.
#
# This helper mutates only the supplied graph dictionary. It does not touch
# NarrativeBattleContext, scene switching, UI, player growth, or strategic node
# effect application.

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")


static func consume_battle_result(graph: Dictionary, source_id: String, result: String) -> Dictionary:
	if graph.is_empty():
		return _response(false, "战斗返回：未找到大势图。", {}, false, false, "missing_graph")
	var pending_id := str(graph.get("pending_map_node_id", ""))
	if pending_id.is_empty():
		return _response(false, "战斗返回：未找到 pending 节点。", {}, false, false, "missing_pending")
	var expected_source_id := "map_" + pending_id
	var source_mismatch := source_id != expected_source_id
	var node := StrategicNetworkMapRuntime.find_node(graph, pending_id)
	if node.is_empty():
		StrategicNetworkMapRuntime.clear_pending(graph)
		return _response(true, "战斗返回：未找到大势图节点。", {}, false, source_mismatch, "missing_node", expected_source_id)
	if result != "win":
		StrategicNetworkMapRuntime.clear_pending(graph)
		return _response(true, "战斗未胜：当前节点可重试。", node, false, source_mismatch, "not_win", expected_source_id)
	StrategicNetworkMapRuntime.complete_node(graph, node)
	StrategicNetworkMapRuntime.refresh_node_states(graph)
	StrategicNetworkMapRuntime.clear_pending(graph)
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "战事暂歇，海风又压回岸边。"
	return _response(true, result_text, node, true, source_mismatch, "win", expected_source_id)


static func runtime_node_for_effects(node: Dictionary) -> Dictionary:
	var runtime_node := node.duplicate(true)
	if not runtime_node.has("node_id"):
		runtime_node["node_id"] = str(node.get("pool_node_id", node.get("map_graph_id", "")))
	return runtime_node


static func _response(mutated: bool, hint: String, node: Dictionary, completed: bool, source_mismatch: bool, status: String, expected_source_id: String = "") -> Dictionary:
	return {
		"mutated": mutated,
		"last_hint": hint,
		"node": node,
		"completed": completed,
		"source_mismatch": source_mismatch,
		"status": status,
		"expected_source_id": expected_source_id,
	}
