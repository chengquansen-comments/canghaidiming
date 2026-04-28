extends "res://scripts/battle_controller_visual_break_preview.gd"

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const BattleStateMachineScript := preload("res://scripts/battle_state_machine.gd")
const CardDataScript := preload("res://scripts/card_data.gd")
const DEFAULT_NARRATIVE_SCENE := "res://scenes/NarrativeDemo.tscn"
const ENEMY_MANIFEST_PATH := "res://data/enemy_manifest.json"
const NARRATIVE_BATTLE_SCENE_MANIFEST_PATH := "res://data/battle_scene_manifest.json"
const NARRATIVE_FALLBACK_BATTLE_ID := "fallback"

var narrative_debug_layer: CanvasLayer
var enemy_config_strip: Label
var narrative_debug_box: VBoxContainer
var narrative_context_label: Label
var battle_mapping_label: Label
var enemy_config_label: Label
var battle_result_label: Label
var recommended_start_button: Button
var continue_narrative_button: Button
var last_result_debug_text: String = ""
var result_recorded: bool = false
var narrative_numbers_applied: bool = false
var narrative_auto_start_attempted: bool = false
var battle_loadout: Dictionary = {}
var battle_loadout_applied: bool = false
var battle_loadout_error: String = ""

func _ready() -> void:
	super._ready()
	_resolve_pending_battle_loadout()
	_add_narrative_debug_layer()
	call_deferred("_auto_start_narrative_battle_if_needed")

func _process(_delta: float) -> void:
	super._process(_delta)
	_update_battle_result_debug()

func _auto_start_narrative_battle_if_needed() -> void:
	if narrative_auto_start_attempted:
		return
	if str(NarrativeBattleContext.encounter_id) != "enc_prologue_master_rescue":
		return
	narrative_auto_start_attempted = true
	player_role_id = "blademaster"
	var called: bool = _try_recommended_role_entry("blademaster")
	if not called:
		called = _press_role_button_by_text(["刀客", "腰刀", "blademaster", "刀"])
	if called:
		_set_battle_result_debug_text("序章师父战：已自动以师父刀法进入教学战。")
	else:
		_set_battle_result_debug_text("序章师父战：已写入师父刀法配置；未命中自动开战入口，请点刀客入口。")

func _select_role_and_start(role_id: String) -> void:
	_mark_battle_loadout_needs_apply()
	super._select_role_and_start(role_id)
	_mark_battle_loadout_needs_apply()
	_load_narrative_battle_once()

func _start_session(role_id: String) -> void:
	_mark_battle_loadout_needs_apply()
	super._start_session(role_id)
	_load_narrative_battle_once()

func _start_battle() -> void:
	_mark_battle_loadout_needs_apply()
	super._start_battle()
	_mark_battle_loadout_needs_apply()
	_load_narrative_battle_once()

func _mark_battle_loadout_needs_apply() -> void:
	if NarrativeBattleContext.has_request():
		battle_loadout_applied = false
		narrative_numbers_applied = false

func _press_role_button_by_text(keywords: Array[String]) -> bool:
	var buttons: Array[Button] = []
	_collect_buttons(self, buttons)
	for button: Button in buttons:
		var text: String = button.text
		for keyword: String in keywords:
			if text.findn(keyword) >= 0:
				button.emit_signal("pressed")
				return true
	return false

