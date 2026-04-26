extends "res://scripts/battle_controller_visual_narrative_formal.gd"

const BATTLE_SCENE_MANIFEST_PATH := "res://data/battle_scene_manifest.json"
const DEFAULT_SCENE_ID := "fallback"

var battle_scene_manifest: Dictionary = {}
var battle_scene_loaded: bool = false
var battle_scene_id: String = ""
var battle_scene_time: float = 0.0

func _ready() -> void:
	_load_battle_scene_manifest()
	super._ready()
	_apply_battle_scene_from_context()

func _process(delta: float) -> void:
	battle_scene_time += delta
	_update_original_background_motion(delta)
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

func _apply_battle_scene_from_context() -> void:
	var id: String = NarrativeBattleContext.get_battle_id()
	if id.is_empty() or id == DEFAULT_SCENE_ID:
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
	var ok: bool = super._try_recommended_role_entry(role_id)
	_apply_battle_scene_from_context()
	return ok

func _apply_battle_scene_by_id(id: String) -> void:
	battle_scene_id = id if not id.is_empty() else DEFAULT_SCENE_ID
	battle_scene_time = 0.0
	var config: Dictionary = _battle_scene_config(battle_scene_id)
	var bg_path: String = str(config.get("background", ""))
	if background_texture != null:
		background_texture.texture = null
		background_texture.visible = true
		background_texture.scale = Vector2.ONE
		background_texture.position = Vector2.ZERO
		background_texture.modulate = Color.WHITE
		if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
			var tex: Texture2D = _safe_load_texture(bg_path)
			if tex != null:
				background_texture.texture = tex
	_update_original_scene_label(config)

func _battle_scene_config(id: String) -> Dictionary:
	if battle_scene_loaded:
		var cfg = battle_scene_manifest.get(id, battle_scene_manifest.get(DEFAULT_SCENE_ID, {}))
		if cfg is Dictionary:
			return cfg
	return {"background":"res://assets/pixel_battle/backgrounds/battle_bg_training_ground.svg", "label":id, "camera_zoom":0.010, "camera_pan_x":0.0, "camera_pan_y":0.0}

func _update_original_background_motion(delta: float) -> void:
	if background_texture == null or background_texture.texture == null:
		return
	var config: Dictionary = _battle_scene_config(battle_scene_id)
	var progress: float = clamp(battle_scene_time / 3.0, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var zoom: float = float(config.get("camera_zoom", 0.0)) * eased
	var pan_x: float = float(config.get("camera_pan_x", 0.0)) * eased
	var pan_y: float = float(config.get("camera_pan_y", 0.0)) * eased
	var breath: float = 0.0025 * sin(battle_scene_time * 0.55)
	background_texture.scale = Vector2(1.0 + zoom + breath, 1.0 + zoom + breath)
	background_texture.position = Vector2(pan_x, pan_y)

func _update_original_scene_label(config: Dictionary) -> void:
	var label_text: String = "战斗场景｜%s｜battle_id=%s｜enemy_source=%s" % [str(config.get("label", battle_scene_id)), battle_scene_id, NarrativeBattleContext.enemy_source_text()]
	if phase_label != null:
		phase_label.text = label_text
	if battle_log_strip != null and not battle_active:
		battle_log_strip.text = label_text
