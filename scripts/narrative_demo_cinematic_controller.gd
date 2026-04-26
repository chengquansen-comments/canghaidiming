extends "res://scripts/narrative_demo_formal_controller.gd"

const PERFORMANCE_RATIO: float = 0.6667
const OPERATION_BOTTOM: float = 0.99
const MIN_OPERATION_HEIGHT: float = 340.0
const PERFORMANCE_TRACKS_PATH := "res://data/performance_tracks.json"
const PROLOGUE_BLACK_TIDE := "res://assets/pixel_battle/backgrounds/prologue_black_tide.svg"
const PROLOGUE_RESCUE := "res://assets/pixel_battle/backgrounds/prologue_master_rescue.svg"
const PROLOGUE_ARROW := "res://assets/pixel_battle/backgrounds/prologue_arrow_silence.svg"
const PROLOGUE_DEPARTURE := "res://assets/pixel_battle/backgrounds/prologue_departure.svg"
const CHAR_MASTER := "res://assets/pixel_battle/portraits/performance_master_veteran.svg"
const CHAR_HERO := "res://assets/pixel_battle/portraits/performance_hero_young.svg"

const NODE_PERFORMANCE := {
	"military_order": {"zoom":0.018, "pan_x":3.0, "pan_y":-1.0, "dim":0.18, "mist":0.12, "fire":0.04, "hero":true, "hero_push":-5.0, "duration":2.8},
	"beach_ambush": {"zoom":0.030, "pan_x":10.0, "pan_y":-2.0, "dim":0.27, "mist":0.34, "fire":0.08, "hero":true, "hero_push":-9.0, "duration":2.8},
	"ming_firearm": {"zoom":0.072, "pan_x":0.0, "pan_y":-4.0, "dim":0.10, "mist":0.04, "fire":0.28, "hero":false, "hero_push":0.0, "duration":3.2},
	"transport_officer": {"zoom":0.024, "pan_x":6.0, "pan_y":-1.0, "dim":0.30, "mist":0.28, "fire":0.04, "hero":true, "hero_push":-6.0, "duration":2.8},
	"wakou_boss": {"zoom":0.036, "pan_x":12.0, "pan_y":-2.0, "dim":0.34, "mist":0.34, "fire":0.16, "hero":true, "hero_push":-10.0, "duration":3.2},
	"military_coverup": {"zoom":0.018, "pan_x":-4.0, "pan_y":0.0, "dim":0.42, "mist":0.14, "fire":0.02, "hero":false, "hero_push":0.0, "duration":3.0},
	"node": {"zoom":0.018, "pan_x":4.0, "pan_y":0.0, "dim":0.22, "mist":0.18, "fire":0.02, "hero":false, "hero_push":0.0, "duration":2.2}
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

func _ready() -> void:
	_load_performance_tracks()
	_add_cinematic_layers()
	super._ready()
	_add_world_map_layer()
	_refresh_world_map()
	_apply_cinematic_layout()

func _process(delta: float) -> void:
	cinematic_time += delta
	cinematic_stage_time += delta
	_update_cinematic_motion(delta)
	_apply_cinematic_layout()

func _render() -> void:
	super._render()
	_hide_node_local_map_controls()
	_refresh_world_map()

func _load_performance_tracks() -> void:
	performance_tracks_loaded = false
	performance_tracks.clear()
	if not FileAccess.file_exists(PERFORMANCE_TRACKS_PATH):
		return
	var file: FileAccess = FileAccess.open(PERFORMANCE_TRACKS_PATH, FileAccess.READ)
	if file == null:
		return
	var raw_text: String = file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		performance_tracks = parsed
		performance_tracks_loaded = true

func _render_visual(path: String, fallback_text: String) -> void:
	var resolved_path: String = _cinematic_background_path(path)
	var new_stage: String = _cinematic_stage_key()
	if new_stage != cinematic_stage:
		cinematic_stage = new_stage
		cinematic_stage_time = 0.0
	_update_cinematic_background(resolved_path)
	_update_cinematic_characters()
	_hide_inline_visual(resolved_path)
	_apply_cinematic_layout()

func _add_cinematic_layers() -> void:
	cinematic_bg = TextureRect.new()
	cinematic_bg.name = "CinematicPerformanceBackground"
	cinematic_bg.anchor_left = 0.0
	cinematic_bg.anchor_top = 0.0
	cinematic_bg.anchor_right = 1.0
	cinematic_bg.anchor_bottom = PERFORMANCE_RATIO
	cinematic_bg.offset_left = -18
	cinematic_bg.offset_top = -10
	cinematic_bg.offset_right = 18
	cinematic_bg.offset_bottom = 10
	cinematic_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cinematic_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cinematic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_bg)
	move_child(cinematic_bg, 0)

	cinematic_mist = ColorRect.new()
	cinematic_mist.name = "CinematicMistLayer"
	cinematic_mist.anchor_left = 0.0
	cinematic_mist.anchor_top = 0.0
	cinematic_mist.anchor_right = 1.0
	cinematic_mist.anchor_bottom = PERFORMANCE_RATIO
	cinematic_mist.offset_left = -260
	cinematic_mist.offset_right = 260
	cinematic_mist.color = Color(0.18, 0.20, 0.20, 0.20)
	cinematic_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_mist)
	move_child(cinematic_mist, 1)

	cinematic_fire = ColorRect.new()
	cinematic_fire.name = "CinematicFirePulse"
	cinematic_fire.anchor_left = 0.58
	cinematic_fire.anchor_top = 0.08
	cinematic_fire.anchor_right = 1.0
	cinematic_fire.anchor_bottom = PERFORMANCE_RATIO
	cinematic_fire.color = Color(0.55, 0.12, 0.08, 0.0)
	cinematic_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_fire)
	move_child(cinematic_fire, 2)

	cinematic_master = _make_character_layer("CinematicMaster", CHAR_MASTER, 0.20, 0.58)
	add_child(cinematic_master)
	move_child(cinematic_master, 3)

	cinematic_hero = _make_character_layer("CinematicHero", CHAR_HERO, 0.55, 0.92)
	add_child(cinematic_hero)
	move_child(cinematic_hero, 4)

	cinematic_dim = ColorRect.new()
	cinematic_dim.name = "CinematicDim"
	cinematic_dim.anchor_left = 0.0
	cinematic_dim.anchor_top = 0.0
	cinematic_dim.anchor_right = 1.0
	cinematic_dim.anchor_bottom = PERFORMANCE_RATIO
	cinematic_dim.color = Color(0.04, 0.035, 0.03, 0.20)
	cinematic_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_dim)
	move_child(cinematic_dim, 5)

	cinematic_focus = ColorRect.new()
	cinematic_focus.name = "CinematicFocus"
	cinematic_focus.anchor_left = 0.0
	cinematic_focus.anchor_top = 0.0
	cinematic_focus.anchor_right = 1.0
	cinematic_focus.anchor_bottom = PERFORMANCE_RATIO
	cinematic_focus.color = Color(0.03, 0.025, 0.02, 0.0)
	cinematic_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_focus)
	move_child(cinematic_focus, 6)

