extends SceneTree

const NARRATIVE_SCENE := "res://scenes/NarrativeDemo.tscn"
const TRACKS_PATH := "res://data/performance_tracks.json"
const FORMAL_PROLOGUE_PREFIX := "res://assets/pixel_battle/backgrounds/formal/prologue/"

const EXPECTED_STAGES := [
	"prologue_01",
	"prologue_02",
	"prologue_03",
	"prologue_04",
	"prologue_05",
	"prologue_06",
	"prologue_07",
	"prologue_08",
	"prologue_09",
	"prologue_10",
	"prologue_11",
	"prologue_12",
]

func _init() -> void:
	var errors: Array[String] = []
	var tracks := _load_tracks(errors)
	var packed: Resource = load(NARRATIVE_SCENE)
	if not (packed is PackedScene):
		errors.append("NarrativeDemo scene failed to load")
	else:
		var demo: Node = (packed as PackedScene).instantiate()
		root.add_child(demo)
		for i in range(EXPECTED_STAGES.size()):
			demo.set("in_prologue", true)
			demo.set("step_index", i)
			var stage := str(demo.call("_cinematic_stage_key"))
			if stage != str(EXPECTED_STAGES[i]):
				errors.append("step %d stage mismatch: got %s expected %s" % [i, stage, EXPECTED_STAGES[i]])
				continue
			var background := str(demo.call("_cinematic_background_path", ""))
			_validate_res_path(background, "step %d background" % i, errors)
			if not background.begins_with(FORMAL_PROLOGUE_PREFIX):
				errors.append("step %d background is not formal prologue art: %s" % [i, background])
			var timeline = tracks.get("timeline", {})
			if timeline is Dictionary and (timeline as Dictionary).has(stage):
				var data: Dictionary = (timeline as Dictionary).get(stage, {})
				for prefix in ["prop", "prop2", "prop3"]:
					var prop_path := str(data.get("%s_path" % prefix, ""))
					if not prop_path.is_empty():
						_validate_res_path(prop_path, "%s.%s_path" % [stage, prefix], errors)
		demo.queue_free()
	if errors.is_empty():
		print("[prologue-png] OK: 12 prologue stage(s) use PNG-backed performance tracks")
		quit(0)
	else:
		for error in errors:
			push_error("[prologue-png] %s" % error)
		quit(1)

func _load_tracks(errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(TRACKS_PATH):
		errors.append("missing performance tracks JSON")
		return {}
	var file := FileAccess.open(TRACKS_PATH, FileAccess.READ)
	if file == null:
		errors.append("failed to open performance tracks JSON")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	errors.append("performance tracks JSON is not a dictionary")
	return {}

func _validate_res_path(path: String, context: String, errors: Array[String]) -> void:
	if path.is_empty():
		errors.append("%s is empty" % context)
		return
	if not path.ends_with(".png"):
		errors.append("%s is not PNG: %s" % [context, path])
	if not ResourceLoader.exists(path):
		errors.append("%s missing resource: %s" % [context, path])
