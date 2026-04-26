extends "res://scripts/narrative_demo_formal_controller.gd"

const PERFORMANCE_RATIO: float = 0.6667
const OPERATION_BOTTOM: float = 0.99
const MIN_OPERATION_HEIGHT: float = 340.0
const PROLOGUE_BLACK_TIDE := "res://assets/pixel_battle/backgrounds/prologue_black_tide.svg"
const PROLOGUE_RESCUE := "res://assets/pixel_battle/backgrounds/prologue_master_rescue.svg"
const PROLOGUE_ARROW := "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.svg"
const PROLOGUE_DEPARTURE := "res://assets/pixel_battle/backgrounds/prologue_departure.svg"
const CHAR_MASTER := "res://assets/pixel_battle/portraits/performance_master_veteran.svg"
const CHAR_HERO := "res://assets/pixel_battle/portraits/performance_hero_young.svg"

const NODE_PERFORMANCE := {
	"military_order": {"zoom":0.018, "pan_x":3.0, "pan_y":-1.0, "dim":0.18, "mist":0.12, "fire":0.04, "hero":true, "hero_push":-5.0},
	"beach_ambush": {"zoom":0.030, "pan_x":10.0, "pan_y":-2.0, "dim":0.27, "mist":0.34, "fire":0.08, "hero":true, "hero_push":-9.0},
	"ming_firearm": {"zoom":0.026, "pan_x":-6.0, "pan_y":0.0, "dim":0.32, "mist":0.18, "fire":0.12, "hero":false, "hero_push":0.0},
	"transport_officer": {"zoom":0.024, "pan_x":6.0, "pan_y":-1.0, "dim":0.30, "mist":0.28, "fire":0.04, "hero":true, "hero_push":-6.0},
	"wakou_boss": {"zoom":0.036, "pan_x":12.0, "pan_y":-2.0, "dim":0.34, "mist":0.34, "fire":0.16, "hero":true, "hero_push":-10.0},
	"military_coverup": {"zoom":0.018, "pan_x":-4.0, "pan_y":0.0, "dim":0.42, "mist":0.14, "fire":0.02, "hero":false, "hero_push":0.0},
	"node": {"zoom":0.018, "pan_x":4.0, "pan_y":0.0, "dim":0.22, "mist":0.18, "fire":0.02, "hero":false, "hero_push":0.0}
}

var cinematic_bg: TextureRect
var cinematic_mist: ColorRect
var cinematic_fire: ColorRect
var cinematic_dim: ColorRect
var cinematic_focus: ColorRect
var cinematic_master: TextureRect
var cinematic_hero: TextureRect
var cinematic_time: float = 0.0
var cinematic_stage: String = ""
var cinematic_stage_time: float = 0.0

func _ready() -> void:
	_add_cinematic_layers()
	super._ready()
	_apply_cinematic_layout()

func _process(delta: float) -> void:
	cinematic_time += delta
	cinematic_stage_time += delta
	_update_cinematic_motion(delta)
	_apply_cinematic_layout()

func _render_visual(path: String, fallback_text: String) -> void:
	var resolved_path: String = _cinematic_background_path(path)
	var new_stage: String = _cinematic_stage_key()
	if new_stage != cinematic_stage:
		cinematic_stage = new_stage
		cinematic_stage_time = 0.0
	_update_cinematic_background(resolved_path)
	_update_cinematic_characters()
	_hide_inline_visual(resolved_path)
	_apply_cinematic_layout()

