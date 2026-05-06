extends RefCounted

static func battle_id_for_encounter(p_encounter_id: String, p_source_node_id: String = "") -> String:
	var mapping: Dictionary = NarrativeEnemyManifest.get_mapping(p_encounter_id, "fallback")
	if not mapping.is_empty():
		return str(mapping.get("battle_id", "fallback"))
	match p_encounter_id:
		"enc_prologue_master_rescue": return "prologue_master_rescue"
		"enc_beach_ambush": return "first_act_beach_ambush"
		"enc_transport_officer": return "first_act_transport_officer"
		"enc_wakou_boss": return "first_act_wakou_boss"
		_:
			if not p_source_node_id.is_empty():
				return p_source_node_id
			return "fallback"

static func enemy_source_text(encounter_id: String, battle_id: String) -> String:
	if NarrativeEnemyManifest.is_loaded():
		var mapping: Dictionary = NarrativeEnemyManifest.get_mapping(encounter_id, battle_id)
		if not mapping.is_empty():
			return "manifest"
	return "fallback"

static func fallback_mapping(battle_id: String) -> Dictionary:
	return {
		"battle_id": battle_id,
		"player_role": "spearman",
		"enemy_role": "enemy_spearman",
		"enemy_family": "spearman",
		"difficulty": "fallback",
		"label": "默认战斗 / 枪手",
		"enemy_config": {
			"enemy_id": "enemy_spearman_fallback",
			"display_name": "默认敌方枪手",
			"narrative_identity": "兜底用敌人配置。",
			"weapon": "长枪",
			"role_sheet": "enemy_spearman",
			"max_hp": 26,
			"max_posture": 10,
			"start_posture": 4,
			"intent_style": "fallback",
			"behavior_tags": ["试探", "突刺"],
			"preferred_intents": ["刺探", "突刺"],
			"ai_note": "默认安全配置。",
			"reward": {"jun_gong": 1, "qing_wang": 0, "clues": 1}
		}
	}

static func with_current_player_role(mapping: Dictionary, battle_id: String, enemy_source: String, profile: Dictionary) -> Dictionary:
	var result: Dictionary = mapping.duplicate(true)
	result["battle_id"] = battle_id
	result["enemy_source"] = enemy_source
	if not profile.is_empty():
		result["player_role"] = str(profile.get("role", ""))
		result["player_career"] = str(profile.get("career", ""))
		result["player_weapon"] = str(profile.get("weapon", ""))
		result["player_profile"] = profile.duplicate(true)
	return result

static func battle_mapping(encounter_id: String, battle_id: String, profile: Dictionary) -> Dictionary:
	var mapping: Dictionary = NarrativeEnemyManifest.get_mapping(encounter_id, battle_id)
	var enemy_source := enemy_source_text(encounter_id, battle_id)
	if not mapping.is_empty():
		return with_current_player_role(mapping, battle_id, enemy_source, profile)
	return with_current_player_role(fallback_mapping(battle_id), battle_id, enemy_source, profile)

static func debug_text(encounter_id: String, battle_id: String, source_node_id: String, override_player_profile: bool, return_after_battle: bool, last_result: String, profile_debug: String) -> String:
	return "encounter_id=%s｜battle_id=%s｜enemy_source=%s｜source_node_id=%s｜override_player_profile=%s｜return_after_battle=%s｜last_result=%s｜%s" % [
		encounter_id,
		battle_id,
		enemy_source_text(encounter_id, battle_id),
		source_node_id,
		str(override_player_profile),
		str(return_after_battle),
		last_result,
		profile_debug
	]

static func battle_mapping_debug_text(mapping: Dictionary, battle_id: String, encounter_id: String, profile_debug: String) -> String:
	return "battle_id=%s｜battle_mapping=%s｜player=%s｜enemy=%s｜difficulty=%s｜enemy_source=%s｜%s" % [
		battle_id,
		str(mapping.get("label", "")),
		str(mapping.get("player_role", "")),
		str(mapping.get("enemy_role", "")),
		str(mapping.get("difficulty", "")),
		enemy_source_text(encounter_id, battle_id),
		profile_debug
	]

static func enemy_config_debug_text(config: Dictionary, encounter_id: String, battle_id: String) -> String:
	var source := enemy_source_text(encounter_id, battle_id)
	if config.is_empty():
		return "enemy_source=%s｜enemy_config=空" % source
	return "enemy_source=%s｜敌人配置=%s｜武器=%s｜HP=%s｜势=%s/%s｜行为=%s｜标签=%s｜意图=%s" % [
		source,
		str(config.get("display_name", "")),
		str(config.get("weapon", "")),
		str(config.get("max_hp", "")),
		str(config.get("start_posture", "")),
		str(config.get("max_posture", "")),
		str(config.get("intent_style", "")),
		", ".join(config.get("behavior_tags", [])),
		", ".join(config.get("preferred_intents", []))
	]

static func enemy_config_full_text(config: Dictionary, encounter_id: String, battle_id: String, profile_debug: String) -> String:
	var source := enemy_source_text(encounter_id, battle_id)
	if config.is_empty():
		return "enemy_source=%s｜敌人详细配置：空｜%s" % [source, profile_debug]
	return "%s｜enemy_source=%s｜battle_id=%s｜敌人详细配置：%s｜身份=%s｜武器=%s｜HP=%s｜势=%s/%s｜行为=%s｜标签=%s｜意图=%s｜说明=%s" % [
		profile_debug,
		source,
		battle_id,
		str(config.get("display_name", "")),
		str(config.get("narrative_identity", "")),
		str(config.get("weapon", "")),
		str(config.get("max_hp", "")),
		str(config.get("start_posture", "")),
		str(config.get("max_posture", "")),
		str(config.get("intent_style", "")),
		", ".join(config.get("behavior_tags", [])),
		", ".join(config.get("preferred_intents", [])),
		str(config.get("ai_note", ""))
	]
