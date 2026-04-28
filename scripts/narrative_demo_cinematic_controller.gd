extends "res://scripts/narrative_demo_formal_controller.gd"

# Static narrative scene-art controller.
# This layer deliberately keeps the performance area pure:
# - one static scene texture
# - no mist / fire / dim / focus overlay
# - no foreground character plates
# - no breathing / zoom / pan / pulse motion
# - no world-map panel over the scene art

const PERFORMANCE_RATIO: float = 0.6667
const OPERATION_BOTTOM: float = 0.99
const MIN_OPERATION_HEIGHT: float = 340.0
const PERFORMANCE_TRACKS_PATH := "res://data/performance_tracks.json"
const FORMAL_PROLOGUE_BG_DIR := "res://assets/pixel_battle/backgrounds/formal/prologue"
const PROLOGUE_BLACK_TIDE := "res://assets/pixel_battle/backgrounds/prologue_black_tide.svg"
const PROLOGUE_RESCUE := "res://assets/pixel_battle/backgrounds/prologue_master_rescue.svg"
const PROLOGUE_ARROW := "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.svg"
const PROLOGUE_DEPARTURE := "res://assets/pixel_battle/backgrounds/prologue_departure.svg"
const CHAR_MASTER := "res://assets/pixel_battle/portraits/performance_master_veteran.svg"
const CHAR_HERO := "res://assets/pixel_battle/portraits/performance_hero_young.svg"

const NODE_PERFORMANCE := {
	"node": {"zoom":0.0, "pan_x":0.0, "pan_y":0.0, "dim":0.0, "mist":0.0, "fire":0.0, "hero":false, "hero_push":0.0, "master":false, "master_push":0.0, "duration":2.2}
}

var cinematic_bg: TextureRect
var cinematic_mist: ColorRect
var cinematic_fire: ColorRect
var cinematic_dim: ColorRect
var cinematic_focus: ColorRect
var cinematic_master: TextureRect
var cinematic_hero: TextureRect
var world_map_layer: Control
var world_map_panel: PanelContainer
var world_map_status_label: Label
var world_map_nodes_row: HBoxContainer
var cinematic_time: float = 0.0
var cinematic_stage: String = ""
var cinematic_stage_time: float = 0.0
var performance_tracks: Dictionary = {}
var performance_tracks_loaded: bool = false
var formal_prologue_background_by_number: Dictionary = {}
var formal_prologue_backgrounds_loaded: bool = false

func _ready() -> void:
	_load_performance_tracks()
	_load_formal_prologue_backgrounds()
	_add_cinematic_layers()
	super._ready()
	_add_world_map_layer()
	_refresh_world_map()
	_apply_cinematic_layout()
	_disable_scene_art_effect_nodes()

func _process(_delta: float) -> void:
	_apply_cinematic_layout()
	_disable_scene_art_effect_nodes()

func _render() -> void:
	super._render()
	_hide_node_local_map_controls()
	_refresh_world_map()
	_disable_scene_art_effect_nodes()

