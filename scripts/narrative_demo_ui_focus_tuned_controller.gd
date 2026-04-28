extends "res://scripts/narrative_demo_ui_focus_controller.gd"

# Final UI tuning layer:
# - Performance caption remains centered, borderless, and integrated into the performance area.
# - Caption moves down by 30 px.
# - Option button font size is 25.
# - Narrative performance art is kept as clean static scene art: no overlay layers, character plates, breathing, pan, zoom, mist, fire, dim, focus pulse, map panel, or debug panel over the scene art.

const TUNED_STORY_FONT_SIZE := 72
const TUNED_OPTION_FONT_SIZE := 25
const TUNED_CAPTION_OFFSET_Y := 30
const STATIC_BACKGROUND_NODE_NAME := "CinematicPerformanceBackground"
const STATIC_SCENE_ART_BACKGROUND_NODE_NAME := "StaticSceneArtBackground"
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
const HIDDEN_SCENE_ART_NAME_FRAGMENTS := [
	"Mist",
	"FirePulse",
	"Dim",
	"Focus",
	"Master",
	"Hero",
	"ForegroundProp",
	"NarrativeFocusArt",
	"WorldMap",
	"Debug",
]
const STATIC_SCENE_ART_KEEP_NAMES := [
	"NarrativeDemo",
	"StaticSceneArtBackground",
	"NarrativePerformanceCaptionLayer",
	"NarrativePerformanceCaptionPanel",
	"NarrativePerformanceCaptionText",
]

var static_scene_art_background: TextureRect

