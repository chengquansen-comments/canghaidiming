extends RefCounted

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

# Debug panel for the focused narrative UI.
#
# Requires owner:
# - focus_debug_layer / panel / label / foot_alignment_debug_button / focus_casefile_art
# - focus_flow_source, step_index, node_index, jun_gong, qing_wang, clues, last_hint
# - title_label / status_label / scene_label
# - _on_focus_foot_alignment_debug_pressed()
# - _foot_alignment_debug_enabled()
# - _safe_label_text(), _focus_current_node_data(), _current_node_id(), _flow_count()

var c

func _init(controller) -> void:
	c = controller


func apply_debug_visibility() -> void:
	var debug_visible: bool = NarrativeBattleContext.is_ui_debug_visible()
	if c.focus_debug_layer != null:
		c.focus_debug_layer.visible = debug_visible
	if c.focus_debug_panel != null:
		c.focus_debug_panel.visible = debug_visible
	if c.focus_casefile_art != null:
		c.focus_casefile_art.visible = debug_visible and c.focus_debug_panel != null and c.focus_debug_panel.visible


func ensure_debug_panel() -> void:
	if c.focus_debug_layer != null:
		return
	c.focus_debug_layer = Control.new()
	c.focus_debug_layer.name = "NarrativeFocusDebugLayer"
	c.focus_debug_layer.anchor_left = 0.0
	c.focus_debug_layer.anchor_top = 0.0
	c.focus_debug_layer.anchor_right = 1.0
	c.focus_debug_layer.anchor_bottom = 1.0
	c.focus_debug_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	c.focus_debug_layer.z_index = 120
	c.focus_debug_layer.z_as_relative = false
	c.add_child(c.focus_debug_layer)

	c.focus_debug_panel = PanelContainer.new()
	c.focus_debug_panel.name = "NarrativeFocusDebugPanel"
	c.focus_debug_panel.anchor_left = 0.68
	c.focus_debug_panel.anchor_top = 0.225
	c.focus_debug_panel.anchor_right = 0.985
	c.focus_debug_panel.anchor_bottom = 0.56
	c.focus_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	c.focus_debug_panel.z_index = 121
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.022, 0.018, 0.78)
	style.border_color = Color(0.78, 0.62, 0.36, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	c.focus_debug_panel.add_theme_stylebox_override("panel", style)
	c.focus_debug_layer.add_child(c.focus_debug_panel)

	var debug_root := VBoxContainer.new()
	debug_root.name = "NarrativeFocusDebugRoot"
	debug_root.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_root.add_theme_constant_override("separation", 8)
	c.focus_debug_panel.add_child(debug_root)

	c.focus_foot_alignment_debug_button = Button.new()
	c.focus_foot_alignment_debug_button.name = "FootAlignmentDebugToggle"
	c.focus_foot_alignment_debug_button.custom_minimum_size = Vector2(0, 34)
	c.focus_foot_alignment_debug_button.focus_mode = Control.FOCUS_NONE
	c.focus_foot_alignment_debug_button.pressed.connect(c._on_focus_foot_alignment_debug_pressed)
	debug_root.add_child(c.focus_foot_alignment_debug_button)

	c.focus_debug_label = RichTextLabel.new()
	c.focus_debug_label.name = "NarrativeFocusDebugText"
	c.focus_debug_label.bbcode_enabled = true
	c.focus_debug_label.fit_content = false
	c.focus_debug_label.scroll_active = true
	c.focus_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_debug_label.add_theme_font_size_override("normal_font_size", c.DEBUG_FONT_SIZE)
	c.focus_debug_label.add_theme_font_size_override("bold_font_size", c.DEBUG_FONT_SIZE)
	c.focus_debug_label.add_theme_color_override("default_color", Color("f0dfb8"))
	debug_root.add_child(c.focus_debug_label)
	apply_debug_visibility()


func update_debug_panel() -> void:
	if c.focus_debug_label == null:
		return
	if c.focus_foot_alignment_debug_button != null:
		c.focus_foot_alignment_debug_button.text = "脚点辅助定位线：%s" % ("开" if c._foot_alignment_debug_enabled() else "关")
	c.focus_debug_label.text = debug_text()


func debug_text() -> String:
	var title_text := ""
	var node_id := "prologue"
	var column_text := "序章"
	var type_text := ""
	var scene_text := ""
	if c.in_prologue:
		title_text = c._safe_label_text(c.title_label, "序章")
		node_id = "prologue_step_%d" % c.step_index
		type_text = c._safe_label_text(c.status_label, "")
		scene_text = c._safe_label_text(c.scene_label, "")
	else:
		var node: Dictionary = c._focus_current_node_data()
		title_text = str(node.get("title", c._safe_label_text(c.title_label, "")))
		node_id = str(node.get("id", c._current_node_id()))
		column_text = str(node.get("column", ""))
		type_text = str(node.get("type", ""))
		scene_text = str(node.get("scene", c._safe_label_text(c.scene_label, "")))
	var profile: String = NarrativeBattleContext.player_profile_debug_text()
	if profile.is_empty():
		profile = "未初始化"
	var lines: Array[String] = []
	lines.append("[b]DEBUG[/b]  [color=#9cc7ff]F10隐藏/显示[/color]")
	lines.append("标题：%s" % title_text)
	lines.append("节点：%s" % node_id)
	lines.append("分类：%s / %s" % [column_text, type_text])
	lines.append("索引：step=%d / node=%d" % [c.step_index, c.node_index])
	lines.append("流程源：%s" % c.focus_flow_source)
	lines.append("流程数：%d" % c._flow_count())
	lines.append("变量：军功 %d / 清望 %d / 旧案 %d" % [c.jun_gong, c.qing_wang, c.clues])
	lines.append("脚点辅助定位线：%s" % ("开" if c._foot_alignment_debug_enabled() else "关"))
	lines.append("职业：%s" % profile)
	lines.append("演出：%s" % c._current_node_id())
	if not c.last_hint.is_empty():
		lines.append("提示：%s" % c.last_hint.replace("\n", " / "))
	if not scene_text.is_empty():
		lines.append("场景：%s" % scene_text.replace("\n", " / "))
	return "\n".join(lines)
