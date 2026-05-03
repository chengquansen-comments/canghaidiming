extends "res://scripts/narrative_demo_ui_focus_controller.gd"

const StrategicMapGenerator := preload("res://scripts/strategic_map_generator.gd")
const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const StrategicNetworkMapGenerator := preload("res://scripts/strategic_network_map_generator.gd")
const StrategicNetworkMapView := preload("res://scripts/strategic_network_map_view.gd")
const STRATEGIC_ENTRY_NODE_ID := "world_map_entry"
const STRATEGIC_FINAL_BOSS_SOURCE_ID := "strategic_final_boss"
const NETWORK_FINAL_BOSS_ENCOUNTER_ID := "enc_boss_ext_wakou_leader"
const NETWORK_FINAL_BOSS_BATTLE_ID := "boss_ext_wakou_leader"
const NETWORK_COMBAT_POOL_FALLBACK := {
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

# Final UI tuning layer.
# Keeps narrative presentation simple: static scene art + caption + bottom floating choices.
# Motion/effects are disabled at the cinematic controller source; this layer only
# applies layout polish and hides optional debug/map UI.

const TUNED_STORY_FONT_SIZE := 72
const TUNED_OPTION_FONT_SIZE := 25
const TUNED_CAPTION_OFFSET_Y := 30

var strategic_config: Dictionary = {}
var strategic_state: Dictionary = StrategicMapState.default_state()
var pending_strategic_ending_render := false
var pending_strategic_card_node: Dictionary = {}
var pending_strategic_card_choices: Array[String] = []
var selected_strategic_card_reward := ""
var network_map_view: Control = null
var network_overlay_layer: Control = null
var network_overlay_panel: PanelContainer = null
var network_map_container: VBoxContainer = null
var network_preview_container: VBoxContainer = null
var network_footer_container: HBoxContainer = null

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
	if network_overlay_layer != null:
		network_overlay_layer.visible = false
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
			var boss: Dictionary = strategic_state.get("final_boss", {})
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
		var graph: Dictionary = strategic_state.get("network_map", {})
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

func _load_strategic_map_config() -> void:
	strategic_config = StrategicMapGenerator.load_config()

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
	var owned_card_ids: Array[String] = []
	if role == "blademaster":
		owned_card_ids = [
			"blade_press_break",
			"blade_press_break",
			"blade_hook_pull",
			"blade_hook_pull",
			"blade_body_press",
			"blade_body_press",
			"reward_guard",
			"reward_guard",
		]
	else:
		owned_card_ids = [
			"spear_step_thrust",
			"spear_step_thrust",
			"spear_retreat_sting",
			"spear_retreat_sting",
			"reward_push",
			"reward_push",
			"reward_guard",
			"reward_guard",
		]
	var selected_loadout_ids := owned_card_ids.duplicate()
	NarrativeBattleContext.set_player_profile({
		"role": role,
		"career": "调试武生",
		"weapon": "长枪" if role == "spearman" else "腰刀",
		"martial_level": martial_level,
		"max_hp": 32,
		"hp": 32,
		"max_posture": 10,
		"posture": 5,
		"qinggong": 1,
		"owned_card_ids": owned_card_ids,
		"selected_loadout_ids": selected_loadout_ids,
		"deck_slots": [],
		"active_deck_index": 0,
		"debug_profile": true,
	})

func _start_strategic_map(hint: String = "") -> void:
	if strategic_config.is_empty():
		last_hint = "大势图配置缺失，暂按线性节点继续。"
		super._advance_to_node(node_index + 1, last_hint)
		return
	var base := StrategicMapState.default_state()
	base["active"] = true
	base["seed"] = 1701 + jun_gong * 17 + qing_wang * 31 + clues * 43
	base["military_merit"] = jun_gong
	base["clean_reputation"] = qing_wang
	base["case_clues"] = clues
	var profile := NarrativeBattleContext.get_player_profile()
	base["martial_level"] = int(profile.get("martial_level", 1))
	base = StrategicMapState.sync_card_state_from_profile(base, profile)
	base["current_map"] = StrategicMapGenerator.generate_map(strategic_config, base, int(base["seed"]))
	base["network_map"] = StrategicNetworkMapGenerator.generate_network_map(strategic_config, base, int(base["seed"]))
	var network_map: Dictionary = base.get("network_map", {})
	base["selected_node_id"] = str(network_map.get("selected_node_id", ""))
	base["available_node_ids"] = (network_map.get("available_node_ids", []) as Array).duplicate(true)
	base["completed_node_ids"] = (network_map.get("completed_node_ids", []) as Array).duplicate(true)
	base["current_node_id"] = str(network_map.get("current_node_id", ""))
	base["pending_map_node_id"] = str(network_map.get("pending_map_node_id", ""))
	base["pending_result_text"] = str(network_map.get("pending_result_text", ""))
	base["pending_effects"] = (network_map.get("pending_effects", {}) as Dictionary).duplicate(true)
	print(StrategicNetworkMapGenerator.summarize_network_map(network_map))
	strategic_state = base
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

func _render_strategic_map() -> void:
	var graph_variant = strategic_state.get("network_map", {})
	if graph_variant is Dictionary and not (graph_variant as Dictionary).is_empty():
		_render_network_strategic_map(graph_variant as Dictionary)
		return
	_render_legacy_strategic_map()

func _render_legacy_strategic_map() -> void:
	_refresh_current_strategic_layer()
	var map_data: Dictionary = strategic_state.get("current_map", {})
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var region := StrategicMapGenerator.current_region(map_data, region_index)
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	if region.is_empty() or layer.is_empty():
		_prepare_strategic_final_gate()
		return
	title_label.text = "海疆大势图"
	status_label.text = "%s｜第 %d 层" % [str(region.get("region_title", "海疆")), layer_index + 1]
	map_label.text = _strategic_progress_text(map_data)
	scene_label.text = _format_scene_text("军情、海防与旧案线索被摊在同一张图上。")
	_render_visual("res://assets/pixel_battle/backgrounds/map_march_coast.png", "海疆大势图")
	body_label.text = "你不再只沿着一条案线走。\n\n每一步只看四件事：军功、清望、旧案、武境。"
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % last_hint
	vars_label.text = StrategicMapState.summary_text(strategic_state)
	_add_placeholder(map_buttons_box, "每层三选一。选中后应用收益；战斗节点会跳转 MainVisual。")
	_add_placeholder(combat_buttons_box, "当前层候选节点")
	var choices: Array = layer.get("choices", [])
	for i in range(choices.size()):
		if choices[i] is Dictionary:
			_add_strategic_choice_button(choices[i] as Dictionary, i)

func _render_network_strategic_map(graph: Dictionary) -> void:
	_ensure_network_overlay_layer()
	network_overlay_layer.visible = true
	_clear_network_overlay_dynamic()
	_ensure_network_selected_node(graph)
	strategic_state["network_map"] = graph
	title_label.text = "海疆大势图"
	status_label.text = "完整网络图｜第 %d / %d 层" % [int(graph.get("current_layer", 0)) + 1, int(graph.get("layer_count", 10))]
	map_label.text = _network_progress_text(graph)
	body_label.text = ""
	vars_label.text = _network_state_summary_text()
	if bool(graph.get("map_complete", false)) or not _network_has_available_node(graph):
		_render_network_overlay_complete(graph)
		return
	_render_network_overlay_map_view(graph)
	_render_network_overlay_preview_panel(graph)
	_render_network_overlay_footer(graph)

func _render_network_map_view(graph: Dictionary) -> void:
	network_map_view = StrategicNetworkMapView.new()
	network_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(network_map_view as Control).custom_minimum_size = Vector2(940, 460)
	network_map_view.set_graph(graph, str(graph.get("selected_node_id", "")))
	network_map_view.node_clicked.connect(_on_network_node_clicked)
	map_buttons_box.add_child(network_map_view)

func _on_network_node_clicked(map_graph_id: String) -> void:
	var graph_variant = strategic_state.get("network_map", {})
	if not (graph_variant is Dictionary):
		return
	var graph := graph_variant as Dictionary
	if graph.is_empty():
		return
	graph["selected_node_id"] = map_graph_id
	strategic_state["network_map"] = graph
	strategic_state["selected_node_id"] = map_graph_id
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

func _network_find_node(graph: Dictionary, map_graph_id: String) -> Dictionary:
	var nodes: Array = graph.get("nodes", [])
	for item in nodes:
		if item is Dictionary:
			var node := item as Dictionary
			if str(node.get("map_graph_id", "")) == map_graph_id:
				return node
	return {}

func _render_network_preview_panel(graph: Dictionary) -> void:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := _network_find_node(graph, selected_id)
	var confirm_meta := _network_confirm_meta(graph, node)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = Vector2(0, 300)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = _network_preview_text(graph)
	combat_buttons_box.add_child(label)
	var confirm := Button.new()
	confirm.text = "确认前往"
	confirm.disabled = not bool(confirm_meta.get("enabled", false))
	confirm.custom_minimum_size = Vector2(0, 58)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm_network_node)
	combat_buttons_box.add_child(confirm)

