extends RefCounted
class_name BattleSkinHelper

static func load_texture_or_svg(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var svg_path := path.get_basename() + ".svg"
	if ResourceLoader.exists(svg_path):
		return load(svg_path)
	return null

static func make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func make_visual_panel_style(fill: Color, border: Color, panel_frame_path: String) -> StyleBox:
	var texture := load_texture_or_svg(panel_frame_path)
	if texture == null:
		return make_panel_style(fill, border)
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

static func make_button_style(tint: Color, button_frame_path: String, panel_frame_path: String) -> StyleBox:
	var texture := load_texture_or_svg(button_frame_path)
	if texture == null:
		return make_visual_panel_style(Color("2a2018"), Color("cfb889"), panel_frame_path)
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
