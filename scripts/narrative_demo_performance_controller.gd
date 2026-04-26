extends "res://scripts/narrative_demo_art_controller.gd"

const OPERATION_MIN_HEIGHT := 230.0
const PERFORMANCE_FADE_SECONDS := 0.42

const BLACK_TIDE_RHYTHM := {
	0: {"dim": 0.42, "mist": 0.32, "speed": 0.55, "pulse": 0.020, "fade": 0.88},
	1: {"dim": 0.34, "mist": 0.42, "speed": 0.75, "pulse": 0.026, "fade": 0.66},
	2: {"dim": 0.29, "mist": 0.50, "speed": 1.00, "pulse": 0.034, "fade": 0.52},
	3: {"dim": 0.24, "mist": 0.58, "speed": 1.18, "pulse": 0.046, "fade": 0.42}
}

const STAGE_TIMELINE := {
	"black_tide_0": {"duration": 3.2, "zoom": 0.012, "pan_x": -8.0, "pan_y": 2.0, "mist_boost": 0.00, "fire_flash_at": -1.0},
	"black_tide_1": {"duration": 3.0, "zoom": 0.018, "pan_x": -4.0, "pan_y": 1.0, "mist_boost": 0.05, "fire_flash_at": 2.2},
	"black_tide_2": {"duration": 3.0, "zoom": 0.026, "pan_x": 4.0, "pan_y": 0.0, "mist_boost": 0.10, "fire_flash_at": 1.6},
	"black_tide_3": {"duration": 3.4, "zoom": 0.034, "pan_x": 10.0, "pan_y": -2.0, "mist_boost": 0.16, "fire_flash_at": 1.2},
	"master_rescue": {"duration": 2.8, "zoom": 0.020, "pan_x": 8.0, "pan_y": -1.0, "mist_boost": 0.04, "fire_flash_at": 0.4},
	"arrow_silence": {"duration": 2.4, "zoom": 0.015, "pan_x": -6.0, "pan_y": 0.0, "mist_boost": 0.02, "fire_flash_at": -1.0},
	"departure": {"duration": 3.0, "zoom": 0.018, "pan_x": 5.0, "pan_y": -1.0, "mist_boost": 0.00, "fire_flash_at": -1.0},
	"node": {"duration": 2.2, "zoom": 0.010, "pan_x": 3.0, "pan_y": 0.0, "mist_boost": 0.00, "fire_flash_at": -1.0}
}

var performance_fade: ColorRect
var shader_mist: ColorRect
var fire_pulse: ColorRect
var last_performance_path: String = ""
var last_stage_key: String = ""
var director_time: float = 0.0
var current_rhythm_dim: float = 0.18
var current_rhythm_mist: float = 0.18
var current_rhythm_speed: float = 1.0
var current_rhythm_pulse: float = 0.035
var timeline_fire_boost: float = 0.0

func _ready() -> void:
	super._ready()
	_add_shader_mist_layer()
	_add_fire_pulse_layer()
	_add_performance_fade_layer()
	_lock_performance_operation_layout()

func _process(delta: float) -> void:
	super._process(delta)
	director_time += delta
	_apply_black_tide_rhythm()
	_update_director_timeline(delta)
	_update_shader_mist(delta)
	_update_fire_pulse(delta)
	_lock_performance_operation_layout()

func _render_visual(path: String, fallback_text: String) -> void:
	var final_path: String = _resolve_background_path(path)
	var stage_key: String = _current_stage_key()
	var changed: bool = final_path != last_performance_path or stage_key != last_stage_key
	super._render_visual(path, fallback_text)
	if changed:
		last_performance_path = final_path
		last_stage_key = stage_key
		_reset_director_track()
		_play_performance_fade()
	_update_performance_debug(final_path)

func _current_stage_key() -> String:
	if step_index <= 3:
		return "black_tide_%d" % step_index
	elif step_index <= 8:
		return "master_rescue"
	elif step_index <= 11:
		return "arrow_silence"
	elif step_index == PROLOGUE_CAREER_STEP:
		return "departure"
	return "node"