func _network_preview_text(graph: Dictionary) -> String:
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := _network_find_node(graph, selected_id)
	if node.is_empty():
		return "尚未选中节点。"
	var node_type := str(node.get("node_type", ""))
	var mark := _network_node_type_mark(node_type)
	var type_label := _network_node_type_label(node_type)
	var state_label := _network_state_label(str(node.get("state", "locked")))
	var text := ""
	text += "[b]【%s】%s[/b]\n" % [str(node.get("title", "")), mark]
	text += "类型：%s\n" % type_label
	text += "状态：%s\n\n" % state_label
	text += "主线：%s\n" % _network_line_label(str(node.get("primary_line", "")))
	text += "副线：%s\n\n" % _network_line_label(str(node.get("secondary_line", "")))
	text += "%s\n\n" % str(node.get("preview_text", ""))
	text += "[b]预期影响：[/b]\n%s\n\n" % _network_effects_preview_text(node.get("effects", {}))
	text += "[b]标签：[/b]\n%s\n\n" % _network_tags_text(node.get("tags", []))
	text += "[b]战斗：[/b]\n%s\n\n" % _network_combat_debug_text(node)
	var confirm_meta := _network_confirm_meta(graph, node)
	if bool(confirm_meta.get("enabled", false)):
		text += "[b]前往状态：[/b]\n可确认前往"
	else:
		text += "[b]前往状态：[/b]\n不可前往：%s" % str(confirm_meta.get("reason", "未解锁"))
	return text

func _network_confirm_meta(graph: Dictionary, node: Dictionary) -> Dictionary:
	return {
		"enabled": _network_selected_can_confirm(graph),
		"reason": _network_confirm_block_reason(node),
	}

func _confirm_network_node() -> void:
	var graph: Dictionary = strategic_state.get("network_map", {})
	if graph.is_empty():
		return
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := _network_find_node(graph, selected_id)
	if node.is_empty():
		last_hint = "未选中有效的大势图节点。"
		_render()
		return
	if not _network_selected_can_confirm(graph):
		last_hint = _network_confirm_block_reason(node)
		_render()
		return
	if _network_node_is_combat(node):
		_enter_network_combat_node(node)
		return
	_execute_network_non_combat_node(node)

func _execute_network_non_combat_node(node: Dictionary) -> void:
	var graph: Dictionary = strategic_state.get("network_map", {})
	if graph.is_empty():
		return
	var runtime_node := node.duplicate(true)
	if not runtime_node.has("node_id"):
		runtime_node["node_id"] = str(node.get("pool_node_id", node.get("map_graph_id", "")))
	_apply_strategic_node(runtime_node)
	_complete_network_node(graph, node)
	_refresh_network_node_states(graph)
	strategic_state["network_map"] = graph
	strategic_state["selected_node_id"] = str(graph.get("selected_node_id", ""))
	strategic_state["available_node_ids"] = (graph.get("available_node_ids", []) as Array).duplicate(true)
	strategic_state["completed_node_ids"] = (graph.get("completed_node_ids", []) as Array).duplicate(true)
	strategic_state["current_node_id"] = str(graph.get("current_node_id", ""))
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "你记下了这一处海疆线索。"
	last_hint = result_text
	_save_narrative_state_to_context()
	_render()