func _load_performance_tracks() -> void:
	performance_tracks_loaded = false
	performance_tracks.clear()
	if not FileAccess.file_exists(PERFORMANCE_TRACKS_PATH):
		return
	var file: FileAccess = FileAccess.open(PERFORMANCE_TRACKS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		performance_tracks = parsed
		performance_tracks_loaded = true

func _load_formal_prologue_backgrounds() -> void:
	formal_prologue_backgrounds_loaded = true
	formal_prologue_background_by_number.clear()
	var dir := DirAccess.open(FORMAL_PROLOGUE_BG_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			var bg_number := _formal_prologue_background_number(file_name)
			if bg_number >= 1 and bg_number <= 12:
				formal_prologue_background_by_number[bg_number] = "%s/%s" % [FORMAL_PROLOGUE_BG_DIR, file_name]
		file_name = dir.get_next()
	dir.list_dir_end()

func _formal_prologue_background_number(file_name: String) -> int:
	# Expected naming convention: 01_black_tide.png, 02_xxx.png ... 12_xxx.png.
	# Only the first two numeric characters are used for binding.
	if file_name.length() < 2:
		return -1
	var prefix := file_name.substr(0, 2)
	if not prefix.is_valid_int():
		return -1
	return int(prefix)

func _formal_prologue_background_for_step(step: int, fallback_path: String) -> String:
	if not formal_prologue_backgrounds_loaded:
		_load_formal_prologue_backgrounds()
	var bg_number := step + 1
	if formal_prologue_background_by_number.has(bg_number):
		return str(formal_prologue_background_by_number[bg_number])
	return fallback_path

func _render_visual(path: String, _fallback_text: String) -> void:
	var resolved_path: String = _cinematic_background_path(path)
	var new_stage: String = _cinematic_stage_key()
	if new_stage != cinematic_stage:
		cinematic_stage = new_stage
		cinematic_stage_time = 0.0
	_update_cinematic_background(resolved_path)
	_update_cinematic_characters()
	_hide_inline_visual(resolved_path)
	_apply_cinematic_layout()
	_disable_scene_art_effect_nodes()

func _add_cinematic_layers() -> void:
	cinematic_bg = TextureRect.new()
	cinematic_bg.name = "CinematicPerformanceBackground"
	cinematic_bg.anchor_left = 0.0
	cinematic_bg.anchor_top = 0.0
	cinematic_bg.anchor_right = 1.0
	cinematic_bg.anchor_bottom = PERFORMANCE_RATIO
	cinematic_bg.offset_left = 0
	cinematic_bg.offset_top = 0
	cinematic_bg.offset_right = 0
	cinematic_bg.offset_bottom = 0
	cinematic_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cinematic_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cinematic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_bg.scale = Vector2.ONE
	cinematic_bg.position = Vector2.ZERO
	cinematic_bg.modulate = Color.WHITE
	add_child(cinematic_bg)
	move_child(cinematic_bg, 0)

	# Keep these variables initialized for compatibility with child controllers,
	# but do not add any of them to the scene tree.
	cinematic_mist = null
	cinematic_fire = null
	cinematic_master = null
	cinematic_hero = null
	cinematic_dim = null
	cinematic_focus = null

func _add_world_map_layer() -> void:
	# The scene-art area should remain pure. Focus controllers may keep their own
	# data, but this cinematic layer no longer creates an overlay map panel.
	world_map_layer = null
	world_map_panel = null
	world_map_status_label = null
	world_map_nodes_row = null

func _make_character_layer(layer_name: String, path: String, left_anchor: float, right_anchor: float) -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.name = layer_name
	layer.anchor_left = left_anchor
	layer.anchor_right = right_anchor
	layer.anchor_top = 0.10
	layer.anchor_bottom = PERFORMANCE_RATIO
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			layer.texture = resource
	return layer

func _current_node_id() -> String:
	if in_prologue:
		return "prologue"
	if node_index >= 0 and node_index < NODES.size():
		var node: Dictionary = NODES[node_index]
		return str(node.get("id", "node"))
	return "node"

func _cinematic_stage_key() -> String:
	if not in_prologue:
		return _current_node_id()
	if step_index >= 0 and step_index < 12:
		return "prologue_%02d" % [step_index + 1]
	if step_index == PROLOGUE_CAREER_STEP:
		return "departure"
	return "node"

func _cinematic_background_path(path: String) -> String:
	if not in_prologue:
		return path
	if step_index >= 0 and step_index < 12:
		return _formal_prologue_background_for_step(step_index, _legacy_prologue_background_path())
	if step_index == PROLOGUE_CAREER_STEP:
		return PROLOGUE_DEPARTURE
	return path

func _legacy_prologue_background_path() -> String:
	if step_index <= 3:
		return PROLOGUE_BLACK_TIDE
	if step_index <= 8:
		return PROLOGUE_RESCUE
	if step_index <= 11:
		return PROLOGUE_ARROW
	return PROLOGUE_DEPARTURE

func _node_performance_data(_stage: String) -> Dictionary:
	return NODE_PERFORMANCE["node"]

func _merge_performance_defaults(_stage: String, data: Dictionary) -> Dictionary:
	var merged: Dictionary = NODE_PERFORMANCE["node"].duplicate(true)
	for key in data.keys():
		if merged.has(key):
			merged[key] = data[key]
	return merged

func _update_cinematic_background(path: String) -> void:
	if cinematic_bg == null:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var resource: Resource = load(path)
	if resource is Texture2D:
		cinematic_bg.texture = resource
	cinematic_bg.visible = true
	cinematic_bg.scale = Vector2.ONE
	cinematic_bg.position = Vector2.ZERO
	cinematic_bg.modulate = Color.WHITE

func _update_cinematic_characters() -> void:
	# Intentionally blank: no foreground character plates over narrative scene art.
	pass

func _hide_inline_visual(path: String) -> void:
	if visual_texture != null:
		visual_texture.texture = null
		visual_texture.visible = false
		visual_texture.custom_minimum_size = Vector2.ZERO
	if visual_label != null:
		visual_label.visible = false
		visual_label.custom_minimum_size = Vector2.ZERO
	if visual_debug_label != null:
		visual_debug_label.visible = false
		visual_debug_label.custom_minimum_size = Vector2.ZERO
		visual_debug_label.text = ""
	if visual_texture != null and visual_texture.get_parent() != null and visual_texture.get_parent().get_parent() != null:
		var frame: Node = visual_texture.get_parent().get_parent()
		if frame is Control:
			(frame as Control).custom_minimum_size = Vector2.ZERO

func _track_source() -> String:
	return "static"

func _update_cinematic_motion(_delta: float) -> void:
	_disable_scene_art_effect_nodes()

func _update_layer_motion(_zoom: float, _pan_x: float, _pan_y: float, _dim_alpha: float, _mist_alpha: float, _fire_alpha: float) -> void:
	_disable_scene_art_effect_nodes()

func _update_character_motion(_zoom: float) -> void:
	_disable_scene_art_effect_nodes()

func _disable_scene_art_effect_nodes() -> void:
	if cinematic_bg != null:
		cinematic_bg.visible = true
		cinematic_bg.scale = Vector2.ONE
		cinematic_bg.position = Vector2.ZERO
		cinematic_bg.modulate = Color.WHITE
	if cinematic_mist != null:
		cinematic_mist.visible = false
	if cinematic_fire != null:
		cinematic_fire.visible = false
	if cinematic_dim != null:
		cinematic_dim.visible = false
	if cinematic_focus != null:
		cinematic_focus.visible = false
	if cinematic_master != null:
		cinematic_master.visible = false
	if cinematic_hero != null:
		cinematic_hero.visible = false
	if world_map_layer != null:
		world_map_layer.visible = false
	if world_map_panel != null:
		world_map_panel.visible = false

func _apply_cinematic_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var operation_height: float = max(MIN_OPERATION_HEIGHT, viewport_size.y * (1.0 - PERFORMANCE_RATIO))
	var operation_top: float = max(0.48, OPERATION_BOTTOM - operation_height / max(1.0, viewport_size.y))
	var performance_bottom: float = operation_top
	if cinematic_bg != null:
		cinematic_bg.anchor_bottom = performance_bottom
		cinematic_bg.offset_left = 0
		cinematic_bg.offset_top = 0
		cinematic_bg.offset_right = 0
		cinematic_bg.offset_bottom = 0
		cinematic_bg.scale = Vector2.ONE
		cinematic_bg.position = Vector2.ZERO
		cinematic_bg.modulate = Color.WHITE
	var root_panel: PanelContainer = _find_operation_panel()
	if root_panel != null:
		root_panel.anchor_left = 0.02
		root_panel.anchor_right = 0.98
		root_panel.anchor_top = operation_top
		root_panel.anchor_bottom = OPERATION_BOTTOM
		root_panel.offset_left = 0
		root_panel.offset_right = 0
		root_panel.offset_top = 0
		root_panel.offset_bottom = 0
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 21)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 13)
	if map_label != null:
		map_label.custom_minimum_size = Vector2.ZERO
		map_label.visible = false
	if scene_label != null:
		scene_label.custom_minimum_size = Vector2.ZERO
		scene_label.visible = false
	if body_label != null:
		body_label.custom_minimum_size = Vector2(0, 54)
		body_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body_label.add_theme_font_size_override("normal_font_size", 18)
	if vars_label != null:
		vars_label.add_theme_font_size_override("font_size", 13)
	if action_scroll != null:
		action_scroll.custom_minimum_size = Vector2(0, max(150.0, operation_height - 170.0))
		action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if action_content != null:
		action_content.add_theme_constant_override("separation", 4)
	_hide_node_local_map_controls()
	_disable_scene_art_effect_nodes()