func _collect_buttons(node: Node, out_buttons: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			out_buttons.append(child)
		_collect_buttons(child, out_buttons)

func _add_narrative_debug_layer() -> void:
	narrative_debug_layer = CanvasLayer.new()
	narrative_debug_layer.name = "NarrativeDebugCanvasLayer"
	narrative_debug_layer.layer = 100
	add_child(narrative_debug_layer)

	enemy_config_strip = Label.new()
	enemy_config_strip.name = "EnemyConfigTopStrip"
	enemy_config_strip.text = _enemy_full_config_text()
	enemy_config_strip.anchor_left = 0.02
	enemy_config_strip.anchor_right = 0.98
	enemy_config_strip.anchor_top = 0.0
	enemy_config_strip.anchor_bottom = 0.0
	enemy_config_strip.offset_top = 6
	enemy_config_strip.offset_bottom = 62
	enemy_config_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_config_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_config_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_config_strip.add_theme_font_size_override("font_size", 13)
	narrative_debug_layer.add_child(enemy_config_strip)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "NarrativeDebugPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -540
	panel.offset_right = -18
	panel.offset_top = 68
	panel.offset_bottom = 500
	narrative_debug_layer.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	narrative_debug_box = VBoxContainer.new()
	narrative_debug_box.add_theme_constant_override("separation", 8)
	margin.add_child(narrative_debug_box)

	narrative_context_label = Label.new()
	narrative_context_label.name = "NarrativeContextDebugLabel"
	narrative_context_label.text = _context_debug_text()
	narrative_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_context_label.add_theme_font_size_override("font_size", 14)
	narrative_debug_box.add_child(narrative_context_label)

	battle_mapping_label = Label.new()
	battle_mapping_label.name = "BattleMappingDebugLabel"
	battle_mapping_label.text = _mapping_debug_text()
	battle_mapping_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_mapping_label.add_theme_font_size_override("font_size", 14)
	narrative_debug_box.add_child(battle_mapping_label)

	enemy_config_label = Label.new()
	enemy_config_label.name = "EnemyConfigDebugLabel"
	enemy_config_label.text = _enemy_config_debug_text()
	enemy_config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_config_label.add_theme_font_size_override("font_size", 14)
	narrative_debug_box.add_child(enemy_config_label)

	battle_result_label = Label.new()
	battle_result_label.name = "BattleResultDebugLabel"
	battle_result_label.text = "战斗结果：可随时返回剧情；胜负会按当前 HP 推断"
	battle_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_label.add_theme_font_size_override("font_size", 13)
	narrative_debug_box.add_child(battle_result_label)

	recommended_start_button = Button.new()
	recommended_start_button.name = "RecommendedBattleButton"
	recommended_start_button.text = "按推荐接敌"
	recommended_start_button.custom_minimum_size = Vector2(0, 40)
	recommended_start_button.pressed.connect(_on_recommended_battle_pressed)
	narrative_debug_box.add_child(recommended_start_button)

	continue_narrative_button = Button.new()
	continue_narrative_button.name = "ContinueNarrativeButton"
	continue_narrative_button.text = "返回剧情"
	continue_narrative_button.custom_minimum_size = Vector2(0, 42)
	continue_narrative_button.pressed.connect(_on_continue_narrative_pressed)
	narrative_debug_box.add_child(continue_narrative_button)

func _context_debug_text() -> String:
	var mapping: Dictionary = battle_loadout.get("encounter_config", NarrativeBattleContext.get_battle_mapping())
	var mapping_summary: String = "关卡信息：%s｜推荐玩家=%s｜敌人=%s｜难度=%s" % [str(mapping.get("label", "")), str(mapping.get("player_role", "")), str(battle_loadout.get("enemy_id", mapping.get("enemy_role", ""))), str(mapping.get("difficulty", ""))]
	if NarrativeBattleContext.has_request():
		return "%s\n叙事上下文：%s" % [mapping_summary, NarrativeBattleContext.debug_text()]
	return "%s\n叙事上下文：无请求｜返回将按 win 保底" % mapping_summary

func _mapping_debug_text() -> String:
	if not battle_loadout.is_empty():
		return "BattleLoadout：battle_id=%s｜encounter_id=%s｜enemy_source=%s｜enemy_id=%s｜scene=%s｜debug_source=%s" % [str(battle_loadout.get("battle_id", "")), str(battle_loadout.get("encounter_id", "")), str(battle_loadout.get("enemy_source", "")), str(battle_loadout.get("enemy_id", "")), str(battle_loadout.get("scene_config", {}).get("label", "")), str(battle_loadout.get("debug_source", ""))]
	return "接战映射：%s" % NarrativeBattleContext.battle_mapping_debug_text()

func _enemy_config_debug_text() -> String:
	var config: Dictionary = battle_loadout.get("enemy_config", {})
	if config.is_empty():
		return NarrativeBattleContext.enemy_config_debug_text()
	return "敌人配置=%s｜武器=%s｜HP=%s｜势=%s/%s｜来源=%s｜行为=%s｜标签=%s｜意图=%s" % [str(config.get("display_name", config.get("name", ""))), str(config.get("weapon", "")), str(config.get("max_hp", "")), str(config.get("start_posture", config.get("momentum", ""))), str(config.get("max_posture", config.get("max_momentum", ""))), str(battle_loadout.get("enemy_source", "")), str(config.get("intent_style", "")), ", ".join(config.get("behavior_tags", [])), ", ".join(config.get("preferred_intents", []))]

func _enemy_full_config_text() -> String:
	if battle_loadout_error != "":
		return "BattleLoadout错误：%s\n%s" % [battle_loadout_error, _runtime_cards_text()]
	if not battle_loadout.is_empty():
		return "%s\n%s" % [_battle_loadout_visible_debug_text(), _runtime_cards_text()]
	return "%s\n%s" % [NarrativeBattleContext.enemy_config_full_text(), _runtime_cards_text()]

func _update_battle_result_debug() -> void:
	if battle_result_label == null:
		return
	if enemy_config_strip != null:
		enemy_config_strip.text = _enemy_full_config_text()
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()
	if battle_mapping_label != null:
		battle_mapping_label.text = _mapping_debug_text()
	if enemy_config_label != null:
		enemy_config_label.text = _enemy_config_debug_text()
	if state_machine == null:
		_set_battle_result_debug_text("战斗结果：state_machine=null｜可点击返回剧情")
		return
	if player == null or enemy == null:
		_set_battle_result_debug_text("战斗结果：等待角色创建｜可点击返回剧情")
		return
	var hp_result_ready: bool = player.hp <= 0 or enemy.hp <= 0
	var phase_result_ready: bool = state_machine.phase == BattleStateMachineScript.BattlePhase.RESULT
	if not hp_result_ready and not phase_result_ready:
		_set_battle_result_debug_text("战斗结果：phase=%s｜player_hp=%d｜enemy_hp=%d｜未结算，可点击返回剧情" % [str(state_machine.phase), player.hp, enemy.hp])
		return
	var narrative_result: String = _get_narrative_result()
	_record_result_once(narrative_result)
	var result_state: String = "RESULT" if phase_result_ready else "HP_ZERO"
	_set_battle_result_debug_text("战斗结果：state=%s｜phase=%s｜player_hp=%d｜enemy_hp=%d｜narrative_result=%s" % [result_state, str(state_machine.phase), player.hp, enemy.hp, narrative_result])

func _apply_narrative_numbers_once() -> void:
	_load_narrative_battle_once()

func _resolve_pending_battle_loadout() -> void:
	if not NarrativeBattleContext.has_request():
		return
	battle_loadout = _resolve_battle_loadout()

func _load_narrative_battle_once() -> void:
	if battle_loadout_applied:
		return
	if not NarrativeBattleContext.has_request():
		return
	if player == null or enemy == null:
		return
	if battle_loadout.is_empty():
		battle_loadout = _resolve_battle_loadout()
	if battle_loadout.is_empty():
		return
	_apply_battle_loadout_once(battle_loadout)

func _resolve_battle_loadout() -> Dictionary:
	battle_loadout_error = ""
	var encounter_id: String = str(NarrativeBattleContext.encounter_id)
	var source_node_id: String = str(NarrativeBattleContext.source_node_id)
	var context_battle_id: String = NarrativeBattleContext.get_battle_id()
	var enemy_manifest: Dictionary = _read_json_dict(ENEMY_MANIFEST_PATH)
	if enemy_manifest.is_empty():
		battle_loadout_error = "无法读取 %s" % ENEMY_MANIFEST_PATH
	var encounters: Dictionary = _dict(enemy_manifest.get("encounters", {}))
	var encounter_config: Dictionary = _dict(encounters.get(encounter_id, {}))
	var enemy_id: String = str(encounter_config.get("enemy_id", ""))
	var enemies: Dictionary = _dict(enemy_manifest.get("enemies", {}))
	var raw_enemy_config: Dictionary = _dict(enemies.get(enemy_id, {}))
	var battle_id: String = context_battle_id
	if battle_id.is_empty() or battle_id == NARRATIVE_FALLBACK_BATTLE_ID:
		battle_id = str(encounter_config.get("battle_id", battle_id))
	if battle_id.is_empty():
		battle_id = NARRATIVE_FALLBACK_BATTLE_ID
	var scene_manifest: Dictionary = _read_json_dict(NARRATIVE_BATTLE_SCENE_MANIFEST_PATH)
	var scene_config: Dictionary = _dict(scene_manifest.get(battle_id, scene_manifest.get(NARRATIVE_FALLBACK_BATTLE_ID, {})))
	var profile: Dictionary = NarrativeBattleContext.get_player_profile()
	var role_id: String = str(profile.get("role", encounter_config.get("player_role", player_role_id if not player_role_id.is_empty() else "spearman")))
	var player_config: Dictionary = _resolve_player_config(role_id, profile, encounter_config)
	var enemy_config: Dictionary = _resolve_enemy_config(enemy_id, raw_enemy_config)
	var enemy_source: String = "enemy_manifest" if not raw_enemy_config.is_empty() else "missing_enemy_manifest"
	if raw_enemy_config.is_empty():
		battle_loadout_error = "enemy_manifest 缺少 enemy_id=%s" % enemy_id
	return {
		"battle_id": battle_id,
		"encounter_id": encounter_id,
		"source_node_id": source_node_id,
		"scene_config": scene_config,
		"encounter_config": encounter_config,
		"player_config": player_config,
		"enemy_config": enemy_config,
		"player_deck": player_config.get("deck", []),
		"enemy_deck": enemy_config.get("deck", []),
		"enemy_id": enemy_id,
		"enemy_source": enemy_source,
		"debug_source": "NarrativeBattleContext + enemy_manifest + battle_scene_manifest"
	}

func _resolve_player_config(role_id: String, profile: Dictionary, encounter_config: Dictionary) -> Dictionary:
	if str(NarrativeBattleContext.encounter_id) == "enc_prologue_master_rescue":
		return _master_config()
	var normalized_role_id: String = role_id
	if normalized_role_id.is_empty():
		normalized_role_id = str(encounter_config.get("player_role", "spearman"))
	return _player_config(normalized_role_id, profile)

func _resolve_enemy_config(enemy_id: String, manifest_config: Dictionary) -> Dictionary:
	var config: Dictionary
	if manifest_config.is_empty():
		config = _enemy_config(str(NarrativeBattleContext.encounter_id))
	else:
		config = manifest_config.duplicate(true)
	config["enemy_id"] = enemy_id
	config["name"] = str(config.get("display_name", config.get("name", enemy_id)))
	config["max_momentum"] = int(config.get("max_posture", config.get("max_momentum", 10)))
	config["momentum"] = int(config.get("start_posture", config.get("momentum", config.get("max_momentum", 5))))
	config["hp"] = int(config.get("hp", config.get("max_hp", 20)))
	config["realm"] = int(config.get("realm", 1))
	config["qinggong"] = int(config.get("qinggong", 1))
	config["position"] = int(config.get("starting_position", config.get("position", 6)))
	config["facing"] = str(config.get("starting_facing", config.get("facing", "left")))
	if not config.has("preferred"):
		config["preferred"] = _preferred_distances_for_role_sheet(str(config.get("role_sheet", "")))
	if not config.has("deck"):
		config["deck"] = _deck_for_enemy_manifest(config)
	return config

func _apply_battle_loadout_once(loadout: Dictionary) -> void:
	if battle_loadout_applied:
		return
	if player == null or enemy == null:
		return
	var player_config: Dictionary = _dict(loadout.get("player_config", {}))
	var enemy_config: Dictionary = _dict(loadout.get("enemy_config", {}))
	if player_config.is_empty() or enemy_config.is_empty():
		battle_loadout_error = "BattleLoadout 缺少 player_config 或 enemy_config"
		return
	_apply_fighter_config(player, player_config)
	_apply_fighter_config(enemy, enemy_config)
	if state_machine != null:
		state_machine.update_distance_from_positions(player, enemy)
	_apply_battle_background(loadout)
	battle_loadout_applied = true
	narrative_numbers_applied = true
	_refresh_narrative_debug_labels()
	_set_battle_result_debug_text("BattleLoadout：已一次性应用敌我配置与背景。")
	_safe_refresh_runtime_ui()

func _apply_battle_background(loadout: Dictionary) -> void:
	var scene_config: Dictionary = _dict(loadout.get("scene_config", {}))
	var bg_path: String = str(scene_config.get("background", ""))
	if background_texture == null:
		return
	background_texture.texture = null
	background_texture.visible = true
	background_texture.scale = Vector2.ONE
	background_texture.position = Vector2.ZERO
	background_texture.modulate = Color.WHITE
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		var tex: Texture2D = _safe_load_texture(bg_path)
		if tex != null:
			background_texture.texture = tex

func _refresh_narrative_debug_labels() -> void:
	if enemy_config_strip != null:
		enemy_config_strip.text = _enemy_full_config_text()
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()
	if battle_mapping_label != null:
		battle_mapping_label.text = _mapping_debug_text()
	if enemy_config_label != null:
		enemy_config_label.text = _enemy_config_debug_text()

func _battle_loadout_visible_debug_text() -> String:
	var enemy_config: Dictionary = _dict(battle_loadout.get("enemy_config", {}))
	var runtime_name: String = str(enemy_config.get("display_name", enemy_config.get("name", "")))
	var runtime_hp: int = int(enemy_config.get("max_hp", 0))
	var runtime_posture: int = int(enemy_config.get("momentum", enemy_config.get("start_posture", 0)))
	var runtime_max_posture: int = int(enemy_config.get("max_momentum", enemy_config.get("max_posture", 0)))
	if enemy != null:
		runtime_name = enemy.data.display_name
		runtime_hp = enemy.hp
		runtime_posture = enemy.momentum
		runtime_max_posture = enemy.data.max_momentum
	return "battle_id=%s\nencounter_id=%s\nenemy_source=%s\nenemy_id=%s\nenemy_name=%s\nenemy_hp=%d\nenemy_posture=%d/%d" % [str(battle_loadout.get("battle_id", "")), str(battle_loadout.get("encounter_id", "")), str(battle_loadout.get("enemy_source", "")), str(battle_loadout.get("enemy_id", "")), runtime_name, runtime_hp, runtime_posture, runtime_max_posture]

func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func _dict(value) -> Dictionary:
	if value is Dictionary:
		return value
	return {}

func _apply_fighter_config(fighter, config: Dictionary) -> void:
	if fighter == null or config.is_empty():
		return
	fighter.data.display_name = str(config.get("display_name", config.get("name", fighter.data.display_name)))
	fighter.data.weapon_name = str(config.get("weapon", fighter.data.weapon_name))
	fighter.data.max_hp = int(config.get("max_hp", fighter.data.max_hp))
	fighter.data.max_momentum = int(config.get("max_posture", config.get("max_momentum", fighter.data.max_momentum)))
	fighter.data.starting_momentum = clampi(int(config.get("start_posture", config.get("momentum", fighter.data.starting_momentum))), 0, fighter.data.max_momentum)
	fighter.data.starting_realm = int(config.get("realm", fighter.data.starting_realm))
	fighter.data.qinggong = int(config.get("qinggong", fighter.data.qinggong))
	fighter.data.starting_position = clampi(int(config.get("starting_position", config.get("position", fighter.data.starting_position))), 0, 8)
	fighter.data.starting_facing = "left" if str(config.get("starting_facing", config.get("facing", fighter.data.starting_facing))) == "left" else "right"
	fighter.data.preferred_distances = _packed_ints(config.get("preferred", []))
	fighter.data.starting_deck = _cards_from_configs(config.get("deck", []))
	fighter.hp = int(config.get("hp", fighter.data.max_hp))
	fighter.momentum = fighter.data.starting_momentum
	fighter.session_realm = fighter.data.starting_realm
	fighter.realm = fighter.session_realm
	fighter.qinggong = fighter.data.qinggong
	fighter.position = fighter.data.starting_position
	fighter.facing = fighter.data.starting_facing
	fighter.draw_pile = fighter.data.clone_deck()
	fighter.discard_pile.clear()
	fighter.hand.clear()
	while fighter.hand.size() < HAND_SIZE and not fighter.draw_pile.is_empty():
		fighter.hand.append(fighter.draw_pile.pop_front())

func _safe_refresh_runtime_ui() -> void:
	var refresh_methods: Array[String] = ["_refresh_ui", "_update_ui", "_render_battle", "_render_state", "_refresh_all", "_render"]
	for method_name: String in refresh_methods:
		if _method_accepts_arg_count(method_name, 0):
			callv(method_name, [])
			return

func _master_config() -> Dictionary:
	return {"name":"沉默老兵", "weapon":"旧腰刀", "max_hp":48, "hp":48, "max_momentum":12, "momentum":9, "realm":4, "qinggong":3, "position":2, "facing":"right", "preferred":[0,1,2], "deck":_master_cards()}

func _player_config(role_id: String, profile: Dictionary) -> Dictionary:
	var realm: int = int(profile.get("martial_level", 1)) if not profile.is_empty() else 1
	if role_id == "blademaster":
		return {"name":str(profile.get("career", "腰刀武官")), "weapon":str(profile.get("weapon", "腰刀")), "max_hp":int(profile.get("max_hp", 34)), "hp":int(profile.get("hp", profile.get("max_hp", 34))), "max_momentum":int(profile.get("max_posture", 10)), "momentum":int(profile.get("posture", 7)), "realm":realm, "qinggong":2, "position":2, "facing":"right", "preferred":[0,1,2], "deck":_blade_cards(realm)}
	return {"name":str(profile.get("career", "长枪武官")), "weapon":str(profile.get("weapon", "长枪")), "max_hp":int(profile.get("max_hp", 38)), "hp":int(profile.get("hp", profile.get("max_hp", 38))), "max_momentum":int(profile.get("max_posture", 10)), "momentum":int(profile.get("posture", 6)), "realm":realm, "qinggong":1, "position":2, "facing":"right", "preferred":[3,4,5], "deck":_spear_cards(realm)}

func _enemy_config(encounter: String) -> Dictionary:
	var manifest_enemy: Dictionary = NarrativeBattleContext.get_enemy_config()
	if not manifest_enemy.is_empty() and NarrativeBattleContext.enemy_source_text() == "manifest":
		return _enemy_runtime_config_from_manifest(encounter, manifest_enemy)
	return _enemy_fallback_config(encounter)

func _enemy_runtime_config_from_manifest(encounter: String, manifest_enemy: Dictionary) -> Dictionary:
	var mapping: Dictionary = NarrativeBattleContext.get_battle_mapping()
	var role_sheet: String = str(manifest_enemy.get("role_sheet", "enemy_spearman"))
	var enemy_family: String = str(mapping.get("enemy_family", "spearman"))
	return {
		"name": str(manifest_enemy.get("display_name", "敌人")),
		"weapon": str(manifest_enemy.get("weapon", "兵器")),
		"max_hp": int(manifest_enemy.get("max_hp", 26)),
		"hp": int(manifest_enemy.get("max_hp", 26)),
		"max_momentum": int(manifest_enemy.get("max_posture", 10)),
		"momentum": int(manifest_enemy.get("start_posture", 4)),
		"realm": int(manifest_enemy.get("realm", _enemy_realm_from_manifest(mapping))),
		"qinggong": maxi(1, int(manifest_enemy.get("qinggong", _enemy_qinggong_from_manifest(role_sheet)))),
		"position": 6,
		"facing": "left",
		"preferred": _enemy_preferred_from_manifest(role_sheet, enemy_family),
		"deck": _enemy_deck_from_manifest(encounter, role_sheet, enemy_family)
	}

func _enemy_realm_from_manifest(mapping: Dictionary) -> int:
	var difficulty: String = str(mapping.get("difficulty", "normal"))
	match difficulty:
		"tutorial_elite": return 1
		"normal": return 1
		"elite": return 2
		"boss": return 3
		_: return 1

func _enemy_qinggong_from_manifest(role_sheet: String) -> int:
	if role_sheet.find("blademaster") >= 0:
		return 2
	return 1

func _enemy_preferred_from_manifest(role_sheet: String, enemy_family: String) -> Array:
	if role_sheet.find("blademaster") >= 0 or enemy_family == "blademaster":
		return [0, 1, 2]
	return [3, 4, 5]

func _enemy_deck_from_manifest(encounter: String, role_sheet: String, enemy_family: String) -> Array:
	if encounter == "enc_prologue_master_rescue":
		return _enemy_intro_cards()
	if encounter == "enc_transport_officer":
		return _enemy_officer_cards()
	if encounter == "enc_wakou_boss":
		return _enemy_boss_cards()
	if role_sheet.find("blademaster") >= 0 or enemy_family == "blademaster":
		return _enemy_officer_cards()
	return _enemy_spear_cards()

func _enemy_fallback_config(encounter: String) -> Dictionary:
	match encounter:
		"enc_prologue_master_rescue": return {"name":"袭村刀手", "weapon":"短刃", "max_hp":22, "hp":22, "max_momentum":8, "momentum":2, "realm":1, "qinggong":1, "position":6, "facing":"left", "preferred":[0,1,2], "deck":_enemy_intro_cards()}
		"enc_transport_officer": return {"name":"押运官", "weapon":"腰刀", "max_hp":34, "hp":34, "max_momentum":10, "momentum":5, "realm":2, "qinggong":2, "position":6, "facing":"left", "preferred":[0,1,2], "deck":_enemy_officer_cards()}
		"enc_wakou_boss": return {"name":"小股首领", "weapon":"倭刀", "max_hp":42, "hp":42, "max_momentum":12, "momentum":6, "realm":3, "qinggong":2, "position":6, "facing":"left", "preferred":[0,1,2], "deck":_enemy_boss_cards()}
		_: return {"name":"敌方枪手", "weapon":"长枪", "max_hp":26, "hp":26, "max_momentum":10, "momentum":4, "realm":1, "qinggong":1, "position":6, "facing":"left", "preferred":[3,4,5], "deck":_enemy_spear_cards()}

func _preferred_distances_for_role_sheet(role_sheet: String) -> Array:
	if role_sheet.findn("spear") >= 0 or role_sheet.findn("枪") >= 0:
		return [3, 4, 5]
	return [0, 1, 2]

func _deck_for_enemy_manifest(config: Dictionary) -> Array:
	var enemy_id: String = str(config.get("enemy_id", ""))
	var role_sheet: String = str(config.get("role_sheet", ""))
	if enemy_id.findn("prologue") >= 0:
		return _enemy_intro_cards()
	if enemy_id.findn("transport") >= 0:
		return _enemy_officer_cards()
	if enemy_id.findn("wakou") >= 0 or enemy_id.findn("boss") >= 0:
		return _enemy_boss_cards()
	if role_sheet.findn("spear") >= 0 or role_sheet.findn("枪") >= 0:
		return _enemy_spear_cards()
	return _enemy_officer_cards()

func _c(id: String, name: String, min_d: int, max_d: int, cost: int, role: String, gain: int, brk: int, dmg: int, guard: int, tags: Array, style: String, facing: bool = true) -> Dictionary:
	return {"id":id, "name":name, "min":min_d, "max":max_d, "cost":cost, "role":role, "gain":gain, "break":brk, "damage":dmg, "guard":guard, "tags":tags, "style":style, "facing":facing}

func _master_cards() -> Array:
	return [_c("m_1","老兵压刀",0,2,0,"momentum",3,2,0,0,["教学","强力"],"刀"), _c("m_2","旧刀横封",0,3,0,"guard",0,0,0,9,["教学","守"],"刀",false), _c("m_3","沉默斩",0,2,1,"damage",0,2,12,0,["教学","斩杀"],"刀"), _c("m_4","断声一刀",0,1,1,"damage",0,3,16,0,["终结"],"刀")]

func _spear_cards(level: int) -> Array:
	var cards: Array = [_c("p_s1","枪式一",3,5,1,"momentum",2,0,0,0,["试探"],"枪"), _c("p_s2","枪式二",3,5,1,"momentum",0,2,0,0,["破势"],"枪"), _c("p_s3","枪式三",3,5,1,"damage",0,0,5,0,["起手"],"枪"), _c("p_s4","枪守式",0,5,1,"guard",0,0,0,5,["守"],"枪",false), _c("p_s5","枪进式",2,4,1,"damage",1,0,4,0,["进身"],"枪"), _c("p_s6","枪终式",4,5,2,"damage",0,1,8,0,["终结"],"枪")]
	if level >= 2:
		cards.append(_c("p_s7","枪先式",2,4,2,"momentum",2,2,0,0,["先机"],"枪"))
	if level >= 3:
		cards.append(_c("p_s8","枪固式",0,5,2,"guard",0,0,0,9,["重守"],"枪",false))
	return cards

func _blade_cards(level: int) -> Array:
	var cards: Array = [_c("p_b1","刀式一",0,2,1,"momentum",2,0,0,0,["试探"],"刀"), _c("p_b2","刀式二",0,2,1,"momentum",0,2,0,0,["破势"],"刀"), _c("p_b3","刀式三",0,2,1,"damage",0,0,5,0,["起手"],"刀"), _c("p_b4","刀守式",0,3,1,"guard",0,0,0,5,["守"],"刀",false), _c("p_b5","刀追式",0,1,1,"damage",1,0,4,0,["追击"],"刀"), _c("p_b6","刀终式",0,1,2,"damage",0,1,8,0,["终结"],"刀")]
	if level >= 2:
		cards.append(_c("p_b7","刀先式",0,2,2,"momentum",2,2,0,0,["先机"],"刀"))
	if level >= 3:
		cards.append(_c("p_b8","刀固式",0,3,2,"guard",0,0,0,9,["重守"],"刀",false))
	return cards

func _enemy_intro_cards() -> Array:
	return [_c("e_i1","乱步",0,2,1,"momentum",1,0,0,0,["教学"],"短"), _c("e_i2","乱砍",0,2,1,"damage",0,0,3,0,["低威胁"],"短"), _c("e_i3","退守",0,3,1,"guard",0,0,0,3,["守"],"短",false), _c("e_i4","困兽",0,1,2,"damage",0,0,5,0,["线索"],"短")]

func _enemy_spear_cards() -> Array:
	return [_c("e_s1","敌枪一",3,5,1,"momentum",2,0,0,0,["试探"],"枪"), _c("e_s2","敌枪二",3,5,1,"momentum",0,2,0,0,["抢势"],"枪"), _c("e_s3","敌枪三",3,5,1,"damage",0,0,4,0,["突刺"],"枪"), _c("e_s4","敌枪守",0,5,1,"guard",0,0,0,4,["守"],"枪",false), _c("e_s5","敌枪终",4,5,2,"damage",0,1,7,0,["重击"],"枪")]

func _enemy_officer_cards() -> Array:
	return [_c("e_o1","官式一",0,2,1,"momentum",2,0,0,0,["压迫"],"刀"), _c("e_o2","官式二",0,2,1,"momentum",0,3,0,0,["破势"],"刀"), _c("e_o3","官式三",0,2,2,"damage",0,1,7,3,["反击"],"刀"), _c("e_o4","官式四",0,2,1,"damage",0,0,5,0,["压制"],"刀"), _c("e_o5","官守式",0,3,1,"guard",0,0,0,6,["守"],"刀",false), _c("e_o6","官终式",0,1,2,"damage",0,1,9,0,["终结"],"刀")]

func _enemy_boss_cards() -> Array:
	return [_c("e_b1","首领式一",0,2,1,"momentum",2,1,0,0,["虚招"],"刀"), _c("e_b2","首领式二",0,2,1,"momentum",0,3,0,0,["抢势"],"刀"), _c("e_b3","首领式三",0,2,1,"damage",0,0,6,0,["连段"],"刀"), _c("e_b4","首领式四",0,1,2,"damage",0,1,10,0,["终结"],"刀"), _c("e_b5","首领守式",0,3,1,"guard",0,0,0,6,["守"],"刀",false), _c("e_b6","首领终式",0,1,2,"damage",0,0,8,2,["线索"],"刀")]

func _cards_from_configs(configs: Array) -> Array[CardDataScript]:
	var cards: Array[CardDataScript] = []
	for config_variant in configs:
		if config_variant is CardDataScript:
			cards.append(config_variant.duplicate_card())
			continue
		var config: Dictionary = config_variant
		cards.append(CardDataScript.new(str(config.get("id", "card")), str(config.get("name", "招式")), str(config.get("name", "")), int(config.get("min", 0)), int(config.get("max", 5)), int(config.get("cost", 1)), str(config.get("role", "damage")), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), PackedStringArray(config.get("tags", [])), str(config.get("style", "")), bool(config.get("facing", true))))
	return cards

