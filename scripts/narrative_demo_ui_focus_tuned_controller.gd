extends "res://scripts/narrative_demo_ui_focus_controller.gd"

# Main narrative strategic orchestration entry.
# Keeps the active inheritance chain short while delegating concrete work to
# runtime/view/formatter/bridge helpers.
# Do not add new business logic here directly. New strategic, network, reward,
# or battle-return behavior should move into helper modules and be called here
# through thin wrappers.

const TUNED_STORY_FONT_SIZE := 72
const TUNED_OPTION_FONT_SIZE := 25
const TUNED_CAPTION_OFFSET_Y := 30
const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const StrategicNetworkMapRuntime := preload("res://scripts/strategic_network_map_runtime.gd")
const StrategicEndingFormatter := preload("res://scripts/narrative/strategic_ending_formatter.gd")
const StrategicFinalGateView := preload("res://scripts/narrative/strategic_final_gate_view.gd")
const StrategicLegacyMapView := preload("res://scripts/narrative/strategic_legacy_map_view.gd")
const StrategicRewardRuntime := preload("res://scripts/narrative/strategic_reward_runtime.gd")
const StrategicCardStateBridge := preload("res://scripts/narrative/strategic_card_state_bridge.gd")
const StrategicChoiceRuntime := preload("res://scripts/narrative/strategic_choice_runtime.gd")
const StrategicDebugProfileBuilder := preload("res://scripts/narrative/strategic_debug_profile_builder.gd")
const StrategicLegacyBattleResultRuntime := preload("res://scripts/narrative/strategic_legacy_battle_result_runtime.gd")
const StrategicMapSessionRuntime := preload("res://scripts/narrative/strategic_map_session_runtime.gd")
const StrategicNetworkMapControllerRuntime := preload("res://scripts/narrative/strategic_network_map_controller_runtime.gd")
const StrategicNetworkMapFlowRuntime := preload("res://scripts/narrative/strategic_network_map_flow_runtime.gd")
const StrategicNodeApplyRuntime := preload("res://scripts/narrative/strategic_node_apply_runtime.gd")
const StrategicWorldMapRuntime := preload("res://scripts/narrative/strategic_world_map_runtime.gd")
const STRATEGIC_ENTRY_NODE_ID := "world_map_entry"
const STRATEGIC_FINAL_BOSS_SOURCE_ID := "strategic_final_boss"
const StrategicNetworkMapFormatter := preload("res://scripts/strategic_network_map_formatter.gd")
const StrategicNetworkBattleBridge := preload("res://scripts/strategic_network_battle_bridge.gd")
const StrategicNetworkMapConfirm := preload("res://scripts/strategic_network_map_confirm.gd")
const StrategicNetworkMapOverlay := preload("res://scripts/strategic_network_map_overlay.gd")
const StrategicNetworkMapBattleResult := preload("res://scripts/strategic_network_map_battle_result.gd")
const NetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const NETWORK_FINAL_BOSS_ENCOUNTER_ID := "enc_boss_ext_wakou_leader"
const NETWORK_FINAL_BOSS_BATTLE_ID := "boss_ext_wakou_leader"

var strategic_config: Dictionary = {}
var strategic_state: Dictionary = StrategicMapState.default_state()
var pending_strategic_ending_render := false
var pending_strategic_card_node: Dictionary = {}
var pending_strategic_card_choices: Array[String] = []
var selected_strategic_card_reward := ""
var _strategic_reward_runtime
var _strategic_ending_formatter
var _strategic_final_gate_view
var _strategic_legacy_map_view
var _network_overlay: StrategicNetworkMapOverlay = null

func _load_strategic_map_config() -> void:
	strategic_config = StrategicMapGenerator.load_config()

func _reward_runtime():
	if _strategic_reward_runtime == null:
		_strategic_reward_runtime = StrategicRewardRuntime.new(self)
	return _strategic_reward_runtime

func _ending_formatter():
	if _strategic_ending_formatter == null:
		_strategic_ending_formatter = StrategicEndingFormatter.new()
	return _strategic_ending_formatter

