extends SceneTree

const StrategicMapState := preload("res://scripts/strategic_map_state.gd")
const AigcStoryBeatRuntime := preload("res://scripts/narrative/aigc_story_beat_runtime.gd")

const RUN_COUNT := 10
const BEATS_PER_RUN := 40
const MIN_UNIQUE_BEATS := 180
const MAX_FIRST_FIVE_REPEAT_RATE := 0.30
const MIN_ENDING_HOOKS := 8
const MIN_GU_IDENTITY_GROUPS := 4
const REPORT_PATH := "res://data/aigc_battle/story/replay_validation_report.json"

const ROUTE_PLANS := [
	["military", "military", "military", "reputation", "old_case", "cross"],
	["reputation", "reputation", "reputation", "military", "old_case", "cross"],
	["old_case", "old_case", "old_case", "military", "reputation", "cross"],
	["military", "reputation", "old_case", "cross", "military", "reputation"],
	["reputation", "cross", "old_case", "reputation", "military", "cross"],
	["old_case", "cross", "military", "old_case", "reputation", "cross"],
	["military", "cross", "reputation", "old_case", "military", "cross"],
	["reputation", "old_case", "cross", "military", "reputation", "old_case"],
	["old_case", "military", "cross", "reputation", "old_case", "military"],
	["cross", "military", "reputation", "old_case", "cross", "reputation"],
]
const PHASE_PLAN := [
	"early", "early", "early", "early", "early", "early", "early", "early", "early", "early",
	"mid", "mid", "mid", "mid", "mid", "mid", "mid", "mid", "mid", "mid", "mid", "mid",
	"late", "late", "late", "late", "late", "late", "late", "late", "late", "late", "late", "late",
	"finale", "finale", "finale", "finale", "finale", "finale",
]
const ENDING_HOOK_PREFIX := "ending_"


func _init() -> void:
	var beats := AigcStoryBeatRuntime.load_pool(AigcStoryBeatRuntime.EXPANDED_POOL_PATH)
	if beats.size() < 300:
		push_error("Expanded story beat pool is too small for replay validation: %d" % beats.size())
		quit(1)
		return
	var report := _simulate_runs(beats)
	if not _validate_report(report):
		_write_report(report)
		quit(1)
		return
	_write_report(report)
	print("AIGC story beat replay validation smoke: OK runs=%d unique=%d first5_repeat=%.3f endings=%d gu_identity_groups=%d" % [
		RUN_COUNT,
		int(report.get("unique_beat_count", 0)),
		float(report.get("first_five_repeat_rate", 1.0)),
		(report.get("ending_hooks", []) as Array).size(),
		(report.get("gu_identity_groups", []) as Array).size(),
	])
	quit(0)


func _simulate_runs(beats: Array) -> Dictionary:
	var all_seen: Dictionary = {}
	var first_five_seen: Dictionary = {}
	var first_five_total := 0
	var ending_hooks: Dictionary = {}
	var gu_identity_groups: Dictionary = {}
	var route_exposure_totals: Dictionary = {}
	var run_reports: Array = []
	for run_index in range(RUN_COUNT):
		var state := _initial_story_state(run_index)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2601 + run_index * 97
		var route_counts: Dictionary = {}
		var phase_counts: Dictionary = {}
		var run_seen: Dictionary = {}
		var sequence: Array = []
		for step in range(BEATS_PER_RUN):
			var phase := str(PHASE_PLAN[step % PHASE_PLAN.size()])
			if phase == "finale":
				_apply_finale_archetype_state(state, run_index)
			var route := _route_for_step(run_index, step)
			var beat := _pick_for_simulation(beats, state, phase, route, rng)
			if beat.is_empty():
				push_error("Replay simulation could not pick beat run=%d step=%d phase=%s route=%s" % [run_index, step, phase, route])
				break
			var beat_id := str(beat.get("story_beat_id", ""))
			all_seen[beat_id] = true
			run_seen[beat_id] = true
			if run_index < 5:
				first_five_total += 1
				first_five_seen[beat_id] = true
			var beat_route := str(beat.get("route_line", ""))
			_count(route_counts, beat_route)
			_count(route_exposure_totals, beat_route)
			_count(phase_counts, str(beat.get("phase", "")))
			for hook in beat.get("followup_hooks", []):
				var hook_text := str(hook)
				if hook_text.begins_with(ENDING_HOOK_PREFIX):
					ending_hooks[hook_text] = true
			if _is_gu_identity_path(beat):
				gu_identity_groups[str(beat.get("exclusive_group", beat_id))] = true
			sequence.append(beat_id)
			state = AigcStoryBeatRuntime.apply_beat_to_state(state, beat)
			state = AigcStoryBeatRuntime.tick_cooldowns(state)
		run_reports.append({
			"run_index": run_index,
			"seed": 2601 + run_index * 97,
			"beat_count": sequence.size(),
			"unique_beat_count": run_seen.size(),
			"route_counts": route_counts,
			"phase_counts": phase_counts,
			"sequence": sequence,
		})
	return {
		"run_count": RUN_COUNT,
		"beats_per_run_target": BEATS_PER_RUN,
		"unique_beat_count": all_seen.size(),
		"first_five_total": first_five_total,
		"first_five_unique": first_five_seen.size(),
		"first_five_repeat_rate": 1.0 - (float(first_five_seen.size()) / float(max(1, first_five_total))),
		"route_exposure_totals": route_exposure_totals,
		"ending_hooks": _sorted_keys(ending_hooks),
		"gu_identity_groups": _sorted_keys(gu_identity_groups),
		"runs": run_reports,
	}


