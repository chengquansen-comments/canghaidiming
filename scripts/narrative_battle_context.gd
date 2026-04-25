extends Node

const META_ENCOUNTER_ID := "canghai_narrative_encounter_id"
const META_SOURCE_NODE_ID := "canghai_narrative_source_node_id"
const META_SOURCE_SCENE := "canghai_narrative_source_scene"
const META_RETURN_AFTER_BATTLE := "canghai_narrative_return_after_battle"
const META_LAST_RESULT := "canghai_narrative_last_result"
const META_RESULT_READY := "canghai_narrative_result_ready"

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
	_write_meta()

static func set_result(p_result: String) -> void:
	_pull_meta()
	last_result = p_result
	result_ready = not p_result.is_empty()
	return_after_battle = result_ready
	if source_scene.is_empty():
		source_scene = "res://scenes/NarrativeDemo.tscn"
	if source_node_id.is_empty():
		source_node_id = "beach_ambush"
	if encounter_id.is_empty():
		encounter_id = "enc_fallback"
	_write_meta()

static func clear() -> void:
	encounter_id = ""
	source_node_id = ""
	source_scene = "res://scenes/NarrativeDemo.tscn"
	return_after_battle = false
	last_result = ""
	result_ready = false
	_clear_meta()

static func has_request() -> bool:
	_pull_meta()
	return not encounter_id.is_empty()

static func has_result() -> bool:
	_pull_meta()
	return result_ready and not last_result.is_empty()

static func debug_text() -> String:
	_pull_meta()
	return "encounter_id=%s｜source_node_id=%s｜return_after_battle=%s｜last_result=%s" % [encounter_id, source_node_id, str(return_after_battle), last_result]

static func _write_meta() -> void:
	Engine.set_meta(META_ENCOUNTER_ID, encounter_id)
	Engine.set_meta(META_SOURCE_NODE_ID, source_node_id)
	Engine.set_meta(META_SOURCE_SCENE, source_scene)
	Engine.set_meta(META_RETURN_AFTER_BATTLE, return_after_battle)
	Engine.set_meta(META_LAST_RESULT, last_result)
	Engine.set_meta(META_RESULT_READY, result_ready)

static func _pull_meta() -> void:
	if Engine.has_meta(META_ENCOUNTER_ID):
		encounter_id = str(Engine.get_meta(META_ENCOUNTER_ID))
	if Engine.has_meta(META_SOURCE_NODE_ID):
		source_node_id = str(Engine.get_meta(META_SOURCE_NODE_ID))
	if Engine.has_meta(META_SOURCE_SCENE):
		source_scene = str(Engine.get_meta(META_SOURCE_SCENE))
	if Engine.has_meta(META_RETURN_AFTER_BATTLE):
		return_after_battle = bool(Engine.get_meta(META_RETURN_AFTER_BATTLE))
	if Engine.has_meta(META_LAST_RESULT):
		last_result = str(Engine.get_meta(META_LAST_RESULT))
	if Engine.has_meta(META_RESULT_READY):
		result_ready = bool(Engine.get_meta(META_RESULT_READY))

static func _clear_meta() -> void:
	for key in [META_ENCOUNTER_ID, META_SOURCE_NODE_ID, META_SOURCE_SCENE, META_RETURN_AFTER_BATTLE, META_LAST_RESULT, META_RESULT_READY]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)