func _network_node_is_combat(node: Dictionary) -> bool:
	var node_type := str(node.get("node_type", ""))
	return node_type.begins_with("combat_") \
		or not str(node.get("combat_pool_id", "")).is_empty() \
		or not str(node.get("encounter_id", "")).is_empty() \
		or not str(node.get("battle_id", "")).is_empty()

func _network_combat_request(node: Dictionary) -> Dictionary:
	var encounter_id := str(node.get("encounter_id", ""))
	var battle_id := str(node.get("battle_id", ""))
	var combat_pool_id := str(node.get("combat_pool_id", ""))
	if encounter_id.is_empty() or battle_id.is_empty():
		if NETWORK_COMBAT_POOL_FALLBACK.has(combat_pool_id):
			var fallback: Dictionary = NETWORK_COMBAT_POOL_FALLBACK[combat_pool_id]
			encounter_id = str(fallback.get("encounter_id", ""))
			battle_id = str(fallback.get("battle_id", ""))
	if encounter_id.is_empty() or battle_id.is_empty():
		return {
			"enabled": false,
			"blocked_reason": "该 combat_pool 暂未接入战斗。"
		}
	return {
		"enabled": true,
		"encounter_id": encounter_id,
		"battle_id": battle_id,
		"override_player_profile": true,
		"combat_pool_id": combat_pool_id,
		"recommended_martial_min": int(node.get("recommended_martial_min", 0)),
		"recommended_martial_max": int(node.get("recommended_martial_max", 0)),
		"enemy_martial_level": int(node.get("enemy_martial_level", 0))
	}