func _packed_ints(values: Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for value_variant in values:
		result.append(int(value_variant))
	return result

func _runtime_cards_text() -> String:
	var player_deck: Array = []
	var enemy_deck: Array = []
	if player != null and player.data != null:
		player_deck = player.data.starting_deck
	elif not battle_loadout.is_empty():
		player_deck = battle_loadout.get("player_deck", [])
	if enemy != null and enemy.data != null:
		enemy_deck = enemy.data.starting_deck
	elif not battle_loadout.is_empty():
		enemy_deck = battle_loadout.get("enemy_deck", [])
	return "玩家持牌：%s\n敌方持牌：%s" % [_deck_summary(player_deck), _deck_summary(enemy_deck)]

func _deck_summary(deck: Array) -> String:
	var chunks: Array[String] = []
	for config_variant in deck:
		if config_variant is CardDataScript:
			var card: CardDataScript = config_variant
			chunks.append("%s[耗%d/伤%d/守%d/势+%d/破%d/距%d-%d]" % [card.display_name, card.momentum_cost, card.damage, card.guard, card.gain_momentum, card.break_momentum, card.min_distance, card.max_distance])
			continue
		var config: Dictionary = config_variant
		chunks.append("%s[耗%d/伤%d/守%d/势+%d/破%d/距%d-%d]" % [str(config.get("name", "")), int(config.get("cost", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("min", 0)), int(config.get("max", 0))])
	return "；".join(chunks)

func _record_result_once(narrative_result: String) -> void:
	if result_recorded:
		return
	NarrativeBattleContext.set_result(narrative_result)
	result_recorded = true
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()

func _set_battle_result_debug_text(text: String) -> void:
	if text == last_result_debug_text:
		return
	last_result_debug_text = text
	battle_result_label.text = text

func _get_narrative_result() -> String:
	if player == null or enemy == null:
		return "win"
	if player.hp > 0 and enemy.hp <= 0:
		return "win"
	if player.hp <= 0 and enemy.hp > 0:
		return "lose"
	if player.hp <= 0 and enemy.hp <= 0:
		return "draw"
	return "win"

func _on_recommended_battle_pressed() -> void:
	var mapping: Dictionary = NarrativeBattleContext.get_battle_mapping()
	var role_id: String = str(mapping.get("player_role", "spearman"))
	player_role_id = role_id
	var called: bool = _try_recommended_role_entry(role_id)
	if called:
		_set_battle_result_debug_text("接战操作：已按推荐玩家=%s 尝试进入战斗。" % role_id)
	else:
		_set_battle_result_debug_text("接战操作：已写入推荐玩家=%s；未匹配自动入口，请继续使用原角色选择按钮。" % role_id)

func _try_recommended_role_entry(role_id: String) -> bool:
	var called: bool = false
	var one_arg_methods: Array[String] = ["_select_role_and_start", "_on_role_selected", "_select_role", "_choose_role", "_pick_role", "_start_battle", "_begin_battle", "_start_session", "_begin_session", "_start_run"]
	for method_name: String in one_arg_methods:
		if _method_accepts_arg_count(method_name, 1):
			callv(method_name, [role_id])
			called = true
			break
	var no_arg_methods: Array[String] = ["_confirm_role_selection", "_confirm_role_pick", "_start_battle", "_begin_battle", "_start_session", "_begin_session", "_start_run"]
	if not called:
		for method_name: String in no_arg_methods:
			if _method_accepts_arg_count(method_name, 0):
				callv(method_name, [])
				called = true
				break
	if called:
		_mark_battle_loadout_needs_apply()
		_load_narrative_battle_once()
	return called

func _method_accepts_arg_count(method_name: String, arg_count: int) -> bool:
	for method_info_variant in get_method_list():
		var method_info: Dictionary = method_info_variant
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() == arg_count
	return false

func _on_continue_narrative_pressed() -> void:
	if not NarrativeBattleContext.has_result():
		NarrativeBattleContext.set_result(_get_narrative_result())
	var target_scene: String = NarrativeBattleContext.source_scene
	if target_scene.is_empty():
		target_scene = DEFAULT_NARRATIVE_SCENE
	get_tree().change_scene_to_file(target_scene)
