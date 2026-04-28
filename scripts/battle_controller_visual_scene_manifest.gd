extends "res://scripts/battle_controller_visual_narrative_formal.gd"

const BATTLE_SCENE_MANIFEST_PATH := "res://data/battle_scene_manifest.json"
const DEFAULT_SCENE_ID := "fallback"
const DEBUG_TOGGLE_KEY := KEY_F10

var battle_scene_manifest: Dictionary = {}
var battle_scene_loaded: bool = false
var battle_scene_id: String = ""
var battle_scene_time: float = 0.0

var stable_debug_layer: CanvasLayer
var stable_debug_panel: PanelContainer
var stable_debug_title_label: Label
var stable_debug_context_label: Label
var stable_debug_enemy_label: Label
var stable_debug_deck_label: Label
var stable_debug_ai_label: Label
var stable_debug_runtime_label: Label
var stable_debug_actions_row: HBoxContainer
var stable_debug_continue_button: Button
var stable_debug_last_values: Dictionary = {}

func _ready() -> void:
	_load_battle_scene_manifest()
	super._ready()
	_hide_legacy_debug_window()
	_build_stable_debug_panel()
	_apply_battle_scene_from_context()
	_refresh_stable_debug_panel()

func _process(delta: float) -> void:
	battle_scene_time += delta
	_update_original_background_motion(delta)
	super._process(delta)
	_refresh_stable_debug_panel()

func _input(event: InputEvent) -> void:
	if _is_debug_toggle_event(event):
		_toggle_stable_debug_panel()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _is_debug_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == DEBUG_TOGGLE_KEY

func _toggle_stable_debug_panel() -> void:
	NarrativeBattleContext.toggle_ui_debug_visible()
	_apply_stable_debug_visibility()

func _apply_stable_debug_visibility() -> void:
	var debug_visible := NarrativeBattleContext.is_ui_debug_visible()
	if stable_debug_layer != null:
		stable_debug_layer.visible = debug_visible
	if stable_debug_panel != null:
		stable_debug_panel.visible = debug_visible

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
	if not NarrativeBattleContext.has_request() and (id.is_empty() or id == DEFAULT_SCENE_ID):
		id = _test_battle_id_for_role()
	if id.is_empty():
		id = DEFAULT_SCENE_ID
	_apply_battle_scene_by_id(id)

func _test_battle_id_for_role() -> String:
	if player_role_id == "blademaster":
		return "test_blademaster_duel"
	if player_role_id == "spearman":
		return "test_spearman_duel"
	return DEFAULT_SCENE_ID

func _select_role_and_start(role_id: String) -> void:
	super._select_role_and_start(role_id)
	if NarrativeBattleContext.has_request():
		_load_narrative_battle_once()
		_apply_enemy_ai_manifest_behavior_once()
		return
	_apply_battle_scene_by_id(_test_battle_id_for_role())

func _try_recommended_role_entry(role_id: String) -> bool:
	var ok: bool = super._try_recommended_role_entry(role_id)
	if NarrativeBattleContext.has_request():
		_load_narrative_battle_once()
		_apply_enemy_ai_manifest_behavior_once()
		return ok
	_apply_battle_scene_from_context()
	return ok

func _apply_battle_background(loadout: Dictionary) -> void:
	var id: String = str(loadout.get("battle_id", ""))
	if id.is_empty():
		super._apply_battle_background(loadout)
		return
	_apply_battle_scene_by_id(id)
	_apply_enemy_ai_manifest_behavior_once()

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
	return {"background":"res://assets/pixel_battle/backgrounds/battle_bg_training_ground.png", "label":id, "camera_zoom":0.010, "camera_pan_x":0.0, "camera_pan_y":0.0}

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
	_refresh_stable_debug_panel()

func _hide_legacy_debug_window() -> void:
	# 旧调试窗口由父类创建，包含“关卡信息 / 接战映射 / 敌人配置”等内容。
	# 这些信息已合并到 StableBattleDebugPanel；旧层整体隐藏，避免与新面板重复。
	if enemy_config_strip != null:
		enemy_config_strip.visible = false
	if narrative_debug_layer != null:
		narrative_debug_layer.visible = false

