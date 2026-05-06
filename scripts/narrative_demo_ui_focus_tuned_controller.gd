extends "res://scripts/narrative_demo_network_map_controller.gd"

# Final UI tuning layer.
# Keeps narrative presentation simple: static scene art + caption + bottom floating choices.
# Motion/effects are disabled at the cinematic controller source; this layer only
# applies layout polish and hides optional debug/map UI.

const TUNED_STORY_FONT_SIZE := 72
const TUNED_OPTION_FONT_SIZE := 25
const TUNED_CAPTION_OFFSET_Y := 30

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
