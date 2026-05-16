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
	var route_count_text := _single_run_node_count_text(graph)
	var visible_node_count := _visible_node_count(nodes)
	var base := "run=%s｜seed=%d｜层数=%d｜当前显示点=%d｜单局路径点=%s｜已完成=%d｜可达=%d" % [
		str(graph.get("run_id", "")),
		int(graph.get("seed", 0)),
		layer_count,
		visible_node_count,
		route_count_text,
		completed,
		available,
	]
	if bool(graph.get("aigc_dungeon_runtime", false)):
		var battle_count := int(graph.get("battle_count_so_far", 0))
		var elite_count := int(graph.get("elite_count_so_far", 0))
		var operation_count := int(graph.get("operation_count_so_far", 0))
		return "%s\n单局目标：大地图战斗 14-16｜经营 7-10｜当前 战斗 %d｜精英 %d｜经营 %d｜说明：全图候选点数不等于单局必经数量" % [
			base,
			battle_count,
			elite_count,
			operation_count,
		]
	return base

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
	if bool(graph.get("aigc_dungeon_runtime", false)):
		c._network_overlay_view().render_dungeon_storage_panel(
			Callable(c, "_save_dungeon_route_slot"),
			Callable(c, "_restore_dungeon_route_slot")
		)

static func render_overlay_footer(c, _graph: Dictionary) -> void:
	var save_slot_callback := Callable()
	var restore_slot_callback := Callable()
	if bool(_graph.get("aigc_dungeon_runtime", false)):
		save_slot_callback = Callable(c, "_save_dungeon_route_slot")
		restore_slot_callback = Callable(c, "_restore_dungeon_route_slot")
	c._network_overlay_view().render_footer(
		c._network_state_summary_text(),
		Callable(c, "_continue_legacy_linear_flow"),
		save_slot_callback,
		restore_slot_callback
	)

static func _single_run_node_count_text(graph: Dictionary) -> String:
	var route_counts := _route_path_node_counts(graph)
	if route_counts.is_empty():
		return "-"
	var selected_route := str(graph.get("selected_ending_route", ""))
	if route_counts.has(selected_route):
		return str(int(route_counts[selected_route]))
	var counts: Array[int] = []
	for key in ["normal", "true", "wuzhuangyuan"]:
		if route_counts.has(key):
			counts.append(int(route_counts[key]))
	if counts.is_empty():
		return "-"
	counts.sort()
	if counts.front() == counts.back():
		return str(counts.front())
	return "%d-%d" % [counts.front(), counts.back()]

static func _route_path_node_counts(graph: Dictionary) -> Dictionary:
	var nodes_variant = graph.get("nodes", [])
	if not (nodes_variant is Array):
		return {}
	var node_by_id: Dictionary = {}
	for item in nodes_variant:
		if item is Dictionary:
			var node := item as Dictionary
			node_by_id[str(node.get("map_graph_id", ""))] = node
	if not node_by_id.has("node_start"):
		return {}
	var result := {}
	var route_targets := {
		"normal": "node_normal_boss",
		"true": "node_true_boss_002",
		"wuzhuangyuan": "node_wuzhuangyuan_exam_005",
	}
	for route_key in route_targets.keys():
		var count := _path_length_to_target("node_start", str(route_targets[route_key]), node_by_id)
		if count > 0:
			result[route_key] = count
	return result

static func _path_length_to_target(start_id: String, target_id: String, node_by_id: Dictionary) -> int:
	if start_id.is_empty() or target_id.is_empty():
		return -1
	if not node_by_id.has(start_id) or not node_by_id.has(target_id):
		return -1
	var queue: Array[String] = [start_id]
	var distance := {start_id: 1}
	while not queue.is_empty():
		var current_id := str(queue.pop_front())
		if current_id == target_id:
			return int(distance.get(current_id, -1))
		var node: Dictionary = node_by_id.get(current_id, {}) as Dictionary
		for next_id_variant in node.get("outgoing", []):
			var next_id := str(next_id_variant)
			if next_id.is_empty() or not node_by_id.has(next_id) or distance.has(next_id):
				continue
			distance[next_id] = int(distance.get(current_id, 0)) + 1
			queue.append(next_id)
	return -1

static func _visible_node_count(nodes: Array) -> int:
	var count := 0
	for item in nodes:
		if item is Dictionary and not bool((item as Dictionary).get("hidden", false)):
			count += 1
	return count

static func render_overlay_complete(c, graph: Dictionary) -> void:
	render_overlay_map_view(c, graph)
	c._network_overlay_view().render_complete_panel(
		StrategicNetworkMapFormatter.final_gate_text(graph, c.strategic_state, NarrativeBattleContext.get_player_profile()),
		Callable(c, "_on_network_final_boss_pressed")
	)
	render_overlay_footer(c, graph)