func _enter_network_combat_node(node: Dictionary) -> void:
	var graph: Dictionary = strategic_state.get("network_map", {})
	if graph.is_empty():
		return
	var request := _network_combat_request(node)
	if not bool(request.get("enabled", false)):
		last_hint = str(request.get("blocked_reason", "该战斗节点暂未接入。"))
		_save_narrative_state_to_context()
		_render()
		return
	var node_id := str(node.get("map_graph_id", ""))
	graph["pending_map_node_id"] = node_id
	graph["pending_result_text"] = str(node.get("result_text", ""))
	graph["pending_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
	strategic_state["network_map"] = graph
	_sync_strategic_cards_to_context()
	_save_narrative_state_to_context()
	NarrativeBattleContext.set_request_from_combat(request, "map_" + node_id)
	get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")

func _network_node_can_confirm(node: Dictionary) -> bool:
	var state := str(node.get("state", "locked"))
	if not (state == "available" or state == "start"):
		return false
	if _network_node_is_combat(node):
		var request := _network_combat_request(node)
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
			if _network_node_is_combat(node):
				var request := _network_combat_request(node)
				if not bool(request.get("enabled", false)):
					return str(request.get("blocked_reason", "该 combat_pool 暂未接入战斗。"))
			return ""
	return "当前节点不可前往。"

func _network_valid_available_ids(graph: Dictionary, candidate_ids: Array) -> Array:
	var result: Array = []
	var completed: Array = graph.get("completed_node_ids", [])
	var nodes: Array = graph.get("nodes", [])
	var node_by_id: Dictionary = {}
	for item in nodes:
		if item is Dictionary:
			var node := item as Dictionary
			var id := str(node.get("map_graph_id", ""))
			if not id.is_empty():
				node_by_id[id] = node
	for item in candidate_ids:
		var node_id := str(item)
		if node_id.is_empty():
			continue
		if result.has(node_id):
			continue
		if completed.has(node_id):
			continue
		if not node_by_id.has(node_id):
			push_warning("network_map outgoing points to missing node: %s" % node_id)
			continue
		var node: Dictionary = node_by_id[node_id]
		var state := str(node.get("state", "locked"))
		if state == "completed" or state == "unreachable":
			continue
		result.append(node_id)
	return result

func _network_has_available_node(graph: Dictionary) -> bool:
	var available: Array = graph.get("available_node_ids", [])
	return not _network_valid_available_ids(graph, available).is_empty()

func _ensure_network_selected_node(graph: Dictionary) -> void:
	var available := _network_valid_available_ids(graph, graph.get("available_node_ids", []))
	graph["available_node_ids"] = available
	var selected_id := str(graph.get("selected_node_id", ""))
	var selected := _network_find_node(graph, selected_id)
	if not selected.is_empty() and available.has(selected_id):
		return
	if not available.is_empty():
		graph["selected_node_id"] = str(available[0])
	else:
		graph["selected_node_id"] = str(graph.get("current_node_id", ""))

func _network_selected_can_confirm(graph: Dictionary) -> bool:
	if bool(graph.get("map_complete", false)):
		return false
	var selected_id := str(graph.get("selected_node_id", ""))
	var node := _network_find_node(graph, selected_id)
	if node.is_empty():
		return false
	var available := _network_valid_available_ids(graph, graph.get("available_node_ids", []))
	if not available.has(selected_id):
		return false
	return _network_node_can_confirm(node)

func _complete_network_node(graph: Dictionary, node: Dictionary) -> void:
	var node_id := str(node.get("map_graph_id", ""))
	if node_id.is_empty():
		return
	var completed: Array = graph.get("completed_node_ids", [])
	if not completed.has(node_id):
		completed.append(node_id)
	var outgoing: Array = []
	for item in node.get("outgoing", []):
		var out_id := str(item)
		if not out_id.is_empty():
			outgoing.append(out_id)
	graph["completed_node_ids"] = completed
	graph["current_node_id"] = node_id
	graph["current_layer"] = int(node.get("layer", 0)) + 1
	var valid_outgoing := _network_valid_available_ids(graph, outgoing)
	graph["available_node_ids"] = valid_outgoing
	if not valid_outgoing.is_empty():
		graph["selected_node_id"] = str(valid_outgoing[0])
		graph["map_complete"] = false
	else:
		graph["selected_node_id"] = node_id
		graph["map_complete"] = true

func _refresh_network_node_states(graph: Dictionary) -> void:
	var completed: Array = graph.get("completed_node_ids", [])
	var available: Array = graph.get("available_node_ids", [])
	var current_layer := int(graph.get("current_layer", 0))
	var nodes: Array = graph.get("nodes", [])
	for i in range(nodes.size()):
		if not (nodes[i] is Dictionary):
			continue
		var node: Dictionary = nodes[i]
		var node_id := str(node.get("map_graph_id", ""))
		var layer := int(node.get("layer", 0))
		if completed.has(node_id):
			node["state"] = "completed"
		elif available.has(node_id):
			node["state"] = "available"
		elif layer < current_layer:
			node["state"] = "unreachable"
		elif layer == current_layer:
			node["state"] = "unreachable"
		else:
			node["state"] = "locked"
		nodes[i] = node
	graph["nodes"] = nodes

func _network_node_type_mark(node_type: String) -> String:
	match node_type:
		"military": return "令"
		"case", "investigation": return "案"
		"combat_common": return "战"
		"combat_elite": return "精"
		"folk", "reputation": return "民"
		"rest": return "息"
		"master": return "师"
		"old_item": return "物"
		"boss": return "首"
		"risk": return "险"
	return "?"

func _network_node_type_label(node_type: String) -> String:
	match node_type:
		"military": return "军令"
		"case": return "旧案"
		"investigation": return "调查"
		"combat_common": return "普通战斗"
		"combat_elite": return "精英战"
		"folk": return "民间"
		"reputation": return "清望"
		"rest": return "休整"
		"master": return "师父"
		"old_item": return "旧物"
		"boss": return "首领"
		"risk": return "风险"
	return node_type

func _network_state_label(state: String) -> String:
	match state:
		"available": return "当前可达"
		"locked": return "未解锁"
		"completed": return "已完成"
		"unreachable": return "当前路线不可达"
		"selected": return "已选中"
		"start": return "起点"
	return state

func _network_line_label(line_id: String) -> String:
	match line_id:
		"military_merit", "military": return "军功"
		"clean_reputation", "reputation": return "清望"
		"case_clues", "old_case", "case": return "旧案"
		"rival_gu_bond": return "顾承岳"
		"rival_shen_bond": return "沈照夜"
		"rival_qi_bond": return "戚衡"
		"soldier_trust": return "军心"
		"": return "无"
	return line_id

func _network_effects_preview_text(effects_variant) -> String:
	if not (effects_variant is Dictionary):
		return "无"
	var effects := effects_variant as Dictionary
	var parts: Array[String] = []
	var labels := {
		"military_merit": "军功",
		"clean_reputation": "清望",
		"case_clues": "旧案",
		"rival_gu_bond": "顾承岳",
		"rival_shen_bond": "沈照夜",
		"rival_qi_bond": "戚衡",
		"soldier_trust": "军心"
	}
	for key in labels.keys():
		var value := int(effects.get(key, 0))
		if value != 0:
			parts.append("%s %+d" % [str(labels[key]), value])
	if effects.has("career_choice"):
		parts.append("career_choice = %s（debug，不应出现在普通大地图节点）" % str(effects.get("career_choice", "")))
	var card_rewards := _card_reward_ids_from_effects(effects.get("card_rewards", []))
	if not card_rewards.is_empty():
		parts.append("招式 +%d" % card_rewards.size())
	if parts.is_empty():
		return "无"
	return "\n".join(parts)

func _network_tags_text(tags_variant) -> String:
	var tags: Array[String] = []
	if tags_variant is Array or tags_variant is PackedStringArray:
		for item in tags_variant:
			var tag := str(item).strip_edges()
			if not tag.is_empty():
				tags.append(tag)
	elif tags_variant is String:
		var raw := str(tags_variant)
		var split_char := "," if raw.find(",") >= 0 else ("|" if raw.find("|") >= 0 else ";")
		for part in raw.split(split_char, false):
			var tag := str(part).strip_edges()
			if not tag.is_empty():
				tags.append(tag)
	return ", ".join(tags) if not tags.is_empty() else "无"

func _network_combat_debug_text(node: Dictionary) -> String:
	var node_type := str(node.get("node_type", ""))
	var combat_pool_id := str(node.get("combat_pool_id", ""))
	var encounter_id := str(node.get("encounter_id", ""))
	var battle_id := str(node.get("battle_id", ""))
	if not node_type.begins_with("combat_") and combat_pool_id.is_empty() and encounter_id.is_empty():
		return "否"
	var lines: Array[String] = []
	lines.append("是")
	if not combat_pool_id.is_empty():
		lines.append("combat_pool_id = %s" % combat_pool_id)
	if not encounter_id.is_empty():
		lines.append("encounter_id = %s" % encounter_id)
	if not battle_id.is_empty():
		lines.append("battle_id = %s" % battle_id)
	var enemy_level := int(node.get("enemy_martial_level", 0))
	var rec_min := int(node.get("recommended_martial_min", 0))
	var rec_max := int(node.get("recommended_martial_max", 0))
	if enemy_level > 0:
		lines.append("enemy_martial_level = %d" % enemy_level)
	if rec_min > 0 or rec_max > 0:
		lines.append("recommended = %d-%d" % [rec_min, rec_max])
	var request := _network_combat_request(node)
	if not bool(request.get("enabled", false)):
		lines.append(str(request.get("blocked_reason", "该 combat_pool 暂未接入战斗。")))
	return "\n".join(lines)

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
	var node := _network_find_node(graph, selected_id)
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
	var graph: Dictionary = strategic_state.get("network_map", {})
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
	var node := _network_find_node(graph, pending_id)
	if node.is_empty():
		last_hint = "战斗返回：未找到大势图节点。"
		_clear_network_pending(graph)
		strategic_state["network_map"] = graph
		return
	if result != "win":
		last_hint = "战斗未胜：当前节点可重试。"
		_clear_network_pending(graph)
		strategic_state["network_map"] = graph
		return
	var runtime_node := node.duplicate(true)
	if not runtime_node.has("node_id"):
		runtime_node["node_id"] = str(node.get("pool_node_id", node.get("map_graph_id", "")))
	_apply_strategic_node(runtime_node)
	NarrativeBattleContext.apply_player_growth("battle_win", 0, 0, 0, true)
	_complete_network_node(graph, node)
	_refresh_network_node_states(graph)
	_clear_network_pending(graph)
	var result_text := str(node.get("result_text", ""))
	if result_text.is_empty():
		result_text = "战事暂歇，海风又压回岸边。"
	last_hint = result_text
	strategic_state["network_map"] = graph
	strategic_state["selected_node_id"] = str(graph.get("selected_node_id", ""))
	strategic_state["available_node_ids"] = (graph.get("available_node_ids", []) as Array).duplicate(true)
	strategic_state["completed_node_ids"] = (graph.get("completed_node_ids", []) as Array).duplicate(true)
	strategic_state["current_node_id"] = str(graph.get("current_node_id", ""))

func _clear_network_pending(graph: Dictionary) -> void:
	graph["pending_map_node_id"] = ""
	graph["pending_result_text"] = ""
	graph["pending_effects"] = {}

func _render_network_map_complete_panel(graph: Dictionary) -> void:
	_render_network_overlay_complete(graph)

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
	summary.text = _network_final_gate_text(graph)
	network_preview_container.add_child(summary)

	var boss_btn := Button.new()
	boss_btn.text = "进入临时终局战"
	boss_btn.custom_minimum_size = Vector2(0, 58)
	boss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_btn.pressed.connect(_on_network_final_boss_pressed)
	network_preview_container.add_child(boss_btn)
	_render_network_overlay_footer(graph)

func _network_final_gate_text(graph: Dictionary) -> String:
	var completed_count := (graph.get("completed_node_ids", []) as Array).size()
	var profile := NarrativeBattleContext.get_player_profile()
	var martial_level := int(profile.get("martial_level", strategic_state.get("martial_level", 1)))
	var lines: Array[String] = []
	lines.append("[b]海门收束[/b]")
	lines.append("")
	lines.append("海图上的线走到尽头。")
	lines.append("潮声压低，旧案、军功与人声都被推到最后一战前。")
	lines.append("")
	lines.append("[b]本局状态[/b]")
	lines.append("军功：%d" % int(strategic_state.get("military_merit", jun_gong)))
	lines.append("清望：%d" % int(strategic_state.get("clean_reputation", qing_wang)))
	lines.append("旧案：%d" % int(strategic_state.get("case_clues", clues)))
	lines.append("武境：%d" % martial_level)
	lines.append("已完成节点：%d" % completed_count)
	lines.append("")
	lines.append("[b]临时收束[/b]")
	lines.append("本轮暂不接 final_boss_rules，先使用倭寇首领战作为 final gate fallback。")
	return "\n".join(lines)

func _on_network_final_boss_pressed() -> void:
	var graph: Dictionary = strategic_state.get("network_map", {})
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

func _render_network_debug_buttons() -> void:
	var fallback := Button.new()
	fallback.text = "继续旧线性流程"
	fallback.custom_minimum_size = Vector2(0, 54)
	fallback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback.pressed.connect(_continue_legacy_linear_flow)
	choices_box.add_child(fallback)

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

func _refresh_current_strategic_layer() -> void:
	var map_data: Dictionary = strategic_state.get("current_map", {})
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	var martial_level := int(strategic_state.get("martial_level", 1))
	if int(layer.get("generated_for_martial_level", -1)) == martial_level:
		return
	var seed_value := int(strategic_state.get("seed", 1701)) + region_index * 101 + layer_index * 17 + martial_level * 1009
	var refreshed := StrategicMapGenerator.refresh_layer(strategic_config, map_data, strategic_state, region_index, layer_index, seed_value)
	if refreshed.is_empty():
		return
	var regions: Array = map_data.get("regions", [])
	if region_index < 0 or region_index >= regions.size() or not (regions[region_index] is Dictionary):
		return
	var region := regions[region_index] as Dictionary
	var layers: Array = region.get("layers", [])
	if layer_index < 0 or layer_index >= layers.size():
		return
	layers[layer_index] = refreshed
	region["layers"] = layers
	regions[region_index] = region
	map_data["regions"] = regions
	strategic_state["current_map"] = map_data
	_sync_world_map_runtime_state()

func _strategic_progress_text(map_data: Dictionary) -> String:
	var regions: Array = map_data.get("regions", [])
	var parts: Array[String] = []
	for i in range(regions.size()):
		if not (regions[i] is Dictionary):
			continue
		var region: Dictionary = regions[i]
		var marker := "●" if i < int(strategic_state.get("region_index", 0)) else ("◆" if i == int(strategic_state.get("region_index", 0)) else "○")
		parts.append("%s %s" % [marker, str(region.get("region_title", ""))])
	return " / ".join(parts)

func _add_strategic_choice_button(node: Dictionary, index: int) -> void:
	var effects: Dictionary = node.get("effects", {})
	var btn := Button.new()
	var scope_text := StrategicMapState.event_scope_text(node)
	var combat_text := _strategic_combat_pool_text(node)
	btn.text = "%s｜%s%s%s\n%s\n%s" % [
		str(node.get("title", "")),
		_strategic_type_label(str(node.get("node_type", ""))),
		"｜%s" % scope_text if not scope_text.is_empty() else "",
		"｜%s" % combat_text if not combat_text.is_empty() else "",
		str(node.get("preview_text", "")),
		_strategic_effects_text(effects),
	]
	btn.custom_minimum_size = Vector2(0, 76)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_strategic_choice.bind(index))
	choices_box.add_child(btn)

