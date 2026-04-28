extends Node

const META_ENCOUNTER_ID := "canghai_narrative_encounter_id"
const META_SOURCE_NODE_ID := "canghai_narrative_source_node_id"
const META_SOURCE_SCENE := "canghai_narrative_source_scene"
const META_RETURN_AFTER_BATTLE := "canghai_narrative_return_after_battle"
const META_LAST_RESULT := "canghai_narrative_last_result"
const META_RESULT_READY := "canghai_narrative_result_ready"
const META_BATTLE_ID := "canghai_narrative_battle_id"
const META_UI_DEBUG_VISIBLE := "canghai_ui_debug_visible"

const META_PLAYER_READY := "canghai_player_ready"
const META_PLAYER_ROLE := "canghai_player_role"
const META_PLAYER_CAREER := "canghai_player_career"
const META_PLAYER_WEAPON := "canghai_player_weapon"
const META_PLAYER_MAX_HP := "canghai_player_max_hp"
const META_PLAYER_HP := "canghai_player_hp"
const META_PLAYER_MAX_POSTURE := "canghai_player_max_posture"
const META_PLAYER_POSTURE := "canghai_player_posture"
const META_PLAYER_MARTIAL_LEVEL := "canghai_player_martial_level"
const META_PLAYER_BATTLES_WON := "canghai_player_battles_won"
const META_NARRATIVE_STATE_READY := "canghai_narrative_state_ready"
const META_NARRATIVE_STATE := "canghai_narrative_state"

static var encounter_id := ""
static var source_node_id := ""
static var source_scene := "res://scenes/NarrativeDemo.tscn"
static var return_after_battle := false
static var last_result := ""
static var result_ready := false
static var battle_id := ""
static var ui_debug_visible := true

static var player_ready := false
static var player_role := ""
static var player_career := ""
static var player_weapon := ""
static var player_max_hp := 0
static var player_hp := 0
static var player_max_posture := 0
static var player_posture := 0
static var player_martial_level := 0
static var player_battles_won := 0
static var narrative_state_ready := false
static var narrative_state: Dictionary = {}

static func set_request(p_encounter_id: String, p_source_node_id: String, p_battle_id: String = "") -> void:
	_pull_meta()
	encounter_id = p_encounter_id
	source_node_id = p_source_node_id
	source_scene = "res://scenes/NarrativeDemo.tscn"
	battle_id = p_battle_id if not p_battle_id.is_empty() else _battle_id_for_encounter(p_encounter_id, p_source_node_id)
	return_after_battle = false
	last_result = ""
	result_ready = false
	_write_meta()

static func _battle_id_for_encounter(p_encounter_id: String, p_source_node_id: String = "") -> String:
	var mapping: Dictionary = NarrativeEnemyManifest.get_mapping(p_encounter_id, "fallback")
	if not mapping.is_empty():
		return str(mapping.get("battle_id", "fallback"))
	match p_encounter_id:
		"enc_prologue_master_rescue": return "prologue_master_rescue"
		"enc_beach_ambush": return "first_act_beach_ambush"
		"enc_transport_officer": return "first_act_transport_officer"
		"enc_wakou_boss": return "first_act_wakou_boss"
		_:
			if not p_source_node_id.is_empty(): return p_source_node_id
			return "fallback"

static func get_battle_id() -> String:
	_pull_meta()
	if battle_id.is_empty(): battle_id = _battle_id_for_encounter(encounter_id, source_node_id)
	return battle_id

static func is_ui_debug_visible() -> bool:
	_pull_ui_debug_meta()
	return ui_debug_visible

static func set_ui_debug_visible(visible: bool) -> void:
	ui_debug_visible = visible
	_write_ui_debug_meta()

static func toggle_ui_debug_visible() -> bool:
	set_ui_debug_visible(not is_ui_debug_visible())
	return ui_debug_visible

static func set_result(p_result: String) -> void:
	_pull_meta()
	last_result = p_result
	result_ready = not p_result.is_empty()
	return_after_battle = result_ready
	if source_scene.is_empty(): source_scene = "res://scenes/NarrativeDemo.tscn"
	if source_node_id.is_empty(): source_node_id = "beach_ambush"
	if encounter_id.is_empty(): encounter_id = "enc_fallback"
	if battle_id.is_empty(): battle_id = _battle_id_for_encounter(encounter_id, source_node_id)
	_write_meta()

static func clear() -> void:
	_pull_meta()
	encounter_id = ""
	source_node_id = ""
	source_scene = "res://scenes/NarrativeDemo.tscn"
	battle_id = ""
	return_after_battle = false
	last_result = ""
	result_ready = false
	_clear_battle_meta()
	_write_player_meta()