func _add_cinematic_layers() -> void:
	cinematic_bg = TextureRect.new()
	cinematic_bg.name = "CinematicPerformanceBackground"
	cinematic_bg.anchor_left = 0.0
	cinematic_bg.anchor_top = 0.0
	cinematic_bg.anchor_right = 1.0
	cinematic_bg.anchor_bottom = PERFORMANCE_RATIO
	cinematic_bg.offset_left = -18
	cinematic_bg.offset_top = -10
	cinematic_bg.offset_right = 18
	cinematic_bg.offset_bottom = 10
	cinematic_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cinematic_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cinematic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_bg)
	move_child(cinematic_bg, 0)

	cinematic_mist = ColorRect.new()
	cinematic_mist.name = "CinematicMistLayer"
	cinematic_mist.anchor_left = 0.0
	cinematic_mist.anchor_top = 0.0
	cinematic_mist.anchor_right = 1.0
	cinematic_mist.anchor_bottom = PERFORMANCE_RATIO
	cinematic_mist.offset_left = -260
	cinematic_mist.offset_right = 260
	cinematic_mist.color = Color(0.18, 0.20, 0.20, 0.20)
	cinematic_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_mist)
	move_child(cinematic_mist, 1)

	cinematic_fire = ColorRect.new()
	cinematic_fire.name = "CinematicFirePulse"
	cinematic_fire.anchor_left = 0.58
	cinematic_fire.anchor_top = 0.08
	cinematic_fire.anchor_right = 1.0
	cinematic_fire.anchor_bottom = PERFORMANCE_RATIO
	cinematic_fire.color = Color(0.55, 0.12, 0.08, 0.0)
	cinematic_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_fire)
	move_child(cinematic_fire, 2)

	cinematic_master = _make_character_layer("CinematicMaster", CHAR_MASTER, 0.20, 0.58)
	add_child(cinematic_master)
	move_child(cinematic_master, 3)

	cinematic_hero = _make_character_layer("CinematicHero", CHAR_HERO, 0.55, 0.92)
	add_child(cinematic_hero)
	move_child(cinematic_hero, 4)

	cinematic_dim = ColorRect.new()
	cinematic_dim.name = "CinematicDim"
	cinematic_dim.anchor_left = 0.0
	cinematic_dim.anchor_top = 0.0
	cinematic_dim.anchor_right = 1.0
	cinematic_dim.anchor_bottom = PERFORMANCE_RATIO
	cinematic_dim.color = Color(0.04, 0.035, 0.03, 0.20)
	cinematic_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_dim)
	move_child(cinematic_dim, 5)

	cinematic_focus = ColorRect.new()
	cinematic_focus.name = "CinematicFocus"
	cinematic_focus.anchor_left = 0.0
	cinematic_focus.anchor_top = 0.0
	cinematic_focus.anchor_right = 1.0
	cinematic_focus.anchor_bottom = PERFORMANCE_RATIO
	cinematic_focus.color = Color(0.03, 0.025, 0.02, 0.0)
	cinematic_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_focus)
	move_child(cinematic_focus, 6)

func _make_character_layer(layer_name: String, path: String, left_anchor: float, right_anchor: float) -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.name = layer_name
	layer.anchor_left = left_anchor
	layer.anchor_right = right_anchor
	layer.anchor_top = 0.10
	layer.anchor_bottom = PERFORMANCE_RATIO
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			layer.texture = resource
	return layer

func _current_node_id() -> String:
	if in_prologue:
		return "prologue"
	if node_index >= 0 and node_index < NODES.size():
		var node: Dictionary = NODES[node_index]
		return str(node.get("id", "node"))
	return "node"

func _cinematic_stage_key() -> String:
	if not in_prologue:
		return _current_node_id()
	if step_index <= 3:
		return "black_tide_%d" % step_index
	if step_index <= 8:
		return "master_rescue"
	if step_index <= 11:
		return "arrow_silence"
	if step_index == PROLOGUE_CAREER_STEP:
		return "departure"
	return "node"

func _cinematic_background_path(path: String) -> String:
	if not in_prologue:
		return path
	if step_index <= 3:
		return PROLOGUE_BLACK_TIDE
	if step_index <= 8:
		return PROLOGUE_RESCUE
	if step_index <= 11:
		return PROLOGUE_ARROW
	if step_index == PROLOGUE_CAREER_STEP:
		return PROLOGUE_DEPARTURE
	return path

func _node_performance_data(stage: String) -> Dictionary:
	var data_variant = NODE_PERFORMANCE.get(stage, NODE_PERFORMANCE["node"])
	if data_variant is Dictionary:
		return data_variant
	return NODE_PERFORMANCE["node"]

func _update_cinematic_background(path: String) -> void:
	if cinematic_bg == null:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var resource: Resource = load(path)
	if resource is Texture2D:
		cinematic_bg.texture = resource

