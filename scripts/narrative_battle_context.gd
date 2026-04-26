extends Node

const META_ENCOUNTER_ID := "canghai_narrative_encounter_id"
const META_SOURCE_NODE_ID := "canghai_narrative_source_node_id"
const META_SOURCE_SCENE := "canghai_narrative_source_scene"
const META_RETURN_AFTER_BATTLE := "canghai_narrative_return_after_battle"
const META_LAST_RESULT := "canghai_narrative_last_result"
const META_RESULT_READY := "canghai_narrative_result_ready"
const META_BATTLE_ID := "canghai_narrative_battle_id"

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

static var encounter_id := ""
static var source_node_id := ""
static var source_scene := "res://scenes/NarrativeDemo.tscn"
static var return_after_battle := false
static var last_result := ""
static var result_ready := false
static var battle_id := ""

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
	match p_encounter_id:
		"enc_prologue_master_rescue":
			return "prologue_master_rescue"
		"enc_beach_ambush":
			return "first_act_beach_ambush"
		"enc_transport_officer":
			return "first_act_transport_officer"
		"enc_wakou_boss":
			return "first_act_wakou_boss"
		_:
			if not p_source_node_id.is_empty():
				return p_source_node_id
			return "fallback"

static func get_battle_id() -> String:
	_pull_meta()
	if battle_id.is_empty():
		battle_id = _battle_id_for_encounter(encounter_id, source_node_id)
	return battle_id

static func set_result(p_result: String) -> void:
	_pull_meta()
	last_result = p_result
	result_ready = not p_result.is_empty()
	return_after_battle = result_ready
	if source_scene.is_empty():
		source_scene = "res://scenes/NarrativeDemo.tscn"
	if source_node_id.is_empty():
		source_node_id = "beach_ambush"
	if encounter_id.is_empty():
		encounter_id = "enc_fallback"
	if battle_id.is_empty():
		battle_id = _battle_id_for_encounter(encounter_id, source_node_id)
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
	if not has_player_profile():
		return {}
	return {"role": player_role, "career": player_career, "weapon": player_weapon, "max_hp": player_max_hp, "hp": player_hp, "max_posture": player_max_posture, "posture": player_posture, "martial_level": player_martial_level, "battles_won": player_battles_won}

static func apply_player_growth(source: String, hp_gain: int = 0, posture_gain: int = 0, martial_gain: int = 0, heal_full: bool = false) -> void:
	_pull_meta()
	if not has_player_profile():
		return
	player_max_hp += hp_gain
	player_max_posture += posture_gain
	player_martial_level += martial_gain
	if source == "battle_win":
		player_battles_won += 1
	if heal_full:
		player_hp = player_max_hp
		player_posture = player_max_posture
	else:
		player_hp = min(player_max_hp, player_hp + max(0, hp_gain))
		player_posture = min(player_max_posture, player_posture + max(0, posture_gain))
	_write_player_meta()

static func player_profile_debug_text() -> String:
	_pull_meta()
	if not has_player_profile():
		return "玩家数据=未初始化"
	return "玩家数据=%s｜职业=%s｜武器=%s｜HP=%d/%d｜势=%d/%d｜武境=%d｜胜场=%d" % [player_role, player_career, player_weapon, player_hp, player_max_hp, player_posture, player_max_posture, player_martial_level, player_battles_won]

static func has_request() -> bool:
	_pull_meta()
	return not encounter_id.is_empty()

static func has_result() -> bool:
	_pull_meta()
	return result_ready and not last_result.is_empty()

static func debug_text() -> String:
	_pull_meta()
	return "encounter_id=%s｜battle_id=%s｜source_node_id=%s｜return_after_battle=%s｜last_result=%s｜%s" % [encounter_id, get_battle_id(), source_node_id, str(return_after_battle), last_result, player_profile_debug_text()]

