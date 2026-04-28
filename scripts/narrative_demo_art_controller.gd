extends "res://scripts/narrative_demo_formal_controller.gd"

const PERFORMANCE_RATIO := 0.6667
const OPERATION_RATIO := 0.3333
const DRIFT_AMPLITUDE := Vector2(10.0, 5.0)
const DRIFT_SPEED := 0.18
const MIST_SPEED := 18.0

const PROLOGUE_BG := {
	"black_tide": "res://assets/pixel_battle/backgrounds/prologue_black_tide.png",
	"rescue": "res://assets/pixel_battle/backgrounds/prologue_master_rescue.png",
	"arrow": "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.png",
	"departure": "res://assets/pixel_battle/backgrounds/prologue_departure.png"
}

const PROLOGUE_BG_PNG := {
	"black_tide": "res://assets/pixel_battle/backgrounds/prologue_black_tide.png",
	"rescue": "res://assets/pixel_battle/backgrounds/prologue_master_rescue.png",
	"arrow": "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.png",
	"departure": "res://assets/pixel_battle/backgrounds/prologue_departure.png"
}

const PROLOGUE_CHAR := {
	"master": "res://assets/pixel_battle/portraits/performance_master_veteran.png",
	"hero": "res://assets/pixel_battle/portraits/performance_hero_young.png"
}

const PROLOGUE_CHAR_PNG := {
	"master": "res://assets/pixel_battle/portraits/performance_master_veteran.png",
	"hero": "res://assets/pixel_battle/portraits/performance_hero_young.png"
}

var background_texture: TextureRect
var mist_layer_a: ColorRect
var mist_layer_b: ColorRect
var background_dim: ColorRect
var char_master: TextureRect
var char_hero: TextureRect
var art_time: float = 0.0

func _ready() -> void:
	_add_scene_background_layer()
	_add_character_layers()
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	_update_performance_motion(delta)

func _render_visual(path: String, fallback_text: String) -> void:
	var final_path: String = _resolve_background_path(path)
	_update_scene_background(final_path, fallback_text)
	_update_character_stage()

func _resolve_background_path(path: String) -> String:
	if step_index <= 3:
		return _prefer_png(PROLOGUE_BG_PNG.black_tide, PROLOGUE_BG.black_tide)
	elif step_index <= 8:
		return _prefer_png(PROLOGUE_BG_PNG.rescue, PROLOGUE_BG.rescue)
	elif step_index <= 11:
		return _prefer_png(PROLOGUE_BG_PNG.arrow, PROLOGUE_BG.arrow)
	elif step_index == PROLOGUE_CAREER_STEP:
		return _prefer_png(PROLOGUE_BG_PNG.departure, PROLOGUE_BG.departure)
	return _prefer_png(_png_variant(path), path)

func _prefer_png(png_path: String, fallback_path: String) -> String:
	if not png_path.is_empty() and ResourceLoader.exists(png_path):
		return png_path
	return fallback_path

func _png_variant(path: String) -> String:
	if path.ends_with(".svg"):
		return path.replace(".svg", ".png")
	return ""

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

func _add_character_layers() -> void:
	char_master = _make_character_layer("NarrativeCharMaster", _prefer_png(PROLOGUE_CHAR_PNG.master, PROLOGUE_CHAR.master), 0.22, 0.57)
	add_child(char_master)
	move_child(char_master, 4)

	char_hero = _make_character_layer("NarrativeCharHero", _prefer_png(PROLOGUE_CHAR_PNG.hero, PROLOGUE_CHAR.hero), 0.58, 0.92)
	add_child(char_hero)
	move_child(char_hero, 5)

func _make_character_layer(layer_name: String, path: String, left_anchor: float, right_anchor: float) -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.name = layer_name
	layer.anchor_left = left_anchor
	layer.anchor_right = right_anchor
	layer.anchor_top = 0.12
	layer.anchor_bottom = PERFORMANCE_RATIO
	layer.offset_left = 0.0
	layer.offset_right = 0.0
	layer.offset_top = 0.0
	layer.offset_bottom = 0.0
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	if ResourceLoader.exists(path):
		var texture_resource: Resource = load(path)
		if texture_resource is Texture2D:
			layer.texture = texture_resource
	return layer

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

func _update_character_stage() -> void:
	if char_master != null:
		char_master.visible = false
	if char_hero != null:
		char_hero.visible = false
	if step_index <= 3:
		return
	elif step_index <= 8:
		if char_master != null:
			char_master.visible = true
	elif step_index <= 11:
		if char_master != null:
			char_master.visible = true
	elif step_index == PROLOGUE_CAREER_STEP:
		if char_hero != null:
			char_hero.visible = true

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
	_update_character_motion()

func _update_character_motion() -> void:
	if char_master != null and char_master.visible:
		var master_breath: float = 1.0 + 0.018 * sin(art_time * 1.05)
		char_master.scale = Vector2(master_breath, master_breath)
		char_master.position.y = 3.0 * sin(art_time * 0.8)
	if char_hero != null and char_hero.visible:
		var hero_breath: float = 1.0 + 0.014 * sin(art_time * 1.2)
		char_hero.scale = Vector2(hero_breath, hero_breath)
		char_hero.position.y = 2.0 * sin(art_time * 0.9)
