extends "res://scripts/narrative_demo_strategic_legacy_controller.gd"

const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkMapFormatter := preload("res://scripts/strategic_network_map_formatter.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapOverlay := preload("res://scripts/strategic_network_map_overlay.gd")
const NetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const NETWORK_FINAL_BOSS_ENCOUNTER_ID := "enc_boss_ext_wakou_leader"
const NETWORK_FINAL_BOSS_BATTLE_ID := "boss_ext_wakou_leader"

var _network_overlay: StrategicNetworkMapOverlay = null

# Network-map layer.
# Handles network node selection, node execution, battle pending, and final gate.
# State transitions and strategic_state mirror writes are delegated to StrategicNetworkMapRuntime.
# Overlay UI construction and panel rendering are delegated to StrategicNetworkMapOverlay.

func _render_strategic_map() -> void:
	var graph_variant = strategic_state.get("network_map", {})
	if graph_variant is Dictionary and not (graph_variant as Dictionary).is_empty():
		_render_network_strategic_map(graph_variant as Dictionary)
		return
	_render_legacy_strategic_map()


func _render_network_strategic_map(graph: Dictionary) -> void:
	_network_overlay_view().ensure_layer()
	_network_overlay_view().set_visible(true)
	_network_overlay_view().clear_dynamic()
	StrategicNetworkMapRuntime.ensure_selected_node(graph)
	_sync_network_state_from_graph(graph)
	title_label.text = "海疆大势图"
	status_label.text = "完整网络图｜第 %d / %d 层" % [int(graph.get("current_layer", 0)) + 1, int(graph.get("layer_count", 10))]
	map_label.text = _network_progress_text(graph)
	body_label.text = ""
	vars_label.text = _network_state_summary_text()
	if bool(graph.get("map_complete", false)) or not StrategicNetworkMapRuntime.has_available_node(graph):
		_render_network_overlay_complete(graph)
		return
	_render_network_overlay_map_view(graph)
	_render_network_overlay_preview_panel(graph)
	_render_network_overlay_footer(graph)


func _network_overlay_view() -> StrategicNetworkMapOverlay:
	if _network_overlay == null:
		_network_overlay = StrategicNetworkMapOverlay.new(self)
	return _network_overlay


func _on_network_node_clicked(map_graph_id: String) -> void:
	var graph_variant = strategic_state.get("network_map", {})
	if not (graph_variant is Dictionary):
		return
	var graph := graph_variant as Dictionary
	if graph.is_empty():
		return
	graph["selected_node_id"] = map_graph_id
	_sync_network_state_from_graph(graph)
	_save_narrative_state_to_context()
	_render()


func _network_progress_text(graph: Dictionary) -> String:
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


func _sync_network_overlay_visibility() -> void:
	var graph_variant = strategic_state.get("network_map", {})
	var should_show := bool(strategic_state.get("active", false)) \
		and graph_variant is Dictionary \
		and not (graph_variant as Dictionary).is_empty()
	_network_overlay_view().sync_visibility(should_show, focus_story_layer, focus_world_map_layer)


func _network_preview_text(graph: Dictionary) -> String:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if node.is_empty():
		return "尚未选中节点。"
	var confirm_meta := _network_confirm_meta(graph, node)
	return StrategicNetworkMapFormatter.preview_text(
		graph,
		node,
		confirm_meta,
		StrategicNetworkBattleBridge.combat_request_for_node(node)
	)


func _network_confirm_meta(graph: Dictionary, node: Dictionary) -> Dictionary:
	return {
		"enabled": _network_selected_can_confirm(graph),
		"reason": _network_confirm_block_reason(node),
	}


func _confirm_network_node() -> void:
	var graph: Dictionary = strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if node.is_empty():
		last_hint = "未选中有效的大势图节点。"
		_render()
		return
	if not _network_selected_can_confirm(graph):
		last_hint = _network_confirm_block_reason(node)
		_render()
		return
	if StrategicNetworkBattleBridge.is_combat_node(node):
		_enter_network_combat_node(node)
		return
	_execute_network_non_combat_node(node)


func _execute_network_non_combat_node(node: Dictionary) -> void:
	var graph: Dictionary = strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return
	var runtime_node := node.duplicate(true)
	if not runtime_node.has("node_id"):
		runtime_node["node_id"] = str(node.get("pool_node_id", node.get("map_graph_id", "")))
	_apply_strategic_node(runtime_node)
	_complete_network_node(graph, node)
	_refresh_network_node_states(graph)
	_sync_network_state_from_graph(graph)
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "你记下了这一处海疆线索。"
	last_hint = result_text
	_save_narrative_state_to_context()
	_render()


func _enter_network_combat_node(node: Dictionary) -> void:
	var graph: Dictionary = strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		return
	var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
	if not bool(request.get("enabled", false)):
		last_hint = str(request.get("blocked_reason", "该战斗节点暂未接入。"))
		_save_narrative_state_to_context()
		_render()
		return
	var node_id := str(node.get("map_graph_id", ""))
	graph["pending_map_node_id"] = node_id
	graph["pending_result_text"] = str(node.get("result_text", ""))
	graph["pending_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
	_sync_network_state_from_graph(graph)
	_sync_strategic_cards_to_context()
	_save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat(request, "map_" + node_id)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")


func _network_node_can_confirm(node: Dictionary) -> bool:
	var state := str(node.get("state", "locked"))
	if not (state == "available" or state == "start"):
		return false
	if StrategicNetworkBattleBridge.is_combat_node(node):
		var request := StrategicNetworkBattleBridge.combat_request_for_node(node)
		if not bool(request.get("enabled", false)):
			return false
	return true


func _network_confirm_block_reason(node: Dictionary) -> String:
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


func _network_selected_can_confirm(graph: Dictionary) -> bool:
	if bool(graph.get("map_complete", false)):
		return false
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	if node.is_empty():
		return false
	var available := StrategicNetworkMapRuntime.valid_available_ids(graph, graph.get("available_node_ids", []))
	if not available.has(selected_id):
		return false
	return _network_node_can_confirm(node)


func _complete_network_node(graph: Dictionary, node: Dictionary) -> void:
	StrategicNetworkMapRuntime.complete_node(graph, node)


func _refresh_network_node_states(graph: Dictionary) -> void:
	StrategicNetworkMapRuntime.refresh_node_states(graph)


func _sync_network_state_from_graph(graph: Dictionary) -> void:
	StrategicNetworkMapRuntime.sync_mirror_fields(strategic_state, graph)


func _render_network_overlay_map_view(graph: Dictionary) -> void:
	_network_overlay_view().render_map_view(
		graph,
		_network_progress_text(graph),
		str(graph.get("selected_node_id", "")),
		Callable(self, "_on_network_node_clicked")
	)


func _render_network_overlay_preview_panel(graph: Dictionary) -> void:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	var confirm_meta := _network_confirm_meta(graph, node)
	_network_overlay_view().render_preview_panel(
		_network_preview_text(graph),
		bool(confirm_meta.get("enabled", false)),
		Callable(self, "_confirm_network_node")
	)


func _render_network_overlay_footer(_graph: Dictionary) -> void:
	_network_overlay_view().render_footer(
		_network_state_summary_text(),
		Callable(self, "_continue_legacy_linear_flow")
	)


func _consume_network_node_battle(source_id: String, result: String) -> void:
	var graph: Dictionary = strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		last_hint = "战斗返回：未找到大势图。"
		return
	var pending_id := str(graph.get("pending_map_node_id", ""))
	if pending_id.is_empty():
		last_hint = "战斗返回：未找到 pending 节点。"
		return
	var expected_source_id := "map_" + pending_id
	if source_id != expected_source_id:
		push_warning("Network map battle source mismatch: expected %s, got %s" % [expected_source_id, source_id])
	var node := StrategicNetworkMapRuntime.find_node(graph, pending_id)
	if node.is_empty():
		last_hint = "战斗返回：未找到大势图节点。"
		StrategicNetworkMapRuntime.clear_pending(graph)
		_sync_network_state_from_graph(graph)
		return
	if result != "win":
		last_hint = "战斗未胜：当前节点可重试。"
		StrategicNetworkMapRuntime.clear_pending(graph)
		_sync_network_state_from_graph(graph)
		return
	var runtime_node := node.duplicate(true)
	if not runtime_node.has("node_id"):
		runtime_node["node_id"] = str(node.get("pool_node_id", node.get("map_graph_id", "")))
	_apply_strategic_node(runtime_node)
	NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
	_complete_network_node(graph, node)
	_refresh_network_node_states(graph)
	StrategicNetworkMapRuntime.clear_pending(graph)
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "战事暂歇，海风又压回岸边。"
	last_hint = result_text
	_sync_network_state_from_graph(graph)


func _render_network_overlay_complete(graph: Dictionary) -> void:
	_render_network_overlay_map_view(graph)
	_network_overlay_view().render_complete_panel(
		StrategicNetworkMapFormatter.final_gate_text(graph, strategic_state, NarrativeBattleContext.get_player_profile()),
		Callable(self, "_on_network_final_boss_pressed")
	)
	_render_network_overlay_footer(graph)


func _on_network_final_boss_pressed() -> void:
	var graph: Dictionary = strategic_state.get("network_map", {}) as Dictionary
	if graph.is_empty():
		last_hint = "终局门未开启：未找到海疆大势图。"
		_render()
		return
	strategic_state["final_gate_active"] = true
	strategic_state["final_boss"] = {
		"title": "海门收束",
		"encounter_id": NETWORK_FINAL_BOSS_ENCOUNTER_ID,
		"battle_id": NETWORK_FINAL_BOSS_BATTLE_ID,
		"ending_flag": "surface_pirate",
	}
	_sync_strategic_cards_to_context()
	_save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat({
		"enabled": true,
		"encounter_id": NETWORK_FINAL_BOSS_ENCOUNTER_ID,
		"battle_id": NETWORK_FINAL_BOSS_BATTLE_ID,
		"override_player_profile": true,
	}, STRATEGIC_FINAL_BOSS_SOURCE_ID)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")


func _network_state_summary_text() -> String:
	return StrategicMapState.summary_text(strategic_state)


func _continue_legacy_linear_flow() -> void:
	strategic_state["active"] = false
	strategic_state["completed"] = true
	_save_narrative_state_to_context()
	var target_index := _find_flow_index_by_node_id("military_order")
	if target_index >= 0:
		super._advance_to_node(target_index, "继续旧线性流程。")
	else:
		super._advance_to_node(_flow_count() - 1, "继续旧线性流程。")


func _find_flow_index_by_node_id(node_id: String) -> int:
	for i in range(_flow_count()):
		if _node_id_at(i) == node_id:
			return i
	return -1


func _ensure_network_map_for_state(warn_if_regenerated: bool = false) -> void:
	var map_variant = strategic_state.get("network_map", {})
	if map_variant is Dictionary and not (map_variant as Dictionary).is_empty():
		return
	var seed_value := int(strategic_state.get("seed", 1701))
	if warn_if_regenerated:
		push_warning("strategic_state.network_map missing during restore, regenerating from seed=%d" % seed_value)
	var network_map: Dictionary = NetworkMapGenerator.generate_network_map(strategic_config, strategic_state, seed_value)
	_sync_network_state_from_graph(network_map)
	print(NetworkMapGenerator.summarize_network_map(network_map))