static func get_battle_mapping() -> Dictionary:
	_pull_meta()
	match encounter_id:
		"enc_prologue_master_rescue":
			return {"battle_id": get_battle_id(), "player_role": "blademaster", "enemy_role": "enemy_blademaster", "enemy_family": "blademaster", "difficulty": "tutorial_elite", "label": "序章救场 / 袭村倭寇刀手", "enemy_config": {"enemy_id": "enemy_blademaster_prologue_raider", "display_name": "袭村倭寇刀手", "narrative_identity": "屠村后折返灭口的倭寇刀手，被师父截住。此战玩家名义上操控师父。", "weapon": "倭刀", "role_sheet": "enemy_blademaster", "max_hp": 24, "max_posture": 10, "start_posture": 3, "intent_style": "tutorial_victim", "behavior_tags": ["教学", "低血量", "可速杀", "临死线索"], "preferred_intents": ["虚张声势", "挥刀", "退步"], "ai_note": "序章教学战，目标是让玩家体验师父三张强力牌压制敌人；敌人应弱于正式战斗。", "reward": {"jun_gong": 0, "qing_wang": 0, "clues": 1}}}
		"enc_beach_ambush":
			return _with_current_player_role({"battle_id": get_battle_id(), "player_role": "spearman", "enemy_role": "enemy_spearman", "enemy_family": "spearman", "difficulty": "normal", "label": "海边伏击 / 敌方枪手", "enemy_config": {"enemy_id": "enemy_spearman_beach_ambush", "display_name": "敌方枪手", "narrative_identity": "伏击海滩的倭寇前哨枪手，熟悉芦苇与潮汐掩护。", "weapon": "长枪", "role_sheet": "enemy_spearman", "max_hp": 26, "max_posture": 10, "start_posture": 4, "intent_style": "poke_pressure", "behavior_tags": ["试探", "抢势", "突刺", "低防御"], "preferred_intents": ["刺探", "压步", "突刺"], "ai_note": "普通战斗，用连续小伤害与抢势逼玩家交出防守；不要做高爆发。", "reward": {"jun_gong": 1, "qing_wang": 0, "clues": 1}}})
		"enc_transport_officer":
			return _with_current_player_role({"battle_id": get_battle_id(), "player_role": "blademaster", "enemy_role": "enemy_blademaster", "enemy_family": "blademaster", "difficulty": "elite", "label": "失械案押运官 / 敌方刀客", "enemy_config": {"enemy_id": "enemy_blademaster_transport_officer", "display_name": "失械案押运官", "narrative_identity": "负责押运明制火器的军中押运官，试图切断名册线索。", "weapon": "腰刀", "role_sheet": "enemy_blademaster", "max_hp": 34, "max_posture": 10, "start_posture": 5, "intent_style": "counter_break", "behavior_tags": ["架刀", "反击", "破防", "压迫"], "preferred_intents": ["格挡反斩", "逼步", "横斩"], "ai_note": "精英战斗，强调反击与破防。玩家若只进攻，会被刀客借势反打。", "reward": {"jun_gong": 1, "qing_wang": 1, "clues": 2}}})
		"enc_wakou_boss":
			return _with_current_player_role({"battle_id": get_battle_id(), "player_role": "blademaster", "enemy_role": "enemy_blademaster", "enemy_family": "blademaster", "difficulty": "boss", "label": "破船 Boss / 小股倭寇首领", "enemy_config": {"enemy_id": "enemy_blademaster_wakou_leader", "display_name": "小股倭寇首领", "narrative_identity": "破船火器箱旁的小股倭寇首领，知道军械流向但将被暗箭灭口。", "weapon": "倭刀", "role_sheet": "enemy_blademaster", "max_hp": 42, "max_posture": 10, "start_posture": 6, "intent_style": "boss_feint_burst", "behavior_tags": ["虚招", "抢势", "连斩", "临死线索"], "preferred_intents": ["虚晃", "疾斩", "抢步连斩"], "ai_note": "Boss 战，强调虚招与爆发。半血后倾向连续进攻，死亡前触发火器箱线索。", "reward": {"jun_gong": 2, "qing_wang": 0, "clues": 2}}})
		_:
			return _with_current_player_role({"battle_id": get_battle_id(), "player_role": "spearman", "enemy_role": "enemy_spearman", "enemy_family": "spearman", "difficulty": "fallback", "label": "默认战斗 / 枪手", "enemy_config": {"enemy_id": "enemy_spearman_fallback", "display_name": "默认敌方枪手", "narrative_identity": "兜底用敌人配置。", "weapon": "长枪", "role_sheet": "enemy_spearman", "max_hp": 26, "max_posture": 10, "start_posture": 4, "intent_style": "fallback", "behavior_tags": ["试探", "突刺"], "preferred_intents": ["刺探", "突刺"], "ai_note": "默认安全配置。", "reward": {"jun_gong": 1, "qing_wang": 0, "clues": 1}}})

