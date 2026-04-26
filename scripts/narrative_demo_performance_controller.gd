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
	"black_tide_0": {"duration": 3.2, "zoom": 0.012, "pan_x": -8.0, "pan_y": 2.0, "mist_boost": 0.00, "fire_flash_at": -1.0, "focus_x": 0.52, "focus_y": 0.50, "focus_radius": 0.58, "focus_dark": 0.18},
	"black_tide_1": {"duration": 3.0, "zoom": 0.018, "pan_x": -4.0, "pan_y": 1.0, "mist_boost": 0.05, "fire_flash_at": 2.2, "focus_x": 0.70, "focus_y": 0.42, "focus_radius": 0.48, "focus_dark": 0.22},
	"black_tide_2": {"duration": 3.0, "zoom": 0.026, "pan_x": 4.0, "pan_y": 0.0, "mist_boost": 0.10, "fire_flash_at": 1.6, "focus_x": 0.76, "focus_y": 0.36, "focus_radius": 0.42, "focus_dark": 0.26},
	"black_tide_3": {"duration": 3.4, "zoom": 0.034, "pan_x": 10.0, "pan_y": -2.0, "mist_boost": 0.16, "fire_flash_at": 1.2, "focus_x": 0.78, "focus_y": 0.34, "focus_radius": 0.38, "focus_dark": 0.30},
	"master_rescue": {"duration": 2.8, "zoom": 0.020, "pan_x": 8.0, "pan_y": -1.0, "mist_boost": 0.04, "fire_flash_at": 0.4, "focus_x": 0.40, "focus_y": 0.50, "focus_radius": 0.42, "focus_dark": 0.24, "char_zoom": 0.035, "char_push_x": 10.0},
	"arrow_silence": {"duration": 2.4, "zoom": 0.015, "pan_x": -6.0, "pan_y": 0.0, "mist_boost": 0.02, "fire_flash_at": -1.0, "focus_x": 0.48, "focus_y": 0.43, "focus_radius": 0.36, "focus_dark": 0.34, "char_zoom": 0.012, "char_push_x": -4.0},
	"departure": {"duration": 3.0, "zoom": 0.018, "pan_x": 5.0, "pan_y": -1.0, "mist_boost": 0.00, "fire_flash_at": -1.0, "focus_x": 0.66, "focus_y": 0.48, "focus_radius": 0.45, "focus_dark": 0.20, "char_zoom": 0.026, "char_push_x": -8.0},
	"node": {"duration": 2.2, "zoom": 0.010, "pan_x": 3.0, "pan_y": 0.0, "mist_boost": 0.00, "fire_flash_at": -1.0, "focus_x": 0.50, "focus_y": 0.50, "focus_radius": 0.60, "focus_dark": 0.14}
}

const STAGE_BEATS := {
	"black_tide_0": [
		{"t": 0.25, "type": "hold", "power": 0.10},
		{"t": 2.30, "type": "mist", "power": 0.08}
	],
	"black_tide_1": [
		{"t": 0.50, "type": "mist", "power": 0.09},
		{"t": 2.20, "type": "fire", "power": 0.16}
	],
	"black_tide_2": [
		{"t": 0.70, "type": "mist", "power": 0.12},
		{"t": 1.60, "type": "fire", "power": 0.24},
		{"t": 2.20, "type": "focus", "power": 0.10}
	],
	"black_tide_3": [
		{"t": 0.35, "type": "mist", "power": 0.15},
		{"t": 1.20, "type": "fire", "power": 0.28},
		{"t": 2.10, "type": "hold", "power": 0.12}
	],
	"master_rescue": [
		{"t": 0.25, "type": "fire", "power": 0.24},
		{"t": 0.65, "type": "character", "power": 0.16},
		{"t": 1.65, "type": "focus", "power": 0.10}
	],
	"arrow_silence": [
		{"t": 0.40, "type": "hold", "power": 0.18},
		{"t": 1.10, "type": "focus", "power": 0.12}
	],
	"departure": [
		{"t": 0.45, "type": "character", "power": 0.10},
		{"t": 1.40, "type": "mist", "power": 0.06}
	],
	"node": []
}

var performance_fade: ColorRect
var shader_mist: ColorRect
var fire_pulse: ColorRect
var focus_vignette: ColorRect
var last_performance_path: String = ""
var last_stage_key: String = ""
var director_time: float = 0.0
var current_rhythm_dim: float = 0.18
var current_rhythm_mist: float = 0.18
var current_rhythm_speed: float = 1.0
var current_rhythm_pulse: float = 0.035
var timeline_fire_boost: float = 0.0
var beat_fire_boost: float = 0.0
var beat_mist_boost: float = 0.0
var beat_focus_boost: float = 0.0
var beat_character_boost: float = 0.0
var beat_hold_boost: float = 0.0

func _ready() -> void:
	super._ready()
	_add_shader_mist_layer()
	_add_fire_pulse_layer()
	_add_focus_vignette_layer()
	_add_performance_fade_layer()
	_lock_performance_operation_layout()

func _process(delta: float) -> void:
	super._process(delta)
	director_time += delta
	_update_beat_values()
	_apply_black_tide_rhythm()
	_update_director_timeline(delta)
	_update_shader_mist(delta)
	_update_fire_pulse(delta)
	_update_focus_control(delta)
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
	beat_fire_boost = 0.0
	beat_mist_boost = 0.0
	beat_focus_boost = 0.0
	beat_character_boost = 0.0
	beat_hold_boost = 0.0
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

