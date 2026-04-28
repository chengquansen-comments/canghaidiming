extends "res://scripts/narrative_demo_ui_focus_controller.gd"

# Final UI tuning layer:
# - Performance caption remains centered, borderless, and integrated into the performance area.
# - Caption moves down by 30 px.
# - Option button font size is 25.
# - Narrative performance art is kept as clean static scene art: no overlay layers, character plates, breathing, pan, zoom, mist, fire, dim, or focus pulse.

const TUNED_STORY_FONT_SIZE := 72
const TUNED_OPTION_FONT_SIZE := 25
const TUNED_CAPTION_OFFSET_Y := 30

func _ready() -> void:
	super._ready()
	_disable_cinematic_effect_layers()

func _process(delta: float) -> void:
	super._process(delta)
	_disable_cinematic_effect_layers()

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

func _update_cinematic_motion(delta: float) -> void:
	_disable_cinematic_effect_layers()

func _update_layer_motion(zoom: float, pan_x: float, pan_y: float, dim_alpha: float, mist_alpha: float, fire_alpha: float) -> void:
	_disable_cinematic_effect_layers()

func _update_character_motion(zoom: float) -> void:
	_disable_cinematic_effect_layers()

func _update_cinematic_characters() -> void:
	_disable_cinematic_effect_layers()

func _disable_cinematic_effect_layers() -> void:
	if cinematic_bg != null:
		cinematic_bg.visible = true
		cinematic_bg.scale = Vector2.ONE
		cinematic_bg.position = Vector2.ZERO
		cinematic_bg.modulate = Color.WHITE
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