static func clear_player_profile() -> void:
	player_ready = false
	player_role = ""
	player_career = ""
	player_weapon = ""
	player_max_hp = 0
	player_hp = 0
	player_max_posture = 0
	player_posture = 0
	player_martial_level = 0
	player_battles_won = 0
	_clear_player_meta()

static func set_narrative_state(state: Dictionary) -> void:
	narrative_state_ready = true
	narrative_state = state.duplicate(true)
	_write_narrative_state_meta()

static func has_narrative_state() -> bool:
	_pull_meta()
	return narrative_state_ready and not narrative_state.is_empty()

static func get_narrative_state() -> Dictionary:
	_pull_meta()
	if not narrative_state_ready:
		return {}
	return narrative_state.duplicate(true)

static func clear_narrative_state() -> void:
	narrative_state_ready = false
	narrative_state.clear()
	_clear_narrative_state_meta()

static func set_player_profile(profile: Dictionary) -> void:
	player_ready = true
	player_role = str(profile.get("role", "spearman"))
	player_career = str(profile.get("career", "长枪武官"))
	player_weapon = str(profile.get("weapon", "长枪"))
	player_max_hp = int(profile.get("max_hp", 36))
	player_hp = int(profile.get("hp", player_max_hp))
	player_max_posture = int(profile.get("max_posture", 10))
	player_posture = int(profile.get("posture", 5))
	player_martial_level = int(profile.get("martial_level", 1))
	player_battles_won = int(profile.get("battles_won", 0))
	_write_player_meta()

static func has_player_profile() -> bool:
	_pull_meta()
	return player_ready and not player_role.is_empty()

static func get_player_profile() -> Dictionary:
	_pull_meta()
	if not has_player_profile(): return {}
	return {"role": player_role, "career": player_career, "weapon": player_weapon, "max_hp": player_max_hp, "hp": player_hp, "max_posture": player_max_posture, "posture": player_posture, "martial_level": player_martial_level, "battles_won": player_battles_won}

static func apply_player_growth(source: String, hp_gain: int = 0, posture_gain: int = 0, martial_gain: int = 0, heal_full: bool = false) -> void:
	_pull_meta()
	if not has_player_profile(): return
	player_max_hp += hp_gain
	player_max_posture += posture_gain
	player_martial_level += martial_gain
	if source == "battle_win": player_battles_won += 1
	if heal_full:
		player_hp = player_max_hp
		player_posture = player_max_posture
	else:
		player_hp = min(player_max_hp, player_hp + max(0, hp_gain))
		player_posture = min(player_max_posture, player_posture + max(0, posture_gain))
	_write_player_meta()

static func player_profile_debug_text() -> String:
	_pull_meta()
	if not has_player_profile(): return "玩家数据=未初始化"
	return "玩家数据=%s｜职业=%s｜武器=%s｜HP=%d/%d｜势=%d/%d｜武境=%d｜胜场=%d" % [player_role, player_career, player_weapon, player_hp, player_max_hp, player_posture, player_max_posture, player_martial_level, player_battles_won]

static func has_request() -> bool:
	_pull_meta()
	return not encounter_id.is_empty()

static func has_result() -> bool:
	_pull_meta()
	return result_ready and not last_result.is_empty()

static func enemy_source_text() -> String:
	if NarrativeEnemyManifest.is_loaded():
		var mapping: Dictionary = NarrativeEnemyManifest.get_mapping(encounter_id, get_battle_id())
		if not mapping.is_empty():
			return "manifest"
	return "fallback"

static func debug_text() -> String:
	_pull_meta()
	return "encounter_id=%s｜battle_id=%s｜enemy_source=%s｜source_node_id=%s｜return_after_battle=%s｜last_result=%s｜%s" % [encounter_id, get_battle_id(), enemy_source_text(), source_node_id, str(return_after_battle), last_result, player_profile_debug_text()]

static func get_battle_mapping() -> Dictionary:
	_pull_meta()
	var mapping: Dictionary = NarrativeEnemyManifest.get_mapping(encounter_id, get_battle_id())
	if not mapping.is_empty(): return _with_current_player_role(mapping)
	return _with_current_player_role(_fallback_mapping())

