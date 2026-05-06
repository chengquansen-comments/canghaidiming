extends RefCounted

var c

func _init(controller) -> void:
	c = controller

func configure_responsive_bottom_layout() -> void:
	configure_bottom_root_bounds()
	configure_control_bar_priority()
	configure_hand_area_priority()
	configure_scrollable_detail_panels()
	configure_hand_button_sizes()

func configure_bottom_root_bounds() -> void:
	if c.bottom_backdrop != null:
		c.bottom_backdrop.anchor_left = 0.0
		c.bottom_backdrop.anchor_right = 1.0
		c.bottom_backdrop.anchor_top = 0.0
		c.bottom_backdrop.anchor_bottom = 1.0
		c.bottom_backdrop.offset_top = c.RESPONSIVE_BOTTOM_TOP - 10.0
		c.bottom_backdrop.offset_bottom = 0.0
	if c.bottom_root != null:
		c.bottom_root.offset_left = 20.0
		c.bottom_root.offset_right = -20.0
		c.bottom_root.offset_top = c.RESPONSIVE_BOTTOM_TOP
		c.bottom_root.offset_bottom = -c.RESPONSIVE_BOTTOM_MARGIN
		c.bottom_root.clip_contents = true
		c.bottom_root.add_theme_constant_override("separation", c.RESPONSIVE_BOTTOM_SEPARATION)
		c.bottom_root.size_flags_vertical = Control.SIZE_EXPAND_FILL

func configure_control_bar_priority() -> void:
	var control_bar := control_bar_node()
	if control_bar == null:
		return
	control_bar.custom_minimum_size = Vector2(0, c.RESPONSIVE_CONTROL_BAR_HEIGHT)
	control_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	control_bar.clip_contents = true
	if control_bar is BoxContainer:
		(control_bar as BoxContainer).add_theme_constant_override("separation", 8)

func configure_hand_area_priority() -> void:
	if c.hand_flow == null:
		return
	c.hand_flow.custom_minimum_size = Vector2(0, c.RESPONSIVE_HAND_HEIGHT)
	c.hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.hand_flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	c.hand_flow.clip_contents = true
	if c.hand_flow is BoxContainer:
		(c.hand_flow as BoxContainer).add_theme_constant_override("separation", 8)

func configure_scrollable_detail_panels() -> void:
	configure_detail_panel(c.card_detail_panel, c.card_detail_label)
	configure_detail_panel(c.effect_preview_panel, c.effect_preview_label)
	configure_detail_parent(c.card_detail_panel)
	configure_detail_parent(c.effect_preview_panel)

func configure_detail_panel(panel: PanelContainer, label: RichTextLabel) -> void:
	if panel != null:
		panel.custom_minimum_size = Vector2(0, c.RESPONSIVE_DETAIL_PANEL_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
	if label != null:
		label.fit_content = false
		label.scroll_active = true
		label.scroll_following = false
		label.clip_contents = true
		label.custom_minimum_size = Vector2(0, c.RESPONSIVE_DETAIL_LABEL_HEIGHT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL

func configure_detail_parent(panel: PanelContainer) -> void:
	if panel == null:
		return
	var parent := panel.get_parent()
	if parent == null or parent == c.bottom_root:
		return
	if parent is Control:
		var parent_control := parent as Control
		parent_control.custom_minimum_size = Vector2(0, c.RESPONSIVE_DETAIL_PANEL_HEIGHT)
		parent_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent_control.clip_contents = true
		if parent_control is BoxContainer:
			(parent_control as BoxContainer).add_theme_constant_override("separation", 8)

func configure_hand_button_sizes() -> void:
	if c.hand_flow == null:
		return
	for child in c.hand_flow.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = c.RESPONSIVE_CARD_SIZE
			button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			button.clip_text = true
			button.clip_contents = true
			button.add_theme_font_size_override("font_size", 11)
		elif child is Control:
			var control := child as Control
			control.custom_minimum_size = Vector2(0, c.RESPONSIVE_HAND_HEIGHT)
			control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			control.clip_contents = true

func control_bar_node() -> Control:
	if c.bottom_root != null:
		var named: Node = c.bottom_root.get_node_or_null("ControlBar")
		if named is Control:
			return named as Control
	if c.bottom_root != null and c.bottom_root.get_child_count() > 0 and c.bottom_root.get_child(0) is Control:
		return c.bottom_root.get_child(0) as Control
	return null
