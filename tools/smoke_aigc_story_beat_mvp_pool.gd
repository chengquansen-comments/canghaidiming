extends SceneTree

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const AigcStoryBeatRuntime := preload("res://scripts/narrative/aigc_story_beat_runtime.gd")

const EXPECTED_BEAT_COUNT := 62
const EXPECTED_ROUTE_COUNTS := {
	"military": 14,
	"reputation": 14,
	"old_case": 14,
	"cross": 20,
}
const EXPECTED_PHASE_COUNTS := {
	"early": 16,
	"mid": 18,
	"late": 18,
	"finale": 10,
}
const REQUIRED_ENDING_HOOKS := [
	"ending_high_office",
	"ending_people_support",
	"ending_truth",
	"ending_military_infighting",
	"ending_gu_identity_storm",
	"ending_lonely_official",
	"ending_smeared_truth",
	"ending_truth_suppressed",
	"ending_open_sea",
	"ending_true_route",
]


func _init() -> void:
	var beats := AigcStoryBeatRuntime.load_pool(AigcStoryBeatRuntime.MVP_POOL_PATH)
	if not _validate_pool(beats):
		quit(1)
		return
	if not _validate_runtime_availability(beats):
		quit(1)
		return
	print("AIGC story beat MVP pool smoke: OK beats=%d" % beats.size())
	quit(0)


func _validate_pool(beats: Array) -> bool:
	if beats.size() != EXPECTED_BEAT_COUNT:
		push_error("Expected %d MVP story beats, got %d" % [EXPECTED_BEAT_COUNT, beats.size()])
		return false
	var seen_ids: Dictionary = {}
	var route_counts: Dictionary = {}
	var phase_counts: Dictionary = {}
	var ending_hooks: Dictionary = {}
	var identity_path_groups: Dictionary = {}
	for item in beats:
		if not (item is Dictionary):
			push_error("MVP story beat item is not a Dictionary")
			return false
		var beat := item as Dictionary
		var beat_id := str(beat.get("story_beat_id", ""))
		if seen_ids.has(beat_id):
			push_error("Duplicate story_beat_id: %s" % beat_id)
			return false
		seen_ids[beat_id] = true
		var errors := AigcStoryBeatRuntime.validate_beat(beat)
		if not errors.is_empty():
			push_error("Invalid MVP story beat %s: %s" % [beat_id, str(errors)])
			return false
		_count(route_counts, str(beat.get("route_line", "")))
		_count(phase_counts, str(beat.get("phase", "")))
		for hook in beat.get("followup_hooks", []):
			ending_hooks[str(hook)] = true
			if str(hook).find("gu_identity") >= 0:
				identity_path_groups[str(beat.get("exclusive_group", beat_id))] = true
		var effects: Dictionary = beat.get("effects", {}) as Dictionary
		var requirements: Dictionary = beat.get("requirements", {}) as Dictionary
		if effects.has("gu_identity_public_risk") or requirements.has("gu_identity_known") or str(beat.get("exclusive_group", "")).find("gu_identity") >= 0:
			identity_path_groups[str(beat.get("exclusive_group", beat_id))] = true
	for route in EXPECTED_ROUTE_COUNTS.keys():
		if int(route_counts.get(route, 0)) != int(EXPECTED_ROUTE_COUNTS[route]):
			push_error("Unexpected route count for %s: %d" % [route, int(route_counts.get(route, 0))])
			return false
	for phase in EXPECTED_PHASE_COUNTS.keys():
		if int(phase_counts.get(phase, 0)) != int(EXPECTED_PHASE_COUNTS[phase]):
			push_error("Unexpected phase count for %s: %d" % [phase, int(phase_counts.get(phase, 0))])
			return false
	for hook in REQUIRED_ENDING_HOOKS:
		if not ending_hooks.has(hook):
			push_error("Missing ending hook coverage: %s" % hook)
			return false
	if identity_path_groups.size() < 4:
		push_error("Expected at least 4 Gu identity path groups, got %d" % identity_path_groups.size())
		return false
	return true


func _validate_runtime_availability(beats: Array) -> bool:
	var state := StrategicMapState.default_state()
	state = StrategicMapState.apply_effects(state, {
		"route_bias_military": 1,
		"route_bias_reputation": 1,
		"route_bias_old_case": 1,
		"shen_respect": 1,
		"gu_trust": 1,
		"gu_identity_known": true,
		"qi_trust": 1,
		"truth_progress": 1,
		"public_reputation": 1,
		"military_merit": 1,
		"clean_reputation": 1,
		"case_clues": 1,
	})
	if AigcStoryBeatRuntime.filter_available_beats(beats, state, "early", "military").is_empty():
		push_error("Expected early military beats to be available from Wuke-seeded state")
		return false
	if AigcStoryBeatRuntime.filter_available_beats(beats, state, "early", "old_case").is_empty():
		push_error("Expected early old-case beats to be available from Wuke-seeded state")
		return false
	var gu_setup := _find_beat(beats, "beat_reputation_gu_herbal_boat_early_002")
	if gu_setup.is_empty():
		push_error("Missing Gu early setup beat")
		return false
	state = AigcStoryBeatRuntime.apply_beat_to_state(state, gu_setup)
	state = AigcStoryBeatRuntime.tick_cooldowns(state)
	var gu_identity := _find_beat(beats, "beat_reputation_gu_identity_mid_001")
	if gu_identity.is_empty() or not AigcStoryBeatRuntime.is_beat_available(gu_identity, state):
		push_error("Gu identity mid beat should become available after early trust setup")
		return false
	var true_ending_state := StrategicMapState.default_state()
	true_ending_state = StrategicMapState.apply_effects(true_ending_state, {
		"military_rank_progress": 3,
		"public_reputation": 5,
		"truth_progress": 6,
		"gu_trust": 3,
		"shen_respect": 3,
		"qi_trust": 3,
	})
	var true_ending := _find_beat(beats, "beat_cross_true_ending_finale_017")
	if true_ending.is_empty() or not AigcStoryBeatRuntime.is_beat_available(true_ending, true_ending_state):
		push_error("True ending setup beat should be available with balanced high route state")
		return false
	return true


func _count(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _find_beat(beats: Array, beat_id: String) -> Dictionary:
	for item in beats:
		if item is Dictionary and str((item as Dictionary).get("story_beat_id", "")) == beat_id:
			return item as Dictionary
	return {}
