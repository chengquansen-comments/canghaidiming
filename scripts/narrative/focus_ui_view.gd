extends RefCounted
const FocusArtLayerView := preload("res://scripts/narrative/focus_art_layer_view.gd")
const FocusDebugPanelView := preload("res://scripts/narrative/focus_debug_panel_view.gd")
const FocusEndingSettlementView := preload("res://scripts/narrative/focus_ending_settlement_view.gd")
const FocusOperationLayoutView := preload("res://scripts/narrative/focus_operation_layout_view.gd")
const FocusStoryCaptionView := preload("res://scripts/narrative/focus_story_caption_view.gd")
const FocusWorldMapView := preload("res://scripts/narrative/focus_world_map_view.gd")

var c
var _focus_art_layer_view
var _focus_debug_panel_view
var _focus_ending_settlement_view
var _focus_operation_layout_view
var _focus_story_caption_view
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

func _operation_layout_view():
	if _focus_operation_layout_view == null:
		_focus_operation_layout_view = FocusOperationLayoutView.new(c)
	return _focus_operation_layout_view

func _story_caption_view():
	if _focus_story_caption_view == null:
		_focus_story_caption_view = FocusStoryCaptionView.new(c)
	return _focus_story_caption_view

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
	_story_caption_view().ensure_story_caption()

func _update_focus_story_caption() -> void:
	_story_caption_view().update_story_caption()

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
	_operation_layout_view().hide_operation_metadata()

func _hide_control(control: Control) -> void:
	_operation_layout_view().hide_control(control)

func _apply_operation_only_choice_layout() -> void:
	_operation_layout_view().apply_operation_only_choice_layout()

func _style_action_buttons() -> void:
	_operation_layout_view().style_action_buttons()

func _style_button_box(box: VBoxContainer) -> void:
	_operation_layout_view().style_button_box(box)

func _hide_section_titles() -> void:
	_operation_layout_view().hide_section_titles()

func _hide_placeholder_labels(box: VBoxContainer) -> void:
	_operation_layout_view().hide_placeholder_labels(box)

func _update_focus_debug_panel() -> void:
	_debug_panel_view().update_debug_panel()

func _focus_debug_text() -> String:
	return _debug_panel_view().debug_text()

func _find_operation_panel() -> PanelContainer:
	return _operation_layout_view().find_operation_panel()

func _hide_scene_art_overlay_nodes() -> void:
	_operation_layout_view().hide_scene_art_overlay_nodes()
