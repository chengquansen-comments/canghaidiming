extends "res://scripts/narrative_demo_unified_controller.gd"

# UI focus layer:
# - Story text is displayed as a large caption at the bottom of the performance area.
# - Operation area shows only actionable buttons.
# - Metadata moves into a right-side debug overlay.
# - Narrative MVP flow is sourced from compiled data/narrative_mvp_nodes.json.
#   Hardcoded MVP_NODE_IDS is only a crash-safe fallback.
# - Top world map node panel remains visible; only operation-area map/debug controls are hidden.

const STORY_FONT_SIZE := 72
const OPTION_FONT_SIZE := 42
const DEBUG_FONT_SIZE := 13
const PERFORMANCE_CAPTION_TOP := 0.48
const PERFORMANCE_CAPTION_BOTTOM := 0.70
const OPERATION_TOP := 0.74

var focus_debug_layer: Control
var focus_debug_panel: PanelContainer
var focus_debug_label: RichTextLabel
var focus_story_layer: Control
var focus_story_panel: PanelContainer
var focus_story_label: RichTextLabel
var focus_flow_node_ids: Array = []
var focus_flow_loaded: bool = false
var focus_flow_source: String = "fallback"
var focus_world_map_layer: Control
var focus_world_map_panel: PanelContainer
var focus_world_map_status_label: Label
var focus_world_map_nodes_row: HBoxContainer

func _ready() -> void:
	super._ready()
	_add_world_map_layer()
	_ensure_focus_story_caption()
	_ensure_focus_debug_panel()
	_apply_focus_ui()

func _process(delta: float) -> void:
	super._process(delta)
	_apply_focus_ui()

func _render() -> void:
	super._render()
	_apply_focus_ui()

func _flow_node_ids() -> Array:
	if focus_flow_loaded:
		return focus_flow_node_ids
	focus_flow_loaded = true
	focus_flow_node_ids.clear()
	focus_flow_source = "fallback"
	_load_flow_from_compiled_data()
	if focus_flow_node_ids.is_empty():
		for node_id in MVP_NODE_IDS:
			focus_flow_node_ids.append(str(node_id))
	return focus_flow_node_ids

func _load_flow_from_compiled_data() -> void:
	if not narrative_mvp_data_loaded:
		return
	var ids = narrative_mvp_data.get("flow_node_ids", [])
	if not (ids is Array):
		return
	for node_id in ids:
		var clean_id := str(node_id).strip_edges()
		if not clean_id.is_empty():
			focus_flow_node_ids.append(clean_id)
	if not focus_flow_node_ids.is_empty():
		focus_flow_source = NARRATIVE_MVP_DATA_PATH

func _flow_count() -> int:
	return _flow_node_ids().size()

func _node_id_at(index: int) -> String:
	var ids := _flow_node_ids()
	if index >= 0 and index < ids.size():
		return str(ids[index])
	return ""

func _world_map_total_count() -> int:
	return _flow_count() + 1

