extends RefCounted
class_name BattleSkinHelper

static var _texture_cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}
static var _style_cache: Dictionary = {}

static func load_texture_or_svg(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if ResourceLoader.exists(path):
		var texture := load(path)
		_texture_cache[path] = texture
		return texture
	var svg_path := path.get_basename() + ".svg"
	if _texture_cache.has(svg_path):
		var cached: Texture2D = _texture_cache[svg_path] as Texture2D
		_texture_cache[path] = cached
		return cached
	if ResourceLoader.exists(svg_path):
		var svg_texture := load(svg_path)
		_texture_cache[svg_path] = svg_texture
		_texture_cache[path] = svg_texture
		return svg_texture
	_texture_cache[path] = null
	return null

static func atlas_frame(source: Texture2D, frame_size: Vector2i, frame: int) -> Texture2D:
	if source == null:
		return null
	var safe_frame := maxi(frame, 0)
	var source_key := source.resource_path if source.resource_path != "" else str(source.get_instance_id())
	var key := "%s|%d|%d|%d" % [source_key, frame_size.x, frame_size.y, safe_frame]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2(frame_size.x * safe_frame, 0), Vector2(frame_size.x, frame_size.y))
	_atlas_cache[key] = atlas
	return atlas

static func clear_texture_cache() -> void:
	_texture_cache.clear()
	_atlas_cache.clear()
	_style_cache.clear()

static func make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var key := "panel|%s|%s" % [fill.to_html(), border.to_html()]
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_style_cache[key] = style
	return style

static func make_visual_panel_style(fill: Color, border: Color, panel_frame_path: String) -> StyleBox:
	var key := "visual_panel|%s|%s|%s" % [fill.to_html(), border.to_html(), panel_frame_path]
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	_style_cache[key] = style
	return style

static func make_button_style(tint: Color, button_frame_path: String, panel_frame_path: String) -> StyleBox:
	var key := "button|%s|%s|%s" % [tint.to_html(), button_frame_path, panel_frame_path]
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = Color("b8a270")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	_style_cache[key] = style
	return style

static func make_flat_card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var key := "flat_card|%s|%s|%d" % [fill.to_html(), border.to_html(), border_width]
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	_style_cache[key] = style
	return style

static func make_type_tag_style(is_guard: bool, is_momentum: bool) -> StyleBoxFlat:
	var key := "type_tag|%s|%s" % [str(is_guard), str(is_momentum)]
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6f2824")
	if is_guard:
		style.bg_color = Color("29495f")
	elif is_momentum:
		style.bg_color = Color("355d46")
	style.border_color = Color("c7b181")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_style_cache[key] = style
	return style

static func make_card_art_style(is_guard: bool, is_momentum: bool) -> StyleBoxFlat:
	var key := "card_art|%s|%s" % [str(is_guard), str(is_momentum)]
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202934")
	if is_guard:
		style.bg_color = Color("243443")
	elif is_momentum:
		style.bg_color = Color("24382e")
	style.border_color = Color("403b31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	_style_cache[key] = style
	return style

static func make_momentum_dot_style(filled: bool) -> StyleBoxFlat:
	var key := "momentum_dot|%s" % str(filled)
	if _style_cache.has(key):
		return _style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9b66c") if filled else Color(0.03, 0.035, 0.04, 0.72)
	style.border_color = Color("f3ddb0") if filled else Color(0.72, 0.66, 0.55, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	_style_cache[key] = style
	return style
