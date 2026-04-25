extends "res://scripts/narrative_demo_formal_controller.gd"

const PERFORMANCE_RATIO := 0.6667
const OPERATION_RATIO := 0.3333

const PROLOGUE_BG := {
	"black_tide": "res://assets/pixel_battle/backgrounds/prologue_black_tide.svg",
	"rescue": "res://assets/pixel_battle/backgrounds/prologue_master_rescue.svg",
	"arrow": "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.svg",
	"departure": "res://assets/pixel_battle/backgrounds/prologue_departure.svg"
}

var background_texture: TextureRect
var background_dim: ColorRect

func _ready() -> void:
	_add_scene_background_layer()
	super._ready()

func _render_visual(path: String, fallback_text: String) -> void:
	var final_path := _resolve_background_path(path)
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
	background_texture.anchor_left = 0.0
	background_texture.anchor_top = 0.0
	background_texture.anchor_right = 1.0
	background_texture.anchor_bottom = PERFORMANCE_RATIO
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background_texture)
	move_child(background_texture, 0)

	background_dim = ColorRect.new()
	background_dim.anchor_left = 0.0
	background_dim.anchor_top = 0.0
	background_dim.anchor_right = 1.0
	background_dim.anchor_bottom = PERFORMANCE_RATIO
	background_dim.color = Color(0.05,0.04,0.03,0.2)
	add_child(background_dim)
	move_child(background_dim, 1)

func _update_scene_background(path: String, fallback_text: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex = load(path)
	if tex is Texture2D:
		background_texture.texture = tex
