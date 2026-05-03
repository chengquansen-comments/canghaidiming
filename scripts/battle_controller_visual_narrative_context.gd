extends "res://scripts/battle_controller_visual_break_preview.gd"

const NarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const BattleStateMachineScript := preload("res://scripts/battle_state_machine.gd")
const NarrativeStoryBattleLoader := preload("res://scripts/story_battle_loader.gd")
const DEFAULT_NARRATIVE_SCENE := "res://scenes/NarrativeDemo.tscn"
const ENEMY_MANIFEST_PATH := "res://data/enemy_manifest.json"
const NARRATIVE_BATTLE_SCENE_MANIFEST_PATH := "res://data/battle_scene_manifest.json"
const STRATEGIC_MAP_CONFIG_PATH := "res://data/strategic_map.json"
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
	player_role_id = "master_veteran"
	var called: bool = _try_recommended_role_entry("master_veteran")
	if not called:
		called = _press_role_button_by_text(["师父", "师傅", "老兵", "master_veteran"])
	if called:
		_set_battle_result_debug_text("序章师父战：已自动以师父刀法进入教学战。")
	else:
		_set_battle_result_debug_text("序章师父战：已写入师父刀法配置；未命中自动开战入口。")

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
	battle_result_label.text = "战斗结果：可随时返回剧情；debug 返回按胜利处理"
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
	var label_text: String = str(mapping.get("label", mapping.get("display_name", "")))
	var player_text: String = str(mapping.get("player_role", mapping.get("player_template_id", "")))
	var difficulty_text: String = str(mapping.get("difficulty", mapping.get("opponent_stat_set_id", "")))
	var mapping_summary: String = "关卡信息：%s｜推荐玩家=%s｜敌人=%s｜难度=%s" % [label_text, player_text, str(battle_loadout.get("enemy_id", mapping.get("enemy_role", ""))), difficulty_text]
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
	var battle_id: String = context_battle_id
	if battle_id.is_empty():
		battle_id = NARRATIVE_FALLBACK_BATTLE_ID
	var scene_manifest: Dictionary = _read_json_dict(NARRATIVE_BATTLE_SCENE_MANIFEST_PATH)
	var scene_config: Dictionary = _dict(scene_manifest.get(battle_id, scene_manifest.get(NARRATIVE_FALLBACK_BATTLE_ID, {})))
	var story_battle: Dictionary = _story_battle_for_encounter(encounter_id)
	if story_battle.is_empty():
		battle_loadout_error = "StoryBattleLoader 缺少 encounter_id=%s" % encounter_id
		return {}
	var encounter_config: Dictionary = _dict(story_battle.get("encounter", {}))
	var player_data = story_battle.get("player_data", null)
	var opponent_data = story_battle.get("opponent_data", null)
	if player_data == null or opponent_data == null:
		battle_loadout_error = "StoryBattleLoader 返回空 fighter data: %s" % encounter_id
		return {}
	var player_config: Dictionary = _fighter_data_to_config(player_data)
	var enemy_config: Dictionary = _fighter_data_to_config(opponent_data)
	var manifest_context: Dictionary = _enemy_manifest_context_for_encounter(encounter_id)
	enemy_config = _apply_enemy_manifest_to_story_config(enemy_config, manifest_context)
	enemy_config = _apply_narrative_battle_overrides(enemy_config)
	var profile: Dictionary = NarrativeBattleContext.get_player_profile()
	player_config = _apply_story_player_overrides(player_config, profile)
	var override_player_profile := NarrativeBattleContext.should_override_player_profile()
	var settlement_mode: String = str(story_battle.get("settlement_mode", BattleStateMachineScript.MODE_REACTIVE_ID))
	var manifest_encounter: Dictionary = _dict(manifest_context.get("encounter", {}))
	var manifest_enemy: Dictionary = _dict(manifest_context.get("enemy", {}))
	var enemy_id: String = str(enemy_config.get("id", manifest_context.get("enemy_id", encounter_config.get("opponent_template_id", ""))))
	var enemy_source: String = str(enemy_config.get("enemy_source", "enemy_manifest" if not manifest_enemy.is_empty() else "story_battles"))
	return {
		"battle_id": battle_id,
		"encounter_id": encounter_id,
		"source_node_id": source_node_id,
		"override_player_profile": override_player_profile,
		"scene_config": scene_config,
		"encounter_config": manifest_encounter if not manifest_encounter.is_empty() else encounter_config,
		"story_encounter_config": encounter_config,
		"player_config": player_config,
		"enemy_config": enemy_config,
		"player_deck": player_config.get("deck", []),
		"enemy_deck": enemy_config.get("deck", []),
		"enemy_id": enemy_id,
		"enemy_source": enemy_source,
		"settlement_mode": settlement_mode,
		"debug_source": "NarrativeBattleContext + StoryBattleLoader + enemy_manifest + battle_scene_manifest"
	}