func _refresh_world_map() -> void:
	if world_map_layer != null:
		world_map_layer.visible = false
	if world_map_panel != null:
		world_map_panel.visible = false
	if world_map_nodes_row != null:
		for child: Node in world_map_nodes_row.get_children():
			child.queue_free()

func _make_world_map_line(_index: int) -> Label:
	var line: Label = Label.new()
	line.visible = false
	return line

func _make_world_map_node_button(_index: int) -> Button:
	var btn: Button = Button.new()
	btn.visible = false
	btn.disabled = true
	return btn

func _world_map_marker_for_index(index: int) -> String:
	if index == node_index:
		return "◆ 当前"
	if index < node_index:
		return "● 已过"
	if index == node_index + 1:
		return "◎ 可前往"
	return "○ 未开放"

func _current_world_map_title() -> String:
	if node_index >= 0 and node_index < NODES.size():
		var node: Dictionary = NODES[node_index]
		return str(node.get("title", ""))
	return "未定"

func _hide_node_local_map_controls() -> void:
	if map_buttons_box != null:
		map_buttons_box.visible = false
		map_buttons_box.custom_minimum_size = Vector2.ZERO
		for child: Node in map_buttons_box.get_children():
			child.queue_free()
	if action_content != null:
		for child: Node in action_content.get_children():
			if child is Label and (child as Label).text == "行军图操作":
				(child as Label).visible = false
				(child as Label).custom_minimum_size = Vector2.ZERO

func _add_safe_map_buttons() -> void:
	_hide_node_local_map_controls()

func _find_operation_panel() -> PanelContainer:
	for child: Node in get_children():
		if child is PanelContainer:
			return child as PanelContainer
	return null