func _final_gate_view():
	if _strategic_final_gate_view == null:
		_strategic_final_gate_view = StrategicFinalGateView.new(self)
	return _strategic_final_gate_view

func _legacy_map_view():
	if _strategic_legacy_map_view == null:
		_strategic_legacy_map_view = StrategicLegacyMapView.new(self)
	return _strategic_legacy_map_view

func _try_consume_debug_world_map_entry() -> void:
	if not NarrativeBattleContext.has_debug_entry():
		return
	var entry := NarrativeBattleContext.consume_debug_entry()
	if str(entry.get("mode", "")) != "world_map":
		return
	var role := str(entry.get("player_role", "spearman"))
	var martial_level: int = max(1, int(entry.get("martial_level", 1)))
	_ensure_debug_world_map_player_profile(role, martial_level)
	jun_gong = 1
	qing_wang = 1
	clues = 1
	_start_strategic_map("Debug：直接进入海疆大势图。")

func _ensure_debug_world_map_player_profile(role: String = "spearman", martial_level: int = 1) -> void:
	if NarrativeBattleContext.has_player_profile():
		return
	NarrativeBattleContext.set_player_profile(
		StrategicDebugProfileBuilder.build_profile(role, martial_level)
	)

func _start_strategic_map(hint: String = "") -> void:
	if strategic_config.is_empty():
		last_hint = "大势图配置缺失，暂按线性节点继续。"
		super._advance_to_node(node_index + 1, last_hint)
		return
	var profile := NarrativeBattleContext.get_player_profile()
	strategic_state = StrategicMapSessionRuntime.build_initial_state(
		strategic_config,
		profile,
		jun_gong,
		qing_wang,
		clues
	)
	print(StrategicMapSessionRuntime.summarize_network_map(strategic_state))
	_sync_world_map_runtime_state()
	last_hint = hint
	_save_narrative_state_to_context()
	if _base_ui_ready():
		_render()

func _base_ui_ready() -> bool:
	return title_label != null \
		and status_label != null \
		and map_label != null \
		and scene_label != null \
		and body_label != null \
		and vars_label != null \
		and map_buttons_box != null \
		and combat_buttons_box != null \
		and choices_box != null

func _render_legacy_strategic_map() -> void:
	_refresh_current_strategic_layer()
	var map_data: Dictionary = strategic_state.get("current_map", {}) as Dictionary
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var region := StrategicMapGenerator.current_region(map_data, region_index)
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	if region.is_empty() or layer.is_empty():
		_prepare_strategic_final_gate()
		return
	_legacy_map_view().render(
		region,
		layer,
		strategic_state,
		layer_index,
		last_hint,
		_strategic_progress_text(map_data),
		Callable(self, "_on_strategic_choice")
	)

func _refresh_current_strategic_layer() -> void:
	StrategicWorldMapRuntime.refresh_current_layer(strategic_config, strategic_state)

func _strategic_progress_text(map_data: Dictionary) -> String:
	return _reward_runtime().strategic_progress_text(map_data)

