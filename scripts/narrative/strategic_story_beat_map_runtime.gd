extends RefCounted

const AigcStoryBeatRuntime := preload("res://scripts/narrative/aigc_story_beat_runtime.gd")

const STORY_PHASE_BY_LAYER := ["early", "early", "early", "mid", "mid", "mid", "late", "late", "late", "finale"]
const ROUTE_LINE_BY_PRIMARY := {
	"military": "military",
	"reputation": "reputation",
	"old_case": "old_case",
	"case": "old_case",
}


static func materialize_story_beats(graph: Dictionary, state: Dictionary, seed: int, beats: Array = []) -> Dictionary:
	var next_graph := graph.duplicate(true)
	var nodes: Array = next_graph.get("nodes", [])
	if nodes.is_empty():
		return next_graph
	var story_beats := beats if not beats.is_empty() else AigcStoryBeatRuntime.load_pool()
	if story_beats.is_empty():
		return next_graph
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, seed + 7919)
	var picker_state := state.duplicate(true)
	picker_state["triggered_story_beat_ids"] = (state.get("triggered_story_beat_ids", []) as Array).duplicate(true)
	picker_state["story_exclusive_groups"] = (state.get("story_exclusive_groups", []) as Array).duplicate(true)
	picker_state["story_cooldowns"] = (state.get("story_cooldowns", {}) as Dictionary).duplicate(true)
	for i in range(nodes.size()):
		if not (nodes[i] is Dictionary):
			continue
		var node := nodes[i] as Dictionary
		if _is_combat_node(node):
			continue
		if bool(node.get("debug_fallback", false)):
			continue
		var beat := _pick_beat_for_node(story_beats, picker_state, node, rng)
		if beat.is_empty():
			continue
		_apply_beat_to_node(node, beat)
		picker_state = AigcStoryBeatRuntime.apply_beat_to_state(picker_state, beat)
		picker_state = AigcStoryBeatRuntime.tick_cooldowns(picker_state)
		nodes[i] = node
	next_graph["nodes"] = nodes
	next_graph["story_beat_pool_path"] = AigcStoryBeatRuntime.DEFAULT_POOL_PATH
	next_graph["story_beat_materialized"] = true
	return next_graph


static func story_node_count(graph: Dictionary) -> int:
	var count := 0
	for item in graph.get("nodes", []):
		if item is Dictionary and not str((item as Dictionary).get("story_beat_id", "")).is_empty():
			count += 1
	return count


static func combat_story_node_count(graph: Dictionary) -> int:
	var count := 0
	for item in graph.get("nodes", []):
		if item is Dictionary:
			var node := item as Dictionary
			if _is_combat_node(node) and not str(node.get("story_beat_id", "")).is_empty():
				count += 1
	return count


static func _pick_beat_for_node(beats: Array, picker_state: Dictionary, node: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var phase := _phase_for_node(node)
	var route_line := _route_line_for_node(node)
	var candidates := AigcStoryBeatRuntime.filter_available_beats(beats, picker_state, phase, route_line)
	if candidates.is_empty() and route_line != "cross":
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, picker_state, phase, "cross")
	if candidates.is_empty():
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, picker_state, phase, "")
	if candidates.is_empty():
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, picker_state, "", route_line)
	if candidates.is_empty():
		candidates = AigcStoryBeatRuntime.filter_available_beats(beats, picker_state)
	return AigcStoryBeatRuntime.pick_weighted_beat(candidates, rng)


static func _apply_beat_to_node(node: Dictionary, beat: Dictionary) -> void:
	if not node.has("source_preview_text"):
		node["source_preview_text"] = str(node.get("preview_text", ""))
	if not node.has("source_result_text"):
		node["source_result_text"] = str(node.get("result_text", ""))
	if not node.has("source_effects"):
		node["source_effects"] = (node.get("effects", {}) as Dictionary).duplicate(true)
	node["story_beat_id"] = str(beat.get("story_beat_id", ""))
	node["story_route_line"] = str(beat.get("route_line", ""))
	node["story_phase"] = str(beat.get("phase", ""))
	node["story_node_type"] = str(beat.get("node_type", ""))
	node["npc_focus"] = str(beat.get("npc_focus", ""))
	node["story_requirements"] = (beat.get("requirements", {}) as Dictionary).duplicate(true)
	node["story_exclusive_group"] = str(beat.get("exclusive_group", ""))
	node["story_cooldown_group"] = str(beat.get("cooldown_group", ""))
	node["story_cooldown_turns"] = int(beat.get("cooldown_turns", 0))
	node["story_followup_hooks"] = (beat.get("followup_hooks", []) as Array).duplicate(true)
	node["preview_text"] = str(beat.get("preview_text", node.get("preview_text", "")))
	node["result_text"] = str(beat.get("result_text", node.get("result_text", "")))
	node["effects"] = (beat.get("effects", {}) as Dictionary).duplicate(true)
	_append_tag(node, "story_beat")
	_append_tag(node, "story_%s" % str(beat.get("route_line", "")))


static func _phase_for_node(node: Dictionary) -> String:
	var layer := clampi(int(node.get("layer", 0)), 0, STORY_PHASE_BY_LAYER.size() - 1)
	return STORY_PHASE_BY_LAYER[layer]


static func _route_line_for_node(node: Dictionary) -> String:
	var primary := str(node.get("primary_line", node.get("node_type", "")))
	return str(ROUTE_LINE_BY_PRIMARY.get(primary, "cross"))


static func _is_combat_node(node: Dictionary) -> bool:
	var node_type := str(node.get("node_type", ""))
	return node_type.begins_with("combat_") \
		or not str(node.get("combat_pool_id", "")).is_empty() \
		or not str(node.get("encounter_id", "")).is_empty() \
		or not str(node.get("battle_id", "")).is_empty()


static func _append_tag(node: Dictionary, tag: String) -> void:
	if tag.is_empty():
		return
	var tags: Array = node.get("tags", [])
	if not (tag in tags):
		tags.append(tag)
	node["tags"] = tags
