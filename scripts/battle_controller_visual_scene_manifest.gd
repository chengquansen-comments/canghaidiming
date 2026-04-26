extends "res://scripts/battle_controller_visual_narrative_formal.gd"

const BATTLE_SCENE_MANIFEST_PATH := "res://data/battle_scene_manifest.json"
const DEFAULT_SCENE_ID := "fallback"

var battle_scene_manifest: Dictionary = {}
var battle_scene_loaded: bool = false
var battle_scene_id: String = ""
var battle_scene_bg: TextureRect
var battle_scene_mist: ColorRect
var battle_scene_dim: ColorRect
var battle_scene_accent: ColorRect
var battle_scene_label: Label
var battle_scene_time: float = 0.0

func _ready() -> void:
	_load_battle_scene_manifest()
	_add_battle_scene_layers()
	super._ready()
	_apply_battle_scene_from_context()

func _process(delta: float) -> void:
	battle_scene_time += delta
	_update_battle_scene_motion(delta)
	super._process(delta)

func _load_battle_scene_manifest() -> void:
	battle_scene_loaded = false
	battle_scene_manifest.clear()
	if not FileAccess.file_exists(BATTLE_SCENE_MANIFEST_PATH):
		return
	var file: FileAccess = FileAccess.open(BATTLE_SCENE_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		battle_scene_manifest = parsed
		battle_scene_loaded = true

func _add_battle_scene_layers() -> void:
	battle_scene_bg = TextureRect.new()
	battle_scene_bg.name = "BattleSceneBackgroundById"
	battle_scene_bg.anchor_left = 0.0
	battle_scene_bg.anchor_top = 0.0
	battle_scene_bg.anchor_right = 1.0
	battle_scene_bg.anchor_bottom = 1.0
	battle_scene_bg.offset_left = -24
	battle_scene_bg.offset_top = -16
	battle_scene_bg.offset_right = 24
	battle_scene_bg.offset_bottom = 16
	battle_scene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_scene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	battle_scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_scene_bg)
	move_child(battle_scene_bg, 0)

	battle_scene_mist = ColorRect.new()
	battle_scene_mist.name = "BattleSceneMistById"
	battle_scene_mist.anchor_left = 0.0
	battle_scene_mist.anchor_top = 0.0
	battle_scene_mist.anchor_right = 1.0
	battle_scene_mist.anchor_bottom = 1.0
	battle_scene_mist.offset_left = -320
	battle_scene_mist.offset_right = 320
	battle_scene_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_scene_mist)
	move_child(battle_scene_mist, 1)

	battle_scene_accent = ColorRect.new()
	battle_scene_accent.name = "BattleSceneAccentById"
	battle_scene_accent.anchor_left = 0.52
	battle_scene_accent.anchor_top = 0.06
	battle_scene_accent.anchor_right = 1.0
	battle_scene_accent.anchor_bottom = 0.78
	battle_scene_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_scene_accent)
	move_child(battle_scene_accent, 2)

	battle_scene_dim = ColorRect.new()
	battle_scene_dim.name = "BattleSceneDimById"
	battle_scene_dim.anchor_left = 0.0
	battle_scene_dim.anchor_top = 0.0
	battle_scene_dim.anchor_right = 1.0
	battle_scene_dim.anchor_bottom = 1.0
	battle_scene_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_scene_dim)
	move_child(battle_scene_dim, 3)

	battle_scene_label = Label.new()
	battle_scene_label.name = "BattleSceneIdLabel"
	battle_scene_label.anchor_left = 0.02
	battle_scene_label.anchor_top = 0.08
	battle_scene_label.anchor_right = 0.48
	battle_scene_label.anchor_bottom = 0.08
	battle_scene_label.offset_top = 0
	battle_scene_label.offset_bottom = 34
	battle_scene_label.add_theme_font_size_override("font_size", 20)
	battle_scene_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_scene_label)
	move_child(battle_scene_label, 4)

func _apply_battle_scene_from_context() -> void:
	var id: String = NarrativeBattleContext.get_battle_id()
	if id.is_empty():
		id = _test_battle_id_for_role()
	_apply_battle_scene_by_id(id)

func _test_battle_id_for_role() -> String:
	if player_role_id == "blademaster":
		return "test_blademaster_duel"
	if player_role_id == "spearman":
		return "test_spearman_duel"
	return DEFAULT_SCENE_ID

func _select_role_and_start(role_id: String) -> void:
	super._select_role_and_start(role_id)
	_apply_battle_scene_by_id(_test_battle_id_for_role())

