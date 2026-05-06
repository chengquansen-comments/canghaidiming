extends RefCounted

# Story caption layer for the focused narrative UI.
#
# Requires owner:
# - focus_story_layer / panel / label
# - body_label
# - PERFORMANCE_CAPTION_TOP / PERFORMANCE_CAPTION_BOTTOM / STORY_FONT_SIZE

var c

func _init(controller) -> void:
	c = controller


func ensure_story_caption() -> void:
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


func update_story_caption() -> void:
	if c.focus_story_label == null:
		return
	var story_text := ""
	if c.body_label != null:
		story_text = c.body_label.text.strip_edges()
	c.focus_story_panel.visible = not story_text.is_empty()
	c.focus_story_label.text = "[center]%s[/center]" % story_text
