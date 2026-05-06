extends "res://scripts/narrative_demo_unified_controller.gd"

const FocusUiView := preload("res://scripts/narrative/focus_ui_view.gd")
const FocusUiRuntime := preload("res://scripts/narrative/focus_ui_runtime.gd")

# UI focus layer:
# - Story text is displayed as a large caption at the bottom of the performance area.
# - Operation area shows only actionable buttons.
# - Metadata moves into a right-side debug overlay.
# - Narrative MVP flow is sourced from compiled data/narrative_mvp_nodes.json.
#   Hardcoded MVP_NODE_IDS is only a crash-safe fallback.
# - Top world map node panel remains visible; only operation-area map/debug controls are hidden.

const STORY_FONT_SIZE := 72
const OPTION_FONT_SIZE := 30
const DEBUG_FONT_SIZE := 13
const PERFORMANCE_CAPTION_TOP := 0.52
const PERFORMANCE_CAPTION_BOTTOM := 0.72
const OPERATION_TOP := 0.68
const UI_TITLE_MARK := "res://assets/pixel_battle/ui/title_canghai_diming.png"
const UI_CASEFILE_PANEL := "res://assets/pixel_battle/ui/ui_casefile_panel.png"
const UI_MILITARY_BADGE := "res://assets/pixel_battle/ui/ui_military_order_badge.png"
const UI_STRATEGY_TABS := "res://assets/pixel_battle/ui/ui_strategy_book_tabs.png"
const UI_MAP_BACKGROUND := "res://assets/pixel_battle/backgrounds/map_march_coast.png"
const BUST_HERO := "res://assets/pixel_battle/portraits/hero_officer_bust.png"
const BUST_HERO_SPEAR := "res://assets/pixel_battle/portraits/hero_officer_spear_bust.png"
const BUST_HERO_SABER := "res://assets/pixel_battle/portraits/hero_officer_saber_bust.png"
const BUST_MASTER := "res://assets/pixel_battle/portraits/master_veteran_bust.png"
const BUST_BOSS := "res://assets/pixel_battle/portraits/wakou_boss_bust.png"
const DEBUG_TOGGLE_KEY := KEY_F10
const FOOT_ALIGNMENT_DEBUG_META := "canghai_foot_alignment_debug_visible"

var focus_debug_layer: Control
var focus_debug_panel: PanelContainer
var focus_debug_label: RichTextLabel
var focus_foot_alignment_debug_button: Button
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
var focus_art_layer: Control
var focus_title_art: TextureRect
var focus_badge_art: TextureRect
var focus_tabs_art: TextureRect
var focus_casefile_art: TextureRect
var focus_map_art: TextureRect
var focus_bust_art: TextureRect
var focus_bust_path: String = ""
var ending_settlement_layer: Control
var ending_settlement_panel: PanelContainer
var ending_settlement_text: RichTextLabel
var ending_settlement_confirm: Button

var _focus_ui_view_helper
var _focus_ui_runtime_helper

func _view():
	if _focus_ui_view_helper == null:
		_focus_ui_view_helper = FocusUiView.new(self)
	return _focus_ui_view_helper

func _runtime():
	if _focus_ui_runtime_helper == null:
		_focus_ui_runtime_helper = FocusUiRuntime.new(self)
	return _focus_ui_runtime_helper

func _ready() -> void:
	super._ready()
	_add_world_map_layer()
	_ensure_focus_story_caption()
	_ensure_focus_debug_panel()
	_apply_focus_ui()
	_hide_scene_art_overlay_nodes()

func _process(delta: float) -> void:
	super._process(delta)
	_apply_focus_ui()
	_hide_scene_art_overlay_nodes()

func _render() -> void:
	_clear_dynamic_boxes()
	if in_prologue:
		_render_prologue()
	else:
		_render_node()
	BattleFontHelper.enforce(self)
	_apply_focus_ui()
	_hide_scene_art_overlay_nodes()

func _render_ending() -> void:
	super._render_ending()
	_apply_focus_ui()
	_show_ending_settlement_popup()
	_hide_scene_art_overlay_nodes()

func _input(event: InputEvent) -> void:
	if _is_debug_toggle_event(event):
		_toggle_focus_debug_panel()
		get_viewport().set_input_as_handled()

func _is_debug_toggle_event(event: InputEvent) -> bool:
	return _runtime()._is_debug_toggle_event(event)

func _toggle_focus_debug_panel() -> void:
	_runtime()._toggle_focus_debug_panel()

func _apply_focus_debug_visibility() -> void:
	_view()._apply_focus_debug_visibility()

func _flow_node_ids() -> Array:
	return _runtime()._flow_node_ids()