func _story_battle_for_encounter(encounter_id: String) -> Dictionary:
	var catalog: Dictionary = _story_loader_card_catalog()
	return NarrativeStoryBattleLoader.build_story_battle(encounter_id, catalog)

func _story_loader_card_catalog() -> Dictionary:
	return NarrativeStoryBattleLoader.build_card_catalog(fighter_catalog, reward_pool)

func _fighter_data_to_config(data) -> Dictionary:
	if data == null:
		return {}
	return {
		"id": data.id,
		"name": data.display_name,
		"display_name": data.display_name,
		"weapon": data.weapon_name,
		"max_hp": data.max_hp,
		"hp": data.max_hp,
		"max_momentum": data.max_momentum,
		"momentum": data.starting_momentum,
		"realm": data.starting_realm,
		"qinggong": data.qinggong,
		"position": data.starting_position,
		"facing": data.starting_facing,
		"preferred": Array(data.preferred_distances),
		"deck": data.clone_deck()
	}

func _enemy_manifest_context_for_encounter(encounter_id: String) -> Dictionary:
	var manifest: Dictionary = _read_json_dict(ENEMY_MANIFEST_PATH)
	if manifest.is_empty():
		return {}
	var encounters: Dictionary = _dict(manifest.get("encounters", {}))
	var manifest_encounter: Dictionary = _dict(encounters.get(encounter_id, {}))
	if manifest_encounter.is_empty():
		return {}
	var enemy_id: String = str(manifest_encounter.get("enemy_id", ""))
	var enemies: Dictionary = _dict(manifest.get("enemies", {}))
	var manifest_enemy: Dictionary = _dict(enemies.get(enemy_id, {}))
	return {
		"enemy_id": enemy_id,
		"encounter": manifest_encounter,
		"enemy": manifest_enemy
	}

func _apply_enemy_manifest_to_story_config(story_config: Dictionary, manifest_context: Dictionary) -> Dictionary:
	if story_config.is_empty():
		return story_config
	var manifest_enemy: Dictionary = _dict(manifest_context.get("enemy", {}))
	if manifest_enemy.is_empty():
		return story_config
	var enemy_id: String = str(manifest_context.get("enemy_id", manifest_enemy.get("enemy_id", story_config.get("id", ""))))
	story_config["id"] = enemy_id
	story_config["enemy_id"] = enemy_id
	story_config["name"] = str(manifest_enemy.get("display_name", story_config.get("name", enemy_id)))
	story_config["display_name"] = str(manifest_enemy.get("display_name", story_config.get("display_name", story_config.get("name", enemy_id))))
	story_config["weapon"] = str(manifest_enemy.get("weapon", story_config.get("weapon", "")))
	story_config["role_sheet"] = str(manifest_enemy.get("role_sheet", story_config.get("role_sheet", "")))
	story_config["max_hp"] = int(manifest_enemy.get("max_hp", story_config.get("max_hp", 20)))
	story_config["hp"] = int(story_config.get("max_hp", 20))
	story_config["max_momentum"] = int(manifest_enemy.get("max_posture", manifest_enemy.get("max_momentum", story_config.get("max_momentum", 10))))
	story_config["momentum"] = int(manifest_enemy.get("start_posture", manifest_enemy.get("momentum", story_config.get("momentum", 4))))
	story_config["realm"] = int(manifest_enemy.get("realm", story_config.get("realm", 1)))
	story_config["qinggong"] = int(manifest_enemy.get("qinggong", story_config.get("qinggong", 1)))
	return story_config