func _update_cinematic_characters() -> void:
	if cinematic_master != null:
		cinematic_master.visible = false
	if cinematic_hero != null:
		cinematic_hero.visible = false
	var stage: String = _cinematic_stage_key()
	if stage == "master_rescue" or stage == "arrow_silence":
		if cinematic_master != null:
			cinematic_master.visible = true
	elif stage == "departure":
		if cinematic_hero != null:
			cinematic_hero.visible = true
	elif not in_prologue:
		var data: Dictionary = _node_performance_data(stage)
		if bool(data.get("hero", false)) and cinematic_hero != null:
			cinematic_hero.visible = true

func _hide_inline_visual(path: String) -> void:
	if visual_texture != null:
		visual_texture.texture = null
		visual_texture.visible = false
		visual_texture.custom_minimum_size = Vector2.ZERO
	if visual_label != null:
		visual_label.visible = false
		visual_label.custom_minimum_size = Vector2.ZERO
	if visual_debug_label != null:
		visual_debug_label.visible = false
		visual_debug_label.text = "演出诊断：single-file｜stage=%s｜path=%s" % [_cinematic_stage_key(), path]
	if visual_texture != null and visual_texture.get_parent() != null and visual_texture.get_parent().get_parent() != null:
		var frame: Node = visual_texture.get_parent().get_parent()
		if frame is Control:
			(frame as Control).custom_minimum_size = Vector2.ZERO