func _on_strategic_choice(index: int) -> void:
	var layer := StrategicMapGenerator.current_layer(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0)))
	var choices: Array = layer.get("choices", [])
	if index < 0 or index >= choices.size() or not (choices[index] is Dictionary):
		return
	var node := choices[index] as Dictionary
	if _strategic_node_triggers_combat(node):
		strategic_state["current_world_map_node_id"] = str(node.get("node_id", ""))
		strategic_state["current_world_map_node_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
		_store_pending_choice(str(node.get("node_id", "")), {
			"label": str(node.get("title", "")),
			"result": str(node.get("result_text", "")),
			"effects": node.get("effects", {}),
		})
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
	if result != "win":
		last_hint = "大势图战斗未胜：当前层暂不推进。"
		_clear_pending_choice()
		_sync_world_map_runtime_state()
		return
	var node := _find_strategic_node(source_id)
	if node.is_empty():
		last_hint = "大势图战斗胜利：未找到节点配置，暂不结算。"
		_clear_pending_choice()
		_sync_world_map_runtime_state()
		return
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
	var effects: Dictionary = node.get("effects", {})
	strategic_state = StrategicMapState.apply_effects(strategic_state, effects)
	_sync_strategic_cards_to_context()
	_sync_context_cards_to_strategic_state()
	jun_gong = int(strategic_state.get("military_merit", jun_gong))
	qing_wang = int(strategic_state.get("clean_reputation", qing_wang))
	clues = int(strategic_state.get("case_clues", clues))
	var selected: Array = strategic_state.get("selected_nodes", [])
	selected.append(str(node.get("node_id", "")))
	strategic_state["selected_nodes"] = selected
	var result_text := str(node.get("result_text", ""))
	strategic_state["last_node_result"] = result_text
	strategic_state["current_world_map_node_id"] = str(node.get("node_id", ""))
	strategic_state["current_world_map_node_effects"] = effects.duplicate(true)
	_sync_world_map_runtime_state()
	last_hint = result_text


func _strategic_card_reward_choices(node: Dictionary) -> Array[String]:
	var effects: Dictionary = node.get("effects", {})
	var ids := _card_reward_ids_from_effects(effects.get("card_rewards", []))
	if ids.is_empty():
		return []
	var owned := _card_reward_ids_from_effects(strategic_state.get("owned_card_ids", []))
	var fresh: Array[String] = []
	for card_id: String in ids:
		if not (card_id in owned):
			fresh.append(card_id)
	var candidates := fresh if not fresh.is_empty() else ids
	candidates.shuffle()
	return candidates.slice(0, mini(3, candidates.size()))


func _show_strategic_card_reward_choice(node: Dictionary, card_ids: Array[String]) -> void:
	pending_strategic_card_node = node.duplicate(true)
	pending_strategic_card_choices = card_ids.duplicate()
	selected_strategic_card_reward = ""
	_clear_dynamic_boxes()
	title_label.text = str(node.get("title", "得招"))
	status_label.text = "%s / 招式抉择" % _strategic_type_label(str(node.get("node_type", "")))
	map_label.text = _strategic_progress_text(strategic_state.get("current_map", {}))
	scene_label.text = _format_scene_text(str(node.get("preview_text", "")))
	_render_visual(str(node.get("visual_path", "")), str(node.get("title", "得招")))
	body_label.text = "%s\n\n选择 1 张新招式加入长期牌库，然后确认。" % str(node.get("result_text", "你得了一次整理招式的机会。"))
	vars_label.text = StrategicMapState.summary_text(strategic_state)
	_add_placeholder(map_buttons_box, "卡牌奖励不会自动发放，需先三选一。")
	_add_placeholder(combat_buttons_box, "非战斗节点")
	for card_id: String in pending_strategic_card_choices:
		var btn := Button.new()
		btn.text = _strategic_card_choice_text(card_id, false)
		btn.custom_minimum_size = Vector2(0, 76)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_select_strategic_card_reward.bind(card_id))
		choices_box.add_child(btn)
	var confirm := Button.new()
	confirm.name = "StrategicCardRewardConfirm"
	confirm.text = "确认"
	confirm.disabled = true
	confirm.custom_minimum_size = Vector2(0, 64)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm_strategic_card_reward)
	choices_box.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "返回本层选择"
	cancel.custom_minimum_size = Vector2(0, 54)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_cancel_strategic_card_reward)
	choices_box.add_child(cancel)
	BattleFontHelper.enforce(self)
	_apply_focus_ui()
	_hide_scene_art_overlay_nodes()


