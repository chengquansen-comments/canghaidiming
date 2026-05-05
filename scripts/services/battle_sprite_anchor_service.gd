extends Node

const DEFAULT_ANCHOR_MANIFEST_PATH := "res://data/battle_sprite_anchors.json"
const DEFAULT_FRAME_SIZE := Vector2i(1536, 512)
const DEFAULT_ANCHOR := Vector2i(768, 492)
const DEFAULT_LAYOUT := "vertical"

var manifest_path: String = DEFAULT_ANCHOR_MANIFEST_PATH
var manifest: Dictionary = {}
var loaded := false
var last_error := ""

func _ready() -> void:
	load_manifest(DEFAULT_ANCHOR_MANIFEST_PATH)

func reload() -> bool:
	return load_manifest(manifest_path)

func load_manifest(path: String = DEFAULT_ANCHOR_MANIFEST_PATH) -> bool:
	manifest_path = path
	manifest.clear()
	loaded = false
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Anchor manifest not found: %s" % path
		manifest = {"version": 1, "assets": {}}
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Anchor manifest failed to open: %s" % path
		manifest = {"version": 1, "assets": {}}
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		last_error = "Anchor manifest is not a JSON object: %s" % path
		manifest = {"version": 1, "assets": {}}
		return false
	manifest = parsed as Dictionary
	loaded = true
	return true

func is_loaded() -> bool:
	return loaded

func error_text() -> String:
	return last_error

func has_asset(asset_id: String) -> bool:
	var assets := _assets()
	return assets.has(asset_id) and assets[asset_id] is Dictionary

func asset_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _assets().keys():
		ids.append(str(key))
	ids.sort()
	return ids

func get_asset(asset_id: String) -> Dictionary:
	var assets := _assets()
	var asset = assets.get(asset_id, {})
	return asset if asset is Dictionary else {}

func get_sheet_path(asset_id: String) -> String:
	return str(get_asset(asset_id).get("sheet", ""))

func get_layout(asset_id: String) -> String:
	var layout := str(get_asset(asset_id).get("layout", DEFAULT_LAYOUT))
	return layout if layout in ["vertical", "horizontal"] else DEFAULT_LAYOUT

func get_frame_size(asset_id: String) -> Vector2i:
	return _vector2i_from_array(get_asset(asset_id).get("frame_size", []), DEFAULT_FRAME_SIZE)

func get_default_anchor(asset_id: String) -> Vector2i:
	return _vector2i_from_array(get_asset(asset_id).get("default_anchor", []), DEFAULT_ANCHOR)

func get_frame_anchor(asset_id: String, frame_index: int) -> Vector2i:
	var frame := get_frame_data(asset_id, frame_index)
	if frame.is_empty():
		return get_default_anchor(asset_id)
	return _vector2i_from_array(frame.get("foot_anchor", []), get_default_anchor(asset_id))

func get_target_anchor(asset_id: String, frame_index: int) -> Vector2i:
	var frame := get_frame_data(asset_id, frame_index)
	if frame.is_empty():
		return get_default_anchor(asset_id)
	return _vector2i_from_array(frame.get("target_anchor", []), get_default_anchor(asset_id))

func get_anchor_shift(asset_id: String, frame_index: int) -> Vector2i:
	var frame := get_frame_data(asset_id, frame_index)
	if not frame.is_empty() and frame.has("shift"):
		return _vector2i_from_array(frame.get("shift", []), Vector2i.ZERO)
	return get_target_anchor(asset_id, frame_index) - get_frame_anchor(asset_id, frame_index)

func get_position_correction(asset_id: String, frame_index: int, scale: Vector2 = Vector2.ONE) -> Vector2:
	var shift := get_anchor_shift(asset_id, frame_index)
	return Vector2(float(shift.x) * scale.x, float(shift.y) * scale.y)

func get_frame_bbox(asset_id: String, frame_index: int) -> Rect2i:
	var frame := get_frame_data(asset_id, frame_index)
	var raw = frame.get("bbox", null)
	if not (raw is Array):
		return Rect2i()
	var arr: Array = raw
	if arr.size() < 4:
		return Rect2i()
	return Rect2i(int(arr[0]), int(arr[1]), int(arr[2]), int(arr[3]))

func get_frame_data(asset_id: String, frame_index: int) -> Dictionary:
	var asset := get_asset(asset_id)
	var frames = asset.get("frames", {})
	if not (frames is Dictionary):
		return {}
	var frame = (frames as Dictionary).get(str(frame_index), {})
	return frame if frame is Dictionary else {}

func get_frame_source_rect(asset_id: String, frame_index: int) -> Rect2i:
	var size := get_frame_size(asset_id)
	if get_layout(asset_id) == "horizontal":
		return Rect2i(frame_index * size.x, 0, size.x, size.y)
	return Rect2i(0, frame_index * size.y, size.x, size.y)

func corrected_position(base_position: Vector2, asset_id: String, frame_index: int, scale: Vector2 = Vector2.ONE) -> Vector2:
	return base_position + get_position_correction(asset_id, frame_index, scale)

func describe_asset(asset_id: String) -> String:
	if not has_asset(asset_id):
		return "anchor asset missing: %s" % asset_id
	return "asset=%s sheet=%s frame_size=%s layout=%s default_anchor=%s" % [
		asset_id,
		get_sheet_path(asset_id),
		str(get_frame_size(asset_id)),
		get_layout(asset_id),
		str(get_default_anchor(asset_id))
	]

func _assets() -> Dictionary:
	var assets = manifest.get("assets", {})
	return assets if assets is Dictionary else {}

func _vector2i_from_array(value, fallback: Vector2i) -> Vector2i:
	if not (value is Array):
		return fallback
	var arr: Array = value
	if arr.size() < 2:
		return fallback
	return Vector2i(int(arr[0]), int(arr[1]))
