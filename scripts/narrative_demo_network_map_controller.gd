extends "res://scripts/narrative_demo_strategic_legacy_controller.gd"

const StrategicNetworkMapView := preload("res://scripts/strategic_network_map_view.gd")
const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicNetworkMapFormatter := preload("res://scripts/strategic_network_map_formatter.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const NetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const NETWORK_FINAL_BOSS_ENCOUNTER_ID := "enc_boss_ext_wakou_leader"
const NETWORK_FINAL_BOSS_BATTLE_ID := "boss_ext_wakou_leader"

var network_map_view: Control = null
var network_overlay_layer: Control = null
var network_overlay_panel: PanelContainer = null
var network_map_container: VBoxContainer = null
var network_preview_container: VBoxContainer = null
var network_footer_container: HBoxContainer = null

# Network-map layer.
# Handles overlay rendering, network node selection, node execution, battle pending, and final gate.
# State transitions and strategic_state mirror writes are delegated to StrategicNetworkMapRuntime.

func _render_strategic_map() -> void:
	var graph_variant = strategic_state.get("network_map", {})
	if graph_variant is Dictionary and not (graph_variant as Dictionary).is_empty():
		_render_network_strategic_map(graph_variant as Dictionary)
		return
	_render_legacy_strategic_map()


func _render_network_strategic_map(graph: Dictionary) -> void:
	_ensure_network_overlay_layer()
	network_overlay_layer.visible = true
	_clear_network_overlay_dynamic()
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


func _ensure_network_overlay_layer() -> void:
	if network_overlay_layer != null:
		return
	network_overlay_layer = Control.new()
	network_overlay_layer.name = "NetworkMapOverlayLayer"
	network_overlay_layer.anchor_left = 0.0
	network_overlay_layer.anchor_top = 0.0
	network_overlay_layer.anchor_right = 1.0
	network_overlay_layer.anchor_bottom = 1.0
	network_overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	network_overlay_layer.z_index = 180
	network_overlay_layer.z_as_relative = false
	add_child(network_overlay_layer)

	var dim := ColorRect.new()
	dim.name = "NetworkMapOverlayDim"
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.015, 0.014, 0.012, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	network_overlay_layer.add_child(dim)

	network_overlay_panel = PanelContainer.new()
	network_overlay_panel.name = "NetworkMapOverlayPanel"
	network_overlay_panel.anchor_left = 0.04
	network_overlay_panel.anchor_top = 0.06
	network_overlay_panel.anchor_right = 0.96
	network_overlay_panel.anchor_bottom = 0.92
	network_overlay_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	network_overlay_layer.add_child(network_overlay_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.039, 0.030, 0.96)
	style.border_color = Color(0.78, 0.62, 0.36, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	network_overlay_panel.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.name = "NetworkMapOverlayRoot"
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_overlay_panel.add_child(root)

	var header := Label.new()
	header.name = "NetworkMapOverlayHeader"
	header.text = "海疆大势图"
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color", Color("f3dfb8"))
	root.add_child(header)

	var main_row := HBoxContainer.new()
	main_row.name = "NetworkMapOverlayMainRow"
	main_row.add_theme_constant_override("separation", 16)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	network_map_container = VBoxContainer.new()
	network_map_container.name = "NetworkMapContainer"
	network_map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network_map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(network_map_container)

	network_preview_container = VBoxContainer.new()
	network_preview_container.name = "NetworkPreviewContainer"
	network_preview_container.custom_minimum_size = Vector2(360, 0)
	network_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_preview_container.add_theme_constant_override("separation", 10)
	main_row.add_child(network_preview_container)

	network_footer_container = HBoxContainer.new()
	network_footer_container.name = "NetworkFooterContainer"
	network_footer_container.add_theme_constant_override("separation", 10)
	network_footer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(network_footer_container)
	network_overlay_layer.visible = false


func _clear_network_overlay_dynamic() -> void:
	if network_map_container != null:
		for child in network_map_container.get_children():
			child.queue_free()
	if network_preview_container != null:
		for child in network_preview_container.get_children():
			child.queue_free()
	if network_footer_container != null:
		for child in network_footer_container.get_children():
			child.queue_free()


func _sync_network_overlay_visibility() -> void:
	var graph_variant = strategic_state.get("network_map", {})
	var should_show := bool(strategic_state.get("active", false)) \
		and graph_variant is Dictionary \
		and not (graph_variant as Dictionary).is_empty()
	if network_overlay_layer != null:
		network_overlay_layer.visible = should_show
	if should_show:
		if focus_story_layer != null:
			focus_story_layer.visible = false
		if focus_world_map_layer != null:
			focus_world_map_layer.visible = false


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
	var progress := Label.new()
	progress.text = _network_progress_text(graph)
	progress.add_theme_font_size_override("font_size", 16)
	progress.add_theme_color_override("font_color", Color("d9c08c"))
	network_map_container.add_child(progress)

	network_map_view = StrategicNetworkMapView.new()
	network_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_map_view.custom_minimum_size = Vector2(920, 520)
	network_map_view.set_graph(graph, str(graph.get("selected_node_id", "")))
	network_map_view.node_clicked.connect(_on_network_node_clicked)
	network_map_container.add_child(network_map_view)


func _render_network_overlay_preview_panel(graph: Dictionary) -> void:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := StrategicNetworkMapRuntime.find_node(graph, selected_id)
	var confirm_meta := _network_confirm_meta(graph, node)

	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = false
	preview.scroll_active = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(340, 420)
	preview.add_theme_font_size_override("normal_font_size", 18)
	preview.add_theme_font_size_override("bold_font_size", 20)
	preview.add_theme_color_override("default_color", Color("f0dfb8"))
	preview.text = _network_preview_text(graph)
	network_preview_container.add_child(preview)

	var confirm := Button.new()
	confirm.text = "确认前往"
	confirm.disabled = not bool(confirm_meta.get("enabled", false))
	confirm.custom_minimum_size = Vector2(0, 58)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm_network_node)
	network_preview_container.add_child(confirm)


func _render_network_overlay_footer(graph: Dictionary) -> void:
	var state_label := Label.new()
	state_label.text = _network_state_summary_text()
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.add_theme_font_size_override("font_size", 16)
	state_label.add_theme_color_override("font_color", Color("d9c08c"))
	network_footer_container.add_child(state_label)

	var fallback := Button.new()
	fallback.text = "继续旧线性流程"
	fallback.custom_minimum_size = Vector2(220, 52)
	fallback.pressed.connect(_continue_legacy_linear_flow)
	network_footer_container.add_child(fallback)


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
	var summary := RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.fit_content = false
	summary.scroll_active = true
	summary.custom_minimum_size = Vector2(340, 420)
	summary.add_theme_font_size_override("normal_font_size", 18)
	summary.add_theme_font_size_override("bold_font_size", 22)
	summary.add_theme_color_override("default_color", Color("f0dfb8"))
	summary.text = StrategicNetworkMapFormatter.final_gate_text(graph, strategic_state, NarrativeBattleContext.get_player_profile())
	network_preview_container.add_child(summary)

	var boss_btn := Button.new()
	boss_btn.text = "进入临时终局战"
	boss_btn.custom_minimum_size = Vector2(0, 58)
	boss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_btn.pressed.connect(_on_network_final_boss_pressed)
	network_preview_container.add_child(boss_btn)
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
