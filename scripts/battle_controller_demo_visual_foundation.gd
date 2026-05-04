extends "res://scripts/battle_controller_core.gd"

# Demo visual foundation layer.
#
# Holds shared constants, visual node references, styles and low-level helpers.
# Runtime refresh behavior is expected to live in battle_controller_visual_ui.gd.

const FRAME_SIZE := Vector2i(512, 512)
const HUD_BAR_WIDTH := 208.0
const SHEET_FRAME_COUNT := 3
const PANEL_FRAME_PATH := "res://assets/pixel_battle/ui/panel_frame.png"
const BUTTON_FRAME_PATH := "res://assets/pixel_battle/ui/button_frame.png"
const SCHOOL_NAME := "清风剑阁"
const GRID_SLOT_COUNT := 9
const GRID_SLOT_WIDTH := 126.0
const GRID_SLOT_HEIGHT := 48.0
const GRID_SLOT_GAP := 6.0
const GRID_STAGE_Y := 468.0
const GRID_RIGHT_ANCHOR_SLOT := 5
const STAGE_GROUND_Y := 510.0
const STAGE_AREA_TOP := 168.0
const STAGE_AREA_BOTTOM := 592.0
const BOTTOM_AREA_TOP := 604.0
const BOTTOM_AREA_BOTTOM_MARGIN := 24.0
const ACTOR_DISPLAY_SIZE := Vector2(228, 228)
const ACTOR_FALLBACK_BASE_SIZE := 320.0
const PLAYER_FOOT_OFFSET_X := 114.0
const ENEMY_FOOT_OFFSET_X := 114.0
const PREVIEW_CYCLE_DURATION := 1.7
const PLAYER_POS_COLOR := Color(0.87, 0.9, 0.98, 0.12)
const ENEMY_POS_COLOR := Color(0.98, 0.86, 0.8, 0.12)
const PLAYER_RANGE_COLOR := Color(0.45, 0.78, 0.96, 0.12)
const ENEMY_RANGE_COLOR := Color(0.92, 0.47, 0.36, 0.12)
const RANGE_OVERLAP_COLOR := Color(0.96, 0.82, 0.48, 0.14)
const GRID_BASE_COLOR := Color(0.06, 0.08, 0.1, 0.12)
const GRID_NEUTRAL_BORDER_COLOR := Color(0.92, 0.88, 0.78, 0.62)
const GRID_PLAYER_BORDER_COLOR := Color(0.78, 0.89, 1.0, 0.95)
const GRID_ENEMY_BORDER_COLOR := Color(1.0, 0.79, 0.67, 0.95)
const GRID_PLAYER_RANGE_BORDER_COLOR := Color(0.63, 0.88, 1.0, 0.86)
const GRID_ENEMY_RANGE_BORDER_COLOR := Color(0.96, 0.62, 0.48, 0.86)
const GRID_OVERLAP_BORDER_COLOR := Color(0.97, 0.88, 0.64, 0.94)
const SLOT_LABELS := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

var stage_layer: Control
var stage_scene_clip: Control
var background_texture: TextureRect
var stage_area_frame: PanelContainer
var bottom_backdrop: PanelContainer
var range_overlay_layer: Node2D
var stage_grid_box: HBoxContainer
var stage_grid_cells: Array[PanelContainer] = []
var stage_grid_labels: Array[Label] = []
var stage_slot_label_box: HBoxContainer
var stage_slot_name_labels: Array[Label] = []
var player_intent_bubble: PanelContainer
var enemy_intent_bubble: PanelContainer
var player_intent_bubble_label: Label
var enemy_intent_bubble_label: Label
var player_sprite: TextureRect
var enemy_sprite: TextureRect
var center_fx_layer: Control
var player_fallback_actor: Control
var enemy_fallback_actor: Control
var player_sheet_source: Texture2D
var enemy_sheet_source: Texture2D

var top_hud: HBoxContainer
var player_hud: PanelContainer
var enemy_hud: PanelContainer
var center_hud: VBoxContainer
var battle_log_strip: Label
var bottom_root: VBoxContainer
var card_detail_panel: PanelContainer
var card_detail_label: RichTextLabel
var effect_preview_panel: PanelContainer
var effect_preview_label: RichTextLabel

var player_avatar: TextureRect
var enemy_avatar: TextureRect
var player_avatar_fallback: ColorRect
var enemy_avatar_fallback: ColorRect
var player_hp_fill: ColorRect
var player_momentum_fill: ColorRect
var enemy_hp_fill: ColorRect
var enemy_momentum_fill: ColorRect
var player_hp_bg: ColorRect
var player_momentum_bg: ColorRect
var enemy_hp_bg: ColorRect
var enemy_momentum_bg: ColorRect
var player_hp_value_label: Label
var enemy_hp_value_label: Label
var player_name_label: Label
var enemy_name_label: Label
var player_school_label: Label
var enemy_school_label: Label
var player_momentum_label: Label
var enemy_momentum_label: Label
var player_momentum_dots: HBoxContainer
var enemy_momentum_dots: HBoxContainer
var preview_anim_time := 0.0

