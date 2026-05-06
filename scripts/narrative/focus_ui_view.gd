extends RefCounted
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const FocusArtLayerView := preload("res://scripts/narrative/focus_art_layer_view.gd")
const FocusDebugPanelView := preload("res://scripts/narrative/focus_debug_panel_view.gd")
const FocusEndingSettlementView := preload("res://scripts/narrative/focus_ending_settlement_view.gd")
const FocusWorldMapView := preload("res://scripts/narrative/focus_world_map_view.gd")

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
var _focus_art_layer_view
var _focus_debug_panel_view
var _focus_ending_settlement_view
var _focus_world_map_view

func _init(controller) -> void:
	c = controller

func _get(property: StringName):
	if c == null:
		return null
	return c.get(property)

func _set(property: StringName, value) -> bool:
	if c == null:
		return false
	c.set(property, value)
	return true

func _art_layer_view():
	if _focus_art_layer_view == null:
		_focus_art_layer_view = FocusArtLayerView.new(c)
	return _focus_art_layer_view

func _debug_panel_view():
	if _focus_debug_panel_view == null:
		_focus_debug_panel_view = FocusDebugPanelView.new(c)
	return _focus_debug_panel_view

func _ending_settlement_view():
	if _focus_ending_settlement_view == null:
		_focus_ending_settlement_view = FocusEndingSettlementView.new(c)
	return _focus_ending_settlement_view

func _world_map_view():
	if _focus_world_map_view == null:
		_focus_world_map_view = FocusWorldMapView.new(c)
	return _focus_world_map_view

func _apply_focus_debug_visibility() -> void:
	_debug_panel_view().apply_debug_visibility()

func _add_world_map_layer() -> void:
	_world_map_view().add_world_map_layer()

func _refresh_world_map() -> void:
	_world_map_view().refresh_world_map()

func _show_world_map_ui() -> void:
	_world_map_view().show_world_map_ui()

func _current_world_map_title() -> String:
	return _world_map_view().current_world_map_title()

func _world_map_title_at(map_index: int) -> String:
	return _world_map_view().world_map_title_at(map_index)

func _world_map_marker_for_index(index: int) -> String:
	return _world_map_view().world_map_marker_for_index(index)

func _make_world_map_line(index: int) -> Label:
	return _world_map_view().make_world_map_line(index)

func _make_world_map_node_button(index: int) -> Button:
	return _world_map_view().make_world_map_node_button(index)

func _ensure_focus_story_caption() -> void:
	if c.focus_story_layer != null:
		return
	c.focus_story_layer = Control.new()
	c.focus_story_layer.name = "NarrativePerformanceCaptionLayer"
	c.focus_story_layer.anchor_left = 0.0
	c.focus_story_layer.anchor_top = 0.0
	c.focus_story_layer.anchor_right = 1.0
	c.focus_story_layer.anchor_bottom = 1.0
	c.focus_story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_story_layer.z_index = 90
	c.focus_story_layer.z_as_relative = false
	c.add_child(c.focus_story_layer)

	c.focus_story_panel = PanelContainer.new()
	c.focus_story_panel.name = "NarrativePerformanceCaptionPanel"
	c.focus_story_panel.anchor_left = 0.06
	c.focus_story_panel.anchor_top = c.PERFORMANCE_CAPTION_TOP
	c.focus_story_panel.anchor_right = 0.94
	c.focus_story_panel.anchor_bottom = c.PERFORMANCE_CAPTION_BOTTOM
	c.focus_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_story_panel.z_index = 91
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	c.focus_story_panel.add_theme_stylebox_override("panel", style)
	c.focus_story_layer.add_child(c.focus_story_panel)

	c.focus_story_label = RichTextLabel.new()
	c.focus_story_label.name = "NarrativePerformanceCaptionText"
	c.focus_story_label.bbcode_enabled = true
	c.focus_story_label.fit_content = false
	c.focus_story_label.scroll_active = false
	c.focus_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_story_label.add_theme_font_size_override("normal_font_size", c.STORY_FONT_SIZE)
	c.focus_story_label.add_theme_font_size_override("bold_font_size", c.STORY_FONT_SIZE)
	c.focus_story_label.add_theme_font_size_override("italics_font_size", c.STORY_FONT_SIZE)
	c.focus_story_label.add_theme_color_override("default_color", Color("f6ead2"))
	c.focus_story_panel.add_child(c.focus_story_label)

