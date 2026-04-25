extends "res://scripts/narrative_demo_art_controller.gd"

const OPERATION_MIN_HEIGHT := 230.0
const PERFORMANCE_FADE_SECONDS := 0.42

var performance_fade: ColorRect
var last_performance_path: String = ""

func _ready() -> void:
	super._ready()
	_add_performance_fade_layer()
	_lock_performance_operation_layout()

func _process(delta: float) -> void:
	super._process(delta)
	_lock_performance_operation_layout()

func _render_visual(path: String, fallback_text: String) -> void:
	var final_path: String = _resolve_background_path(path)
	var changed: bool = final_path != last_performance_path
	super._render_visual(path, fallback_text)
	if changed:
		last_performance_path = final_path
		_play_performance_fade()
	_update_performance_debug(final_path)

func _add_performance_fade_layer() -> void:
	performance_fade = ColorRect.new()
	performance_fade.name = "NarrativePerformanceFade"
	performance_fade.anchor_left = 0.0
	performance_fade.anchor_top = 0.0
	performance_fade.anchor_right = 1.0
	performance_fade.anchor_bottom = PERFORMANCE_RATIO
	performance_fade.color = Color(0.03, 0.025, 0.02, 0.0)
	performance_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(performance_fade)
	move_child(performance_fade, min(get_child_count() - 1, 8))

func _play_performance_fade() -> void:
	if performance_fade == null:
		return
	performance_fade.color = Color(0.03, 0.025, 0.02, 0.72)
	var tween: Tween = create_tween()
	tween.tween_property(performance_fade, "color:a", 0.0, PERFORMANCE_FADE_SECONDS)

func _lock_performance_operation_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var operation_height: float = max(OPERATION_MIN_HEIGHT, viewport_size.y * OPERATION_RATIO)
	var performance_ratio: float = (viewport_size.y - operation_height) / max(1.0, viewport_size.y)
	if background_texture != null:
		background_texture.anchor_bottom = performance_ratio
	if mist_layer_a != null:
		mist_layer_a.anchor_bottom = performance_ratio
	if mist_layer_b != null:
		mist_layer_b.anchor_bottom = performance_ratio
	if background_dim != null:
		background_dim.anchor_bottom = performance_ratio
	if char_master != null:
		char_master.anchor_bottom = performance_ratio
	if char_hero != null:
		char_hero.anchor_bottom = performance_ratio
	if performance_fade != null:
		performance_fade.anchor_bottom = performance_ratio
	if action_scroll != null:
		action_scroll.custom_minimum_size = Vector2(0, max(150.0, operation_height - 150.0))
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if body_label != null:
		body_label.custom_minimum_size = Vector2(0, 72)
		body_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if map_label != null:
		map_label.custom_minimum_size = Vector2(0, 48)
	if scene_label != null:
		scene_label.custom_minimum_size = Vector2(0, 38)
	if visual_texture != null:
		visual_texture.visible = false
		visual_texture.custom_minimum_size = Vector2(0, 0)
	if visual_label != null:
		visual_label.visible = false
		visual_label.custom_minimum_size = Vector2(0, 0)

func _update_performance_debug(path: String) -> void:
	if visual_debug_label == null:
		return
	var stage: String = "black_tide"
	if step_index <= 3:
		stage = "black_tide"
	elif step_index <= 8:
		stage = "master_rescue"
	elif step_index <= 11:
		stage = "arrow_silence"
	elif step_index == PROLOGUE_CAREER_STEP:
		stage = "departure"
	else:
		stage = "node"
	visual_debug_label.text = "演出诊断：stage=%s｜path=%s｜layer=bg+mist+char+fade" % [stage, path]
