extends RefCounted

var _parent: Node
var _pool: Dictionary[String, Array] = {}


func set_parent(parent: Node) -> void:
	_parent = parent


func acquire(
	key: String,
	texture: Texture2D,
	draw_size: Vector2,
	at_position: Vector2,
	tint: Color,
	rotation_deg: float = 0.0,
	start_scale: Vector2 = Vector2.ONE
) -> TextureRect:
	if _parent == null or texture == null:
		return null
	var fx := _take_from_pool(key)
	if fx == null:
		fx = TextureRect.new()
		fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fx.get_parent() == null:
		_parent.add_child(fx)
	elif fx.get_parent() != _parent:
		fx.get_parent().remove_child(fx)
		_parent.add_child(fx)
	fx.texture = texture
	fx.custom_minimum_size = draw_size
	fx.size = draw_size
	fx.position = at_position - draw_size * 0.5
	fx.rotation_degrees = rotation_deg
	fx.scale = start_scale
	fx.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	fx.visible = true
	return fx


func release(key: String, fx: TextureRect) -> void:
	if fx == null or not is_instance_valid(fx):
		return
	fx.visible = false
	fx.modulate = Color(fx.modulate.r, fx.modulate.g, fx.modulate.b, 0.0)
	fx.rotation_degrees = 0.0
	fx.scale = Vector2.ONE
	var bucket: Array = _pool.get(key, [])
	if not bucket.has(fx):
		bucket.append(fx)
	_pool[key] = bucket


func clear() -> void:
	for bucket in _pool.values():
		for fx in bucket:
			if fx is TextureRect and is_instance_valid(fx):
				(fx as TextureRect).queue_free()
	_pool.clear()


func _take_from_pool(key: String) -> TextureRect:
	var bucket: Array = _pool.get(key, [])
	while not bucket.is_empty():
		var candidate = bucket.pop_back()
		if candidate is TextureRect and is_instance_valid(candidate):
			_pool[key] = bucket
			return candidate as TextureRect
	_pool[key] = bucket
	return null
