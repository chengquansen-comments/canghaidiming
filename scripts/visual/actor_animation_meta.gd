extends RefCounted
class_name ActorAnimationMeta

const DEFAULT_FRAME_SIZE := Vector2i(512, 512)
const DEFAULT_FOOT_ANCHOR := Vector2(256, 500)
const DEFAULT_BODY_CENTER := Vector2(256, 300)
const DEFAULT_HEAD_ANCHOR := Vector2(256, 150)

var source_path: String = ""
var actor_dir: String = ""
var role_id: String = ""
var display_name: String = ""
var profession: String = ""
var frame_size: Vector2i = DEFAULT_FRAME_SIZE
var foot_anchor: Vector2 = DEFAULT_FOOT_ANCHOR
var body_center: Vector2 = DEFAULT_BODY_CENTER
var head_anchor: Vector2 = DEFAULT_HEAD_ANCHOR
var default_facing: String = "right"
var actor_scale: float = 1.0
var animations: Dictionary = {}
var is_valid: bool = false
var error_message: String = ""

static func load_from_path(path: String) -> ActorAnimationMeta:
	var meta := ActorAnimationMeta.new()
	meta.source_path = path
	meta.actor_dir = path.get_base_dir()
	meta._load()
	return meta

func has_animation(animation_name: String) -> bool:
	return animations.has(animation_name)

func animation(animation_name: String) -> Dictionary:
	if not animations.has(animation_name):
		return {}
	return animations[animation_name] as Dictionary

func animation_file(animation_name: String) -> String:
	var config: Dictionary = animation(animation_name)
	if config.is_empty():
		return ""
	return str(config.get("file", ""))

func animation_files(animation_name: String) -> Array[String]:
	var config: Dictionary = animation(animation_name)
	var result: Array[String] = []
	if config.is_empty():
		return result
	var raw_files: Variant = config.get("files", [])
	if raw_files is Array:
		for item in raw_files as Array:
			var file_name := str(item)
			if file_name != "":
				result.append(file_name)
	if result.is_empty():
		var single_file := animation_file(animation_name)
		if single_file != "":
			result.append(single_file)
	return result

func animation_texture_path(animation_name: String) -> String:
	var file_name: String = animation_file(animation_name)
	if file_name == "":
		return ""
	return actor_dir.path_join(file_name)

func animation_texture_path_for_frame(animation_name: String, frame_index: int) -> String:
	var files := animation_files(animation_name)
	if files.is_empty():
		return ""
	var safe_index := clampi(frame_index, 0, files.size() - 1)
	return actor_dir.path_join(files[safe_index])

func animation_frames(animation_name: String) -> int:
	var config: Dictionary = animation(animation_name)
	return int(config.get("frames", 1)) if not config.is_empty() else 1

func animation_fps(animation_name: String) -> float:
	var config: Dictionary = animation(animation_name)
	return float(config.get("fps", 8.0)) if not config.is_empty() else 8.0

func animation_loops(animation_name: String) -> bool:
	var config: Dictionary = animation(animation_name)
	return bool(config.get("loop", false)) if not config.is_empty() else false

func animation_hit_frame(animation_name: String) -> int:
	var config: Dictionary = animation(animation_name)
	return int(config.get("hit_frame", -1)) if not config.is_empty() else -1

func animation_recovery_to(animation_name: String) -> String:
	var config: Dictionary = animation(animation_name)
	return str(config.get("recovery_to", "idle")) if not config.is_empty() else "idle"

func animation_fx(animation_name: String) -> String:
	var config: Dictionary = animation(animation_name)
	return str(config.get("fx", "")) if not config.is_empty() else ""

func animation_impact_offset(animation_name: String) -> Vector2:
	var config: Dictionary = animation(animation_name)
	return _vector2_from_array(config.get("impact_offset", [0, 0]), Vector2.ZERO) if not config.is_empty() else Vector2.ZERO

func preferred_idle() -> String:
	return "idle" if has_animation("idle") else first_animation_name()

func first_animation_name() -> String:
	for key in animations.keys():
		return str(key)
	return ""

func _load() -> void:
	if source_path == "" or not FileAccess.file_exists(source_path):
		_fail("meta file not found: %s" % source_path)
		return
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		_fail("failed to open meta file: %s" % source_path)
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		_fail("meta json root must be object: %s" % source_path)
		return
	var data: Dictionary = parsed as Dictionary
	role_id = str(data.get("role_id", ""))
	display_name = str(data.get("display_name", role_id))
	profession = str(data.get("profession", ""))
	frame_size = _vector2i_from_array(data.get("frame_size", [DEFAULT_FRAME_SIZE.x, DEFAULT_FRAME_SIZE.y]), DEFAULT_FRAME_SIZE)
	foot_anchor = _vector2_from_array(data.get("foot_anchor", [DEFAULT_FOOT_ANCHOR.x, DEFAULT_FOOT_ANCHOR.y]), DEFAULT_FOOT_ANCHOR)
	body_center = _vector2_from_array(data.get("body_center", [DEFAULT_BODY_CENTER.x, DEFAULT_BODY_CENTER.y]), DEFAULT_BODY_CENTER)
	head_anchor = _vector2_from_array(data.get("head_anchor", [DEFAULT_HEAD_ANCHOR.x, DEFAULT_HEAD_ANCHOR.y]), DEFAULT_HEAD_ANCHOR)
	default_facing = str(data.get("default_facing", "right"))
	actor_scale = float(data.get("scale", 1.0))
	var raw_animations: Variant = data.get("animations", {})
	if not raw_animations is Dictionary:
		_fail("animations must be object: %s" % source_path)
		return
	animations = raw_animations as Dictionary
	if role_id == "":
		_fail("role_id missing in %s" % source_path)
		return
	if animations.is_empty():
		_fail("animations empty in %s" % source_path)
		return
	is_valid = true
	error_message = ""

func _fail(message: String) -> void:
	is_valid = false
	error_message = message
	push_warning(message)

static func _vector2_from_array(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array:
		return fallback
	var arr: Array = value as Array
	if arr.size() < 2:
		return fallback
	return Vector2(float(arr[0]), float(arr[1]))

static func _vector2i_from_array(value: Variant, fallback: Vector2i) -> Vector2i:
	if not value is Array:
		return fallback
	var arr: Array = value as Array
	if arr.size() < 2:
		return fallback
	return Vector2i(int(arr[0]), int(arr[1]))