func _reset_director_track() -> void:
	director_time = 0.0
	timeline_fire_boost = 0.0
	if background_texture != null:
		background_texture.scale = Vector2.ONE
		background_texture.position = Vector2.ZERO
	if char_master != null:
		char_master.scale = Vector2.ONE
		char_master.position = Vector2.ZERO
	if char_hero != null:
		char_hero.scale = Vector2.ONE
		char_hero.position = Vector2.ZERO

func _stage_data() -> Dictionary:
	var key: String = _current_stage_key()
	return STAGE_TIMELINE.get(key, STAGE_TIMELINE["node"])

func _timeline_progress() -> float:
	var data: Dictionary = _stage_data()
	var duration: float = max(0.1, float(data.get("duration", 2.0)))
	return clamp(director_time / duration, 0.0, 1.0)

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _update_director_timeline(delta: float) -> void:
	var data: Dictionary = _stage_data()
	var progress: float = _ease_in_out(_timeline_progress())
	var zoom: float = float(data.get("zoom", 0.01)) * progress
	var pan_x: float = float(data.get("pan_x", 0.0)) * progress
	var pan_y: float = float(data.get("pan_y", 0.0)) * progress
	if background_texture != null:
		var breath: float = 0.004 * sin(art_time * 0.42)
		background_texture.scale = Vector2(1.0 + zoom + breath, 1.0 + zoom + breath)
		background_texture.position = Vector2(pan_x, pan_y)
	var fire_at: float = float(data.get("fire_flash_at", -1.0))
	if fire_at >= 0.0:
		var dist: float = abs(director_time - fire_at)
		var flash: float = clamp(1.0 - dist / 0.32, 0.0, 1.0)
		timeline_fire_boost = max(timeline_fire_boost * 0.86, flash * flash * 0.22)
	else:
		timeline_fire_boost *= 0.84

func _add_shader_mist_layer() -> void:
	shader_mist = ColorRect.new()
	shader_mist.name = "NarrativeShaderMist"
	shader_mist.anchor_left = 0.0
	shader_mist.anchor_top = 0.0
	shader_mist.anchor_right = 1.0
	shader_mist.anchor_bottom = PERFORMANCE_RATIO
	shader_mist.color = Color(1, 1, 1, 1)
	shader_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_mist.material = _make_mist_shader_material()
	add_child(shader_mist)
	move_child(shader_mist, min(get_child_count() - 1, 4))

func _make_mist_shader_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float time = 0.0;
uniform float mist_alpha = 0.35;
uniform float drift_speed = 1.0;
uniform vec4 mist_color : source_color = vec4(0.68, 0.72, 0.70, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * vec2(4.2, 1.6);
	p.x += time * 0.045 * drift_speed;
	p.y += sin(time * 0.16 + uv.x * 5.0) * 0.08;
	float n1 = noise(p);
	float n2 = noise(p * 2.3 + vec2(time * 0.025 * drift_speed, 0.0));
	float band = smoothstep(0.10, 0.85, 1.0 - abs(uv.y - 0.55) * 1.8);
	float alpha = smoothstep(0.42, 0.90, n1 * 0.65 + n2 * 0.35) * band * mist_alpha;
	COLOR = vec4(mist_color.rgb, alpha);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("time", 0.0)
	material.set_shader_parameter("mist_alpha", current_rhythm_mist)
	material.set_shader_parameter("drift_speed", current_rhythm_speed)
	return material

func _add_fire_pulse_layer() -> void:
	fire_pulse = ColorRect.new()
	fire_pulse.name = "NarrativeFirePulse"
	fire_pulse.anchor_left = 0.58
	fire_pulse.anchor_top = 0.08
	fire_pulse.anchor_right = 1.0
	fire_pulse.anchor_bottom = PERFORMANCE_RATIO
	fire_pulse.color = Color(0.55, 0.12, 0.08, 0.0)
	fire_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fire_pulse)
	move_child(fire_pulse, min(get_child_count() - 1, 5))

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
	move_child(performance_fade, min(get_child_count() - 1, 9))

