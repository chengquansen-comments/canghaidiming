extends SceneTree

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const AigcStoryBeatRuntime := preload("res://scripts/narrative/aigc_story_beat_runtime.gd")

const SAMPLE_PATH := "res://data/aigc_battle/story/story_beat_foundation_samples.json"
const SCHEMA_PATH := "res://data/aigc_battle/story/story_beat_schema.json"


func _init() -> void:
	if not FileAccess.file_exists(SCHEMA_PATH):
		push_error("Story beat schema missing: %s" % SCHEMA_PATH)
		quit(1)
		return
	var beats := _read_json_array(SAMPLE_PATH)
	if beats.is_empty():
		push_error("Story beat samples missing or empty")
		quit(1)
		return
	for item in beats:
		if not (item is Dictionary):
			push_error("Story beat sample item is not a Dictionary")
			quit(1)
			return
		var errors := AigcStoryBeatRuntime.validate_beat(item as Dictionary)
		if not errors.is_empty():
			push_error("Invalid story beat %s: %s" % [str((item as Dictionary).get("story_beat_id", "")), str(errors)])
			quit(1)
			return
	if not _validate_state_defaults():
		quit(1)
		return
	if not _validate_runtime_rules(beats):
		quit(1)
		return
	print("AIGC story beat runtime smoke: OK beats=%d" % beats.size())
	quit(0)


func _validate_state_defaults() -> bool:
	var state := StrategicMapState.default_state()
	for key in StrategicMapState.STORY_NUMERIC_FIELDS:
		if not state.has(key):
			push_error("Strategic default state missing numeric story field: %s" % key)
			return false
	for key in StrategicMapState.STORY_BOOLEAN_FIELDS:
		if not state.has(key):
			push_error("Strategic default state missing boolean story field: %s" % key)
			return false
	for key in ["triggered_story_beat_ids", "story_exclusive_groups", "story_cooldowns"]:
		if not state.has(key):
			push_error("Strategic default state missing story runtime field: %s" % key)
			return false
	state = StrategicMapState.apply_effects(state, {
		"gu_trust": 2,
		"gu_identity_known": true,
		"gu_affection": 1,
	})
	if int(state.get("gu_trust", 0)) != 2 or not bool(state.get("gu_identity_known", false)):
		push_error("Strategic story effects did not apply")
		return false
	state = StrategicMapState.apply_effects(state, {"gu_trust": -5})
	if int(state.get("gu_trust", -1)) != 0:
		push_error("Strategic story numeric effects should clamp at zero")
		return false
	return true


func _validate_runtime_rules(beats: Array) -> bool:
	var gu_beat := _find_beat(beats, "beat_reputation_gu_identity_mid_001")
	if gu_beat.is_empty():
		push_error("Missing Gu identity sample beat")
		return false
	var state := StrategicMapState.default_state()
	if AigcStoryBeatRuntime.is_beat_available(gu_beat, state):
		push_error("Gu identity beat should be locked before trust and identity requirements")
		return false
	state = StrategicMapState.apply_effects(state, {
		"gu_trust": 2,
		"gu_identity_known": true,
	})
	if not AigcStoryBeatRuntime.is_beat_available(gu_beat, state):
		push_error("Gu identity beat should become available after requirements")
		return false
	var filtered := AigcStoryBeatRuntime.filter_available_beats(beats, state, "mid", "reputation")
	if filtered.size() != 1:
		push_error("Expected exactly one available mid reputation beat, got %d" % filtered.size())
		return false
	state = AigcStoryBeatRuntime.apply_beat_to_state(state, gu_beat)
	if int(state.get("gu_affection", 0)) != 1 or int(state.get("public_reputation", 0)) != 1:
		push_error("Gu identity beat effects did not apply")
		return false
	if not ("beat_reputation_gu_identity_mid_001" in (state.get("triggered_story_beat_ids", []) as Array)):
		push_error("Triggered story beat id was not recorded")
		return false
	if not ("gu_identity_reveal_mid" in (state.get("story_exclusive_groups", []) as Array)):
		push_error("Story exclusive group was not recorded")
		return false
	if int((state.get("story_cooldowns", {}) as Dictionary).get("gu_private_scene", 0)) != 2:
		push_error("Story cooldown was not set")
		return false
	if AigcStoryBeatRuntime.is_beat_available(gu_beat, state):
		push_error("Triggered exclusive beat should not be available again")
		return false
	var sibling := gu_beat.duplicate(true)
	sibling["story_beat_id"] = "beat_reputation_gu_private_followup_mid_001"
	sibling["exclusive_group"] = "gu_private_followup_mid"
	if AigcStoryBeatRuntime.is_beat_available(sibling, state):
		push_error("Sibling beat should be blocked by cooldown")
		return false
	state = AigcStoryBeatRuntime.tick_cooldowns(state)
	if AigcStoryBeatRuntime.is_beat_available(sibling, state):
		push_error("Sibling beat should still be blocked after one cooldown tick")
		return false
	state = AigcStoryBeatRuntime.tick_cooldowns(state)
	if not AigcStoryBeatRuntime.is_beat_available(sibling, state):
		push_error("Sibling beat should be available after cooldown expires")
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	if AigcStoryBeatRuntime.pick_weighted_beat([sibling], rng).is_empty():
		push_error("Weighted story beat pick returned empty")
		return false
	return true


func _find_beat(beats: Array, beat_id: String) -> Dictionary:
	for item in beats:
		if item is Dictionary and str((item as Dictionary).get("story_beat_id", "")) == beat_id:
			return item as Dictionary
	return {}


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed as Array
	return []