func _add_world_map_layer() -> void:
	if world_map_layer != null:
		return
	world_map_layer = Control.new()
	world_map_layer.name = "CinematicWorldMapLayer"
	world_map_layer.anchor_left = 0.0
	world_map_layer.anchor_top = 0.0
	world_map_layer.anchor_right = 1.0
	world_map_layer.anchor_bottom = PERFORMANCE_RATIO
	world_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_map_layer.z_index = 40
	world_map_layer.z_as_relative = false
	add_child(world_map_layer)

	world_map_panel = PanelContainer.new()
	world_map_panel.name = "WorldMapPanel"
	world_map_panel.anchor_left = 0.055
	world_map_panel.anchor_top = 0.035
	world_map_panel.anchor_right = 0.945
	world_map_panel.anchor_bottom = 0.205
	world_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_map_panel.z_index = 41
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.030, 0.024, 0.66)
	style.border_color = Color(0.74, 0.60, 0.38, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	world_map_panel.add_theme_stylebox_override("panel", style)
	world_map_layer.add_child(world_map_panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_map_panel.add_child(root)

	world_map_status_label = Label.new()
	world_map_status_label.name = "WorldMapStatusLabel"
	world_map_status_label.add_theme_font_size_override("font_size", 14)
	world_map_status_label.add_theme_color_override("font_color", Color("f0dfb8"))
	world_map_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	world_map_status_label.add_theme_constant_override("shadow_offset_x", 1)
	world_map_status_label.add_theme_constant_override("shadow_offset_y", 1)
	world_map_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(world_map_status_label)

	world_map_nodes_row = HBoxContainer.new()
	world_map_nodes_row.name = "WorldMapNodesRow"
	world_map_nodes_row.add_theme_constant_override("separation", 5)
	world_map_nodes_row.mouse_filter = Control.MOUSE_FILTER_PASS
	world_map_nodes_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(world_map_nodes_row)

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
	if step_index <= 3:
		return "black_tide_%d" % step_index
	if step_index <= 8:
		return "master_rescue"
	if step_index <= 11:
		return "arrow_silence"
	if step_index == PROLOGUE_CAREER_STEP:
		return "departure"
	return "node"

func _cinematic_background_path(path: String) -> String:
	if not in_prologue:
		return path
	if step_index <= 3:
		return PROLOGUE_BLACK_TIDE
	if step_index <= 8:
		return PROLOGUE_RESCUE
	if step_index <= 11:
		return PROLOGUE_ARROW
	if step_index == PROLOGUE_CAREER_STEP:
		return PROLOGUE_DEPARTURE
	return path

func _node_performance_data(stage: String) -> Dictionary:
	if performance_tracks_loaded:
		var timeline_variant = performance_tracks.get("timeline", {})
		if timeline_variant is Dictionary:
			var timeline: Dictionary = timeline_variant
			var data_variant = timeline.get(stage, timeline.get("node", {}))
			if data_variant is Dictionary:
				return _merge_performance_defaults(stage, data_variant)
	var fallback_variant = NODE_PERFORMANCE.get(stage, NODE_PERFORMANCE["node"])
	if fallback_variant is Dictionary:
		return fallback_variant
	return NODE_PERFORMANCE["node"]

func _merge_performance_defaults(stage: String, data: Dictionary) -> Dictionary:
	var fallback_variant = NODE_PERFORMANCE.get(stage, NODE_PERFORMANCE["node"])
	var merged: Dictionary = {}
	if fallback_variant is Dictionary:
		for key in (fallback_variant as Dictionary).keys():
			merged[key] = (fallback_variant as Dictionary)[key]
	for key in data.keys():
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

func _update_cinematic_characters() -> void:
	if cinematic_master != null:
		cinematic_master.visible = false
	if cinematic_hero != null:
		cinematic_hero.visible = false
	var stage: String = _cinematic_stage_key()
	var data: Dictionary = _node_performance_data(stage)
	if bool(data.get("master", false)) and cinematic_master != null:
		cinematic_master.visible = true
	if bool(data.get("hero", false)) and cinematic_hero != null:
		cinematic_hero.visible = true
	if in_prologue and not bool(data.get("master", false)) and not bool(data.get("hero", false)):
		if stage == "master_rescue" or stage == "arrow_silence":
			if cinematic_master != null:
				cinematic_master.visible = true
		elif stage == "departure":
			if cinematic_hero != null:
				cinematic_hero.visible = true

func _hide_inline_visual(path: String) -> void:
	if visual_texture != null:
		visual_texture.texture = null
		visual_texture.visible = false
		visual_texture.custom_minimum_size = Vector2.ZERO
	if visual_label != null:
		visual_label.visible = false
		visual_label.custom_minimum_size = Vector2.ZERO
	if visual_debug_label != null:
		visual_debug_label.visible = true
		visual_debug_label.text = "演出诊断：single-file｜source=%s｜stage=%s｜path=%s" % [_track_source(), _cinematic_stage_key(), path]
	if visual_texture != null and visual_texture.get_parent() != null and visual_texture.get_parent().get_parent() != null:
		var frame: Node = visual_texture.get_parent().get_parent()
		if frame is Control:
			(frame as Control).custom_minimum_size = Vector2.ZERO

func _track_source() -> String:
	return "json" if performance_tracks_loaded else "code"

func _update_cinematic_motion(delta: float) -> void:
	var stage: String = _cinematic_stage_key()
	var data: Dictionary = _node_performance_data(stage)
	var duration: float = max(0.2, float(data.get("duration", 3.0)))
	var progress: float = clamp(cinematic_stage_time / duration, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var zoom: float = float(data.get("zoom", 0.018)) * eased
	var pan_x: float = float(data.get("pan_x", 0.0)) * eased
	var pan_y: float = float(data.get("pan_y", 0.0)) * eased
	var dim_base: float = float(data.get("dim", 0.22))
	var mist_base: float = float(data.get("mist", 0.18))
	var fire_base: float = float(data.get("fire", 0.02))
	var pulse: float = float(data.get("pulse", 0.030))
	var dim_alpha: float = dim_base + pulse * sin(cinematic_time * 0.75)
	var mist_alpha: float = mist_base + 0.055 * eased
	var fire_alpha: float = fire_base + fire_base * max(0.0, sin(cinematic_time * 2.4))
	_update_layer_motion(zoom, pan_x, pan_y, dim_alpha, mist_alpha, fire_alpha)

func _update_layer_motion(zoom: float, pan_x: float, pan_y: float, dim_alpha: float, mist_alpha: float, fire_alpha: float) -> void:
	if cinematic_bg != null:
		var breath: float = 0.004 * sin(cinematic_time * 0.42)
		cinematic_bg.scale = Vector2(1.0 + zoom + breath, 1.0 + zoom + breath)
		cinematic_bg.position = Vector2(pan_x, pan_y)
	if cinematic_mist != null:
		var mist_offset: float = fmod(cinematic_time * 22.0, 240.0)
		cinematic_mist.offset_left = -260.0 + mist_offset
		cinematic_mist.offset_right = 260.0 + mist_offset
		cinematic_mist.color = Color(0.18, 0.20, 0.20, clamp(mist_alpha, 0.0, 0.55))
	if cinematic_fire != null:
		cinematic_fire.color = Color(0.55, 0.12, 0.08, clamp(fire_alpha, 0.0, 0.24))
	if cinematic_dim != null:
		cinematic_dim.color = Color(0.04, 0.035, 0.03, clamp(dim_alpha, 0.0, 0.70))
	_update_character_motion(zoom)

func _update_character_motion(zoom: float) -> void:
	var stage: String = _cinematic_stage_key()
	var data: Dictionary = _node_performance_data(stage)
	var hero_push: float = float(data.get("hero_push", -6.0))
	var master_push: float = float(data.get("master_push", 10.0))
	if cinematic_master != null and cinematic_master.visible:
		var s: float = 1.0 + zoom + 0.018 * sin(cinematic_time * 1.05)
		cinematic_master.scale = Vector2(s, s)
		cinematic_master.position.x = master_push * clamp(cinematic_stage_time / 2.8, 0.0, 1.0)
		cinematic_master.position.y = 3.0 * sin(cinematic_time * 0.8)
	if cinematic_hero != null and cinematic_hero.visible:
		var h: float = 1.0 + zoom + 0.014 * sin(cinematic_time * 1.2)
		cinematic_hero.scale = Vector2(h, h)
		cinematic_hero.position.x = hero_push * clamp(cinematic_stage_time / 3.0, 0.0, 1.0)
		cinematic_hero.position.y = 2.0 * sin(cinematic_time * 0.9)

func _apply_cinematic_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var operation_height: float = max(MIN_OPERATION_HEIGHT, viewport_size.y * (1.0 - PERFORMANCE_RATIO))
	var operation_top: float = max(0.48, OPERATION_BOTTOM - operation_height / max(1.0, viewport_size.y))
	var performance_bottom: float = operation_top
	if cinematic_bg != null:
		cinematic_bg.anchor_bottom = performance_bottom
	if cinematic_mist != null:
		cinematic_mist.anchor_bottom = performance_bottom
	if cinematic_fire != null:
		cinematic_fire.anchor_bottom = performance_bottom
	if cinematic_master != null:
		cinematic_master.anchor_bottom = performance_bottom
	if cinematic_hero != null:
		cinematic_hero.anchor_bottom = performance_bottom
	if cinematic_dim != null:
		cinematic_dim.anchor_bottom = performance_bottom
	if cinematic_focus != null:
		cinematic_focus.anchor_bottom = performance_bottom
	if world_map_layer != null:
		world_map_layer.anchor_bottom = performance_bottom
	if world_map_panel != null:
		world_map_panel.anchor_bottom = minf(0.205, maxf(0.145, performance_bottom - 0.44))
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
		map_label.custom_minimum_size = Vector2(0, 0)
		map_label.visible = false
	if scene_label != null:
		scene_label.custom_minimum_size = Vector2(0, 0)
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

func _refresh_world_map() -> void:
	if world_map_layer == null or world_map_panel == null or world_map_nodes_row == null:
		return
	world_map_panel.visible = not in_prologue
	if in_prologue:
		return
	if world_map_status_label != null:
		world_map_status_label.text = "海疆行军图｜当前：%s｜军功 %d｜清望 %d｜旧案 %d" % [_current_world_map_title(), jun_gong, qing_wang, clues]
	for child: Node in world_map_nodes_row.get_children():
		child.queue_free()
	for i in range(NODES.size()):
		if i > 0:
			world_map_nodes_row.add_child(_make_world_map_line(i))
		world_map_nodes_row.add_child(_make_world_map_node_button(i))

func _make_world_map_line(index: int) -> Label:
	var line: Label = Label.new()
	line.text = "━━"
	line.custom_minimum_size = Vector2(24, 34)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Color("c9a35b") if index <= node_index else Color(0.60, 0.55, 0.46, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _make_world_map_node_button(index: int) -> Button:
	var node: Dictionary = NODES[index]
	var btn: Button = Button.new()
	btn.text = "%s\n%s" % [_world_map_marker_for_index(index), str(node.get("title", ""))]
	btn.custom_minimum_size = Vector2(116, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = index > node_index + 1
	btn.pressed.connect(_on_map_node_pressed.bind(index))
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
