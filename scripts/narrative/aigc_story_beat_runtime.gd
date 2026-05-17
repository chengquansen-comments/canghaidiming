extends RefCounted

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")

const REQUIRED_FIELDS := [
	"story_beat_id",
	"route_line",
	"npc_focus",
	"phase",
	"node_type",
	"requirements",
	"effects",
	"exclusive_group",
	"cooldown_group",
	"cooldown_turns",
	"weight",
	"preview_text",
	"result_text",
	"followup_hooks",
]
const VALID_ROUTE_LINES := ["military", "reputation", "old_case", "cross"]
const VALID_PHASES := ["early", "mid", "late", "finale"]
const VALID_NODE_TYPES := ["military", "reputation", "case", "cross", "romance", "ending_setup"]


static func validate_beat(beat: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not beat.has(field):
			errors.append("missing_field:%s" % field)
	if not (str(beat.get("route_line", "")) in VALID_ROUTE_LINES):
		errors.append("invalid_route_line:%s" % str(beat.get("route_line", "")))
	if not (str(beat.get("phase", "")) in VALID_PHASES):
		errors.append("invalid_phase:%s" % str(beat.get("phase", "")))
	if not (str(beat.get("node_type", "")) in VALID_NODE_TYPES):
		errors.append("invalid_node_type:%s" % str(beat.get("node_type", "")))
	if not (beat.get("requirements", {}) is Dictionary):
		errors.append("requirements_not_dictionary")
	if not (beat.get("effects", {}) is Dictionary):
		errors.append("effects_not_dictionary")
	if not (beat.get("followup_hooks", []) is Array):
		errors.append("followup_hooks_not_array")
	if int(beat.get("weight", 0)) <= 0:
		errors.append("weight_not_positive")
	if int(beat.get("cooldown_turns", 0)) < 0:
		errors.append("cooldown_turns_negative")
	if beat.get("requirements", {}) is Dictionary:
		errors.append_array(_validate_requirements(beat.get("requirements", {}) as Dictionary))
	if beat.get("effects", {}) is Dictionary:
		errors.append_array(_validate_effects(beat.get("effects", {}) as Dictionary))
	return errors


static func filter_available_beats(beats: Array, state: Dictionary, phase: String = "", route_line: String = "") -> Array:
	var result: Array = []
	for item in beats:
		if not (item is Dictionary):
			continue
		var beat := item as Dictionary
		if not phase.is_empty() and str(beat.get("phase", "")) != phase:
			continue
		if not route_line.is_empty() and str(beat.get("route_line", "")) != route_line:
			continue
		if is_beat_available(beat, state):
			result.append(beat)
	return result


static func is_beat_available(beat: Dictionary, state: Dictionary) -> bool:
	if not validate_beat(beat).is_empty():
		return false
	var beat_id := str(beat.get("story_beat_id", ""))
	if beat_id in _string_array(state.get("triggered_story_beat_ids", [])):
		return false
	var exclusive_group := str(beat.get("exclusive_group", ""))
	if not exclusive_group.is_empty() and (exclusive_group in _string_array(state.get("story_exclusive_groups", []))):
		return false
	var cooldown_group := str(beat.get("cooldown_group", ""))
	var cooldowns: Dictionary = state.get("story_cooldowns", {}) as Dictionary
	if not cooldown_group.is_empty() and int(cooldowns.get(cooldown_group, 0)) > 0:
		return false
	return _requirements_met(beat.get("requirements", {}) as Dictionary, state)


static func apply_beat_to_state(state: Dictionary, beat: Dictionary) -> Dictionary:
	var next_state := StrategicMapState.apply_effects(state, beat.get("effects", {}) as Dictionary)
	var beat_id := str(beat.get("story_beat_id", ""))
	if not beat_id.is_empty():
		_append_unique(next_state, "triggered_story_beat_ids", beat_id)
	var exclusive_group := str(beat.get("exclusive_group", ""))
	if not exclusive_group.is_empty():
		_append_unique(next_state, "story_exclusive_groups", exclusive_group)
	var cooldown_group := str(beat.get("cooldown_group", ""))
	if not cooldown_group.is_empty():
		var cooldowns: Dictionary = (next_state.get("story_cooldowns", {}) as Dictionary).duplicate(true)
		cooldowns[cooldown_group] = int(beat.get("cooldown_turns", 0))
		next_state["story_cooldowns"] = cooldowns
	return next_state


static func tick_cooldowns(state: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	var cooldowns: Dictionary = (next_state.get("story_cooldowns", {}) as Dictionary).duplicate(true)
	for key in cooldowns.keys():
		var remaining := int(cooldowns.get(key, 0)) - 1
		if remaining > 0:
			cooldowns[key] = remaining
		else:
			cooldowns.erase(key)
	next_state["story_cooldowns"] = cooldowns
	return next_state


static func pick_weighted_beat(beats: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0
	for item in beats:
		if item is Dictionary:
			total_weight += max(0, int((item as Dictionary).get("weight", 0)))
	if total_weight <= 0:
		return {}
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for item in beats:
		if not (item is Dictionary):
			continue
		var beat := item as Dictionary
		cursor += max(0, int(beat.get("weight", 0)))
		if roll <= cursor:
			return beat
	return {}


static func _validate_requirements(requirements: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in requirements.keys():
		var field := _requirement_state_field(str(key))
		if not _is_known_state_field(field):
			errors.append("unknown_requirement:%s" % str(key))
	return errors


static func _validate_effects(effects: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in effects.keys():
		if not _is_known_effect_field(str(key)):
			errors.append("unknown_effect:%s" % str(key))
	return errors


static func _requirements_met(requirements: Dictionary, state: Dictionary) -> bool:
	for key_variant in requirements.keys():
		var key := str(key_variant)
		var expected = requirements.get(key_variant)
		var field := _requirement_state_field(key)
		var actual = state.get(field, null)
		if key.ends_with("_min"):
			if int(actual) < int(expected):
				return false
		elif key.ends_with("_max"):
			if int(actual) > int(expected):
				return false
		elif expected is Array:
			if not (actual in (expected as Array)):
				return false
		else:
			if actual != expected:
				return false
	return true


static func _requirement_state_field(key: String) -> String:
	if key.ends_with("_min") or key.ends_with("_max"):
		return key.substr(0, key.length() - 4)
	return key


static func _is_known_effect_field(field: String) -> bool:
	return (field in StrategicMapState.STORY_NUMERIC_FIELDS) or (field in StrategicMapState.STORY_BOOLEAN_FIELDS)


static func _is_known_state_field(field: String) -> bool:
	return _is_known_effect_field(field) or (field in [
		"martial_level",
		"lightness_level",
	])


static func _append_unique(state: Dictionary, field: String, value: String) -> void:
	var items := _string_array(state.get(field, []))
	if not (value in items):
		items.append(value)
	state[field] = items


static func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	elif value is String:
		var text := str(value)
		if not text.is_empty():
			result.append(text)
	return result
