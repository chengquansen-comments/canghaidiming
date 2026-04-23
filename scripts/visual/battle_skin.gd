extends RefCounted
class_name BattleSkinHelper

static var _texture_cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}

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
		var cached := _texture_cache[svg_path]
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
	var key := "%s|%d|%d|%d" % [source.resource_path, frame_size.x, frame_size.y, safe_frame]
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
	return style

static func make_button_style(tint: Color, button_frame_path: String, panel_frame_path: String) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = Color("b8a270")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	return style