func _apply_narrative_battle_overrides(enemy_config: Dictionary) -> Dictionary:
	var overrides := NarrativeBattleContext.get_battle_overrides()
	enemy_config = _apply_combat_enemy_pool_override(enemy_config, overrides)
	var enemy_martial_level := int(overrides.get("enemy_martial_level", 0))
	if enemy_martial_level > 0:
		enemy_config = _apply_enemy_martial_stats(enemy_config, enemy_martial_level)
		enemy_config["enemy_martial_level"] = enemy_martial_level
	var combat_pool_id := str(overrides.get("combat_pool_id", ""))
	if not combat_pool_id.is_empty():
		enemy_config["combat_pool_id"] = combat_pool_id
	return enemy_config

func _apply_combat_enemy_pool_override(enemy_config: Dictionary, overrides: Dictionary) -> Dictionary:
	var combat_pool_id := str(overrides.get("combat_pool_id", ""))
	if combat_pool_id.is_empty():
		return enemy_config
	var enemy_martial_level := int(overrides.get("enemy_martial_level", 0))
	var strategic_config := _read_json_dict(STRATEGIC_MAP_CONFIG_PATH)
	var pools: Dictionary = _dict(strategic_config.get("combat_enemy_pools", {}))
	var entries: Array = pools.get(combat_pool_id, [])
	var eligible: Array[Dictionary] = []
	for item in entries:
		if not (item is Dictionary):
			continue
		var entry := item as Dictionary
		if enemy_martial_level > 0:
			if enemy_martial_level < int(entry.get("martial_min", 1)) or enemy_martial_level > int(entry.get("martial_max", 999)):
				continue
		eligible.append(entry)
	if eligible.is_empty():
		return enemy_config
	var selected := _weighted_pool_entry(eligible, _combat_pool_seed(combat_pool_id, enemy_martial_level))
	if selected.is_empty():
		return enemy_config
	var deck_id := str(selected.get("opponent_deck_id", ""))
	var template_id := str(selected.get("opponent_template_id", ""))
	var data = NarrativeStoryBattleLoader.build_fighter_data(template_id, deck_id, "normal", _story_loader_card_catalog(), false)
	if data == null:
		return enemy_config
	enemy_config = _fighter_data_to_config(data)
	enemy_config["id"] = str(selected.get("pool_entry_id", template_id))
	enemy_config["enemy_id"] = str(selected.get("pool_entry_id", template_id))
	enemy_config["display_name"] = str(selected.get("display_name", enemy_config.get("display_name", "")))
	enemy_config["name"] = str(selected.get("display_name", enemy_config.get("name", "")))
	enemy_config["enemy_family"] = str(selected.get("enemy_family", ""))
	enemy_config["combat_pool_id"] = combat_pool_id
	enemy_config["combat_pool_entry_id"] = str(selected.get("pool_entry_id", ""))
	enemy_config["enemy_source"] = "combat_enemy_pool"
	enemy_config["hp_bonus"] = int(selected.get("hp_bonus", 0))
	enemy_config["max_momentum_bonus"] = int(selected.get("max_momentum_bonus", 0))
	enemy_config["starting_momentum_bonus"] = int(selected.get("starting_momentum_bonus", 0))
	enemy_config["qinggong_bonus"] = int(selected.get("qinggong_bonus", 0))
	return enemy_config

func _apply_enemy_martial_stats(enemy_config: Dictionary, martial_level: int) -> Dictionary:
	var strategic_config := _read_json_dict(STRATEGIC_MAP_CONFIG_PATH)
	var stats_by_level: Dictionary = _dict(strategic_config.get("enemy_martial_stats", {}))
	var stats: Dictionary = _dict(stats_by_level.get(str(martial_level), {}))
	if stats.is_empty():
		enemy_config["realm"] = martial_level
		return enemy_config
	var hp_bonus := int(enemy_config.get("hp_bonus", 0))
	var max_momentum_bonus := int(enemy_config.get("max_momentum_bonus", 0))
	var starting_momentum_bonus := int(enemy_config.get("starting_momentum_bonus", 0))
	var qinggong_bonus := int(enemy_config.get("qinggong_bonus", 0))
	var max_momentum := maxi(1, int(stats.get("max_momentum", enemy_config.get("max_momentum", 6))) + max_momentum_bonus)
	var momentum := clampi(int(stats.get("starting_momentum", enemy_config.get("momentum", 3))) + starting_momentum_bonus, 0, max_momentum)
	enemy_config["max_hp"] = maxi(1, int(stats.get("max_hp", enemy_config.get("max_hp", 20))) + hp_bonus)
	enemy_config["hp"] = int(enemy_config.get("max_hp", 20))
	enemy_config["max_momentum"] = max_momentum
	enemy_config["max_posture"] = max_momentum
	enemy_config["momentum"] = momentum
	enemy_config["start_posture"] = momentum
	enemy_config["realm"] = martial_level
	enemy_config["qinggong"] = maxi(1, int(stats.get("qinggong", enemy_config.get("qinggong", 1))) + qinggong_bonus)
	return enemy_config