static func _fallback_mapping() -> Dictionary:
	return {"battle_id": get_battle_id(), "player_role": "spearman", "enemy_role": "enemy_spearman", "enemy_family": "spearman", "difficulty": "fallback", "label": "默认战斗 / 枪手", "enemy_config": {"enemy_id": "enemy_spearman_fallback", "display_name": "默认敌方枪手", "narrative_identity": "兜底用敌人配置。", "weapon": "长枪", "role_sheet": "enemy_spearman", "max_hp": 26, "max_posture": 10, "start_posture": 4, "intent_style": "fallback", "behavior_tags": ["试探", "突刺"], "preferred_intents": ["刺探", "突刺"], "ai_note": "默认安全配置。", "reward": {"jun_gong": 1, "qing_wang": 0, "clues": 1}}}

static func _with_current_player_role(mapping: Dictionary) -> Dictionary:
	_pull_meta()
	mapping["battle_id"] = get_battle_id()
	mapping["enemy_source"] = enemy_source_text()
	if has_player_profile():
		mapping["player_role"] = player_role
		mapping["player_career"] = player_career
		mapping["player_weapon"] = player_weapon
		mapping["player_profile"] = get_player_profile()
	return mapping

static func get_enemy_config() -> Dictionary:
	var mapping := get_battle_mapping()
	return mapping.get("enemy_config", {})

static func battle_mapping_debug_text() -> String:
	var mapping := get_battle_mapping()
	return "battle_id=%s｜battle_mapping=%s｜player=%s｜enemy=%s｜difficulty=%s｜enemy_source=%s｜%s" % [get_battle_id(), str(mapping.get("label", "")), str(mapping.get("player_role", "")), str(mapping.get("enemy_role", "")), str(mapping.get("difficulty", "")), enemy_source_text(), player_profile_debug_text()]

static func enemy_config_debug_text() -> String:
	var config := get_enemy_config()
	if config.is_empty(): return "enemy_source=%s｜enemy_config=空" % enemy_source_text()
	return "enemy_source=%s｜敌人配置=%s｜武器=%s｜HP=%s｜势=%s/%s｜行为=%s｜标签=%s｜意图=%s" % [enemy_source_text(), str(config.get("display_name", "")), str(config.get("weapon", "")), str(config.get("max_hp", "")), str(config.get("start_posture", "")), str(config.get("max_posture", "")), str(config.get("intent_style", "")), ", ".join(config.get("behavior_tags", [])), ", ".join(config.get("preferred_intents", []))]

static func enemy_config_full_text() -> String:
	var config := get_enemy_config()
	if config.is_empty(): return "enemy_source=%s｜敌人详细配置：空｜%s" % [enemy_source_text(), player_profile_debug_text()]
	return "%s｜enemy_source=%s｜battle_id=%s｜敌人详细配置：%s｜身份=%s｜武器=%s｜HP=%s｜势=%s/%s｜行为=%s｜标签=%s｜意图=%s｜说明=%s" % [player_profile_debug_text(), enemy_source_text(), get_battle_id(), str(config.get("display_name", "")), str(config.get("narrative_identity", "")), str(config.get("weapon", "")), str(config.get("max_hp", "")), str(config.get("start_posture", "")), str(config.get("max_posture", "")), str(config.get("intent_style", "")), ", ".join(config.get("behavior_tags", [])), ", ".join(config.get("preferred_intents", [])), str(config.get("ai_note", ""))]

static func _write_meta() -> void:
	Engine.set_meta(META_ENCOUNTER_ID, encounter_id)
	Engine.set_meta(META_SOURCE_NODE_ID, source_node_id)
	Engine.set_meta(META_SOURCE_SCENE, source_scene)
	Engine.set_meta(META_RETURN_AFTER_BATTLE, return_after_battle)
	Engine.set_meta(META_LAST_RESULT, last_result)
	Engine.set_meta(META_RESULT_READY, result_ready)
	Engine.set_meta(META_BATTLE_ID, battle_id)
	_write_ui_debug_meta()
	_write_player_meta()
	_write_narrative_state_meta()

static func _write_ui_debug_meta() -> void:
	Engine.set_meta(META_UI_DEBUG_VISIBLE, ui_debug_visible)

static func _write_player_meta() -> void:
	Engine.set_meta(META_PLAYER_READY, player_ready)
	Engine.set_meta(META_PLAYER_ROLE, player_role)
	Engine.set_meta(META_PLAYER_CAREER, player_career)
	Engine.set_meta(META_PLAYER_WEAPON, player_weapon)
	Engine.set_meta(META_PLAYER_MAX_HP, player_max_hp)
	Engine.set_meta(META_PLAYER_HP, player_hp)
	Engine.set_meta(META_PLAYER_MAX_POSTURE, player_max_posture)
	Engine.set_meta(META_PLAYER_POSTURE, player_posture)
	Engine.set_meta(META_PLAYER_MARTIAL_LEVEL, player_martial_level)
	Engine.set_meta(META_PLAYER_BATTLES_WON, player_battles_won)