func _ready() -> void:
	super._ready()
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _process(delta: float) -> void:
	super._process(delta)
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _physics_process(_delta: float) -> void:
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _render() -> void:
	super._render()
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _ensure_focus_story_caption() -> void:
	if focus_story_layer != null:
		return
	focus_story_layer = Control.new()
	focus_story_layer.name = "NarrativePerformanceCaptionLayer"
	focus_story_layer.anchor_left = 0.0
	focus_story_layer.anchor_top = 0.0
	focus_story_layer.anchor_right = 1.0
	focus_story_layer.anchor_bottom = 1.0
	focus_story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_layer.z_index = 90
	focus_story_layer.z_as_relative = false
	add_child(focus_story_layer)

	focus_story_panel = PanelContainer.new()
	focus_story_panel.name = "NarrativePerformanceCaptionPanel"
	focus_story_panel.anchor_left = 0.06
	focus_story_panel.anchor_top = PERFORMANCE_CAPTION_TOP
	focus_story_panel.anchor_right = 0.94
	focus_story_panel.anchor_bottom = PERFORMANCE_CAPTION_BOTTOM
	focus_story_panel.offset_top = TUNED_CAPTION_OFFSET_Y
	focus_story_panel.offset_bottom = TUNED_CAPTION_OFFSET_Y
	focus_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_panel.z_index = 91
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	focus_story_panel.add_theme_stylebox_override("panel", style)
	focus_story_layer.add_child(focus_story_panel)

	focus_story_label = RichTextLabel.new()
	focus_story_label.name = "NarrativePerformanceCaptionText"
	focus_story_label.bbcode_enabled = true
	focus_story_label.fit_content = false
	focus_story_label.scroll_active = false
	focus_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_story_label.add_theme_font_size_override("normal_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("bold_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_font_size_override("italics_font_size", TUNED_STORY_FONT_SIZE)
	focus_story_label.add_theme_color_override("default_color", Color("f6ead2"))
	focus_story_panel.add_child(focus_story_label)

func _style_button_box(box: VBoxContainer) -> void:
	if box == null:
		return
	box.visible = true
	box.add_theme_constant_override("separation", 16)
	for child in box.get_children():
		if child is Button:
			var btn := child as Button
			btn.visible = true
			btn.custom_minimum_size = Vector2(0, 92)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", TUNED_OPTION_FONT_SIZE)
		elif child is Label:
			_hide_control(child as Control)

func _update_cinematic_motion(_delta: float) -> void:
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _update_layer_motion(_zoom: float, _pan_x: float, _pan_y: float, _dim_alpha: float, _mist_alpha: float, _fire_alpha: float) -> void:
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _update_character_motion(_zoom: float) -> void:
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _update_cinematic_characters() -> void:
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _refresh_world_map() -> void:
	super._refresh_world_map()
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _update_focus_debug_panel() -> void:
	_disable_scene_art_overlays()
	call_deferred("_disable_scene_art_overlays")

func _disable_scene_art_overlays() -> void:
	_sync_static_scene_art_background()
	_hide_original_cinematic_background()
	_hide_named_scene_art_overlay_nodes()
	_hard_sanitize_scene_art_tree(self)
	_disable_cinematic_effect_layers()
	_disable_performance_ui_panels()
	_sync_static_scene_art_background()
	_hide_original_cinematic_background()

func _ensure_static_scene_art_background() -> TextureRect:
	if static_scene_art_background != null and is_instance_valid(static_scene_art_background):
		return static_scene_art_background
	static_scene_art_background = TextureRect.new()
	static_scene_art_background.name = STATIC_SCENE_ART_BACKGROUND_NODE_NAME
	static_scene_art_background.anchor_left = 0.0
	static_scene_art_background.anchor_top = 0.0
	static_scene_art_background.anchor_right = 1.0
	static_scene_art_background.anchor_bottom = _scene_art_bottom_anchor()
	static_scene_art_background.offset_left = 0.0
	static_scene_art_background.offset_top = 0.0
	static_scene_art_background.offset_right = 0.0
	static_scene_art_background.offset_bottom = 0.0
	static_scene_art_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	static_scene_art_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	static_scene_art_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_scene_art_background.z_index = -100
	static_scene_art_background.z_as_relative = false
	static_scene_art_background.material = null
	add_child(static_scene_art_background)
	move_child(static_scene_art_background, 0)
	return static_scene_art_background

func _scene_art_bottom_anchor() -> float:
	var viewport_size := get_viewport_rect().size
	var operation_height: float = max(MIN_OPERATION_HEIGHT, viewport_size.y * (1.0 - PERFORMANCE_RATIO))
	return max(0.48, OPERATION_BOTTOM - operation_height / max(1.0, viewport_size.y))

func _sync_static_scene_art_background() -> void:
	var static_bg := _ensure_static_scene_art_background()
	var source_texture: Texture2D = null
	if cinematic_bg != null and cinematic_bg.texture != null:
		source_texture = cinematic_bg.texture
	var bg_node := find_child(STATIC_BACKGROUND_NODE_NAME, true, false)
	if bg_node is TextureRect:
		var source_bg := bg_node as TextureRect
		if source_bg.texture != null:
			source_texture = source_bg.texture
	if source_texture != null:
		static_bg.texture = source_texture
	_pin_static_scene_art_background(static_bg)

func _pin_static_scene_art_background(static_bg: TextureRect) -> void:
	if static_bg == null:
		return
	static_bg.visible = true
	static_bg.anchor_left = 0.0
	static_bg.anchor_top = 0.0
	static_bg.anchor_right = 1.0
	static_bg.anchor_bottom = _scene_art_bottom_anchor()
	static_bg.offset_left = 0.0
	static_bg.offset_top = 0.0
	static_bg.offset_right = 0.0
	static_bg.offset_bottom = 0.0
	static_bg.scale = Vector2.ONE
	static_bg.position = Vector2.ZERO
	static_bg.rotation = 0.0
	static_bg.pivot_offset = Vector2.ZERO
	static_bg.modulate = Color.WHITE
	static_bg.self_modulate = Color.WHITE
	static_bg.material = null

func _hide_original_cinematic_background() -> void:
	if cinematic_bg != null:
		_hide_background_source_node(cinematic_bg)
	var bg_node := find_child(STATIC_BACKGROUND_NODE_NAME, true, false)
	if bg_node is CanvasItem:
		_hide_background_source_node(bg_node as CanvasItem)

func _hide_background_source_node(node: CanvasItem) -> void:
	if node == null:
		return
	if node.name == STATIC_SCENE_ART_BACKGROUND_NODE_NAME:
		return
	node.visible = false
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.material = null

func _hide_named_scene_art_overlay_nodes() -> void:
	for node_name in HIDDEN_SCENE_ART_OVERLAY_NODE_NAMES:
		var node := find_child(node_name, true, false)
		_hide_overlay_node(node)

func _hard_sanitize_scene_art_tree(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		var child_name := str(child.name)
		if child_name == STATIC_SCENE_ART_BACKGROUND_NODE_NAME and child is TextureRect:
			_pin_static_scene_art_background(child as TextureRect)
		elif child_name == STATIC_BACKGROUND_NODE_NAME and child is CanvasItem:
			_hide_background_source_node(child as CanvasItem)
		elif _should_hide_scene_art_node(child_name):
			_hide_overlay_node(child)
		_hard_sanitize_scene_art_tree(child)

func _should_hide_scene_art_node(node_name: String) -> bool:
	if node_name in STATIC_SCENE_ART_KEEP_NAMES:
		return false
	for fragment in HIDDEN_SCENE_ART_NAME_FRAGMENTS:
		if node_name.find(fragment) >= 0:
			return true
	return false

func _hide_overlay_node(node: Node) -> void:
	if node == null:
		return
	if node.name == STATIC_SCENE_ART_BACKGROUND_NODE_NAME:
		return
	if node is CanvasItem:
		var item := node as CanvasItem
		item.visible = false
		item.modulate = Color(1.0, 1.0, 1.0, 0.0)
		item.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		item.material = null
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.custom_minimum_size = Vector2.ZERO
		control.scale = Vector2.ONE
		control.position = Vector2.ZERO

func _disable_cinematic_effect_layers() -> void:
	_sync_static_scene_art_background()
	_hide_original_cinematic_background()
	if cinematic_mist != null:
		cinematic_mist.visible = false
		cinematic_mist.color = Color(0.0, 0.0, 0.0, 0.0)
	if cinematic_fire != null:
		cinematic_fire.visible = false
		cinematic_fire.color = Color(0.0, 0.0, 0.0, 0.0)
	if cinematic_dim != null:
		cinematic_dim.visible = false
		cinematic_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	if cinematic_focus != null:
		cinematic_focus.visible = false
		cinematic_focus.color = Color(0.0, 0.0, 0.0, 0.0)
	if cinematic_master != null:
		cinematic_master.visible = false
		cinematic_master.scale = Vector2.ONE
		cinematic_master.position = Vector2.ZERO
	if cinematic_hero != null:
		cinematic_hero.visible = false
		cinematic_hero.scale = Vector2.ONE
		cinematic_hero.position = Vector2.ZERO

func _disable_performance_ui_panels() -> void:
	if world_map_layer != null:
		world_map_layer.visible = false
		world_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world_map_panel != null:
		world_map_panel.visible = false
		world_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if focus_world_map_layer != null:
		focus_world_map_layer.visible = false
		focus_world_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if focus_world_map_panel != null:
		focus_world_map_panel.visible = false
		focus_world_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if focus_debug_layer != null:
		focus_debug_layer.visible = false
		focus_debug_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if focus_debug_panel != null:
		focus_debug_panel.visible = false
		focus_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if visual_debug_label != null:
		visual_debug_label.visible = false
		visual_debug_label.custom_minimum_size = Vector2.ZERO