static func _with_current_player_role(mapping: Dictionary) -> Dictionary:
	_pull_meta()
	mapping["battle_id"] = get_battle_id()
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
	return "battle_id=%s｜battle_mapping=%s｜player=%s｜enemy=%s｜difficulty=%s｜%s" % [get_battle_id(), str(mapping.get("label", "")), str(mapping.get("player_role", "")), str(mapping.get("enemy_role", "")), str(mapping.get("difficulty", "")), player_profile_debug_text()]

static func enemy_config_debug_text() -> String:
	var config := get_enemy_config()
	if config.is_empty():
		return "enemy_config=空"
	return "敌人配置=%s｜武器=%s｜HP=%s｜势=%s/%s｜行为=%s｜标签=%s｜意图=%s" % [str(config.get("display_name", "")), str(config.get("weapon", "")), str(config.get("max_hp", "")), str(config.get("start_posture", "")), str(config.get("max_posture", "")), str(config.get("intent_style", "")), ", ".join(config.get("behavior_tags", [])), ", ".join(config.get("preferred_intents", []))]

static func enemy_config_full_text() -> String:
	var config := get_enemy_config()
	if config.is_empty():
		return "敌人详细配置：空｜%s" % player_profile_debug_text()
	return "%s｜battle_id=%s｜敌人详细配置：%s｜身份=%s｜武器=%s｜HP=%s｜势=%s/%s｜行为=%s｜标签=%s｜意图=%s｜说明=%s" % [player_profile_debug_text(), get_battle_id(), str(config.get("display_name", "")), str(config.get("narrative_identity", "")), str(config.get("weapon", "")), str(config.get("max_hp", "")), str(config.get("start_posture", "")), str(config.get("max_posture", "")), str(config.get("intent_style", "")), ", ".join(config.get("behavior_tags", [])), ", ".join(config.get("preferred_intents", [])), str(config.get("ai_note", ""))]

static func _write_meta() -> void:
	Engine.set_meta(META_ENCOUNTER_ID, encounter_id)
	Engine.set_meta(META_SOURCE_NODE_ID, source_node_id)
	Engine.set_meta(META_SOURCE_SCENE, source_scene)
	Engine.set_meta(META_RETURN_AFTER_BATTLE, return_after_battle)
	Engine.set_meta(META_LAST_RESULT, last_result)
	Engine.set_meta(META_RESULT_READY, result_ready)
	Engine.set_meta(META_BATTLE_ID, battle_id)
	_write_player_meta()

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

static func _pull_meta() -> void:
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

static func _clear_battle_meta() -> void:
	for key in [META_ENCOUNTER_ID, META_SOURCE_NODE_ID, META_SOURCE_SCENE, META_RETURN_AFTER_BATTLE, META_LAST_RESULT, META_RESULT_READY, META_BATTLE_ID]:
		if Engine.has_meta(key): Engine.remove_meta(key)

static func _clear_player_meta() -> void:
	for key in [META_PLAYER_READY, META_PLAYER_ROLE, META_PLAYER_CAREER, META_PLAYER_WEAPON, META_PLAYER_MAX_HP, META_PLAYER_HP, META_PLAYER_MAX_POSTURE, META_PLAYER_POSTURE, META_PLAYER_MARTIAL_LEVEL, META_PLAYER_BATTLES_WON]:
		if Engine.has_meta(key): Engine.remove_meta(key)
