extends RefCounted

# Operation-panel layout and generic hide/style helpers for the focused narrative UI.
#
# Requires owner:
# - title_label / status_label / map_label / scene_label / vars_label / visual_label / visual_debug_label / body_label / visual_texture
# - map_buttons_box / combat_buttons_box / choices_box / action_scroll / action_content
# - OPERATION_TOP / OPTION_FONT_SIZE

const HIDDEN_SCENE_ART_OVERLAY_NODE_NAMES := [
	"CinematicMistLayer",
	"CinematicFirePulse",
	"CinematicMaster",
	"CinematicHero",
	"CinematicForegroundProp",
	"CinematicForegroundProp2",
	"CinematicForegroundProp3",
	"CinematicDim",
	"CinematicFocus",
	"NarrativeFocusDebugLayer",
	"NarrativeFocusArtLayer",
	"FocusWorldMapLayer",
]

var c

func _init(controller) -> void:
	c = controller


func hide_operation_metadata() -> void:
	hide_control(c.title_label)
	hide_control(c.status_label)
	hide_control(c.map_label)
	hide_control(c.scene_label)
	hide_control(c.vars_label)
	hide_control(c.visual_label)
	hide_control(c.visual_debug_label)
	hide_control(c.body_label)
	if c.visual_texture != null:
		c.visual_texture.texture = null
		hide_control(c.visual_texture)
	if c.map_buttons_box != null:
		c.map_buttons_box.visible = false
		c.map_buttons_box.custom_minimum_size = Vector2.ZERO
		for child in c.map_buttons_box.get_children():
			child.queue_free()
	hide_section_titles()
	hide_placeholder_labels(c.combat_buttons_box)
	hide_placeholder_labels(c.choices_box)


func hide_control(control: Control) -> void:
	if control == null:
		return
	control.visible = false
	control.custom_minimum_size = Vector2.ZERO
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func apply_operation_only_choice_layout() -> void:
	var operation_panel := find_operation_panel()
	if operation_panel != null:
		operation_panel.anchor_left = 0.04
		operation_panel.anchor_top = c.OPERATION_TOP
		operation_panel.anchor_right = 0.96
		operation_panel.anchor_bottom = 0.92
		operation_panel.offset_left = 0
		operation_panel.offset_top = 0
		operation_panel.offset_right = 0
		operation_panel.offset_bottom = 0
	if c.action_scroll != null:
		c.action_scroll.visible = true
		c.action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.action_scroll.custom_minimum_size = Vector2(0, 170)
	if c.action_content != null:
		c.action_content.add_theme_constant_override("separation", 16)


func style_action_buttons() -> void:
	style_button_box(c.combat_buttons_box)
	style_button_box(c.choices_box)


func style_button_box(box: VBoxContainer) -> void:
	if box == null:
		return
	box.visible = true
	box.add_theme_constant_override("separation", 16)
	for child in box.get_children():
		if child is Button:
			var btn := child as Button
			btn.visible = true
			btn.custom_minimum_size = Vector2(0, 80)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", c.OPTION_FONT_SIZE)
		elif child is Label:
			hide_control(child as Control)


func hide_section_titles() -> void:
	if c.action_content == null:
		return
	for child in c.action_content.get_children():
		if child is Label:
			hide_control(child as Control)


func hide_placeholder_labels(box: VBoxContainer) -> void:
	if box == null:
		return
	for child in box.get_children():
		if child is Label:
			hide_control(child as Control)


func find_operation_panel() -> PanelContainer:
	for child in c.get_children():
		if child is PanelContainer:
			return child as PanelContainer
	return null


func hide_scene_art_overlay_nodes() -> void:
	for node_name in HIDDEN_SCENE_ART_OVERLAY_NODE_NAMES:
		var node: Node = c.find_child(node_name, true, false)
		if node is CanvasItem:
			var item := node as CanvasItem
			item.visible = false
		if node is Control:
			var control := node as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
