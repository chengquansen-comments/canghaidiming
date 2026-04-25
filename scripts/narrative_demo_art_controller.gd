extends "res://scripts/narrative_demo_formal_controller.gd"

const PERFORMANCE_RATIO := 0.6667
const OPERATION_RATIO := 0.3333
const BODY_AREA_SIZE := Vector2(0, 74)
const MAP_AREA_SIZE := Vector2(0, 48)
const SCENE_AREA_SIZE := Vector2(0, 38)
const MINI_VISUAL_FRAME_SIZE := Vector2(0, 20)

var background_texture: TextureRect
var background_dim: ColorRect
var operation_panel: PanelContainer

func _ready() -> void:
	_add_scene_background_layer()
	super._ready()
	_apply_art_layout_size()

func _render_visual(path: String, fallback_text: String) -> void:
	_apply_art_layout_size()
	_update_scene_background(path, fallback_text)
	if visual_texture != null:
		visual_texture.texture = null
		visual_texture.visible = false
	if visual_label != null:
		visual_label.visible = false
	if visual_debug_label != null:
		visual_debug_label.text = _background_debug_text(path)

func _render() -> void:
	super._render()
	_apply_art_layout_size()

func _add_scene_background_layer() -> void:
	background_texture = TextureRect.new()
	background_texture.name = "NarrativePerformanceBackground"
	background_texture.anchor_left = 0.0
	background_texture.anchor_top = 0.0
	background_texture.anchor_right = 1.0
	background_texture.anchor_bottom = PERFORMANCE_RATIO
	background_texture.offset_left = 0.0
	background_texture.offset_top = 0.0
	background_texture.offset_right = 0.0
	background_texture.offset_bottom = 0.0
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_texture)
	move_child(background_texture, 0)

	background_dim = ColorRect.new()
	background_dim.name = "NarrativePerformanceDim"
	background_dim.anchor_left = 0.0
	background_dim.anchor_top = 0.0
	background_dim.anchor_right = 1.0
	background_dim.anchor_bottom = PERFORMANCE_RATIO
	background_dim.offset_left = 0.0
	background_dim.offset_top = 0.0
	background_dim.offset_right = 0.0
	background_dim.offset_bottom = 0.0
	background_dim.color = Color(0.05, 0.045, 0.035, 0.20)
	background_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_dim)
	move_child(background_dim, 1)

func _update_scene_background(path: String, fallback_text: String) -> void:
	if background_texture == null:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		background_texture.texture = _make_fallback_background(fallback_text)
		background_texture.visible = true
		return
	var resource: Resource = load(path)
	if resource is Texture2D:
		background_texture.texture = resource
		background_texture.visible = true
	else:
		background_texture.texture = _make_fallback_background(fallback_text)
		background_texture.visible = true

func _make_fallback_background(text: String) -> Texture2D:
	var image: Image = Image.create(960, 640, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.78, 0.70, 0.55, 1.0))
	for y in range(390, 640):
		for x in range(0, 960):
			var alpha: float = float(y - 390) / 250.0
			image.set_pixel(x, y, Color(0.10, 0.12, 0.12, 0.55 + 0.25 * alpha))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture

func _background_debug_text(path: String) -> String:
	if path.is_empty():
		return "背景诊断：path=空｜表演区使用主视觉色底"
	if not ResourceLoader.exists(path):
		return "背景诊断：path=%s｜exists=false｜表演区使用主视觉色底" % path
	return "背景诊断：path=%s｜exists=true｜状态=上方2/3表演区背景" % path

func _apply_art_layout_size() -> void:
	# 剧情 UI 明确分割：上方 2/3 为表演区，下方 1/3 为选项/操作区。
	# 旧的小图区域只保留诊断；真正场景图铺在上方表演区。
	var viewport_size: Vector2 = get_viewport_rect().size
	var operation_height: float = max(230.0, viewport_size.y * OPERATION_RATIO)
	var performance_height: float = viewport_size.y - operation_height
	if background_texture != null:
		background_texture.anchor_bottom = performance_height / max(1.0, viewport_size.y)
	if background_dim != null:
		background_dim.anchor_bottom = performance_height / max(1.0, viewport_size.y)
	if map_label != null:
		map_label.custom_minimum_size = MAP_AREA_SIZE
	if scene_label != null:
		scene_label.custom_minimum_size = SCENE_AREA_SIZE
	if body_label != null:
		body_label.custom_minimum_size = BODY_AREA_SIZE
		body_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if action_scroll != null:
		action_scroll.custom_minimum_size = Vector2(0, max(150.0, operation_height - 150.0))
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if visual_texture != null:
		visual_texture.custom_minimum_size = Vector2(0, 0)
		visual_texture.visible = false
	if visual_label != null:
		visual_label.custom_minimum_size = Vector2(0, 0)
		visual_label.visible = false
	if visual_texture != null and visual_texture.get_parent() != null and visual_texture.get_parent().get_parent() != null:
		var frame: Node = visual_texture.get_parent().get_parent()
		if frame is Control:
			(frame as Control).custom_minimum_size = MINI_VISUAL_FRAME_SIZE

func _prologue_visual_hint() -> String:
	if step_index <= 3:
		return "主视觉背景：黑屏潮声 / 宣纸暗海 / 村火朱砂 / 远岸烟云"
	if step_index <= 8:
		return "主视觉背景：师父旧腰刀 / 童年主角 / 火光剪影 / 家国旧案"
	if step_index == PROLOGUE_CAREER_STEP:
		return "主视觉背景：青年明代武官 / 深绛红战袍 / 海疆出山 / 风起沧海"
	return "主视觉背景：暗箭 / 师父背影 / 海雾山路"

func _prologue_scene_hint() -> String:
	if step_index <= 3:
		return "序章美术：宣纸底色、黑墨海岸、远处村火、低垂烟云。"
	if step_index <= 8:
		return "序章美术：旧腰刀挡刀、童年主角倒地、火光剪影、悲壮克制。"
	if step_index == PROLOGUE_CAREER_STEP:
		return "出山美术：青年明代武官、深色札甲、深绛红战袍、海雾、远崖、家国情怀。"
	return "序章美术：暗箭灭口、师父沉默、海雾山路、旧案未尽。"