func _try_recommended_role_entry(role_id: String) -> bool:
	_apply_battle_scene_from_context()
	return super._try_recommended_role_entry(role_id)

func _apply_battle_scene_by_id(id: String) -> void:
	battle_scene_id = id if not id.is_empty() else DEFAULT_SCENE_ID
	_reset_battle_scene_visual()
	var config: Dictionary = _battle_scene_config(battle_scene_id)
	var bg_path: String = str(config.get("background", ""))
	if battle_scene_bg != null and not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		var resource: Resource = load(bg_path)
		if resource is Texture2D:
			battle_scene_bg.texture = resource
			battle_scene_bg.visible = true
	var mist: float = float(config.get("mist", 0.0))
	var dim: float = float(config.get("dim", 0.0))
	var accent: float = float(config.get("accent", 0.0))
	if battle_scene_mist != null:
		battle_scene_mist.visible = mist > 0.001
		battle_scene_mist.color = Color(0.75, 0.80, 0.80, clamp(mist, 0.0, 0.60))
	if battle_scene_dim != null:
		battle_scene_dim.color = Color(0.02, 0.018, 0.016, clamp(dim, 0.0, 0.75))
	if battle_scene_accent != null:
		battle_scene_accent.visible = accent > 0.001
		battle_scene_accent.color = Color(0.55, 0.12, 0.08, clamp(accent, 0.0, 0.40))
	if battle_scene_label != null:
		battle_scene_label.text = "战斗场景｜%s｜battle_id=%s" % [str(config.get("label", battle_scene_id)), battle_scene_id]
		battle_scene_label.visible = true

func _reset_battle_scene_visual() -> void:
	battle_scene_time = 0.0
	if battle_scene_bg != null:
		battle_scene_bg.texture = null
		battle_scene_bg.visible = false
		battle_scene_bg.scale = Vector2.ONE
		battle_scene_bg.position = Vector2.ZERO
		battle_scene_bg.modulate = Color.WHITE
	if battle_scene_mist != null:
		battle_scene_mist.visible = false
		battle_scene_mist.color = Color(1, 1, 1, 0)
		battle_scene_mist.offset_left = -320
		battle_scene_mist.offset_right = 320
	if battle_scene_dim != null:
		battle_scene_dim.color = Color(0, 0, 0, 0)
	if battle_scene_accent != null:
		battle_scene_accent.visible = false
		battle_scene_accent.color = Color(1, 1, 1, 0)
	if battle_scene_label != null:
		battle_scene_label.text = ""
		battle_scene_label.visible = false

func _battle_scene_config(id: String) -> Dictionary:
	if battle_scene_loaded:
		var cfg = battle_scene_manifest.get(id, battle_scene_manifest.get(DEFAULT_SCENE_ID, {}))
		if cfg is Dictionary:
			return cfg
	return {"background":"res://assets/pixel_battle/backgrounds/battle_bg_training_ground.svg", "label":id, "mist":0.08, "dim":0.08, "accent":0.02, "camera_zoom":0.010, "camera_pan_x":0.0, "camera_pan_y":0.0}

func _update_battle_scene_motion(delta: float) -> void:
	var config: Dictionary = _battle_scene_config(battle_scene_id)
	var progress: float = clamp(battle_scene_time / 3.0, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	if battle_scene_bg != null and battle_scene_bg.visible:
		var zoom: float = float(config.get("camera_zoom", 0.0)) * eased
		var pan_x: float = float(config.get("camera_pan_x", 0.0)) * eased
		var pan_y: float = float(config.get("camera_pan_y", 0.0)) * eased
		var breath: float = 0.003 * sin(battle_scene_time * 0.55)
		battle_scene_bg.scale = Vector2(1.0 + zoom + breath, 1.0 + zoom + breath)
		battle_scene_bg.position = Vector2(pan_x, pan_y)
	if battle_scene_mist != null and battle_scene_mist.visible:
		var mist_offset: float = fmod(battle_scene_time * 18.0, 260.0)
		battle_scene_mist.offset_left = -320.0 + mist_offset
		battle_scene_mist.offset_right = 320.0 + mist_offset
	if battle_scene_accent != null and battle_scene_accent.visible:
		var base_alpha: float = float(config.get("accent", 0.0))
		battle_scene_accent.color = Color(0.55, 0.12, 0.08, clamp(base_alpha + base_alpha * max(0.0, sin(battle_scene_time * 2.2)), 0.0, 0.42))
