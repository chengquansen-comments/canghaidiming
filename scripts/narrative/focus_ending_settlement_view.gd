extends RefCounted

# Ending settlement popup for the focused narrative UI.
#
# Requires owner:
# - ending_settlement_layer / panel / text / confirm
# - selected_ending_flag, jun_gong, qing_wang, clues
# - _ending_data(), _ending_catalog(), _on_ending_settlement_confirmed()

var c

func _init(controller) -> void:
	c = controller


func ensure_popup() -> void:
	if c.ending_settlement_layer != null:
		return
	c.ending_settlement_layer = Control.new()
	c.ending_settlement_layer.name = "EndingSettlementLayer"
	c.ending_settlement_layer.anchor_left = 0.0
	c.ending_settlement_layer.anchor_top = 0.0
	c.ending_settlement_layer.anchor_right = 1.0
	c.ending_settlement_layer.anchor_bottom = 1.0
	c.ending_settlement_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	c.ending_settlement_layer.z_index = 220
	c.ending_settlement_layer.z_as_relative = false
	c.ending_settlement_layer.visible = false
	c.add_child(c.ending_settlement_layer)

	var dim := ColorRect.new()
	dim.name = "EndingSettlementDim"
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	c.ending_settlement_layer.add_child(dim)

	c.ending_settlement_panel = PanelContainer.new()
	c.ending_settlement_panel.name = "EndingSettlementPanel"
	c.ending_settlement_panel.anchor_left = 0.18
	c.ending_settlement_panel.anchor_top = 0.12
	c.ending_settlement_panel.anchor_right = 0.82
	c.ending_settlement_panel.anchor_bottom = 0.86
	c.ending_settlement_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.047, 0.035, 0.96)
	style.border_color = Color(0.86, 0.68, 0.38, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 18
	c.ending_settlement_panel.add_theme_stylebox_override("panel", style)
	c.ending_settlement_layer.add_child(c.ending_settlement_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	c.ending_settlement_panel.add_child(layout)

	c.ending_settlement_text = RichTextLabel.new()
	c.ending_settlement_text.name = "EndingSettlementText"
	c.ending_settlement_text.bbcode_enabled = true
	c.ending_settlement_text.fit_content = false
	c.ending_settlement_text.scroll_active = true
	c.ending_settlement_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.ending_settlement_text.mouse_filter = Control.MOUSE_FILTER_STOP
	c.ending_settlement_text.add_theme_font_size_override("normal_font_size", 22)
	c.ending_settlement_text.add_theme_font_size_override("bold_font_size", 25)
	c.ending_settlement_text.add_theme_color_override("default_color", Color("f3e4c2"))
	layout.add_child(c.ending_settlement_text)

	c.ending_settlement_confirm = Button.new()
	c.ending_settlement_confirm.name = "EndingSettlementConfirm"
	c.ending_settlement_confirm.text = "确认"
	c.ending_settlement_confirm.custom_minimum_size = Vector2(0, 56)
	c.ending_settlement_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.ending_settlement_confirm.add_theme_font_size_override("font_size", 26)
	c.ending_settlement_confirm.pressed.connect(c._on_ending_settlement_confirmed)
	layout.add_child(c.ending_settlement_confirm)


func show_popup() -> void:
	ensure_popup()
	if c.ending_settlement_layer == null or c.ending_settlement_text == null:
		return
	c.ending_settlement_text.text = popup_text()
	c.ending_settlement_layer.visible = true
	if c.ending_settlement_confirm != null:
		c.ending_settlement_confirm.grab_focus()


func on_confirmed() -> void:
	if c.ending_settlement_layer != null:
		c.ending_settlement_layer.visible = false


func popup_text() -> String:
	var current: Dictionary = c._ending_data()
	var current_id := str(current.get("id", c.selected_ending_flag)).strip_edges()
	if current_id.is_empty():
		current_id = c.selected_ending_flag
	var lines: Array[String] = []
	lines.append("[center][b]结局结算[/b][/center]")
	lines.append("")
	lines.append("[b]本次结局：%s[/b]" % str(current.get("status", current.get("title", "结局"))))
	lines.append(str(current.get("text", "")).strip_edges())
	var feedback := str(current.get("feedback", "")).strip_edges()
	if not feedback.is_empty():
		lines.append("[color=#d9bd7a]%s[/color]" % feedback)
	lines.append("")
	lines.append("军功 %d / 清望 %d / 旧案线索 %d" % [c.jun_gong, c.qing_wang, c.clues])
	lines.append("")
	lines.append("[b]结局图鉴[/b]")
	var catalog: Array = c._ending_catalog()
	for ending_variant in catalog:
		if not (ending_variant is Dictionary):
			continue
		var ending := ending_variant as Dictionary
		var ending_id := str(ending.get("id", "")).strip_edges()
		var unlocked: bool = ending_id == current_id or (not c.selected_ending_flag.is_empty() and ending_id == c.selected_ending_flag)
		var state := "已解锁" if unlocked else "未解锁"
		var color := "#9fe0a2" if unlocked else "#8f8778"
		lines.append("")
		lines.append("[color=%s][b]%s｜%s[/b][/color]" % [color, state, str(ending.get("status", ending.get("title", ending_id)))])
		if unlocked:
			lines.append(str(ending.get("text", "")).strip_edges())
		else:
			lines.append("尚未在本次流程中达成。")
	return "\n".join(lines)
