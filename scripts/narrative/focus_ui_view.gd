extends RefCounted
const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const FocusDebugPanelView := preload("res://scripts/narrative/focus_debug_panel_view.gd")
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
var _focus_debug_panel_view
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

func _debug_panel_view():
	if _focus_debug_panel_view == null:
		_focus_debug_panel_view = FocusDebugPanelView.new(c)
	return _focus_debug_panel_view

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

func _show_ending_settlement_popup() -> void:
	_ensure_ending_settlement_popup()
	if c.ending_settlement_layer == null or c.ending_settlement_text == null:
		return
	c.ending_settlement_text.text = _ending_settlement_popup_text()
	c.ending_settlement_layer.visible = true
	if c.ending_settlement_confirm != null:
		c.ending_settlement_confirm.grab_focus()

func _on_ending_settlement_confirmed() -> void:
	if c.ending_settlement_layer != null:
		c.ending_settlement_layer.visible = false

func _ending_settlement_popup_text() -> String:
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

func _ensure_focus_art_layer() -> void:
	if c.focus_art_layer != null:
		return
	c.focus_art_layer = Control.new()
	c.focus_art_layer.name = "NarrativeFocusArtLayer"
	c.focus_art_layer.anchor_left = 0.0
	c.focus_art_layer.anchor_top = 0.0
	c.focus_art_layer.anchor_right = 1.0
	c.focus_art_layer.anchor_bottom = 1.0
	c.focus_art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_art_layer.z_index = 58
	c.focus_art_layer.z_as_relative = false
	c.add_child(c.focus_art_layer)

	c.focus_map_art = _make_focus_texture("FocusMapBackground", c.UI_MAP_BACKGROUND, 0.055, 0.035, 0.945, 0.205, 0.20)
	c.focus_art_layer.add_child(c.focus_map_art)
	c.focus_title_art = _make_focus_texture("FocusTitleMark", c.UI_TITLE_MARK, 0.055, 0.045, 0.345, 0.215, 0.92)
	c.focus_art_layer.add_child(c.focus_title_art)
	c.focus_badge_art = _make_focus_texture("FocusMilitaryBadge", c.UI_MILITARY_BADGE, 0.012, 0.038, 0.052, 0.145, 0.86)
	c.focus_art_layer.add_child(c.focus_badge_art)
	c.focus_tabs_art = _make_focus_texture("FocusStrategyTabs", c.UI_STRATEGY_TABS, 0.055, 0.617, 0.330, 0.672, 0.72)
	c.focus_art_layer.add_child(c.focus_tabs_art)
	c.focus_casefile_art = _make_focus_texture("FocusCasefilePanel", c.UI_CASEFILE_PANEL, 0.660, 0.205, 0.995, 0.575, 0.58)
	c.focus_art_layer.add_child(c.focus_casefile_art)
	c.focus_bust_art = _make_focus_texture("FocusRoleBust", c.BUST_HERO, 0.026, 0.225, 0.250, 0.590, 0.54)
	c.focus_art_layer.add_child(c.focus_bust_art)

func _make_focus_texture(layer_name: String, path: String, left: float, top: float, right: float, bottom: float, alpha: float) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = layer_name
	texture_rect.anchor_left = left
	texture_rect.anchor_top = top
	texture_rect.anchor_right = right
	texture_rect.anchor_bottom = bottom
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.modulate = Color(1.0, 1.0, 1.0, alpha)
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			texture_rect.texture = resource
	return texture_rect

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
	if c.focus_art_layer == null:
		return
	if c.focus_title_art != null:
		c.focus_title_art.visible = c.in_prologue
	if c.focus_badge_art != null:
		c.focus_badge_art.visible = not c.in_prologue
	if c.focus_tabs_art != null:
		c.focus_tabs_art.visible = not c.in_prologue
	if c.focus_map_art != null:
		c.focus_map_art.visible = not c.in_prologue
	if c.focus_casefile_art != null:
		c.focus_casefile_art.visible = NarrativeBattleContext.is_ui_debug_visible() and c.focus_debug_panel != null and c.focus_debug_panel.visible
	_update_focus_bust_art()

func _update_focus_bust_art() -> void:
	if c.focus_bust_art == null:
		return
	var target_path := _focus_bust_path()
	c.focus_bust_art.visible = not target_path.is_empty()
	if target_path.is_empty() or target_path == c.focus_bust_path:
		return
	c.focus_bust_path = target_path
	if ResourceLoader.exists(target_path):
		var resource := load(target_path)
		if resource is Texture2D:
			c.focus_bust_art.texture = resource

func _focus_bust_path() -> String:
	if c.in_prologue:
		if c.step_index >= c.PROLOGUE_MASTER_RESCUE_STEP and c.step_index < c.PROLOGUE_CAREER_STEP:
			return c.BUST_MASTER
		if c.step_index == c.PROLOGUE_CAREER_STEP:
			return _route_hero_bust_path()
		return ""
	var node_id: String = c._current_node_id()
	match node_id:
		"night_knife_camp", "military_coverup":
			return c.BUST_MASTER
		"wakou_boss":
			return c.BUST_BOSS
		_:
			return _route_hero_bust_path()

func _route_hero_bust_path() -> String:
	if not NarrativeBattleContext.has_player_profile():
		return c.BUST_HERO
	var profile: Dictionary = NarrativeBattleContext.get_player_profile()
	var role_id := str(profile.get("role", "")).strip_edges()
	var weapon := str(profile.get("weapon", "")).strip_edges()
	if role_id == "blademaster" or weapon.find("刀") >= 0:
		return c.BUST_HERO_SABER
	if role_id == "spearman" or weapon.find("枪") >= 0:
		return c.BUST_HERO_SPEAR
	return c.BUST_HERO

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
