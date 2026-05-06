extends RefCounted

# Pure story text segmentation helper for canonical narrative controllers.
#
# It has no UI writes, no context saves, no node advancement, no battle request,
# and no controller/owner calls.


static func node_story_segments(node: Dictionary) -> Array[String]:
	var segments: Array[String] = []
	append_text_segments(segments, str(node.get("text", "")))
	var combat = node.get("combat", {})
	if combat is Dictionary and bool((combat as Dictionary).get("enabled", false)):
		append_text_segments(segments, str((combat as Dictionary).get("pre", "")))
	if segments.is_empty():
		segments.append("")
	return segments


static func append_text_segments(segments: Array[String], raw_text: String) -> void:
	var normalized := raw_text.replace("\r", "")
	var lines := normalized.split("\n")
	for raw_line in lines:
		var line := str(raw_line).strip_edges()
		if not line.is_empty():
			segments.append(line)


static func is_node_story_complete(node: Dictionary, sentence_index: int) -> bool:
	var segments := node_story_segments(node)
	return sentence_index >= segments.size() - 1


static func current_node_story_text(node: Dictionary, sentence_index: int) -> String:
	var segments := node_story_segments(node)
	var safe_index := clamp(sentence_index, 0, segments.size() - 1)
	return str(segments[safe_index])