func _initial_story_state(run_index: int) -> Dictionary:
	var state := StrategicMapState.default_state()
	state["route_bias_military"] = 1
	state["route_bias_reputation"] = 1
	state["route_bias_old_case"] = 1
	state["shen_respect"] = 1
	state["gu_trust"] = 1
	state["gu_identity_known"] = true
	state["qi_trust"] = 1
	state["truth_progress"] = 1
	state["public_reputation"] = 1
	state["military_merit"] = 1
	state["clean_reputation"] = 1
	state["case_clues"] = 1
	state["martial_level"] = 3
	state["lightness_level"] = 1
	if run_index % 3 == 0:
		state["military_rank_progress"] = 2
		state["shen_respect"] = 2
	elif run_index % 3 == 1:
		state["gu_trust"] = 2
		state["gu_affection"] = 1
		state["public_reputation"] = 2
	else:
		state["qi_trust"] = 2
		state["truth_progress"] = 2
		state["case_clues"] = 2
	return state


func _apply_finale_archetype_state(state: Dictionary, run_index: int) -> void:
	match run_index:
		0:
			state["military_rank_progress"] = 5
			state["truth_progress"] = 2
			state["public_reputation"] = 2
		1:
			state["public_reputation"] = 5
			state["gu_trust"] = 3
		2:
			state["truth_progress"] = 6
			state["qi_trust"] = 3
		3:
			state["military_rank_progress"] = 3
			state["truth_progress"] = 4
			state["shen_respect"] = 3
		4:
			state["gu_identity_public_risk"] = 4
			state["gu_affection"] = 2
		5:
			state["military_rank_progress"] = 5
			state["gu_trust"] = 0
			state["public_reputation"] = 2
		6:
			state["truth_progress"] = 5
			state["public_reputation"] = 2
		7:
			state["military_rank_progress"] = 4
			state["truth_progress"] = 4
			state["public_reputation"] = 2
		8:
			state["public_reputation"] = 4
			state["truth_progress"] = 5
			state["gu_affection"] = 2
		_:
			state["military_rank_progress"] = 3
			state["public_reputation"] = 5
			state["truth_progress"] = 6
			state["gu_trust"] = 3
			state["shen_respect"] = 3
			state["qi_trust"] = 3


func _route_for_step(run_index: int, step: int) -> String:
	var plan: Array = ROUTE_PLANS[run_index % ROUTE_PLANS.size()]
	if step >= 34:
		return str(plan[(step + 2) % plan.size()])
	return str(plan[(step + run_index) % plan.size()])


func _pick_for_simulation(beats: Array, state: Dictionary, phase: String, route: String, rng: RandomNumberGenerator) -> Dictionary:
	var candidates := AigcStoryBeatRuntime.filter_available_beats(beats, state, phase, route)
	if candidates.is_empty() and route != "cross":
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, state, phase, "cross")
	if candidates.is_empty():
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, state, phase, "")
	if candidates.is_empty():
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, state, "", route)
	if candidates.is_empty():
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, state)
	return AigcStoryBeatRuntime.pick_weighted_beat(candidates, rng)


func _validate_report(report: Dictionary) -> bool:
	if int(report.get("unique_beat_count", 0)) < MIN_UNIQUE_BEATS:
		push_error("Replay unique beat exposure too low: %d" % int(report.get("unique_beat_count", 0)))
		return false
	if float(report.get("first_five_repeat_rate", 1.0)) > MAX_FIRST_FIVE_REPEAT_RATE:
		push_error("Replay first five repeat rate too high: %.3f" % float(report.get("first_five_repeat_rate", 1.0)))
		return false
	var route_totals: Dictionary = report.get("route_exposure_totals", {}) as Dictionary
	for route in ["military", "reputation", "old_case", "cross"]:
		if int(route_totals.get(route, 0)) <= 0:
			push_error("Replay route exposure missing: %s" % route)
			return false
	if (report.get("ending_hooks", []) as Array).size() < MIN_ENDING_HOOKS:
		push_error("Replay ending hook coverage too low: %d" % (report.get("ending_hooks", []) as Array).size())
		return false
	if (report.get("gu_identity_groups", []) as Array).size() < MIN_GU_IDENTITY_GROUPS:
		push_error("Replay Gu identity path coverage too low: %d" % (report.get("gu_identity_groups", []) as Array).size())
		return false
	for item in report.get("runs", []):
		if not (item is Dictionary):
			continue
		var run := item as Dictionary
		if int(run.get("beat_count", 0)) != BEATS_PER_RUN:
			push_error("Replay run did not reach target beat count: %s" % str(run.get("run_index", "")))
			return false
		var counts: Dictionary = run.get("route_counts", {}) as Dictionary
		for route in ["military", "reputation", "old_case"]:
			if int(counts.get(route, 0)) <= 0:
				push_error("Replay run missing main route %s in run %s" % [route, str(run.get("run_index", ""))])
				return false
	return true


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write replay validation report: %s" % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))


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


func _sorted_keys(source: Dictionary) -> Array:
	var result: Array = []
	for key in source.keys():
		result.append(str(key))
	result.sort()
	return result
