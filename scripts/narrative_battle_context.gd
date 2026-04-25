extends Node

static var encounter_id := ""
static var source_node_id := ""
static var source_scene := "res://scenes/NarrativeDemo.tscn"
static var return_after_battle := false
static var last_result := ""
static var result_ready := false

static func set_request(p_encounter_id: String, p_source_node_id: String) -> void:
	encounter_id = p_encounter_id
	source_node_id = p_source_node_id
	source_scene = "res://scenes/NarrativeDemo.tscn"
	return_after_battle = false
	last_result = ""
	result_ready = false

static func set_result(p_result: String) -> void:
	last_result = p_result
	result_ready = not p_result.is_empty()
	return_after_battle = result_ready

static func clear() -> void:
	encounter_id = ""
	source_node_id = ""
	source_scene = "res://scenes/NarrativeDemo.tscn"
	return_after_battle = false
	last_result = ""
	result_ready = false

static func has_request() -> bool:
	return not encounter_id.is_empty()

static func has_result() -> bool:
	return has_request() and result_ready and not last_result.is_empty()

static func debug_text() -> String:
	return "encounter_id=%s｜source_node_id=%s｜return_after_battle=%s｜last_result=%s" % [encounter_id, source_node_id, str(return_after_battle), last_result]