func _weighted_pool_entry(entries: Array[Dictionary], seed_value: int) -> Dictionary:
	if entries.is_empty():
		return {}
	var total := 0
	for entry in entries:
		total += maxi(1, int(entry.get("weight", 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for entry in entries:
		cursor += maxi(1, int(entry.get("weight", 1)))
		if roll <= cursor:
			return entry.duplicate(true)
	return entries[0].duplicate(true)

func _combat_pool_seed(combat_pool_id: String, enemy_martial_level: int) -> int:
	var key := "%s|%s|%s|%d" % [
		combat_pool_id,
		str(NarrativeBattleContext.source_node_id),
		str(NarrativeBattleContext.battle_id),
		enemy_martial_level,
	]
	return int(abs(key.hash()))

func _apply_story_player_overrides(base_config: Dictionary, profile: Dictionary) -> Dictionary:
	if base_config.is_empty():
		return base_config
	if not NarrativeBattleContext.should_override_player_profile():
		return base_config
	var overrides: Dictionary = NarrativeBattleContext.get_battle_overrides()
	var temp_role_id: String = str(overrides.get("temporary_player_role", "")).strip_edges()
	if temp_role_id == "spearman" or temp_role_id == "blademaster":
		var temp_owned_card_ids: Array[String] = []
		var temp_selected_loadout_ids: Array[String] = []
		if temp_role_id == "blademaster":
			temp_owned_card_ids = ["blade_front_cut", "blade_chase_cut", "blade_breathe", "blade_press_break"]
			temp_selected_loadout_ids = ["blade_front_cut", "blade_front_cut", "blade_chase_cut", "blade_chase_cut", "blade_breathe", "blade_breathe", "blade_press_break", "blade_press_break"]
		else:
			temp_owned_card_ids = ["spear_mid_thrust", "spear_line_press", "spear_focus", "spear_guard_horse"]
			temp_selected_loadout_ids = ["spear_mid_thrust", "spear_mid_thrust", "spear_line_press", "spear_line_press", "spear_focus", "spear_focus", "spear_guard_horse", "spear_guard_horse"]
		var temp_profile := {
			"role": temp_role_id,
			"career": str(overrides.get("temporary_player_career", "武科出身")),
			"weapon": str(overrides.get("temporary_player_weapon", "长枪" if temp_role_id == "spearman" else "腰刀")),
			"martial_level": 1,
			"battles_won": 0,
			"max_hp": int(base_config.get("max_hp", 20)),
			"hp": int(base_config.get("hp", base_config.get("max_hp", 20))),
			"max_posture": int(base_config.get("max_momentum", 6)),
			"posture": int(base_config.get("momentum", 5)),
			"qinggong": int(base_config.get("qinggong", 1)),
			"owned_card_ids": temp_owned_card_ids,
			"selected_loadout_ids": temp_selected_loadout_ids,
		}
		profile = temp_profile
	if profile.is_empty():
		return base_config
	var role_id: String = str(profile.get("role", ""))
	if role_id == "blademaster" or role_id == "spearman":
		var role_config: Dictionary = _player_role_config_from_story_sets(role_id, profile)
		if not role_config.is_empty():
			base_config = role_config
	var owned_cards := _cards_from_card_ids(profile.get("owned_card_ids", []))
	if not owned_cards.is_empty():
		base_config["deck"] = owned_cards
	var selected_loadout_ids := _card_id_array(profile.get("selected_loadout_ids", []))
	if not selected_loadout_ids.is_empty():
		base_config["selected_loadout_ids"] = selected_loadout_ids
	var deck_slots := _deck_slots_from_card_ids(profile.get("deck_slots", []))
	if not deck_slots.is_empty():
		base_config["deck_slots"] = deck_slots
		base_config["active_deck_index"] = int(profile.get("active_deck_index", 0))
	base_config["name"] = str(profile.get("career", base_config.get("name", "")))
	base_config["display_name"] = str(profile.get("career", base_config.get("display_name", base_config.get("name", ""))))
	base_config["weapon"] = str(profile.get("weapon", base_config.get("weapon", "")))
	base_config["max_hp"] = int(profile.get("max_hp", base_config.get("max_hp", 20)))
	base_config["hp"] = clampi(int(profile.get("hp", base_config.get("hp", base_config.get("max_hp", 20)))), 0, int(base_config.get("max_hp", 20)))
	base_config["max_momentum"] = int(profile.get("max_posture", profile.get("max_momentum", base_config.get("max_momentum", 6))))
	base_config["momentum"] = int(profile.get("posture", profile.get("momentum", base_config.get("momentum", 5))))
	base_config["realm"] = int(profile.get("martial_level", base_config.get("realm", 1)))
	base_config["qinggong"] = clampi(int(profile.get("qinggong", base_config.get("qinggong", 1))), 1, 4)
	base_config["position"] = int(base_config.get("position", 2))
	base_config["facing"] = str(base_config.get("facing", "right"))
	return base_config

func _player_role_config_from_story_sets(role_id: String, profile: Dictionary) -> Dictionary:
	var template_id := "player_blademaster" if role_id == "blademaster" else "player_spearman"
	var deck_id := _player_deck_id_for_profile(role_id, profile)
	var data = NarrativeStoryBattleLoader.build_fighter_data(template_id, deck_id, "player_start", _story_loader_card_catalog(), true)
	return _fighter_data_to_config(data)


func _player_deck_id_for_profile(role_id: String, profile: Dictionary) -> String:
	var wins := int(profile.get("battles_won", 0))
	if role_id == "spearman":
		return "player_spear_advanced" if wins >= 6 else "player_spear_start"
	return "player_blade_start"

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
	_clear_actor_runtime(true)
	_clear_actor_runtime(false)
	if state_machine != null:
		var settlement_mode: String = str(loadout.get("settlement_mode", ""))
		if not settlement_mode.is_empty():
			state_machine.set_settlement_mode_id(settlement_mode)
			set("settlement_mode_id", settlement_mode)
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
	fighter.data.id = str(config.get("id", fighter.data.id))
	fighter.data.display_name = str(config.get("display_name", config.get("name", fighter.data.display_name)))
	fighter.data.weapon_name = str(config.get("weapon", fighter.data.weapon_name))
	fighter.data.max_hp = int(config.get("max_hp", fighter.data.max_hp))
	fighter.data.max_momentum = int(config.get("max_posture", config.get("max_momentum", fighter.data.max_momentum)))
	fighter.data.starting_momentum = clampi(int(config.get("start_posture", config.get("momentum", fighter.data.starting_momentum))), 0, fighter.data.max_momentum)
	fighter.data.starting_realm = int(config.get("realm", fighter.data.starting_realm))
	fighter.data.qinggong = maxi(1, int(config.get("qinggong", fighter.data.qinggong)))
	fighter.data.starting_position = clampi(int(config.get("starting_position", config.get("position", fighter.data.starting_position))), 0, 8)
	fighter.data.starting_facing = "left" if str(config.get("starting_facing", config.get("facing", fighter.data.starting_facing))) == "left" else "right"
	fighter.data.preferred_distances = _packed_ints(config.get("preferred", []))
	fighter.data.starting_deck = _cards_from_configs(config.get("deck", []))
	if fighter == player:
		fighter.set_battle_deck_limit(PLAYER_BATTLE_DECK_SIZE)
		var deck_slots: Array = config.get("deck_slots", [])
		if not deck_slots.is_empty():
			fighter.set_battle_deck_slots(deck_slots, int(config.get("active_deck_index", 0)))
			_sanitize_player_battle_deck_selection()
		var selected_cards := _cards_from_card_ids(config.get("selected_loadout_ids", []))
		if deck_slots.is_empty() and selected_cards.is_empty():
			selected_cards = _cards_from_configs(config.get("selected_loadout", []))
		if deck_slots.is_empty() and selected_cards.is_empty():
			fighter.reset_battle_deck_to_default()
		elif deck_slots.is_empty():
			fighter.set_selected_battle_deck(selected_cards)
			_sanitize_player_battle_deck_selection()
			if fighter.get_battle_deck_size() < PLAYER_BATTLE_DECK_SIZE:
				_auto_fill_player_battle_deck()
	else:
		fighter.set_battle_deck_limit(0)
		fighter.reset_battle_deck_to_default()
	fighter.hp = clampi(int(config.get("hp", fighter.data.max_hp)), 0, fighter.data.max_hp)
	fighter.momentum = fighter.data.starting_momentum
	fighter.session_realm = fighter.data.starting_realm
	fighter.realm = fighter.session_realm
	fighter.qinggong = maxi(1, fighter.data.qinggong)
	fighter.position = fighter.data.starting_position
	fighter.facing = fighter.data.starting_facing
	fighter.draw_pile = fighter.get_battle_deck()
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


func _cards_from_configs(configs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for config_variant in configs:
		if config_variant is CardData:
			cards.append(config_variant.duplicate_card())
			continue
		var config: Dictionary = config_variant
		cards.append(CardData.new(str(config.get("id", "card")), str(config.get("name", "招式")), str(config.get("name", "")), int(config.get("min", 0)), int(config.get("max", 5)), int(config.get("cost", 1)), str(config.get("role", CardData.ROLE_GUARD)), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), PackedStringArray(config.get("tags", [])), str(config.get("style", "")), bool(config.get("facing", true))))
	return cards

func _cards_from_card_ids(card_ids) -> Array[CardData]:
	var cards: Array[CardData] = []
	var catalog: Dictionary = _story_loader_card_catalog()
	for card_id: String in _card_id_array(card_ids):
		if not catalog.has(card_id):
			push_warning("Narrative battle loadout: unknown player card id: %s" % card_id)
			continue
		var card_variant = catalog[card_id]
		if card_variant is CardData:
			cards.append((card_variant as CardData).duplicate_card())
	return cards

func _deck_slots_from_card_ids(value) -> Array:
	var slots: Array = []
	if value is Array:
		for slot_variant in value:
			slots.append(_cards_from_card_ids(slot_variant))
	return slots

func _card_ids_from_cards(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card_variant in cards:
		if card_variant is CardData:
			var card: CardData = card_variant
			if not card.id.is_empty():
				ids.append(card.id)
		elif card_variant is Dictionary:
			var config: Dictionary = card_variant
			var card_id := str(config.get("id", ""))
			if not card_id.is_empty():
				ids.append(card_id)
	return ids

func _card_id_slots_from_fighter(fighter) -> Array:
	var slots: Array = []
	if fighter == null:
		return slots
	for slot in fighter.get_battle_deck_slots():
		slots.append(_card_ids_from_cards(slot as Array))
	return slots

func _card_id_array(value) -> Array[String]:
	var ids: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var card_id := str(item)
			if not card_id.is_empty():
				ids.append(card_id)
	elif value is String:
		var card_id := str(value)
		if not card_id.is_empty():
			ids.append(card_id)
	return ids

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
		if config_variant is CardData:
			var card: CardData = config_variant
			chunks.append("%s[耗%d/伤%d/守%d/势+%d/破%d/距%d-%d]" % [card.display_name, card.momentum_cost, card.damage, card.guard, card.gain_momentum, card.break_momentum, card.min_distance, card.max_distance])
			continue
		var config: Dictionary = config_variant
		chunks.append("%s[耗%d/伤%d/守%d/势+%d/破%d/距%d-%d]" % [str(config.get("name", "")), int(config.get("cost", 0)), int(config.get("damage", 0)), int(config.get("guard", 0)), int(config.get("gain", 0)), int(config.get("break", 0)), int(config.get("min", 0)), int(config.get("max", 0))])
	return "；".join(chunks)

func _record_result_once(narrative_result: String) -> void:
	if result_recorded:
		return
	if player != null and player.data != null:
		NarrativeBattleContext.set_player_card_state(_card_ids_from_cards(player.data.starting_deck), _card_ids_from_cards(player.get_selected_battle_deck()), _card_id_slots_from_fighter(player), player.get_active_battle_deck_index())
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
	battle_active = false
	awaiting_player_input = false
	if state_machine != null:
		state_machine.phase = BattleStateMachineScript.BattlePhase.RESULT
	_set_battle_result_debug_text("战斗结果：debug 强制胜利，进入结算确认")
	_show_battle_result_overlay(true)