func _update_focus_story_caption() -> void:
	if c.focus_story_label == null:
		return
	var story_text := ""
	if c.body_label != null:
		story_text = c.body_label.text.strip_edges()
	c.focus_story_panel.visible = not story_text.is_empty()
	c.focus_story_label.text = "[center]%s[/center]" % story_text

func _ensure_focus_debug_panel() -> void:
	_debug_panel_view().ensure_debug_panel()

func _ensure_ending_settlement_popup() -> void:
	_ending_settlement_view().ensure_popup()

func _show_ending_settlement_popup() -> void:
	_ending_settlement_view().show_popup()

func _on_ending_settlement_confirmed() -> void:
	_ending_settlement_view().on_confirmed()

func _ending_settlement_popup_text() -> String:
	return _ending_settlement_view().popup_text()

func _ensure_focus_art_layer() -> void:
	_art_layer_view().ensure_art_layer()

func _make_focus_texture(layer_name: String, path: String, left: float, top: float, right: float, bottom: float, alpha: float) -> TextureRect:
	return _art_layer_view().make_focus_texture(layer_name, path, left, top, right, bottom, alpha)

func _apply_focus_ui() -> void:
	_ensure_focus_story_caption()
	_ensure_focus_debug_panel()
	_ensure_focus_art_layer()
	_update_focus_story_caption()
	_hide_operation_metadata()
	_apply_operation_only_choice_layout()
	_style_action_buttons()
	_refresh_world_map()
	_update_focus_art_layer()
	_apply_focus_debug_visibility()
	_update_focus_debug_panel()

func _update_focus_art_layer() -> void:
	_art_layer_view().update_art_layer()

func _update_focus_bust_art() -> void:
	_art_layer_view().update_bust_art()

func _focus_bust_path() -> String:
	return _art_layer_view().focus_bust_path()

func _route_hero_bust_path() -> String:
	return _art_layer_view().route_hero_bust_path()

func _hide_operation_metadata() -> void:
	_hide_control(c.title_label)
	_hide_control(c.status_label)
	_hide_control(c.map_label)
	_hide_control(c.scene_label)
	_hide_control(c.vars_label)
	_hide_control(c.visual_label)
	_hide_control(c.visual_debug_label)
	_hide_control(c.body_label)
	if c.visual_texture != null:
		c.visual_texture.texture = null
		_hide_control(c.visual_texture)
	if c.map_buttons_box != null:
		c.map_buttons_box.visible = false
		c.map_buttons_box.custom_minimum_size = Vector2.ZERO
		for child in c.map_buttons_box.get_children():
			child.queue_free()
	_hide_section_titles()
	_hide_placeholder_labels(c.combat_buttons_box)
	_hide_placeholder_labels(c.choices_box)

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

func _style_action_buttons() -> void:
	_style_button_box(c.combat_buttons_box)
	_style_button_box(c.choices_box)

func _style_button_box(box: VBoxContainer) -> void:
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
			_hide_control(child as Control)

func _hide_section_titles() -> void:
	if c.action_content == null:
		return
	for child in c.action_content.get_children():
		if child is Label:
			_hide_control(child as Control)

func _hide_placeholder_labels(box: VBoxContainer) -> void:
	if box == null:
		return
	for child in box.get_children():
		if child is Label:
			_hide_control(child as Control)

func _update_focus_debug_panel() -> void:
	_debug_panel_view().update_debug_panel()

func _focus_debug_text() -> String:
	return _debug_panel_view().debug_text()

func _find_operation_panel() -> PanelContainer:
	for child in c.get_children():
		if child is PanelContainer:
			return child as PanelContainer
	return null

func _hide_scene_art_overlay_nodes() -> void:
	for node_name in HIDDEN_SCENE_ART_OVERLAY_NODE_NAMES:
		var node: Node = c.find_child(node_name, true, false)
		if node is CanvasItem:
			var item := node as CanvasItem
			item.visible = false
		if node is Control:
			var control := node as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
