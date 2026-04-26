extends RefCounted
class_name NarrativeMvpData

const DATA_PATH := "res://data/narrative_mvp_nodes.json"

static var cached_data: Dictionary = {}
static var loaded: bool = false
static var attempted: bool = false

static func get_data() -> Dictionary:
	if not attempted:
		_load()
	return cached_data

static func is_loaded() -> bool:
	if not attempted:
		_load()
	return loaded

static func _load() -> void:
	attempted = true
	loaded = false
	cached_data.clear()
	if not FileAccess.file_exists(DATA_PATH):
		return
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		cached_data = parsed
		loaded = true

static func get_prologue_step(index: int) -> Dictionary:
	var data: Dictionary = get_data()
	var prologue_variant = data.get("prologue", {})
	if not (prologue_variant is Dictionary):
		return {}
	var steps_variant = (prologue_variant as Dictionary).get("steps", [])
	if not (steps_variant is Array):
		return {}
	var steps: Array = steps_variant
	if index >= 0 and index < steps.size() and steps[index] is Dictionary:
		return steps[index]
	return {}

static func get_node(node_id: String) -> Dictionary:
	var data: Dictionary = get_data()
	var nodes_variant = data.get("nodes", [])
	if not (nodes_variant is Array):
		return {}
	for node_variant in (nodes_variant as Array):
		if node_variant is Dictionary and str((node_variant as Dictionary).get("id", "")) == node_id:
			return node_variant
	return {}

static func get_node_combat(node_id: String) -> Dictionary:
	var node: Dictionary = get_node(node_id)
	var combat_variant = node.get("combat", {})
	if combat_variant is Dictionary:
		return combat_variant
	return {}

static func get_combat_by_encounter(encounter_id: String) -> Dictionary:
	var data: Dictionary = get_data()
	var prologue_variant = data.get("prologue", {})
	if prologue_variant is Dictionary:
		var steps_variant = (prologue_variant as Dictionary).get("steps", [])
		if steps_variant is Array:
			for step_variant in (steps_variant as Array):
				if not (step_variant is Dictionary):
					continue
				var combat_variant = (step_variant as Dictionary).get("combat", {})
				if combat_variant is Dictionary and str((combat_variant as Dictionary).get("encounter_id", "")) == encounter_id:
					return combat_variant
	var nodes_variant = data.get("nodes", [])
	if nodes_variant is Array:
		for node_variant in (nodes_variant as Array):
			if not (node_variant is Dictionary):
				continue
			var combat_variant = (node_variant as Dictionary).get("combat", {})
			if combat_variant is Dictionary and str((combat_variant as Dictionary).get("encounter_id", "")) == encounter_id:
				return combat_variant
	return {}

static func has_combat(node_id: String) -> bool:
	return bool(get_node_combat(node_id).get("enabled", false))

static func get_ending() -> Dictionary:
	var data: Dictionary = get_data()
	var ending_variant = data.get("ending", {})
	if ending_variant is Dictionary:
		return ending_variant
	return {}

static func get_hints() -> Dictionary:
	var data: Dictionary = get_data()
	var hints_variant = data.get("hints", {})
	if hints_variant is Dictionary:
		return hints_variant
	return {}