func _select_strategic_card_reward(card_id: String) -> void:
	selected_strategic_card_reward = card_id
	for child in choices_box.get_children():
		if child is Button:
			var btn := child as Button
			if btn.name == "StrategicCardRewardConfirm":
				btn.disabled = selected_strategic_card_reward.is_empty()
				continue
			if card_id in pending_strategic_card_choices:
				for choice_id: String in pending_strategic_card_choices:
					if btn.text.find(_strategic_card_label(choice_id)) >= 0:
						btn.text = _strategic_card_choice_text(choice_id, choice_id == card_id)
	body_label.text = "%s\n\n已选择：%s" % [str(pending_strategic_card_node.get("result_text", "")), _strategic_card_label(card_id)]


func _confirm_strategic_card_reward() -> void:
	if pending_strategic_card_node.is_empty() or selected_strategic_card_reward.is_empty():
		return
	var node := pending_strategic_card_node.duplicate(true)
	var effects: Dictionary = node.get("effects", {})
	effects["card_rewards"] = [selected_strategic_card_reward]
	node["effects"] = effects
	pending_strategic_card_node.clear()
	pending_strategic_card_choices.clear()
	selected_strategic_card_reward = ""
	_apply_strategic_node(node)
	_advance_strategic_cursor()
	_save_narrative_state_to_context()
	_render()


func _cancel_strategic_card_reward() -> void:
	pending_strategic_card_node.clear()
	pending_strategic_card_choices.clear()
	selected_strategic_card_reward = ""
	_render()


func _strategic_card_choice_text(card_id: String, selected: bool) -> String:
	var prefix := "✓ " if selected else ""
	return "%s%s\n%s" % [prefix, _strategic_card_label(card_id), _strategic_card_hint(card_id)]


