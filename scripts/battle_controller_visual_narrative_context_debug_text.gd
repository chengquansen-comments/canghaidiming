extends "res://scripts/battle_controller_visual_narrative_context_loadout.gd"

# Narrative context debug text layer.

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

func _enemy_full_config_text() -> String:
	var generated_status := _generated_visible_status_text()
	if battle_loadout_error != "":
		return "BattleLoadout错误：%s\n%s\n%s" % [battle_loadout_error, _runtime_cards_text(), generated_status]
	if not battle_loadout.is_empty():
		return "%s\n%s\n%s" % [_battle_loadout_visible_debug_text(), _runtime_cards_text(), generated_status]
	return "%s\n%s\n%s" % [NarrativeBattleContext.enemy_config_full_text(), _runtime_cards_text(), generated_status]


func _generated_visible_status_text() -> String:
	var payload: Dictionary = _dict(battle_loadout.get("generated_player_visible_status", {}))
	if payload.is_empty():
		return "Generated Content: OFF"
	return GeneratedContentPlayerVisibleDebugPanel.new().build_visible_status_text(payload)
