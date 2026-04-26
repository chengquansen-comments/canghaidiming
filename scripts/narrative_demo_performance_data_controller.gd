extends "res://scripts/narrative_demo_performance_controller.gd"

const PERFORMANCE_TRACKS_PATH := "res://data/performance_tracks.json"

var performance_tracks: Dictionary = {}
var performance_tracks_loaded: bool = false

func _ready() -> void:
	_load_performance_tracks()
	super._ready()

func _load_performance_tracks() -> void:
	performance_tracks_loaded = false
	performance_tracks.clear()
	if not FileAccess.file_exists(PERFORMANCE_TRACKS_PATH):
		return
	var file: FileAccess = FileAccess.open(PERFORMANCE_TRACKS_PATH, FileAccess.READ)
	if file == null:
		return
	var raw_text: String = file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		performance_tracks = parsed
		performance_tracks_loaded = true

func _stage_data() -> Dictionary:
	if performance_tracks_loaded:
		var timeline_variant = performance_tracks.get("timeline", {})
		if timeline_variant is Dictionary:
			var timeline: Dictionary = timeline_variant
			var key: String = _current_stage_key()
			if timeline.has(key):
				var data_variant = timeline.get(key, {})
				if data_variant is Dictionary:
					return data_variant
			if timeline.has("node"):
				var fallback_variant = timeline.get("node", {})
				if fallback_variant is Dictionary:
					return fallback_variant
	return super._stage_data()

func _current_black_tide_rhythm() -> Dictionary:
	if performance_tracks_loaded and step_index >= 0 and step_index <= 3:
		var rhythm_variant = performance_tracks.get("rhythm", {})
		if rhythm_variant is Dictionary:
			var rhythm: Dictionary = rhythm_variant
			var key: String = str(step_index)
			if rhythm.has(key):
				var data_variant = rhythm.get(key, {})
				if data_variant is Dictionary:
					return data_variant
	return super._current_black_tide_rhythm()

func _beat_value(beat_type: String, width: float = 0.28) -> float:
	if not performance_tracks_loaded:
		return super._beat_value(beat_type, width)
	var beats_variant = performance_tracks.get("beats", {})
	if not (beats_variant is Dictionary):
		return super._beat_value(beat_type, width)
	var beats: Dictionary = beats_variant
	var stage_key: String = _current_stage_key()
	var events_variant = beats.get(stage_key, [])
	if not (events_variant is Array):
		return 0.0
	var events: Array = events_variant
	var value: float = 0.0
	for event_variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		if str(event.get("type", "")) != beat_type:
			continue
		var t: float = float(event.get("t", 0.0))
		var power: float = float(event.get("power", 0.0))
		var distance: float = abs(director_time - t)
		var pulse: float = clamp(1.0 - distance / width, 0.0, 1.0)
		value = max(value, pulse * pulse * power)
	return value

func _update_performance_debug(path: String) -> void:
	if visual_debug_label == null:
		return
	var source: String = "json" if performance_tracks_loaded else "code"
	visual_debug_label.text = "演出诊断：stage=%s｜source=%s｜t=%.2f｜beat=%.2f/%.2f/%.2f/%.2f｜path=%s" % [
		_current_stage_key(),
		source,
		director_time,
		beat_fire_boost,
		beat_mist_boost,
		beat_focus_boost,
		beat_character_boost,
		path
	]