func _strategic_card_label(card_id: String) -> String:
	match card_id:
		"reward_push": return "压线"
		"reward_pull": return "挂带"
		"reward_guard": return "铁壁"
		"blade_press_break": return "压刀破架"
		"blade_hook_pull": return "挂刀带步"
		"blade_body_press": return "贴身撞刀"
		"spear_retreat_sting": return "退枪留锋"
		"spear_step_thrust": return "顺步送枪"
	return card_id


func _strategic_card_hint(card_id: String) -> String:
	match card_id:
		"reward_push": return "控线，命中后击退敌人。"
		"reward_pull": return "拉扯，命中后拉近敌人。"
		"reward_guard": return "架势，获得高额格挡。"
		"blade_press_break": return "短兵破势，贴身压架。"
		"blade_hook_pull": return "短兵拉扯，调整距离。"
		"blade_body_press": return "极近破势，压短兵节奏。"
		"spear_retreat_sting": return "近身脱身刺，命中后后撤。"
		"spear_step_thrust": return "三格追击刺，命中后进身。"
	return "加入长期牌库。"

func _sync_context_cards_to_strategic_state() -> void:
	var profile := NarrativeBattleContext.get_player_profile()
	if profile.is_empty():
		return
	strategic_state = StrategicMapState.sync_card_state_from_profile(strategic_state, profile)

func _sync_strategic_cards_to_context() -> void:
	if not NarrativeBattleContext.has_player_profile():
		return
	NarrativeBattleContext.set_player_card_state(strategic_state.get("owned_card_ids", []), strategic_state.get("selected_loadout_ids", []), strategic_state.get("deck_slots", []), int(strategic_state.get("active_deck_index", 0)))

func _advance_strategic_cursor() -> void:
	var cursor := StrategicMapGenerator.advance_cursor(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0)))
	strategic_state["region_index"] = int(cursor.get("region_index", 0))
	strategic_state["layer_index"] = int(cursor.get("layer_index", 0))
	_sync_world_map_runtime_state()
	if StrategicMapGenerator.is_map_complete(strategic_state.get("current_map", {}), int(strategic_state.get("region_index", 0)), int(strategic_state.get("layer_index", 0))):
		if _base_ui_ready():
			_prepare_strategic_final_gate()
		else:
			strategic_state["final_boss"] = StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)

func _prepare_strategic_final_gate() -> void:
	var boss := StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
	strategic_state["final_boss"] = boss
	strategic_state["is_world_map_active"] = false
	_sync_world_map_runtime_state()
	if not _base_ui_ready():
		return
	title_label.text = "海门收束"
	status_label.text = str(boss.get("title", "终局门槛"))
	map_label.text = "大势图已走完：%d 个节点" % [(strategic_state.get("selected_nodes", []) as Array).size()]
	scene_label.text = _format_scene_text("海门风紧，所有线索都被推到最后一战前。")
	_render_visual("res://assets/pixel_battle/backgrounds/battle_bg_broken_ship.png", "海门收束")
	body_label.text = str(boss.get("intro_text", "倭患仍在海上。案卷仍少一页。"))
	if not last_hint.is_empty():
		body_label.text += "\n\n[i]%s[/i]" % last_hint
	vars_label.text = StrategicMapState.summary_text(strategic_state)
	_add_placeholder(map_buttons_box, "终局版本由军功、清望、旧案、武境共同决定。")
	_add_button(combat_buttons_box, "进入终局战：%s" % str(boss.get("title", "海门收束")), _on_strategic_final_boss)
	_add_placeholder(choices_box, "终局战胜利后进入对应结局。")

func _on_strategic_final_boss() -> void:
	var boss: Dictionary = strategic_state.get("final_boss", {})
	if boss.is_empty():
		boss = StrategicMapGenerator.select_final_boss(strategic_config, strategic_state)
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
	var map_data: Dictionary = strategic_state.get("current_map", {})
	var region_index := int(strategic_state.get("region_index", 0))
	var layer_index := int(strategic_state.get("layer_index", 0))
	var region := StrategicMapGenerator.current_region(map_data, region_index)
	var layer := StrategicMapGenerator.current_layer(map_data, region_index, layer_index)
	var generated_nodes: Array[String] = []
	var choices: Array = layer.get("choices", [])
	for choice_variant in choices:
		if choice_variant is Dictionary:
			generated_nodes.append(str((choice_variant as Dictionary).get("node_id", "")))
	strategic_state["current_region_id"] = str(region.get("region_id", ""))
	strategic_state["current_region_layer"] = layer_index + 1
	strategic_state["world_map_generated_nodes"] = generated_nodes
	strategic_state["world_map_completed_nodes"] = (strategic_state.get("selected_nodes", []) as Array).duplicate(true)
	strategic_state["is_world_map_active"] = bool(strategic_state.get("active", false))

func _ensure_network_map_for_state(warn_if_regenerated: bool = false) -> void:
	var map_variant = strategic_state.get("network_map", {})
	if map_variant is Dictionary and not (map_variant as Dictionary).is_empty():
		return
	var seed_value := int(strategic_state.get("seed", 1701))
	if warn_if_regenerated:
		push_warning("strategic_state.network_map missing during restore, regenerating from seed=%d" % seed_value)
	strategic_state["network_map"] = StrategicNetworkMapGenerator.generate_network_map(strategic_config, strategic_state, seed_value)
	var network_map: Dictionary = strategic_state.get("network_map", {})
	strategic_state["selected_node_id"] = str(network_map.get("selected_node_id", ""))
	strategic_state["available_node_ids"] = (network_map.get("available_node_ids", []) as Array).duplicate(true)
	strategic_state["completed_node_ids"] = (network_map.get("completed_node_ids", []) as Array).duplicate(true)
	strategic_state["current_node_id"] = str(network_map.get("current_node_id", ""))
	strategic_state["pending_map_node_id"] = str(network_map.get("pending_map_node_id", ""))
	strategic_state["pending_result_text"] = str(network_map.get("pending_result_text", ""))
	strategic_state["pending_effects"] = (network_map.get("pending_effects", {}) as Dictionary).duplicate(true)
	print(StrategicNetworkMapGenerator.summarize_network_map(network_map))