static func _write_narrative_state_meta() -> void:
	Engine.set_meta(META_NARRATIVE_STATE_READY, narrative_state_ready)
	Engine.set_meta(META_NARRATIVE_STATE, narrative_state.duplicate(true))

static func _pull_meta() -> void:
	_pull_ui_debug_meta()
	if Engine.has_meta(META_ENCOUNTER_ID): encounter_id = str(Engine.get_meta(META_ENCOUNTER_ID))
	if Engine.has_meta(META_SOURCE_NODE_ID): source_node_id = str(Engine.get_meta(META_SOURCE_NODE_ID))
	if Engine.has_meta(META_SOURCE_SCENE): source_scene = str(Engine.get_meta(META_SOURCE_SCENE))
	if Engine.has_meta(META_RETURN_AFTER_BATTLE): return_after_battle = bool(Engine.get_meta(META_RETURN_AFTER_BATTLE))
	if Engine.has_meta(META_LAST_RESULT): last_result = str(Engine.get_meta(META_LAST_RESULT))
	if Engine.has_meta(META_RESULT_READY): result_ready = bool(Engine.get_meta(META_RESULT_READY))
	if Engine.has_meta(META_BATTLE_ID): battle_id = str(Engine.get_meta(META_BATTLE_ID))
	if Engine.has_meta(META_PLAYER_READY): player_ready = bool(Engine.get_meta(META_PLAYER_READY))
	if Engine.has_meta(META_PLAYER_ROLE): player_role = str(Engine.get_meta(META_PLAYER_ROLE))
	if Engine.has_meta(META_PLAYER_CAREER): player_career = str(Engine.get_meta(META_PLAYER_CAREER))
	if Engine.has_meta(META_PLAYER_WEAPON): player_weapon = str(Engine.get_meta(META_PLAYER_WEAPON))
	if Engine.has_meta(META_PLAYER_MAX_HP): player_max_hp = int(Engine.get_meta(META_PLAYER_MAX_HP))
	if Engine.has_meta(META_PLAYER_HP): player_hp = int(Engine.get_meta(META_PLAYER_HP))
	if Engine.has_meta(META_PLAYER_MAX_POSTURE): player_max_posture = int(Engine.get_meta(META_PLAYER_MAX_POSTURE))
	if Engine.has_meta(META_PLAYER_POSTURE): player_posture = int(Engine.get_meta(META_PLAYER_POSTURE))
	if Engine.has_meta(META_PLAYER_MARTIAL_LEVEL): player_martial_level = int(Engine.get_meta(META_PLAYER_MARTIAL_LEVEL))
	if Engine.has_meta(META_PLAYER_BATTLES_WON): player_battles_won = int(Engine.get_meta(META_PLAYER_BATTLES_WON))
	if Engine.has_meta(META_NARRATIVE_STATE_READY): narrative_state_ready = bool(Engine.get_meta(META_NARRATIVE_STATE_READY))
	if Engine.has_meta(META_NARRATIVE_STATE):
		var state_variant = Engine.get_meta(META_NARRATIVE_STATE)
		if state_variant is Dictionary:
			narrative_state = (state_variant as Dictionary).duplicate(true)

static func _pull_ui_debug_meta() -> void:
	if Engine.has_meta(META_UI_DEBUG_VISIBLE):
		ui_debug_visible = bool(Engine.get_meta(META_UI_DEBUG_VISIBLE))
	else:
		_write_ui_debug_meta()

static func _clear_battle_meta() -> void:
	for key in [META_ENCOUNTER_ID, META_SOURCE_NODE_ID, META_SOURCE_SCENE, META_RETURN_AFTER_BATTLE, META_LAST_RESULT, META_RESULT_READY, META_BATTLE_ID]:
		if Engine.has_meta(key): Engine.remove_meta(key)

static func _clear_player_meta() -> void:
	for key in [META_PLAYER_READY, META_PLAYER_ROLE, META_PLAYER_CAREER, META_PLAYER_WEAPON, META_PLAYER_MAX_HP, META_PLAYER_HP, META_PLAYER_MAX_POSTURE, META_PLAYER_POSTURE, META_PLAYER_MARTIAL_LEVEL, META_PLAYER_BATTLES_WON]:
		if Engine.has_meta(key): Engine.remove_meta(key)

static func _clear_narrative_state_meta() -> void:
	for key in [META_NARRATIVE_STATE_READY, META_NARRATIVE_STATE]:
		if Engine.has_meta(key): Engine.remove_meta(key)
