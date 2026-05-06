extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkMapFormatter := preload("res://scripts/strategic_network_map_formatter.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapConfirm := preload("res://scripts/strategic_network_map_confirm.gd")

static func progress_text(graph: Dictionary) -> String:
	var nodes: Array = graph.get("nodes", [])
	var layer_count := int(graph.get("layer_count", 0))
	var completed := (graph.get("completed_node_ids", []) as Array).size()
	var available := (graph.get("available_node_ids", []) as Array).size()
	return "run=%s｜seed=%d｜层数=%d｜节点=%d｜已完成=%d｜可达=%d" % [
		str(graph.get("run_id", "")),
		int(graph.get("seed", 0)),
		layer_count,
		nodes.size(),
		completed,
		available,
	]

static func confirm_meta(graph: Dictionary, node: Dictionary) -> Dictionary:
	return StrategicNetworkMapConfirm.confirm_meta(graph, node)

static func preview_text(graph: Dictionary) -> String:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if node.is_empty():
		return "尚未选中节点。"
	return StrategicNetworkMapFormatter.preview_text(
		graph,
		node,
		confirm_meta(graph, node),
		StrategicNetworkBattleBridge.combat_request_for_node(node)
	)

static func state_summary_text(strategic_state: Dictionary) -> String:
	return StrategicMapState.summary_text(strategic_state)