func _find_strategic_node(node_id: String) -> Dictionary:
	var node_pool: Array = strategic_config.get("node_pool", [])
	for item in node_pool:
		if item is Dictionary and str((item as Dictionary).get("node_id", "")) == node_id:
			return (item as Dictionary).duplicate(true)
	return {}

func _strategic_node_triggers_combat(node: Dictionary) -> bool:
	return str(node.get("node_type", "")).begins_with("combat_") and not str(node.get("encounter_id", "")).is_empty()

func _strategic_type_label(node_type: String) -> String:
	match node_type:
		"combat_common": return "普通战斗"
		"combat_elite": return "强敌"
		"military": return "军功"
		"case": return "旧案"
		"reputation": return "清望"
		"rest": return "休整"
		"risk": return "风险"
	return node_type

func _strategic_effects_text(effects: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		"military_merit": "军功",
		"clean_reputation": "清望",
		"case_clues": "旧案",
	}
	for key in labels.keys():
		var value := int(effects.get(key, 0))
		if value != 0:
			parts.append("%s %+d" % [str(labels[key]), value])
	var card_rewards := _card_reward_ids_from_effects(effects.get("card_rewards", []))
	if not card_rewards.is_empty():
		parts.append("招式 +%d" % card_rewards.size())
	return "收益：%s" % (" / ".join(parts) if not parts.is_empty() else "无")

func _card_reward_ids_from_effects(value) -> Array[String]:
	var ids: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var card_id := str(item)
			if not card_id.is_empty():
				ids.append(card_id)
	elif value is String:
		var card_id := str(value)
		if not card_id.is_empty():
			ids.append(card_id)
	return ids

func _strategic_combat_pool_text(node: Dictionary) -> String:
	if not str(node.get("node_type", "")).begins_with("combat_"):
		return ""
	var pool_id := str(node.get("combat_pool_id", ""))
	var recommended_min := int(node.get("recommended_martial_min", 0))
	var recommended_max := int(node.get("recommended_martial_max", 0))
	var enemy_martial := int(node.get("enemy_martial_level", 0))
	if pool_id.is_empty():
		return ""
	return "敌类%s 武境%d-%d 敌%d" % [pool_id, recommended_min, recommended_max, enemy_martial]

func _ending_data_for_flag(flag: String) -> Dictionary:
	match flag:
		"true_resolution":
			return {
				"id": "true_resolution",
				"title": "结局：海门真收束",
				"status": "海门真收束",
				"text": "堂上开卷。\n\n海门起风。\n\n这一次，军令、人声、旧案都没有退。",
				"feedback": "军功让你进堂，旧案让你说话，清望让别人敢信。"
			}
		"court_exposure":
			return {
				"id": "court_exposure",
				"title": "结局：堂审翻案",
				"status": "堂审翻案",
				"text": "案卷被迫摊开。\n\n堂外很静。\n\n你赢了一场堂审，却还要等人敢抬头。\n\n然而这就是事情的真相吗？",
				"feedback": "军功和旧案足以开卷，但清望不足时，真相仍显得孤。"
			}
		"reputation_redress":
			return {
				"id": "reputation_redress",
				"title": "结局：清望昭雪",
				"status": "清望昭雪",
				"text": "堂上无人开口。\n\n堂外，有人替你跪了一地。\n\n案卷终于不能只在灯下合上。\n\n然而这就是事情的真相吗？",
				"feedback": "清望让别人敢信你，旧案因此有了见光的缝。"
			}
		"military_reputation":
			return {
				"id": "military_reputation",
				"title": "结局：封海得众",
				"status": "封海得众",
				"text": "海口封住了。\n\n百姓没有散。\n\n你第一次觉得军令也能护住活人。\n\n然而这就是你想要的吗？",
				"feedback": "军功给你权力，清望让权力没有只剩冷铁。"
			}
		"private_truth":
			return {
				"id": "private_truth",
				"title": "结局：私查真相",
				"status": "私查真相",
				"text": "箭从岸上来。\n\n这一次，没有人替他灭口。\n\n师父站得很远。\n\n然而这就是事情的真相吗？",
				"feedback": "旧案让你说得出话，但没有足够军功时，真相仍难进堂。"
			}
		"military_promotion":
			return {
				"id": "military_promotion",
				"title": "结局：军功升迁",
				"status": "军功升迁",
				"text": "你升入卫中。\n\n旧案也封在卫中。\n\n潮声隔着官印，仍然很近。\n\n然而这就是你想要的吗？",
				"feedback": "军功让你进得了堂，也让堂门在你身后落锁。"
			}
		"isolated_evidence":
			return {
				"id": "isolated_evidence",
				"title": "结局：孤证难鸣",
				"status": "孤证难鸣",
				"text": "你知道箭从哪里来。\n\n纸也知道。\n\n可是堂上没有人接这句话。\n\n然而这就是事情的真相吗？",
				"feedback": "旧案足够深，但军功和清望都不足时，真相只能先活在你手里。"
			}
		"martial_survival":
			return {
				"id": "martial_survival",
				"title": "结局：武境破围",
				"status": "武境破围",
				"text": "你杀出海门。\n\n身后火起，堂上灯灭。\n\n旧案没有开卷，但没人再敢轻易灭你的口。\n\n然而这就是你想要的吗？",
				"feedback": "武境能让你活下来，却不能替你赢得堂口和人心。"
			}
		"surface_pirate":
			return {
				"id": "surface_pirate",
				"title": "结局：表层平倭",
				"status": "表层平倭",
				"text": "倭患平了。\n\n案卷仍少一页。\n\n师父没有看你。\n\n然而这就是你想要的吗？",
				"feedback": "表面的海寇被清掉了，旧案还在潮下。"
			}
	return super._ending_data_for_flag(flag)

func _ending_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for flag in [
		"true_resolution",
		"court_exposure",
		"reputation_redress",
		"military_reputation",
		"military_promotion",
		"private_truth",
		"isolated_evidence",
		"martial_survival",
		"surface_pirate",
	]:
		var ending := _ending_data_for_flag(flag)
		if not ending.is_empty():
			catalog.append(ending)
	return catalog

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
	operation_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