func _beat_value(beat_type: String, width: float = 0.28) -> float:
	var stage_key: String = _current_stage_key()
	var events: Array = STAGE_BEATS.get(stage_key, [])
	var value: float = 0.0
	for event_variant in events:
		var event: Dictionary = event_variant
		if str(event.get("type", "")) != beat_type:
			continue
		var t: float = float(event.get("t", 0.0))
		var power: float = float(event.get("power", 0.0))
		var distance: float = abs(director_time - t)
		var pulse: float = clamp(1.0 - distance / width, 0.0, 1.0)
		value = max(value, pulse * pulse * power)
	return value

func _update_beat_values() -> void:
	beat_fire_boost = _beat_value("fire", 0.34)
	beat_mist_boost = _beat_value("mist", 0.44)
	beat_focus_boost = _beat_value("focus", 0.42)
	beat_character_boost = _beat_value("character", 0.46)
	beat_hold_boost = _beat_value("hold", 0.55)

func _update_director_timeline(delta: float) -> void:
	var data: Dictionary = _stage_data()
	var progress: float = _ease_in_out(_timeline_progress())
	var zoom: float = float(data.get("zoom", 0.01)) * progress
	var pan_x: float = float(data.get("pan_x", 0.0)) * progress
	var pan_y: float = float(data.get("pan_y", 0.0)) * progress
	if background_texture != null:
		var hold_drag: float = 1.0 - clamp(beat_hold_boost * 1.8, 0.0, 0.45)
		var breath: float = 0.004 * sin(art_time * 0.42)
		background_texture.scale = Vector2(1.0 + zoom + breath, 1.0 + zoom + breath)
		background_texture.position = Vector2(pan_x * hold_drag, pan_y * hold_drag)
	_update_character_camera(progress)
	var fire_at: float = float(data.get("fire_flash_at", -1.0))
	if fire_at >= 0.0:
		var dist: float = abs(director_time - fire_at)
		var flash: float = clamp(1.0 - dist / 0.32, 0.0, 1.0)
		timeline_fire_boost = max(timeline_fire_boost * 0.86, flash * flash * 0.22)
	else:
		timeline_fire_boost *= 0.84

func _update_character_camera(progress: float) -> void:
	var data: Dictionary = _stage_data()
	var char_zoom: float = float(data.get("char_zoom", 0.0)) * progress + beat_character_boost
	var char_push_x: float = float(data.get("char_push_x", 0.0)) * progress
	if char_master != null and char_master.visible:
		var master_breath: float = 1.0 + 0.018 * sin(art_time * 1.05)
		char_master.scale = Vector2(master_breath + char_zoom, master_breath + char_zoom)
		char_master.position.x = char_push_x
		char_master.position.y = 3.0 * sin(art_time * 0.8)
	if char_hero != null and char_hero.visible:
		var hero_breath: float = 1.0 + 0.014 * sin(art_time * 1.2)
		char_hero.scale = Vector2(hero_breath + char_zoom, hero_breath + char_zoom)
		char_hero.position.x = char_push_x
		char_hero.position.y = 2.0 * sin(art_time * 0.9)

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

func _add_focus_vignette_layer() -> void:
	focus_vignette = ColorRect.new()
	focus_vignette.name = "NarrativeFocusVignette"
	focus_vignette.anchor_left = 0.0
	focus_vignette.anchor_top = 0.0
	focus_vignette.anchor_right = 1.0
	focus_vignette.anchor_bottom = PERFORMANCE_RATIO
	focus_vignette.color = Color(1, 1, 1, 1)
	focus_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_vignette.material = _make_focus_shader_material()
	add_child(focus_vignette)
	move_child(focus_vignette, min(get_child_count() - 1, 8))

func _make_focus_shader_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 focus = vec2(0.5, 0.5);
uniform float radius = 0.52;
uniform float dark_alpha = 0.20;

void fragment() {
	float d = distance(UV, focus);
	float a = smoothstep(radius * 0.55, radius, d) * dark_alpha;
	COLOR = vec4(0.02, 0.017, 0.014, a);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("focus", Vector2(0.5, 0.5))
	material.set_shader_parameter("radius", 0.52)
	material.set_shader_parameter("dark_alpha", 0.20)
	return material

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
	current_rhythm_dim = float(rhythm.get("dim", 0.18)) + beat_hold_boost * 0.22
	current_rhythm_mist = float(rhythm.get("mist", 0.24)) + float(timeline_data.get("mist_boost", 0.0)) * _timeline_progress() + beat_mist_boost
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
	flicker += timeline_fire_boost + beat_fire_boost
	fire_pulse.color = Color(0.55, 0.12, 0.08, clamp(flicker, 0.0, 0.36))

func _update_focus_control(delta: float) -> void:
	if focus_vignette == null or focus_vignette.material == null:
		return
	var data: Dictionary = _stage_data()
	var material: ShaderMaterial = focus_vignette.material as ShaderMaterial
	var focus_x: float = float(data.get("focus_x", 0.5))
	var focus_y: float = float(data.get("focus_y", 0.5))
	var radius: float = float(data.get("focus_radius", 0.52))
	var dark_alpha: float = float(data.get("focus_dark", 0.20)) + beat_focus_boost
	material.set_shader_parameter("focus", Vector2(focus_x, focus_y))
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("dark_alpha", clamp(dark_alpha, 0.0, 0.48))

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
	if focus_vignette != null:
		focus_vignette.anchor_bottom = performance_ratio
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
	visual_debug_label.text = "演出诊断：stage=%s｜t=%.2f｜beat(fire/mist/focus/char)=%.2f/%.2f/%.2f/%.2f｜path=%s｜director=on｜focus=on" % [stage, director_time, beat_fire_boost, beat_mist_boost, beat_focus_boost, beat_character_boost, path]
