extends "res://scripts/narrative_demo_formal_controller.gd"

const PERFORMANCE_RATIO := 0.6667
const OPERATION_RATIO := 0.3333
const DRIFT_AMPLITUDE := Vector2(10.0, 5.0)
const DRIFT_SPEED := 0.18
const MIST_SPEED := 18.0

const PROLOGUE_BG := {
	"black_tide": "res://assets/pixel_battle/backgrounds/prologue_black_tide.svg",
	"rescue": "res://assets/pixel_battle/backgrounds/prologue_master_rescue.svg",
	"arrow": "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.svg",
	"departure": "res://assets/pixel_battle/backgrounds/prologue_departure.svg"
}

var background_texture: TextureRect
var mist_layer_a: ColorRect
var mist_layer_b: ColorRect
var background_dim: ColorRect
var art_time: float = 0.0

func _ready() -> void:
	_add_scene_background_layer()
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	_update_performance_motion(delta)

func _render_visual(path: String, fallback_text: String) -> void:
	var final_path: String = _resolve_background_path(path)
	_update_scene_background(final_path, fallback_text)

func _resolve_background_path(path: String) -> String:
	if step_index <= 3:
		return PROLOGUE_BG.black_tide
	elif step_index <= 8:
		return PROLOGUE_BG.rescue
	elif step_index <= 11:
		return PROLOGUE_BG.arrow
	elif step_index == PROLOGUE_CAREER_STEP:
		return PROLOGUE_BG.departure
	return path

func _add_scene_background_layer() -> void:
	background_texture = TextureRect.new()
	background_texture.name = "NarrativePerformanceBackground"
	background_texture.anchor_left = 0.0
	background_texture.anchor_top = 0.0
	background_texture.anchor_right = 1.0
	background_texture.anchor_bottom = PERFORMANCE_RATIO
	background_texture.offset_left = -14.0
	background_texture.offset_top = -8.0
	background_texture.offset_right = 14.0
	background_texture.offset_bottom = 8.0
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_texture)
	move_child(background_texture, 0)

	mist_layer_a = _make_mist_layer("NarrativeMistLayerA", 0.10, 0.18)
	add_child(mist_layer_a)
	move_child(mist_layer_a, 1)

	mist_layer_b = _make_mist_layer("NarrativeMistLayerB", 0.16, 0.12)
	add_child(mist_layer_b)
	move_child(mist_layer_b, 2)

	background_dim = ColorRect.new()
	background_dim.name = "NarrativePerformanceDim"
	background_dim.anchor_left = 0.0
	background_dim.anchor_top = 0.0
	background_dim.anchor_right = 1.0
	background_dim.anchor_bottom = PERFORMANCE_RATIO
	background_dim.color = Color(0.05, 0.04, 0.03, 0.18)
	background_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_dim)
	move_child(background_dim, 3)

func _make_mist_layer(layer_name: String, gray: float, alpha: float) -> ColorRect:
	var layer: ColorRect = ColorRect.new()
	layer.name = layer_name
	layer.anchor_left = 0.0
	layer.anchor_top = 0.0
	layer.anchor_right = 1.0
	layer.anchor_bottom = PERFORMANCE_RATIO
	layer.offset_left = -240.0
	layer.offset_right = 240.0
	layer.color = Color(gray, gray + 0.02, gray + 0.025, alpha)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer

func _update_scene_background(path: String, fallback_text: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex: Resource = load(path)
	if tex is Texture2D:
		background_texture.texture = tex

func _update_performance_motion(delta: float) -> void:
	art_time += delta
	var drift_x: float = sin(art_time * DRIFT_SPEED) * DRIFT_AMPLITUDE.x
	var drift_y: float = cos(art_time * DRIFT_SPEED * 0.7) * DRIFT_AMPLITUDE.y
	if background_texture != null:
		background_texture.offset_left = -14.0 + drift_x
		background_texture.offset_right = 14.0 + drift_x
		background_texture.offset_top = -8.0 + drift_y
		background_texture.offset_bottom = 8.0 + drift_y
	if mist_layer_a != null:
		mist_layer_a.offset_left = -240.0 + fmod(art_time * MIST_SPEED, 240.0)
		mist_layer_a.offset_right = 240.0 + fmod(art_time * MIST_SPEED, 240.0)
	if mist_layer_b != null:
		mist_layer_b.offset_left = -180.0 - fmod(art_time * MIST_SPEED * 0.55, 220.0)
		mist_layer_b.offset_right = 180.0 - fmod(art_time * MIST_SPEED * 0.55, 220.0)
	if background_dim != null:
		var pulse: float = 0.18 + 0.035 * sin(art_time * 0.9)
		background_dim.color = Color(0.05, 0.04, 0.03, pulse)
