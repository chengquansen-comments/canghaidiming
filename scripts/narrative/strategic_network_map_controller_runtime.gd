extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkMapFormatter := preload("res://scripts/strategic_network_map_formatter.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapConfirm := preload("res://scripts/strategic_network_map_confirm.gd")
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

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

static func sync_overlay_visibility(c) -> void:
	var graph_variant = c.strategic_state.get("network_map", {})
	var should_show := bool(c.strategic_state.get("active", false)) \
		and graph_variant is Dictionary \
		and not (graph_variant as Dictionary).is_empty()
	c._network_overlay_view().sync_visibility(should_show, c.focus_story_layer, c.focus_world_map_layer)

static func render_network_strategic_map(c, graph: Dictionary) -> void:
	c._network_overlay_view().ensure_layer()
	c._network_overlay_view().set_visible(true)
	c._network_overlay_view().clear_dynamic()
	StrategicNetworkMapRuntime.ensure_selected_node(graph)
	c._sync_network_state_from_graph(graph)
	c.title_label.text = "海疆大势图"
	c.status_label.text = "完整网络图｜第 %d / %d 层" % [int(graph.get("current_layer", 0)) + 1, int(graph.get("layer_count", 10))]
	c.map_label.text = c._network_progress_text(graph)
	c.body_label.text = ""
	c.vars_label.text = c._network_state_summary_text()
	if bool(graph.get("map_complete", false)) or not StrategicNetworkMapRuntime.has_available_node(graph):
		render_overlay_complete(c, graph)
		return
	render_overlay_map_view(c, graph)
	render_overlay_preview_panel(c, graph)
	render_overlay_footer(c, graph)

static func render_overlay_map_view(c, graph: Dictionary) -> void:
	c._network_overlay_view().render_map_view(
		graph,
		c._network_progress_text(graph),
		str(graph.get("selected_node_id", "")),
		Callable(c, "_on_network_node_clicked")
	)

static func render_overlay_preview_panel(c, graph: Dictionary) -> void:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	var confirm_meta: Dictionary = c._network_confirm_meta(graph, node)
	c._network_overlay_view().render_preview_panel(
		c._network_preview_text(graph),
		bool(confirm_meta.get("enabled", false)),
		Callable(c, "_confirm_network_node")
	)

static func render_overlay_footer(c, _graph: Dictionary) -> void:
	c._network_overlay_view().render_footer(
		c._network_state_summary_text(),
		Callable(c, "_continue_legacy_linear_flow")
	)

static func render_overlay_complete(c, graph: Dictionary) -> void:
	render_overlay_map_view(c, graph)
	c._network_overlay_view().render_complete_panel(
		StrategicNetworkMapFormatter.final_gate_text(graph, c.strategic_state, NarrativeBattleContext.get_player_profile()),
		Callable(c, "_on_network_final_boss_pressed")
	)
	render_overlay_footer(c, graph)