func _on_strategic_choice(index: int) -> void:
	var node := StrategicChoiceRuntime.current_choice(strategic_state, index)
	if node.is_empty():
		return
	if _strategic_node_triggers_combat(node):
		strategic_state["current_world_map_node_id"] = str(node.get("node_id", ""))
		strategic_state["current_world_map_node_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
		_store_pending_choice(str(node.get("node_id", "")), StrategicChoiceRuntime.pending_payload(node))
		_sync_world_map_runtime_state()
		_sync_strategic_cards_to_context()
		_save_narrative_state_to_context()
		NarrativeBattleContext.set_request_from_combat({
			"enabled": true,
			"encounter_id": str(node.get("encounter_id", "")),
			"battle_id": str(node.get("battle_id", "")),
			"override_player_profile": true,
			"combat_pool_id": str(node.get("combat_pool_id", "")),
			"recommended_martial_min": int(node.get("recommended_martial_min", 0)),
			"recommended_martial_max": int(node.get("recommended_martial_max", 0)),
			"enemy_martial_level": int(node.get("enemy_martial_level", 0)),
		}, str(node.get("node_id", "")))
		get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
		return
	var reward_choices := _strategic_card_reward_choices(node)
	if not reward_choices.is_empty():
		_show_strategic_card_reward_choice(node, reward_choices)
		return
	_apply_strategic_node(node)
	_advance_strategic_cursor()
	_sync_world_map_runtime_state()
	_save_narrative_state_to_context()
	_render()

func _consume_strategic_node_battle(source_id: String, result: String) -> void:
	var pending := _load_pending_choice()
	var outcome: Dictionary = StrategicLegacyBattleResultRuntime.consume_result(strategic_config, source_id, result)
	if not bool(outcome.get("completed", false)):
		last_hint = str(outcome.get("last_hint", ""))
		_clear_pending_choice()
		_sync_world_map_runtime_state()
		return
	var node: Dictionary = outcome.get("node", {}) as Dictionary
	_apply_strategic_node(node)
	NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
	var profile := NarrativeBattleContext.get_player_profile()
	strategic_state = StrategicMapState.apply_battle_win(strategic_state, profile)
	strategic_state["martial_level"] = int(profile.get("martial_level", strategic_state.get("martial_level", 1)))
	if not pending.is_empty():
		strategic_state["last_node_result"] = str(pending.get("result", strategic_state.get("last_node_result", "")))
	_advance_strategic_cursor()
	_clear_pending_choice()
	_sync_world_map_runtime_state()

func _apply_strategic_node(node: Dictionary) -> void:
	_sync_context_cards_to_strategic_state()
	var outcome: Dictionary = StrategicNodeApplyRuntime.apply_node(strategic_state, node, jun_gong, qing_wang, clues)
	var state_variant = outcome.get("strategic_state", strategic_state)
	if state_variant is Dictionary:
		strategic_state = state_variant as Dictionary
	_sync_strategic_cards_to_context()
	_sync_context_cards_to_strategic_state()
	jun_gong = int(outcome.get("military_merit", jun_gong))
	qing_wang = int(outcome.get("clean_reputation", qing_wang))
	clues = int(outcome.get("case_clues", clues))
	last_hint = str(outcome.get("last_hint", ""))
	_sync_world_map_runtime_state()

func _strategic_card_reward_choices(node: Dictionary) -> Array[String]:
	return _reward_runtime().strategic_card_reward_choices(node)

func _show_strategic_card_reward_choice(node: Dictionary, card_ids: Array[String]) -> void:
	_reward_runtime().show_strategic_card_reward_choice(node, card_ids)

func _select_strategic_card_reward(card_id: String) -> void:
	_reward_runtime().select_strategic_card_reward(card_id)

func _confirm_strategic_card_reward() -> void:
	_reward_runtime().confirm_strategic_card_reward()

func _cancel_strategic_card_reward() -> void:
	_reward_runtime().cancel_strategic_card_reward()

func _strategic_card_choice_text(card_id: String, selected: bool) -> String:
	return _reward_runtime().strategic_card_choice_text(card_id, selected)

func _strategic_card_label(card_id: String) -> String:
	return _reward_runtime().strategic_card_label(card_id)

func _strategic_card_hint(card_id: String) -> String:
	return _reward_runtime().strategic_card_hint(card_id)

func _sync_context_cards_to_strategic_state() -> void:
	strategic_state = StrategicCardStateBridge.sync_context_cards_to_state(strategic_state)

func _sync_strategic_cards_to_context() -> void:
	StrategicCardStateBridge.sync_state_cards_to_context(strategic_state)

func _advance_strategic_cursor() -> void:
	var map_complete := StrategicWorldMapRuntime.advance_cursor(strategic_state)
	if map_complete:
		if _base_ui_ready():
			_prepare_strategic_final_gate()
		else:
			strategic_state["final_boss"] = StrategicWorldMapRuntime.select_final_boss(strategic_config, strategic_state)

func _prepare_strategic_final_gate() -> void:
	var boss := StrategicWorldMapRuntime.prepare_final_gate_state(strategic_config, strategic_state)
	if not _base_ui_ready():
		return
	_final_gate_view().render(boss, strategic_state, last_hint, Callable(self, "_on_strategic_final_boss"))

func _on_strategic_final_boss() -> void:
	var boss: Dictionary = strategic_state.get("final_boss", {}) as Dictionary
	if boss.is_empty():
		boss = StrategicWorldMapRuntime.select_final_boss(strategic_config, strategic_state)
		strategic_state["final_boss"] = boss
	_sync_strategic_cards_to_context()
	_save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat({
		"enabled": true,
		"encounter_id": str(boss.get("encounter_id", "enc_boss_ext_wakou_leader")),
		"battle_id": str(boss.get("battle_id", "boss_ext_wakou_leader")),
		"override_player_profile": true,
	}, STRATEGIC_FINAL_BOSS_SOURCE_ID)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

func _sync_world_map_runtime_state() -> void:
	StrategicWorldMapRuntime.sync_runtime_state(strategic_state)

func _find_strategic_node(node_id: String) -> Dictionary:
	return StrategicWorldMapRuntime.find_node(strategic_config, node_id)

func _strategic_node_triggers_combat(node: Dictionary) -> bool:
	return StrategicWorldMapRuntime.node_triggers_combat(node)

func _strategic_type_label(node_type: String) -> String:
	return _reward_runtime().strategic_type_label(node_type)

func _strategic_effects_text(effects: Dictionary) -> String:
	return _reward_runtime().strategic_effects_text(effects)

func _card_reward_ids_from_effects(value) -> Array[String]:
	return _reward_runtime().card_reward_ids_from_effects(value)

func _strategic_combat_pool_text(node: Dictionary) -> String:
	return _reward_runtime().strategic_combat_pool_text(node)

func _ending_data_for_flag(flag: String) -> Dictionary:
	var ending: Dictionary = _ending_formatter().ending_data_for_flag(flag)
	if ending.is_empty():
		return super._ending_data_for_flag(flag)
	return ending

func _ending_catalog() -> Array[Dictionary]:
	return _ending_formatter().ending_catalog()

func _ready() -> void:
	_load_strategic_map_config()
	super._ready()
	_apply_tuned_scene_art_view()
	call_deferred("_try_consume_debug_world_map_entry")
func _process(delta: float) -> void:
	super._process(delta)
	_apply_tuned_scene_art_view()
func _render() -> void:
	if pending_strategic_ending_render and _base_ui_ready():
		pending_strategic_ending_render = false
		super._advance_to_node(_flow_count(), last_hint)
		return
	if bool(strategic_state.get("active", false)):
		if not _base_ui_ready():
			return
		_clear_dynamic_boxes()
		_render_strategic_map()
		BattleFontHelper.enforce(self)
		_apply_focus_ui()
		_hide_scene_art_overlay_nodes()
		_sync_network_overlay_visibility()
		return
	_network_overlay_view().set_visible(false)
	super._render()
	_apply_tuned_scene_art_view()
	_sync_network_overlay_visibility()
func _narrative_state_snapshot() -> Dictionary:
	var snapshot := super._narrative_state_snapshot()
	snapshot["strategic_state"] = strategic_state.duplicate(true)
	return snapshot
func _restore_narrative_state_from_context() -> void:
	super._restore_narrative_state_from_context()
	var state := NarrativeBattleContext.get_narrative_state()
	var strategic_variant = state.get("strategic_state", {})
	if strategic_variant is Dictionary:
		strategic_state = (strategic_variant as Dictionary).duplicate(true)
		if bool(strategic_state.get("active", false)):
			_ensure_network_map_for_state(true)
		_sync_world_map_runtime_state()
		_sync_context_cards_to_strategic_state()
func _restart() -> void:
	strategic_state = StrategicMapState.default_state()
	super._restart()
func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id := NarrativeBattleContext.source_node_id
	var result := NarrativeBattleContext.last_result
	if source_id == STRATEGIC_FINAL_BOSS_SOURCE_ID:
		if result == "win":
			var boss: Dictionary = strategic_state.get("final_boss", {}) as Dictionary
			selected_ending_flag = str(boss.get("ending_flag", "surface_pirate"))
			strategic_state["active"] = false
			strategic_state["completed"] = true
			strategic_state["final_gate_active"] = false
			last_hint = "终局战胜利：%s" % str(boss.get("title", "海门收束"))
			NarrativeBattleContext.clear()
			_save_narrative_state_to_context()
			if _base_ui_ready():
				super._advance_to_node(_flow_count(), last_hint)
			else:
				pending_strategic_ending_render = true
			return
		last_hint = "终局战未胜：海门仍未收束，可再次挑战。"
		strategic_state["final_gate_active"] = true
		NarrativeBattleContext.clear()
		_save_narrative_state_to_context()
		if _base_ui_ready():
			_render()
		return
	if source_id.begins_with("map_"):
		var graph: Dictionary = strategic_state.get("network_map", {}) as Dictionary
		if not graph.is_empty() and not str(graph.get("pending_map_node_id", "")).is_empty():
			_consume_network_node_battle(source_id, result)
			NarrativeBattleContext.clear()
			_save_narrative_state_to_context()
			return
		_consume_strategic_node_battle(source_id, result)
		NarrativeBattleContext.clear()
		_save_narrative_state_to_context()
		return
	super._consume_battle_result_if_needed()
func _advance_to_node(target_index: int, hint: String = "") -> void:
	var current_node_id := _node_id_at(node_index)
	if not bool(strategic_state.get("completed", false)) \
		and current_node_id == STRATEGIC_ENTRY_NODE_ID \
		and target_index == node_index + 1:
		_start_strategic_map("破船之后，海疆大势图展开。")
		return
	super._advance_to_node(target_index, hint)

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
	StrategicNetworkMapFlowRuntime.on_network_node_clicked(self, map_graph_id)

func _network_progress_text(graph: Dictionary) -> String:
	return StrategicNetworkMapControllerRuntime.progress_text(graph)

func _sync_network_overlay_visibility() -> void:
	var graph_variant = strategic_state.get("network_map", {})
	var should_show := bool(strategic_state.get("active", false)) \
		and graph_variant is Dictionary \
		and not (graph_variant as Dictionary).is_empty()
	_network_overlay_view().sync_visibility(should_show, focus_story_layer, focus_world_map_layer)

func _network_preview_text(graph: Dictionary) -> String:
	return StrategicNetworkMapControllerRuntime.preview_text(graph)

func _network_confirm_meta(graph: Dictionary, node: Dictionary) -> Dictionary:
	return StrategicNetworkMapControllerRuntime.confirm_meta(graph, node)

func _confirm_network_node() -> void:
	StrategicNetworkMapFlowRuntime.confirm_network_node(self)

func _execute_network_non_combat_node(node: Dictionary) -> void:
	StrategicNetworkMapFlowRuntime.execute_network_non_combat_node(self, node)

func _enter_network_combat_node(node: Dictionary) -> void:
	StrategicNetworkMapFlowRuntime.enter_network_combat_node(self, node)

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
	StrategicNetworkMapFlowRuntime.consume_network_node_battle(self, source_id, result)

func _render_network_overlay_complete(graph: Dictionary) -> void:
	_render_network_overlay_map_view(graph)
	_network_overlay_view().render_complete_panel(
		StrategicNetworkMapFormatter.final_gate_text(graph, strategic_state, NarrativeBattleContext.get_player_profile()),
		Callable(self, "_on_network_final_boss_pressed")
	)
	_render_network_overlay_footer(graph)

func _on_network_final_boss_pressed() -> void:
	StrategicNetworkMapFlowRuntime.on_network_final_boss_pressed(self)

func _network_state_summary_text() -> String:
	return StrategicNetworkMapControllerRuntime.state_summary_text(strategic_state)

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
	StrategicNetworkMapFlowRuntime.ensure_network_map_for_state(self, warn_if_regenerated)

func _ensure_focus_story_caption() -> void:
	if focus_story_layer != null:
		return
	focus_story_layer = Control.new()
	focus_story_layer.name = "NarrativePerformanceCaptionLayer"
	focus_story_layer.anchor_left = 0.0
	focus_story_layer.anchor_top = 0.0
	focus_story_layer.anchor_right = 1.0
	focus_story_layer.anchor_bottom = 1.0
	focus_story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_layer.z_index = 90
	focus_story_layer.z_as_relative = false
	add_child(focus_story_layer)

	focus_story_panel = PanelContainer.new()
	focus_story_panel.name = "NarrativePerformanceCaptionPanel"
	focus_story_panel.anchor_left = 0.06
	focus_story_panel.anchor_top = PERFORMANCE_CAPTION_TOP
	focus_story_panel.anchor_right = 0.94
	focus_story_panel.anchor_bottom = PERFORMANCE_CAPTION_BOTTOM
	focus_story_panel.offset_top = TUNED_CAPTION_OFFSET_Y
	focus_story_panel.offset_bottom = TUNED_CAPTION_OFFSET_Y
	focus_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_panel.z_index = 91
	focus_story_panel.add_theme_stylebox_override("panel", _transparent_panel_style())
	focus_story_layer.add_child(focus_story_panel)

	focus_story_label = RichTextLabel.new()
	focus_story_label.name = "NarrativePerformanceCaptionText"
	focus_story_label.bbcode_enabled = true
	focus_story_label.fit_content = false
	focus_story_label.scroll_active = false
	focus_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_label.add_theme_font_size_override("normal_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("bold_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("italics_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_color_override("default_color", Color("f6ead2"))
	focus_story_panel.add_child(focus_story_label)
func _style_button_box(box: VBoxContainer) -> void:
	if box == null:
		return
	box.visible = true
	box.add_theme_constant_override("separation", 16)
	for child in box.get_children():
		if child is Button:
			var btn := child as Button
			btn.visible = true
			btn.custom_minimum_size = Vector2(0, 92)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", TUNED_OPTION_FONT_SIZE)
		elif child is Label:
			_hide_control(child as Control)
func _apply_tuned_scene_art_view() -> void:
	_pin_cinematic_background()
	_make_operation_panel_floating()
	_hide_scene_art_overlay_ui()
func _pin_cinematic_background() -> void:
	if cinematic_bg == null:
		return
	cinematic_bg.visible = true
	cinematic_bg.scale = Vector2.ONE
	cinematic_bg.position = Vector2.ZERO
	cinematic_bg.rotation = 0.0
	cinematic_bg.pivot_offset = Vector2.ZERO
	cinematic_bg.modulate = Color.WHITE
	cinematic_bg.self_modulate = Color.WHITE
	cinematic_bg.material = null
	cinematic_bg.offset_left = 0.0
	cinematic_bg.offset_top = 0.0
	cinematic_bg.offset_right = 0.0
	cinematic_bg.offset_bottom = 0.0
func _make_operation_panel_floating() -> void:
	var operation_panel := _find_operation_panel()
	if operation_panel == null:
		return
	operation_panel.add_theme_stylebox_override("panel", _transparent_panel_style())
	operation_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := operation_panel.get_child(0) if operation_panel.get_child_count() > 0 else null
	if margin is MarginContainer:
		var margin_container := margin as MarginContainer
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_right", 0)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_bottom", 0)
func _hide_scene_art_overlay_ui() -> void:
	_hide_canvas_item(cinematic_mist)
	_hide_canvas_item(cinematic_fire)
	_hide_canvas_item(cinematic_dim)
	_hide_canvas_item(cinematic_focus)
	_hide_canvas_item(cinematic_master)
	_hide_canvas_item(cinematic_hero)
	_hide_canvas_item(world_map_layer)
	_hide_canvas_item(world_map_panel)
	_hide_canvas_item(focus_world_map_layer)
	_hide_canvas_item(focus_world_map_panel)
	_hide_canvas_item(focus_debug_layer)
	_hide_canvas_item(focus_debug_panel)
	if visual_debug_label != null:
		visual_debug_label.visible = false
		visual_debug_label.custom_minimum_size = Vector2.ZERO
func _hide_canvas_item(node: CanvasItem) -> void:
	if node == null:
		return
	node.visible = false
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.material = null
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.custom_minimum_size = Vector2.ZERO
func _transparent_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style