func _set_single_line_ellipsis(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _set_wrapped_label(label: Label, max_lines: int = 2) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = max_lines

func _make_hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.24)
	style.border_color = Color(0.76, 0.65, 0.45, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_badge_style(is_player: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("446b6e") if is_player else Color("3f5370")
	style.border_color = Color("d7c49b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _make_detail_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d7d0c3")
	style.border_color = Color("6f624e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func _make_stage_area_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.1)
	style.border_color = Color(0.82, 0.76, 0.62, 0.24)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 0
	style.border_width_right = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

func _make_intent_bubble_style(is_player: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.07, 0.86) if is_player else Color(0.13, 0.045, 0.035, 0.86)
	style.border_color = Color("8fb4dc") if is_player else Color("d48566")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_bottom_backdrop_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("070a0f")
	style.border_color = Color("6f6043")
	style.border_width_top = 2
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

func _make_momentum_dot_style(filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9b66c") if filled else Color(0.03, 0.035, 0.04, 0.72)
	style.border_color = Color("f3ddb0") if filled else Color(0.72, 0.66, 0.55, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	return style

func _make_overlay_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9d0bd")
	style.border_color = Color("5d4d35")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func _safe_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var svg_path := path.get_basename() + ".svg"
	if ResourceLoader.exists(svg_path):
		return load(svg_path)
	return null

func _make_demo_panel_style(fill: Color, border: Color) -> StyleBox:
	var texture := _safe_load_texture(PANEL_FRAME_PATH)
	if texture == null:
		return _make_panel_style(fill, border)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 24
	style.texture_margin_top = 24
	style.texture_margin_right = 24
	style.texture_margin_bottom = 24
	style.expand_margin_left = 10
	style.expand_margin_top = 10
	style.expand_margin_right = 10
	style.expand_margin_bottom = 10
	style.content_margin_left = 26
	style.content_margin_top = 20
	style.content_margin_right = 26
	style.content_margin_bottom = 20
	style.draw_center = true
	style.modulate_color = Color(0.96, 0.92, 0.84, 1.0)
	return style

func _make_button_style(tint: Color) -> StyleBox:
	var texture := _safe_load_texture(BUTTON_FRAME_PATH)
	if texture == null:
		return _make_demo_panel_style(Color("2a2018"), Color("cfb889"))
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 28
	style.texture_margin_top = 20
	style.texture_margin_right = 28
	style.texture_margin_bottom = 20
	style.expand_margin_left = 8
	style.expand_margin_top = 8
	style.expand_margin_right = 8
	style.expand_margin_bottom = 8
	style.content_margin_left = 24
	style.content_margin_top = 12
	style.content_margin_right = 24
	style.content_margin_bottom = 12
	style.draw_center = true
	style.modulate_color = tint
	return style

func _make_grid_cell_style(
	fill: Color,
	slot_index: int,
	has_player: bool,
	has_enemy: bool,
	in_player_range: bool,
	in_enemy_range: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	# Draw shared edges only once so adjacent attack-range cells stay readable.
	style.border_width_left = 2 if slot_index == 0 else 0
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = GRID_NEUTRAL_BORDER_COLOR
	if in_player_range and in_enemy_range:
		style.border_color = GRID_OVERLAP_BORDER_COLOR
	elif in_player_range:
		style.border_color = GRID_PLAYER_RANGE_BORDER_COLOR
	elif in_enemy_range:
		style.border_color = GRID_ENEMY_RANGE_BORDER_COLOR
	if has_player and has_enemy:
		style.border_color = GRID_OVERLAP_BORDER_COLOR
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_width_left = 3 if slot_index == 0 else 0
	elif has_player:
		style.border_color = GRID_PLAYER_BORDER_COLOR
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_width_left = 3 if slot_index == 0 else 0
	elif has_enemy:
		style.border_color = GRID_ENEMY_BORDER_COLOR
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_width_left = 3 if slot_index == 0 else 0
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _apply_button_styles() -> void:
	var groups: Array = [
		[deck_button, reset_pick_button, confirm_button],
		hand_flow.get_children() if hand_flow != null else [],
		node_buttons_box.get_children() if node_buttons_box != null else [],
		overlay_actions.get_children() if overlay_actions != null else []
	]
	for group in groups:
		for child in group:
			if child is Button:
				_style_button(child)

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.22, 0.24, 0.28, 0.98)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.28, 0.29, 0.34, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.36, 0.3, 0.2, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.45, 0.36, 0.2, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.16, 0.17, 0.2, 0.88)))
	button.add_theme_color_override("font_color", Color("eadfbe"))
	button.add_theme_color_override("font_hover_color", Color("f6edcf"))
	button.add_theme_color_override("font_pressed_color", Color("fff7db"))
	button.add_theme_color_override("font_disabled_color", Color("938871"))
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = button.custom_minimum_size.max(Vector2(108, 44))