func _update_cinematic_motion(delta: float) -> void:
	var stage: String = _cinematic_stage_key()
	var progress: float = clamp(cinematic_stage_time / 3.0, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	if not in_prologue:
		_update_first_act_motion(stage, eased)
		return
	var zoom: float = 0.012 + 0.022 * eased
	var pan_x: float = 0.0
	var pan_y: float = 0.0
	var dim_alpha: float = 0.20
	var mist_alpha: float = 0.18
	var fire_alpha: float = 0.0
	if stage.begins_with("black_tide"):
		pan_x = -8.0 + 18.0 * eased
		pan_y = 2.0 - 3.0 * eased
		dim_alpha = 0.42 - 0.16 * eased + 0.035 * sin(cinematic_time * 0.9)
		mist_alpha = 0.18 + 0.22 * eased
		var flash: float = max(0.0, sin(cinematic_time * 2.1)) * 0.05
		if step_index >= 2:
			flash += max(0.0, sin(cinematic_time * 5.5)) * 0.05
		fire_alpha = clamp(0.02 + flash, 0.0, 0.18)
	elif stage == "master_rescue":
		pan_x = 8.0 * eased
		dim_alpha = 0.24 + 0.035 * sin(cinematic_time * 0.8)
		mist_alpha = 0.22
		fire_alpha = 0.14 * max(0.0, sin(cinematic_time * 2.6))
	elif stage == "arrow_silence":
		pan_x = -6.0 * eased
		dim_alpha = 0.34
		mist_alpha = 0.24
	elif stage == "departure":
		pan_x = 5.0 * eased
		dim_alpha = 0.18
		mist_alpha = 0.16
	_update_layer_motion(zoom, pan_x, pan_y, dim_alpha, mist_alpha, fire_alpha)

func _update_first_act_motion(stage: String, eased: float) -> void:
	var data: Dictionary = _node_performance_data(stage)
	var zoom: float = float(data.get("zoom", 0.018)) * eased
	var pan_x: float = float(data.get("pan_x", 0.0)) * eased
	var pan_y: float = float(data.get("pan_y", 0.0)) * eased
	var dim_base: float = float(data.get("dim", 0.22))
	var mist_base: float = float(data.get("mist", 0.18))
	var fire_base: float = float(data.get("fire", 0.02))
	var dim_alpha: float = dim_base + 0.030 * sin(cinematic_time * 0.75)
	var mist_alpha: float = mist_base + 0.055 * eased
	var fire_alpha: float = fire_base + fire_base * max(0.0, sin(cinematic_time * 2.4))
	_update_layer_motion(zoom, pan_x, pan_y, dim_alpha, mist_alpha, fire_alpha)

func _update_layer_motion(zoom: float, pan_x: float, pan_y: float, dim_alpha: float, mist_alpha: float, fire_alpha: float) -> void:
	if cinematic_bg != null:
		var breath: float = 0.004 * sin(cinematic_time * 0.42)
		cinematic_bg.scale = Vector2(1.0 + zoom + breath, 1.0 + zoom + breath)
		cinematic_bg.position = Vector2(pan_x, pan_y)
	if cinematic_mist != null:
		var mist_offset: float = fmod(cinematic_time * 22.0, 240.0)
		cinematic_mist.offset_left = -260.0 + mist_offset
		cinematic_mist.offset_right = 260.0 + mist_offset
		cinematic_mist.color = Color(0.18, 0.20, 0.20, clamp(mist_alpha, 0.0, 0.55))
	if cinematic_fire != null:
		cinematic_fire.color = Color(0.55, 0.12, 0.08, clamp(fire_alpha, 0.0, 0.24))
	if cinematic_dim != null:
		cinematic_dim.color = Color(0.04, 0.035, 0.03, clamp(dim_alpha, 0.0, 0.70))
	_update_character_motion(zoom)

func _update_character_motion(zoom: float) -> void:
	var stage: String = _cinematic_stage_key()
	var hero_push: float = -8.0
	if not in_prologue:
		var data: Dictionary = _node_performance_data(stage)
		hero_push = float(data.get("hero_push", -6.0))
	if cinematic_master != null and cinematic_master.visible:
		var s: float = 1.0 + zoom + 0.018 * sin(cinematic_time * 1.05)
		cinematic_master.scale = Vector2(s, s)
		cinematic_master.position.x = 10.0 * clamp(cinematic_stage_time / 2.8, 0.0, 1.0)
		cinematic_master.position.y = 3.0 * sin(cinematic_time * 0.8)
	if cinematic_hero != null and cinematic_hero.visible:
		var h: float = 1.0 + zoom + 0.014 * sin(cinematic_time * 1.2)
		cinematic_hero.scale = Vector2(h, h)
		cinematic_hero.position.x = hero_push * clamp(cinematic_stage_time / 3.0, 0.0, 1.0)
		cinematic_hero.position.y = 2.0 * sin(cinematic_time * 0.9)

func _apply_cinematic_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var operation_height: float = max(MIN_OPERATION_HEIGHT, viewport_size.y * (1.0 - PERFORMANCE_RATIO))
	var operation_top: float = max(0.48, OPERATION_BOTTOM - operation_height / max(1.0, viewport_size.y))
	var performance_bottom: float = operation_top
	if cinematic_bg != null:
		cinematic_bg.anchor_bottom = performance_bottom
	if cinematic_mist != null:
		cinematic_mist.anchor_bottom = performance_bottom
	if cinematic_fire != null:
		cinematic_fire.anchor_bottom = performance_bottom
	if cinematic_master != null:
		cinematic_master.anchor_bottom = performance_bottom
	if cinematic_hero != null:
		cinematic_hero.anchor_bottom = performance_bottom
	if cinematic_dim != null:
		cinematic_dim.anchor_bottom = performance_bottom
	if cinematic_focus != null:
		cinematic_focus.anchor_bottom = performance_bottom
	var root_panel: PanelContainer = _find_operation_panel()
	if root_panel != null:
		root_panel.anchor_left = 0.02
		root_panel.anchor_right = 0.98
		root_panel.anchor_top = operation_top
		root_panel.anchor_bottom = OPERATION_BOTTOM
		root_panel.offset_left = 0
		root_panel.offset_right = 0
		root_panel.offset_top = 0
		root_panel.offset_bottom = 0
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 21)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 13)
	if map_label != null:
		map_label.custom_minimum_size = Vector2(0, 0)
		map_label.visible = false
	if scene_label != null:
		scene_label.custom_minimum_size = Vector2(0, 0)
		scene_label.visible = false
	if body_label != null:
		body_label.custom_minimum_size = Vector2(0, 54)
		body_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body_label.add_theme_font_size_override("normal_font_size", 18)
	if vars_label != null:
		vars_label.add_theme_font_size_override("font_size", 13)
	if action_scroll != null:
		action_scroll.custom_minimum_size = Vector2(0, max(150.0, operation_height - 170.0))
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if action_content != null:
		action_content.add_theme_constant_override("separation", 4)

func _find_operation_panel() -> PanelContainer:
	for child: Node in get_children():
		if child is PanelContainer:
			return child as PanelContainer
	return null
