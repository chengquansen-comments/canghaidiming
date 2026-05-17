extends SceneTree

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const AigcStoryBeatRuntime := preload("res://scripts/narrative/aigc_story_beat_runtime.gd")

const EXPECTED_BEAT_COUNT := 300
const EXPECTED_ROUTE_COUNTS := {
	"military": 72,
	"reputation": 72,
	"old_case": 72,
	"cross": 84,
}
const EXPECTED_PHASE_COUNTS := {
	"early": 84,
	"mid": 86,
	"late": 84,
	"finale": 46,
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
	var beats := AigcStoryBeatRuntime.load_pool(AigcStoryBeatRuntime.EXPANDED_POOL_PATH)
	if not _validate_expanded_pool(beats):
		quit(1)
		return
	print("AIGC story beat expanded pool smoke: OK beats=%d" % beats.size())
	quit(0)


func _validate_expanded_pool(beats: Array) -> bool:
	if beats.size() != EXPECTED_BEAT_COUNT:
		push_error("Expected %d expanded story beats, got %d" % [EXPECTED_BEAT_COUNT, beats.size()])
		return false
	var ids: Dictionary = {}
	var preview_texts: Dictionary = {}
	var result_texts: Dictionary = {}
	var route_counts: Dictionary = {}
	var phase_counts: Dictionary = {}
	var ending_hooks: Dictionary = {}
	var identity_path_count := 0
	var identity_groups: Dictionary = {}
	var exclusive_meta: Dictionary = {}
	for item in beats:
		if not (item is Dictionary):
			push_error("Expanded story beat item is not a Dictionary")
			return false
		var beat := item as Dictionary
		var beat_id := str(beat.get("story_beat_id", ""))
		if ids.has(beat_id):
			push_error("Duplicate story_beat_id: %s" % beat_id)
			return false
		ids[beat_id] = true
		var errors := AigcStoryBeatRuntime.validate_beat(beat)
		if not errors.is_empty():
			push_error("Invalid expanded story beat %s: %s" % [beat_id, str(errors)])
			return false
		if not _validate_reachable(beat):
			return false
		if not _validate_text_unique(preview_texts, beat, "preview_text"):
			return false
		if not _validate_text_unique(result_texts, beat, "result_text"):
			return false
		_count(route_counts, str(beat.get("route_line", "")))
		_count(phase_counts, str(beat.get("phase", "")))
		if not _validate_exclusive_meta(exclusive_meta, beat):
			return false
		for hook in beat.get("followup_hooks", []):
			ending_hooks[str(hook)] = true
		if _is_gu_identity_path(beat):
			identity_path_count += 1
			identity_groups[str(beat.get("exclusive_group", beat_id))] = true
	for route in EXPECTED_ROUTE_COUNTS.keys():
		if int(route_counts.get(route, 0)) != int(EXPECTED_ROUTE_COUNTS[route]):
			push_error("Unexpected expanded route count for %s: %d" % [route, int(route_counts.get(route, 0))])
			return false
	for phase in EXPECTED_PHASE_COUNTS.keys():
		if int(phase_counts.get(phase, 0)) != int(EXPECTED_PHASE_COUNTS[phase]):
			push_error("Unexpected expanded phase count for %s: %d" % [phase, int(phase_counts.get(phase, 0))])
			return false
	for hook in REQUIRED_ENDING_HOOKS:
		if not ending_hooks.has(hook):
			push_error("Missing expanded ending hook coverage: %s" % hook)
			return false
	if identity_path_count < 40 or identity_groups.size() < 4:
		push_error("Gu identity coverage too low: beats=%d groups=%d" % [identity_path_count, identity_groups.size()])
		return false
	return true


func _validate_reachable(beat: Dictionary) -> bool:
	var state := StrategicMapState.default_state()
	var requirements: Dictionary = beat.get("requirements", {}) as Dictionary
	var mins: Dictionary = {}
	var maxs: Dictionary = {}
	for key_variant in requirements.keys():
		var key := str(key_variant)
		var value = requirements[key_variant]
		if key.ends_with("_min"):
			var field := key.substr(0, key.length() - 4)
			mins[field] = max(int(mins.get(field, 0)), int(value))
			state[field] = int(mins[field])
		elif key.ends_with("_max"):
			var field := key.substr(0, key.length() - 4)
			maxs[field] = int(value)
			if not mins.has(field):
				state[field] = min(int(state.get(field, 0)), int(value))
		else:
			state[key] = value
	for field in mins.keys():
		if maxs.has(field) and int(mins[field]) > int(maxs[field]):
			push_error("Unreachable requirement bounds in %s: %s_min > %s_max" % [str(beat.get("story_beat_id", "")), field, field])
			return false
	if not AigcStoryBeatRuntime.is_beat_available(beat, state):
		push_error("Beat requirements are not reachable: %s" % str(beat.get("story_beat_id", "")))
		return false
	return true


func _validate_text_unique(seen: Dictionary, beat: Dictionary, field: String) -> bool:
	var text := _normalized_text(str(beat.get(field, "")))
	if seen.has(text):
		push_error("Duplicate %s between %s and %s" % [field, str(seen[text]), str(beat.get("story_beat_id", ""))])
		return false
	seen[text] = str(beat.get("story_beat_id", ""))
	return true


func _validate_exclusive_meta(exclusive_meta: Dictionary, beat: Dictionary) -> bool:
	var group := str(beat.get("exclusive_group", ""))
	if group.is_empty():
		return true
	var meta := "%s|%s|%s|%s" % [
		str(beat.get("route_line", "")),
		str(beat.get("phase", "")),
		str(beat.get("node_type", "")),
		str(beat.get("npc_focus", "")),
	]
	if exclusive_meta.has(group) and str(exclusive_meta[group]) != meta:
		push_error("Exclusive group crosses incompatible meta: %s" % group)
		return false
	exclusive_meta[group] = meta
	return true


func _is_gu_identity_path(beat: Dictionary) -> bool:
	var effects: Dictionary = beat.get("effects", {}) as Dictionary
	var requirements: Dictionary = beat.get("requirements", {}) as Dictionary
	if effects.has("gu_identity_public_risk") or requirements.has("gu_identity_known"):
		return true
	if str(beat.get("exclusive_group", "")).find("gu_identity") >= 0:
		return true
	for hook in beat.get("followup_hooks", []):
		if str(hook).find("gu_identity") >= 0:
			return true
	return false


func _count(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _normalized_text(text: String) -> String:
	return text.strip_edges().replace(" ", "").replace("\n", "")
