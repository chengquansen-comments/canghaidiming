extends RefCounted

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")

# Decorative art layer for the focused narrative UI.
#
# Requires owner:
# - focus_art_layer / focus_map_art / focus_title_art / focus_badge_art / focus_tabs_art
# - focus_casefile_art / focus_bust_art / focus_bust_path
# - in_prologue, step_index
# - UI_MAP_BACKGROUND / UI_TITLE_MARK / UI_MILITARY_BADGE / UI_STRATEGY_TABS / UI_CASEFILE_PANEL
# - BUST_HERO / BUST_MASTER / BUST_BOSS / BUST_HERO_SABER / BUST_HERO_SPEAR
# - PROLOGUE_MASTER_RESCUE_STEP / PROLOGUE_CAREER_STEP
# - _current_node_id()

var c

func _init(controller) -> void:
	c = controller


func ensure_art_layer() -> void:
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

	c.focus_map_art = make_focus_texture("FocusMapBackground", c.UI_MAP_BACKGROUND, 0.055, 0.035, 0.945, 0.205, 0.20)
	c.focus_art_layer.add_child(c.focus_map_art)
	c.focus_title_art = make_focus_texture("FocusTitleMark", c.UI_TITLE_MARK, 0.055, 0.045, 0.345, 0.215, 0.92)
	c.focus_art_layer.add_child(c.focus_title_art)
	c.focus_badge_art = make_focus_texture("FocusMilitaryBadge", c.UI_MILITARY_BADGE, 0.012, 0.038, 0.052, 0.145, 0.86)
	c.focus_art_layer.add_child(c.focus_badge_art)
	c.focus_tabs_art = make_focus_texture("FocusStrategyTabs", c.UI_STRATEGY_TABS, 0.055, 0.617, 0.330, 0.672, 0.72)
	c.focus_art_layer.add_child(c.focus_tabs_art)
	c.focus_casefile_art = make_focus_texture("FocusCasefilePanel", c.UI_CASEFILE_PANEL, 0.660, 0.205, 0.995, 0.575, 0.58)
	c.focus_art_layer.add_child(c.focus_casefile_art)
	c.focus_bust_art = make_focus_texture("FocusRoleBust", c.BUST_HERO, 0.026, 0.225, 0.250, 0.590, 0.54)
	c.focus_art_layer.add_child(c.focus_bust_art)


func make_focus_texture(layer_name: String, path: String, left: float, top: float, right: float, bottom: float, alpha: float) -> TextureRect:
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


func update_art_layer() -> void:
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
	update_bust_art()


func update_bust_art() -> void:
	if c.focus_bust_art == null:
		return
	var target_path := focus_bust_path()
	c.focus_bust_art.visible = not target_path.is_empty()
	if target_path.is_empty() or target_path == c.focus_bust_path:
		return
	c.focus_bust_path = target_path
	if ResourceLoader.exists(target_path):
		var resource := load(target_path)
		if resource is Texture2D:
			c.focus_bust_art.texture = resource


func focus_bust_path() -> String:
	if c.in_prologue:
		if c.step_index >= c.PROLOGUE_MASTER_RESCUE_STEP and c.step_index < c.PROLOGUE_CAREER_STEP:
			return c.BUST_MASTER
		if c.step_index == c.PROLOGUE_CAREER_STEP:
			return route_hero_bust_path()
		return ""
	var node_id: String = c._current_node_id()
	match node_id:
		"night_knife_camp", "military_coverup":
			return c.BUST_MASTER
		"wakou_boss":
			return c.BUST_BOSS
		_:
			return route_hero_bust_path()


func route_hero_bust_path() -> String:
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