func _build_stable_debug_panel() -> void:
	if stable_debug_layer != null:
		return
	stable_debug_layer = CanvasLayer.new()
	stable_debug_layer.name = "StableBattleDebugLayer"
	stable_debug_layer.layer = 150
	add_child(stable_debug_layer)

	stable_debug_panel = PanelContainer.new()
	stable_debug_panel.name = "StableBattleDebugPanel"
	stable_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	stable_debug_panel.anchor_left = 1.0
	stable_debug_panel.anchor_right = 1.0
	stable_debug_panel.anchor_top = 0.0
	stable_debug_panel.anchor_bottom = 0.0
	stable_debug_panel.offset_left = -720
	stable_debug_panel.offset_top = 8
	stable_debug_panel.offset_right = -12
	stable_debug_panel.offset_bottom = 214
	stable_debug_panel.add_theme_stylebox_override("panel", _stable_debug_panel_style())
	stable_debug_layer.add_child(stable_debug_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	stable_debug_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	stable_debug_title_label = _make_stable_debug_label(15)
	stable_debug_title_label.add_theme_color_override("font_color", Color("ffe6b5"))
	box.add_child(stable_debug_title_label)

	stable_debug_context_label = _make_stable_debug_label(13)
	box.add_child(stable_debug_context_label)

	stable_debug_enemy_label = _make_stable_debug_label(13)
	box.add_child(stable_debug_enemy_label)

	stable_debug_deck_label = _make_stable_debug_label(13)
	box.add_child(stable_debug_deck_label)

	stable_debug_ai_label = _make_stable_debug_label(13)
	box.add_child(stable_debug_ai_label)

	stable_debug_runtime_label = _make_stable_debug_label(13)
	box.add_child(stable_debug_runtime_label)

	stable_debug_actions_row = HBoxContainer.new()
	stable_debug_actions_row.mouse_filter = Control.MOUSE_FILTER_PASS
	stable_debug_actions_row.add_theme_constant_override("separation", 8)
	box.add_child(stable_debug_actions_row)

	stable_debug_continue_button = Button.new()
	stable_debug_continue_button.text = "返回剧情"
	stable_debug_continue_button.custom_minimum_size = Vector2(132, 32)
	stable_debug_continue_button.focus_mode = Control.FOCUS_NONE
	stable_debug_continue_button.pressed.connect(_on_continue_narrative_pressed)
	stable_debug_actions_row.add_child(stable_debug_continue_button)
	_apply_stable_debug_visibility()

func _stable_debug_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.78)
	style.border_color = Color(0.88, 0.72, 0.42, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _make_stable_debug_label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9dcc2"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _refresh_stable_debug_panel() -> void:
	if stable_debug_panel == null:
		return
	if not NarrativeBattleContext.is_ui_debug_visible():
		return
	var manifest_enemy: Dictionary = NarrativeBattleContext.get_enemy_config()
	var mapping: Dictionary = NarrativeBattleContext.get_battle_mapping()
	var scene_config: Dictionary = _battle_scene_config(battle_scene_id)
	var enemy_id := str(manifest_enemy.get("enemy_id", ""))
	var enemy_name := _runtime_enemy_name(manifest_enemy)
	var enemy_hp_text := _runtime_enemy_hp_text(manifest_enemy)
	var enemy_posture_text := _runtime_enemy_posture_text(manifest_enemy)
	var deck_text := _runtime_enemy_deck_text(manifest_enemy)
	var ai_text := _runtime_enemy_ai_text(manifest_enemy)
	var runtime_text := _runtime_battle_state_text()
	var values := {
		"title": "Battle Debug [F10]｜%s｜battle_id=%s｜enemy_source=%s" % [str(scene_config.get("label", battle_scene_id)), battle_scene_id, NarrativeBattleContext.enemy_source_text()],
		"context": "encounter=%s｜node=%s｜mapping=%s｜difficulty=%s" % [str(NarrativeBattleContext.encounter_id), str(NarrativeBattleContext.source_node_id), str(mapping.get("label", "")), str(mapping.get("difficulty", ""))],
		"enemy": "enemy_id=%s｜name=%s｜HP=%s｜势=%s" % [enemy_id, enemy_name, enemy_hp_text, enemy_posture_text],
		"deck": deck_text,
		"ai": ai_text,
		"runtime": runtime_text
	}
	_set_stable_label_text(stable_debug_title_label, values["title"], "title")
	_set_stable_label_text(stable_debug_context_label, values["context"], "context")
	_set_stable_label_text(stable_debug_enemy_label, values["enemy"], "enemy")
	_set_stable_label_text(stable_debug_deck_label, values["deck"], "deck")
	_set_stable_label_text(stable_debug_ai_label, values["ai"], "ai")
	_set_stable_label_text(stable_debug_runtime_label, values["runtime"], "runtime")

func _set_stable_label_text(label: Label, value: String, key: String) -> void:
	if label == null:
		return
	if str(stable_debug_last_values.get(key, "")) == value:
		return
	stable_debug_last_values[key] = value
	label.text = value

func _runtime_enemy_name(manifest_enemy: Dictionary) -> String:
	if enemy != null:
		return str(enemy.data.display_name)
	return str(manifest_enemy.get("display_name", "未生成"))

func _runtime_enemy_hp_text(manifest_enemy: Dictionary) -> String:
	if enemy != null:
		return "%d/%d" % [int(enemy.hp), int(enemy.data.max_hp)]
	return "?/%s" % str(manifest_enemy.get("max_hp", "?"))

func _runtime_enemy_posture_text(manifest_enemy: Dictionary) -> String:
	if enemy != null:
		return "%d/%d" % [int(enemy.momentum), int(enemy.data.max_momentum)]
	return "%s/%s" % [str(manifest_enemy.get("start_posture", "?")), str(manifest_enemy.get("max_posture", "?"))]

func _runtime_enemy_deck_text(manifest_enemy: Dictionary) -> String:
	var hand_names: Array[String] = []
	if enemy != null:
		for card in enemy.hand:
			hand_names.append(str(card.display_name))
	if not hand_names.is_empty():
		return "deck=runtime_hand｜%s" % " / ".join(hand_names)
	var manifest_deck = manifest_enemy.get("deck", [])
	if manifest_deck is Array:
		var deck_names: Array[String] = []
		for card_variant in (manifest_deck as Array):
			if card_variant is Dictionary:
				deck_names.append(str((card_variant as Dictionary).get("name", "?")))
		return "deck=manifest｜%s" % " / ".join(deck_names)
	return "deck=none"

func _runtime_enemy_ai_text(manifest_enemy: Dictionary) -> String:
	var weights = manifest_enemy.get("intent_weights", {})
	var phases = manifest_enemy.get("phase_behaviors", [])
	var weight_text := "{}"
	if weights is Dictionary:
		weight_text = _compact_weights(weights)
	var phase_count := 0
	if phases is Array:
		phase_count = (phases as Array).size()
	var source := "enemy_manifest" if NarrativeBattleContext.enemy_source_text() == "manifest" else "fallback"
	return "AI=%s｜weights=%s｜phases=%d" % [source, weight_text, phase_count]

func _compact_weights(weights_variant) -> String:
	if not (weights_variant is Dictionary):
		return "{}"
	var weights: Dictionary = weights_variant
	return "atk:%s guard:%s gain:%s break:%s feint:%s" % [str(weights.get("attack", 0)), str(weights.get("guard", 0)), str(weights.get("gain_posture", 0)), str(weights.get("break_posture", 0)), str(weights.get("feint", 0))]

func _runtime_battle_state_text() -> String:
	if state_machine == null:
		return "runtime=state_machine:null"
	var player_hp := "?"
	var enemy_hp := "?"
	if player != null:
		player_hp = "%d/%d" % [int(player.hp), int(player.data.max_hp)]
	if enemy != null:
		enemy_hp = "%d/%d" % [int(enemy.hp), int(enemy.data.max_hp)]
	return "phase=%s｜active=%s｜player_hp=%s｜enemy_hp=%s" % [str(state_machine.phase), str(battle_active), player_hp, enemy_hp]

func _apply_enemy_ai_manifest_behavior_once() -> void:
	if enemy_ai == null:
		return
	var manifest_enemy: Dictionary = NarrativeBattleContext.get_enemy_config()
	if manifest_enemy.is_empty() or NarrativeBattleContext.enemy_source_text() != "manifest":
		if enemy_ai.has_method("clear_manifest_behavior"):
			enemy_ai.call("clear_manifest_behavior")
		return
	var weights: Dictionary = {}
	var phases: Array = []
	var weights_variant = manifest_enemy.get("intent_weights", {})
	if weights_variant is Dictionary:
		weights = weights_variant
	var phases_variant = manifest_enemy.get("phase_behaviors", [])
	if phases_variant is Array:
		phases = phases_variant
	if enemy_ai.has_method("set_manifest_behavior"):
		enemy_ai.call("set_manifest_behavior", weights, phases)
	_refresh_stable_debug_panel()