func _load_flow_from_compiled_data() -> void:
	_runtime()._load_flow_from_compiled_data()

func _flow_count() -> int:
	return _runtime()._flow_count()

func _node_id_at(index: int) -> String:
	return _runtime()._node_id_at(index)

func _current_node_id() -> String:
	return _runtime()._current_node_id()

func _world_map_total_count() -> int:
	return _runtime()._world_map_total_count()

func _add_world_map_layer() -> void:
	_view()._add_world_map_layer()

func _refresh_world_map() -> void:
	_view()._refresh_world_map()

func _show_world_map_ui() -> void:
	_view()._show_world_map_ui()

func _current_world_map_title() -> String:
	return _view()._current_world_map_title()

func _world_map_current_index() -> int:
	return _runtime()._world_map_current_index()

func _world_map_title_at(map_index: int) -> String:
	return _view()._world_map_title_at(map_index)

func _world_map_marker_for_index(index: int) -> String:
	return _view()._world_map_marker_for_index(index)

func _make_world_map_line(index: int) -> Label:
	return _view()._make_world_map_line(index)

func _make_world_map_node_button(index: int) -> Button:
	return _view()._make_world_map_node_button(index)

func _on_world_map_node_pressed(map_index: int) -> void:
	_runtime()._on_world_map_node_pressed(map_index)

func _ensure_focus_story_caption() -> void:
	_view()._ensure_focus_story_caption()

func _update_focus_story_caption() -> void:
	_view()._update_focus_story_caption()

func _battle_growth_reward_for_source(source_index: int) -> Dictionary:
	return _runtime()._battle_growth_reward_for_source(source_index)

func _consume_battle_result_if_needed() -> void:
	_runtime()._consume_battle_result_if_needed()

func _on_continue_after_choice_result() -> void:
	_runtime()._on_continue_after_choice_result()

func _advance_to_node(target_index: int, hint: String = "") -> void:
	_runtime()._advance_to_node(target_index, hint)

func _ensure_focus_debug_panel() -> void:
	_view()._ensure_focus_debug_panel()

func _ensure_ending_settlement_popup() -> void:
	_view()._ensure_ending_settlement_popup()

func _show_ending_settlement_popup() -> void:
	_view()._show_ending_settlement_popup()

func _on_ending_settlement_confirmed() -> void:
	_view()._on_ending_settlement_confirmed()

func _ending_settlement_popup_text() -> String:
	return _view()._ending_settlement_popup_text()

func _ensure_focus_art_layer() -> void:
	_view()._ensure_focus_art_layer()

func _make_focus_texture(layer_name: String, path: String, left: float, top: float, right: float, bottom: float, alpha: float) -> TextureRect:
	return _view()._make_focus_texture(layer_name, path, left, top, right, bottom, alpha)

func _apply_focus_ui() -> void:
	_view()._apply_focus_ui()

func _update_focus_art_layer() -> void:
	_view()._update_focus_art_layer()

func _update_focus_bust_art() -> void:
	_view()._update_focus_bust_art()

func _focus_bust_path() -> String:
	return _view()._focus_bust_path()

func _route_hero_bust_path() -> String:
	return _view()._route_hero_bust_path()

func _hide_operation_metadata() -> void:
	_view()._hide_operation_metadata()

func _hide_control(control: Control) -> void:
	_view()._hide_control(control)

func _apply_operation_only_choice_layout() -> void:
	_view()._apply_operation_only_choice_layout()

func _style_action_buttons() -> void:
	_view()._style_action_buttons()

func _style_button_box(box: VBoxContainer) -> void:
	_view()._style_button_box(box)

func _hide_section_titles() -> void:
	_view()._hide_section_titles()

func _hide_placeholder_labels(box: VBoxContainer) -> void:
	_view()._hide_placeholder_labels(box)

func _update_focus_debug_panel() -> void:
	_view()._update_focus_debug_panel()

func _on_focus_foot_alignment_debug_pressed() -> void:
	_runtime()._on_focus_foot_alignment_debug_pressed()

func _foot_alignment_debug_enabled() -> bool:
	return _runtime()._foot_alignment_debug_enabled()

func _focus_debug_text() -> String:
	return _view()._focus_debug_text()

func _focus_current_node_data() -> Dictionary:
	return _runtime()._focus_current_node_data()

func _safe_label_text(label: Label, fallback: String) -> String:
	return _runtime()._safe_label_text(label, fallback)

func _find_operation_panel() -> PanelContainer:
	return _view()._find_operation_panel()

func _hide_scene_art_overlay_nodes() -> void:
	_view()._hide_scene_art_overlay_nodes()