func _play_performance_fade() -> void:
	if performance_fade == null:
		return
	var rhythm: Dictionary = _current_black_tide_rhythm()
	var fade_alpha: float = float(rhythm.get("fade", 0.72))
	performance_fade.color = Color(0.03, 0.025, 0.02, fade_alpha)
	var tween: Tween = create_tween()
	tween.tween_property(performance_fade, "color:a", 0.0, PERFORMANCE_FADE_SECONDS)

func _current_black_tide_rhythm() -> Dictionary:
	if step_index >= 0 and step_index <= 3:
		return BLACK_TIDE_RHYTHM.get(step_index, BLACK_TIDE_RHYTHM[0])
	return {"dim": 0.18, "mist": 0.24, "speed": 0.75, "pulse": 0.018, "fade": 0.42}

func _apply_black_tide_rhythm() -> void:
	var rhythm: Dictionary = _current_black_tide_rhythm()
	var timeline_data: Dictionary = _stage_data()
	current_rhythm_dim = float(rhythm.get("dim", 0.18))
	current_rhythm_mist = float(rhythm.get("mist", 0.24)) + float(timeline_data.get("mist_boost", 0.0)) * _timeline_progress()
	current_rhythm_speed = float(rhythm.get("speed", 0.75))
	current_rhythm_pulse = float(rhythm.get("pulse", 0.018))
	if background_dim != null:
		var pulse_alpha: float = current_rhythm_dim + current_rhythm_pulse * sin(art_time * 0.9)
		background_dim.color = Color(0.05, 0.04, 0.03, clamp(pulse_alpha, 0.05, 0.75))

func _update_shader_mist(delta: float) -> void:
	if shader_mist == null or shader_mist.material == null:
		return
	var material: ShaderMaterial = shader_mist.material as ShaderMaterial
	material.set_shader_parameter("time", art_time)
	material.set_shader_parameter("mist_alpha", current_rhythm_mist)
	material.set_shader_parameter("drift_speed", current_rhythm_speed)
	shader_mist.visible = true

func _update_fire_pulse(delta: float) -> void:
	if fire_pulse == null:
		return
	var active: bool = step_index >= 0 and step_index <= 3
	fire_pulse.visible = active
	if not active:
		fire_pulse.color = Color(0.55, 0.12, 0.08, 0.0)
		return
	var flicker: float = 0.045 + 0.035 * max(0.0, sin(art_time * 2.1)) + 0.018 * max(0.0, sin(art_time * 5.7))
	if step_index >= 2:
		flicker += 0.035
	flicker += timeline_fire_boost
	fire_pulse.color = Color(0.55, 0.12, 0.08, clamp(flicker, 0.0, 0.32))

func _lock_performance_operation_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var operation_height: float = max(OPERATION_MIN_HEIGHT, viewport_size.y * OPERATION_RATIO)
	var performance_ratio: float = (viewport_size.y - operation_height) / max(1.0, viewport_size.y)
	if background_texture != null:
		background_texture.anchor_bottom = performance_ratio
	if mist_layer_a != null:
		mist_layer_a.anchor_bottom = performance_ratio
		mist_layer_a.visible = false
	if mist_layer_b != null:
		mist_layer_b.anchor_bottom = performance_ratio
		mist_layer_b.visible = false
	if shader_mist != null:
		shader_mist.anchor_bottom = performance_ratio
	if fire_pulse != null:
		fire_pulse.anchor_bottom = performance_ratio
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
	var stage: String = _current_stage_key()
	visual_debug_label.text = "演出诊断：stage=%s｜t=%.2f｜path=%s｜director=on｜zoom=on｜shader_mist=on｜dim=%.2f｜mist=%.2f｜speed=%.2f" % [stage, director_time, path, current_rhythm_dim, current_rhythm_mist, current_rhythm_speed]