func _add_world_map_layer() -> void:
	if focus_world_map_layer != null:
		return
	focus_world_map_layer = Control.new()
	focus_world_map_layer.name = "FocusWorldMapLayer"
	focus_world_map_layer.anchor_left = 0.0
	focus_world_map_layer.anchor_top = 0.0
	focus_world_map_layer.anchor_right = 1.0
	focus_world_map_layer.anchor_bottom = 0.33
	focus_world_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_world_map_layer.z_index = 60
	focus_world_map_layer.z_as_relative = false
	add_child(focus_world_map_layer)

	focus_world_map_panel = PanelContainer.new()
	focus_world_map_panel.name = "FocusWorldMapPanel"
	focus_world_map_panel.anchor_left = 0.055
	focus_world_map_panel.anchor_top = 0.035
	focus_world_map_panel.anchor_right = 0.945
	focus_world_map_panel.anchor_bottom = 0.205
	focus_world_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_world_map_panel.z_index = 61
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.030, 0.024, 0.66)
	style.border_color = Color(0.74, 0.60, 0.38, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	focus_world_map_panel.add_theme_stylebox_override("panel", style)
	focus_world_map_layer.add_child(focus_world_map_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_world_map_panel.add_child(root)

	focus_world_map_status_label = Label.new()
	focus_world_map_status_label.name = "FocusWorldMapStatusLabel"
	focus_world_map_status_label.add_theme_font_size_override("font_size", 14)
	focus_world_map_status_label.add_theme_color_override("font_color", Color("f0dfb8"))
	focus_world_map_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	focus_world_map_status_label.add_theme_constant_override("shadow_offset_x", 1)
	focus_world_map_status_label.add_theme_constant_override("shadow_offset_y", 1)
	focus_world_map_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(focus_world_map_status_label)

	focus_world_map_nodes_row = HBoxContainer.new()
	focus_world_map_nodes_row.name = "FocusWorldMapNodesRow"
	focus_world_map_nodes_row.add_theme_constant_override("separation", 5)
	focus_world_map_nodes_row.mouse_filter = Control.MOUSE_FILTER_PASS
	focus_world_map_nodes_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(focus_world_map_nodes_row)
	_refresh_world_map()

func _refresh_world_map() -> void:
	if focus_world_map_layer == null or focus_world_map_panel == null or focus_world_map_nodes_row == null:
		return
	var should_show := not in_prologue
	focus_world_map_layer.visible = should_show
	focus_world_map_panel.visible = should_show
	if not should_show:
		return
	if focus_world_map_status_label != null:
		focus_world_map_status_label.text = "海疆行军图｜当前：%s｜军功 %d｜清望 %d｜旧案 %d" % [_current_world_map_title(), jun_gong, qing_wang, clues]
	for child in focus_world_map_nodes_row.get_children():
		child.queue_free()
	for i in range(_world_map_total_count()):
		if i > 0:
			focus_world_map_nodes_row.add_child(_make_world_map_line(i))
		focus_world_map_nodes_row.add_child(_make_world_map_node_button(i))

func _show_world_map_ui() -> void:
	_refresh_world_map()

func _current_world_map_title() -> String:
	if in_prologue:
		return _prologue_map_title()
	var node: Dictionary = _node_data_at(node_index)
	return str(node.get("title", ""))

func _world_map_current_index() -> int:
	return 0 if in_prologue else node_index + 1

func _world_map_title_at(map_index: int) -> String:
	if map_index == 0:
		return _prologue_map_title()
	var node: Dictionary = _node_data_at(map_index - 1)
	return str(node.get("title", ""))

func _world_map_marker_for_index(index: int) -> String:
	var current := _world_map_current_index()
	if index == current:
		return "◆ 当前"
	if index < current:
		return "● 已过"
	if index == current + 1:
		return "◎ 可前往"
	return "○ 未开放"

func _make_world_map_line(index: int) -> Label:
	var line := Label.new()
	line.text = "━━"
	line.custom_minimum_size = Vector2(24, 34)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Color("c9a35b") if index <= _world_map_current_index() else Color(0.60, 0.55, 0.46, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _make_world_map_node_button(index: int) -> Button:
	var btn := Button.new()
	btn.text = "%s\n%s" % [_world_map_marker_for_index(index), _world_map_title_at(index)]
	btn.custom_minimum_size = Vector2(116, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = index > _world_map_current_index() + 1
	btn.pressed.connect(_on_world_map_node_pressed.bind(index))
	return btn

func _on_world_map_node_pressed(map_index: int) -> void:
	if map_index == 0:
		last_hint = "地图节点：序章。"
		_render()
		return
	_on_map_node_pressed(map_index - 1)

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
	focus_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_panel.z_index = 91
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	focus_story_panel.add_theme_stylebox_override("panel", style)
	focus_story_layer.add_child(focus_story_panel)

	focus_story_label = RichTextLabel.new()
	focus_story_label.name = "NarrativePerformanceCaptionText"
	focus_story_label.bbcode_enabled = true
	focus_story_label.fit_content = false
	focus_story_label.scroll_active = false
	focus_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_label.add_theme_font_size_override("normal_font_size", STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("bold_font_size", STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("italics_font_size", STORY_FONT_SIZE)
	focus_story_label.add_theme_color_override("default_color", Color("f6ead2"))
	focus_story_panel.add_child(focus_story_label)

func _update_focus_story_caption() -> void:
	if focus_story_label == null:
		return
	var story_text := ""
	if body_label != null:
		story_text = body_label.text.strip_edges()
	focus_story_panel.visible = not story_text.is_empty()
	focus_story_label.text = "[center]%s[/center]" % story_text

func _battle_growth_reward_for_source(source_index: int) -> Dictionary:
	if source_index < 0 or source_index >= _flow_count():
		return {"hp_gain": 0, "posture_gain": 0, "martial_gain": 0, "heal_full": false}
	var node: Dictionary = _node_data_at(source_index)
	var combat := _node_level_combat(node)
	var encounter_id := str(combat.get("encounter_id", ""))
	if encounter_id.is_empty() and str(node.get("id", "")) == BOSS_NODE_ID:
		encounter_id = BOSS_ENCOUNTER_ID
	if has_method("_formal_reward_for_encounter"):
		return _formal_reward_for_encounter(encounter_id, str(node.get("type", "")))
	return {"hp_gain": 2, "posture_gain": 0, "martial_gain": 1, "heal_full": true}

func _consume_battle_result_if_needed() -> void:
	if not NarrativeBattleContext.has_result():
		return
	var source_id: String = NarrativeBattleContext.source_node_id
	var result: String = NarrativeBattleContext.last_result
	if source_id == "prologue_master_rescue":
		in_prologue = true
		if result == "win":
			var pending_choice := _load_pending_choice()
			var effects := _choice_effects(pending_choice)
			_apply_canonical_effects(effects)
			step_index = PROLOGUE_AFTER_MASTER_BATTLE_STEP
			prologue_sentence_index = 0
			prologue_result_sentence_index = 0
			showing_prologue_choice_result = false
			prologue_choice_result_text = ""
			prologue_choice_result_delta_text = ""
			last_hint = ""
		else:
			step_index = PROLOGUE_MASTER_RESCUE_STEP
			prologue_sentence_index = _prologue_story_segments().size() - 1
			last_hint = "序章战斗返回：当前 Demo 按师父救场继续推进。"
		NarrativeBattleContext.clear()
		_clear_pending_choice()
		return
	for i in range(_flow_count()):
		if _node_id_at(i) == source_id:
			node_index = i
			in_prologue = false
			break
	if result == "win":
		_apply_battle_growth(node_index)
		if source_id == BOSS_NODE_ID:
			boss_battle_completed = true
			showing_choice_result = false
			choice_result_text = ""
			choice_result_delta_text = ""
			choice_result_sentence_index = 0
			last_hint = "首领倒下。现在决定这场战斗留下什么。"
		else:
			var pending_choice := _load_pending_choice()
			if pending_choice.is_empty():
				last_hint = "战斗胜利：未找到待结算选择，暂不推进。"
			else:
				var effects := _choice_effects(pending_choice)
				_apply_canonical_effects(effects)
				choice_result_text = str(pending_choice.get("result", "战斗胜利。"))
				choice_result_delta_text = ""
				choice_result_sentence_index = 0
				showing_choice_result = true
				last_hint = ""
	elif result == "lose":
		last_hint = "战斗失败：已返回剧情。当前暂不扣除资源，可重新选择。"
		showing_choice_result = false
	elif result == "draw":
		last_hint = "战斗同归于尽：已返回剧情。线索保留，可重新选择。"
		showing_choice_result = false
	else:
		last_hint = "战斗结果未知：已返回剧情。"
	NarrativeBattleContext.clear()
	_clear_pending_choice()
	_clear_pending_boss_node()
	node_sentence_index = _node_story_segments(_node_data_at(node_index)).size() - 1

func _on_continue_after_choice_result() -> void:
	if not _is_choice_result_complete():
		choice_result_sentence_index += 1
		_render()
		return
	showing_choice_result = false
	choice_result_text = ""
	choice_result_delta_text = ""
	choice_result_sentence_index = 0
	if _node_id_at(node_index) == BOSS_NODE_ID:
		boss_battle_completed = false
	if node_index < _flow_count() - 1:
		_advance_to_node(node_index + 1, "")
	else:
		_render_ending()

func _advance_to_node(target_index: int, hint: String = "") -> void:
	last_hint = hint
	node_sentence_index = 0
	if target_index >= _flow_count():
		_render_ending()
		return
	node_index = target_index
	_render()

func _ensure_focus_debug_panel() -> void:
	if focus_debug_layer != null:
		return
	focus_debug_layer = Control.new()
	focus_debug_layer.name = "NarrativeFocusDebugLayer"
	focus_debug_layer.anchor_left = 0.0
	focus_debug_layer.anchor_top = 0.0
	focus_debug_layer.anchor_right = 1.0
	focus_debug_layer.anchor_bottom = 1.0
	focus_debug_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_debug_layer.z_index = 120
	focus_debug_layer.z_as_relative = false
	add_child(focus_debug_layer)

	focus_debug_panel = PanelContainer.new()
	focus_debug_panel.name = "NarrativeFocusDebugPanel"
	focus_debug_panel.anchor_left = 0.68
	focus_debug_panel.anchor_top = 0.225
	focus_debug_panel.anchor_right = 0.985
	focus_debug_panel.anchor_bottom = 0.56
	focus_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_debug_panel.z_index = 121
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.022, 0.018, 0.78)
	style.border_color = Color(0.78, 0.62, 0.36, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	focus_debug_panel.add_theme_stylebox_override("panel", style)
	focus_debug_layer.add_child(focus_debug_panel)

	focus_debug_label = RichTextLabel.new()
	focus_debug_label.name = "NarrativeFocusDebugText"
	focus_debug_label.bbcode_enabled = true
	focus_debug_label.fit_content = false
	focus_debug_label.scroll_active = true
	focus_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_debug_label.add_theme_font_size_override("normal_font_size", DEBUG_FONT_SIZE)
	focus_debug_label.add_theme_font_size_override("bold_font_size", DEBUG_FONT_SIZE)
	focus_debug_label.add_theme_color_override("default_color", Color("f0dfb8"))
	focus_debug_panel.add_child(focus_debug_label)

func _apply_focus_ui() -> void:
	_ensure_focus_story_caption()
	_ensure_focus_debug_panel()
	_update_focus_story_caption()
	_hide_operation_metadata()
	_apply_operation_only_choice_layout()
	_style_action_buttons()
	_refresh_world_map()
	_update_focus_debug_panel()

func _hide_operation_metadata() -> void:
	_hide_control(title_label)
	_hide_control(status_label)
	_hide_control(map_label)
	_hide_control(scene_label)
	_hide_control(vars_label)
	_hide_control(visual_label)
	_hide_control(visual_debug_label)
	_hide_control(body_label)
	if visual_texture != null:
		visual_texture.texture = null
		_hide_control(visual_texture)
	if map_buttons_box != null:
		map_buttons_box.visible = false
		map_buttons_box.custom_minimum_size = Vector2.ZERO
		for child in map_buttons_box.get_children():
			child.queue_free()
	_hide_section_titles()
	_hide_placeholder_labels(combat_buttons_box)
	_hide_placeholder_labels(choices_box)

func _hide_control(control: Control) -> void:
	if control == null:
		return
	control.visible = false
	control.custom_minimum_size = Vector2.ZERO
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _apply_operation_only_choice_layout() -> void:
	var operation_panel := _find_operation_panel()
	if operation_panel != null:
		operation_panel.anchor_left = 0.04
		operation_panel.anchor_top = OPERATION_TOP
		operation_panel.anchor_right = 0.96
		operation_panel.anchor_bottom = 0.985
		operation_panel.offset_left = 0
		operation_panel.offset_top = 0
		operation_panel.offset_right = 0
		operation_panel.offset_bottom = 0
	if action_scroll != null:
		action_scroll.visible = true
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		action_scroll.custom_minimum_size = Vector2(0, 170)
	if action_content != null:
		action_content.add_theme_constant_override("separation", 16)

func _style_action_buttons() -> void:
	_style_button_box(combat_buttons_box)
	_style_button_box(choices_box)

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
			btn.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
		elif child is Label:
			_hide_control(child as Control)

func _hide_section_titles() -> void:
	if action_content == null:
		return
	for child in action_content.get_children():
		if child is Label:
			_hide_control(child as Control)

func _hide_placeholder_labels(box: VBoxContainer) -> void:
	if box == null:
		return
	for child in box.get_children():
		if child is Label:
			_hide_control(child as Control)

func _update_focus_debug_panel() -> void:
	if focus_debug_label == null:
		return
	focus_debug_label.text = _focus_debug_text()

func _focus_debug_text() -> String:
	var title_text := ""
	var node_id := "prologue"
	var column_text := "序章"
	var type_text := ""
	var scene_text := ""
	if in_prologue:
		title_text = _safe_label_text(title_label, "序章")
		node_id = "prologue_step_%d" % step_index
		type_text = _safe_label_text(status_label, "")
		scene_text = _safe_label_text(scene_label, "")
	else:
		var node := _focus_current_node_data()
		title_text = str(node.get("title", _safe_label_text(title_label, "")))
		node_id = str(node.get("id", _current_node_id()))
		column_text = str(node.get("column", ""))
		type_text = str(node.get("type", ""))
		scene_text = str(node.get("scene", _safe_label_text(scene_label, "")))
	var profile := NarrativeBattleContext.player_profile_debug_text()
	if profile.is_empty():
		profile = "未初始化"
	var lines: Array[String] = []
	lines.append("[b]DEBUG[/b]")
	lines.append("标题：%s" % title_text)
	lines.append("节点：%s" % node_id)
	lines.append("分类：%s / %s" % [column_text, type_text])
	lines.append("索引：step=%d / node=%d" % [step_index, node_index])
	lines.append("流程源：%s" % focus_flow_source)
	lines.append("流程数：%d" % _flow_count())
	lines.append("变量：军功 %d / 清望 %d / 旧案 %d" % [jun_gong, qing_wang, clues])
	lines.append("职业：%s" % profile)
	lines.append("演出：%s" % _current_node_id())
	if not last_hint.is_empty():
		lines.append("提示：%s" % last_hint.replace("\n", " / "))
	if not scene_text.is_empty():
		lines.append("场景：%s" % scene_text.replace("\n", " / "))
	return "\n".join(lines)

func _focus_current_node_data() -> Dictionary:
	if has_method("_node_data_at"):
		var variant = call("_node_data_at", node_index)
		if variant is Dictionary:
			return variant
	if node_index >= 0 and node_index < NODES.size():
		return NODES[node_index]
	return {}

func _safe_label_text(label: Label, fallback: String) -> String:
	if label == null:
		return fallback
	var text := label.text.strip_edges()
	return fallback if text.is_empty() else text

func _find_operation_panel() -> PanelContainer:
	for child in get_children():
		if child is PanelContainer:
			return child as PanelContainer
	return null
