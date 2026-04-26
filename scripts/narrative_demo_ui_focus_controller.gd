extends "res://scripts/narrative_demo_unified_controller.gd"

# UI focus layer:
# - Operation area shows only story text and actionable buttons.
# - Metadata moves into a top-right debug overlay.
# - Story and option text are enlarged for playtest readability.

const STORY_FONT_SIZE := 54
const OPTION_FONT_SIZE := 42
const DEBUG_FONT_SIZE := 13

var focus_debug_layer: Control
var focus_debug_panel: PanelContainer
var focus_debug_label: RichTextLabel

func _ready() -> void:
	super._ready()
	_ensure_focus_debug_panel()
	_apply_focus_ui()

func _process(delta: float) -> void:
	super._process(delta)
	_apply_focus_ui()

func _render() -> void:
	super._render()
	_apply_focus_ui()

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
	focus_debug_panel.anchor_left = 0.66
	focus_debug_panel.anchor_top = 0.025
	focus_debug_panel.anchor_right = 0.985
	focus_debug_panel.anchor_bottom = 0.34
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
	_ensure_focus_debug_panel()
	_hide_operation_metadata()
	_style_story_text()
	_style_action_buttons()
	_update_focus_debug_panel()

func _hide_operation_metadata() -> void:
	_hide_control(title_label)
	_hide_control(status_label)
	_hide_control(map_label)
	_hide_control(scene_label)
	_hide_control(vars_label)
	_hide_control(visual_label)
	_hide_control(visual_debug_label)
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
	if world_map_panel != null:
		world_map_panel.visible = false

func _hide_control(control: Control) -> void:
	if control == null:
		return
	control.visible = false
	control.custom_minimum_size = Vector2.ZERO
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _style_story_text() -> void:
	if body_label == null:
		return
	body_label.visible = true
	body_label.custom_minimum_size = Vector2(0, 140)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", STORY_FONT_SIZE)
	body_label.add_theme_font_size_override("bold_font_size", STORY_FONT_SIZE)
	body_label.add_theme_font_size_override("italics_font_size", STORY_FONT_SIZE)

func _style_action_buttons() -> void:
	if action_content != null:
		action_content.add_theme_constant_override("separation", 16)
	_style_button_box(combat_buttons_box)
	_style_button_box(choices_box)
	if action_scroll != null:
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		action_scroll.custom_minimum_size = Vector2(0, 190)

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
