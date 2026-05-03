extends Node

const META_ENCOUNTER_ID := "canghai_narrative_encounter_id"
const META_SOURCE_NODE_ID := "canghai_narrative_source_node_id"
const META_SOURCE_SCENE := "canghai_narrative_source_scene"
const META_RETURN_AFTER_BATTLE := "canghai_narrative_return_after_battle"
const META_LAST_RESULT := "canghai_narrative_last_result"
const META_RESULT_READY := "canghai_narrative_result_ready"
const META_BATTLE_ID := "canghai_narrative_battle_id"
const META_OVERRIDE_PLAYER_PROFILE := "canghai_narrative_override_player_profile"
const META_BATTLE_OVERRIDES := "canghai_narrative_battle_overrides"
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
const META_PLAYER_QINGGONG := "canghai_player_qinggong"
const META_PLAYER_OWNED_CARD_IDS := "canghai_player_owned_card_ids"
const META_PLAYER_SELECTED_LOADOUT_IDS := "canghai_player_selected_loadout_ids"
const META_PLAYER_DECK_SLOTS := "canghai_player_deck_slots"
const META_PLAYER_ACTIVE_DECK_INDEX := "canghai_player_active_deck_index"
const META_NARRATIVE_STATE_READY := "canghai_narrative_state_ready"
const META_NARRATIVE_STATE := "canghai_narrative_state"

const PLAYER_INITIAL_HP := 20
const PLAYER_INITIAL_QINGGONG := 1
const PLAYER_INITIAL_MAX_POSTURE := 3
const PLAYER_INITIAL_MARTIAL_LEVEL := 1
const PLAYER_LOADOUT_SIZE := 8
const PLAYER_DECK_SLOT_COUNT := 4
const PLAYER_DECK_CARD_COPY_LIMIT := 2
const PLAYER_MAX_QINGGONG := 4
const PLAYER_MAX_POSTURE := 10

static var encounter_id := ""
static var source_node_id := ""
static var source_scene := "res://scenes/NarrativeDemo.tscn"
static var return_after_battle := false
static var last_result := ""
static var result_ready := false
static var battle_id := ""
static var override_player_profile := true
static var battle_overrides: Dictionary = {}
static var ui_debug_visible := false

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
static var player_qinggong := 1
static var player_owned_card_ids: Array[String] = []
static var player_selected_loadout_ids: Array[String] = []
static var player_deck_slots: Array = []
static var player_active_deck_index := 0
static var narrative_state_ready := false
static var narrative_state: Dictionary = {}
static var pending_debug_entry: Dictionary = {}

static func set_debug_entry_world_map() -> void:
	pending_debug_entry = {
		"mode": "world_map",
		"player_role": "spearman",
		"martial_level": 1,
	}

static func consume_debug_entry() -> Dictionary:
	var entry := pending_debug_entry.duplicate(true)
	pending_debug_entry.clear()
	return entry

static func has_debug_entry() -> bool:
	return not pending_debug_entry.is_empty()

static func set_request(p_encounter_id: String, p_source_node_id: String, p_battle_id: String = "", p_override_player_profile: bool = true) -> void:
	_pull_meta()
	encounter_id = p_encounter_id
	source_node_id = p_source_node_id
	source_scene = "res://scenes/NarrativeDemo.tscn"
	battle_id = p_battle_id if not p_battle_id.is_empty() else _battle_id_for_encounter(p_encounter_id, p_source_node_id)
	override_player_profile = p_override_player_profile
	battle_overrides.clear()
	return_after_battle = false
	last_result = ""
	result_ready = false
	_write_meta()

static func set_request_from_combat(combat: Dictionary, p_source_node_id: String) -> void:
	set_request(
		str(combat.get("encounter_id", "")),
		p_source_node_id,
		str(combat.get("battle_id", "")),
		bool(combat.get("override_player_profile", true))
	)
	battle_overrides = combat.duplicate(true)
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

static func should_override_player_profile() -> bool:
	_pull_meta()
	return override_player_profile

static func get_battle_overrides() -> Dictionary:
	_pull_meta()
	return battle_overrides.duplicate(true)

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
	override_player_profile = true
	battle_overrides.clear()
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
	player_qinggong = PLAYER_INITIAL_QINGGONG
	player_owned_card_ids.clear()
	player_selected_loadout_ids.clear()
	player_deck_slots.clear()
	player_active_deck_index = 0
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
	player_martial_level = max(PLAYER_INITIAL_MARTIAL_LEVEL, int(profile.get("martial_level", PLAYER_INITIAL_MARTIAL_LEVEL)))
	player_battles_won = int(profile.get("battles_won", 0))
	_apply_player_numbers_from_martial(true)
	if profile.has("owned_card_ids"):
		player_owned_card_ids = _string_array(profile.get("owned_card_ids", []))
	else:
		player_owned_card_ids = _default_owned_cards_for_role(player_role)
	if profile.has("selected_loadout_ids"):
		player_selected_loadout_ids = _string_array(profile.get("selected_loadout_ids", []))
	elif profile.has("loadout_card_ids"):
		player_selected_loadout_ids = _string_array(profile.get("loadout_card_ids", []))
	else:
		player_selected_loadout_ids = _default_loadout_for_role(player_role)
	if profile.has("deck_slots"):
		player_deck_slots = _deck_slots_from_variant(profile.get("deck_slots", []))
	else:
		player_deck_slots = _default_deck_slots_from_loadout(player_selected_loadout_ids)
	player_active_deck_index = clampi(int(profile.get("active_deck_index", 0)), 0, PLAYER_DECK_SLOT_COUNT - 1)
	_sanitize_player_card_state()
	_write_player_meta()

static func has_player_profile() -> bool:
	_pull_meta()
	return player_ready and not player_role.is_empty()

static func get_player_profile() -> Dictionary:
	_pull_meta()
	if not has_player_profile(): return {}
	_sanitize_player_card_state()
	return {"role": player_role, "career": player_career, "weapon": player_weapon, "max_hp": player_max_hp, "hp": player_hp, "max_posture": player_max_posture, "posture": player_posture, "martial_level": player_martial_level, "qinggong": player_qinggong, "battles_won": player_battles_won, "owned_card_ids": player_owned_card_ids.duplicate(), "selected_loadout_ids": player_selected_loadout_ids.duplicate(), "deck_slots": player_deck_slots.duplicate(true), "active_deck_index": player_active_deck_index, "loadout_size": PLAYER_LOADOUT_SIZE}

static func get_player_card_state() -> Dictionary:
	_pull_meta()
	_sanitize_player_card_state()
	return {"owned_card_ids": player_owned_card_ids.duplicate(), "selected_loadout_ids": player_selected_loadout_ids.duplicate(), "deck_slots": player_deck_slots.duplicate(true), "active_deck_index": player_active_deck_index, "loadout_size": PLAYER_LOADOUT_SIZE}

static func set_player_card_state(owned_card_ids: Array, selected_loadout_ids: Array = [], deck_slots: Array = [], active_deck_index: int = -1) -> void:
	_pull_meta()
	if not has_player_profile():
		return
	player_owned_card_ids = _string_array(owned_card_ids)
	player_selected_loadout_ids = _string_array(selected_loadout_ids)
	if not deck_slots.is_empty():
		player_deck_slots = _deck_slots_from_variant(deck_slots)
	elif not player_selected_loadout_ids.is_empty():
		player_deck_slots = _default_deck_slots_from_loadout(player_selected_loadout_ids)
	if active_deck_index >= 0:
		player_active_deck_index = clampi(active_deck_index, 0, PLAYER_DECK_SLOT_COUNT - 1)
	_sanitize_player_card_state()
	_write_player_meta()

static func set_player_selected_loadout(card_ids: Array) -> void:
	_pull_meta()
	if not has_player_profile():
		return
	player_selected_loadout_ids = _string_array(card_ids)
	if player_deck_slots.is_empty():
		player_deck_slots = _default_deck_slots_from_loadout(player_selected_loadout_ids)
	else:
		player_deck_slots[player_active_deck_index] = player_selected_loadout_ids.duplicate()
	_sanitize_player_card_state()
	_write_player_meta()

static func grant_player_cards(card_ids: Array) -> void:
	_pull_meta()
	if not has_player_profile():
		return
	for card_id: String in _string_array(card_ids):
		if not card_id.is_empty():
			player_owned_card_ids.append(card_id)
	_sanitize_player_card_state()
	_write_player_meta()

static func apply_player_growth(source: String, hp_gain: int = 0, posture_gain: int = 0, martial_gain: int = 0, heal_full: bool = false) -> void:
	_pull_meta()
	if not has_player_profile(): return
	var old_level := player_martial_level
	if source == "battle_win":
		player_battles_won += 1
		player_martial_level += 1
	else:
		player_martial_level += max(0, martial_gain)
	_apply_player_numbers_from_martial(heal_full or source == "battle_win")
	_grant_martial_rewards_between(old_level, player_martial_level)
	_write_player_meta()

static func _apply_player_numbers_from_martial(heal_full: bool) -> void:
	player_martial_level = max(PLAYER_INITIAL_MARTIAL_LEVEL, player_martial_level)
	player_max_hp = PLAYER_INITIAL_HP + max(0, player_martial_level - PLAYER_INITIAL_MARTIAL_LEVEL) * 2
	player_qinggong = clampi(PLAYER_INITIAL_QINGGONG + int(max(0, player_martial_level - PLAYER_INITIAL_MARTIAL_LEVEL) / 3), PLAYER_INITIAL_QINGGONG, PLAYER_MAX_QINGGONG)
	player_max_posture = clampi(PLAYER_INITIAL_MAX_POSTURE + max(0, player_martial_level - PLAYER_INITIAL_MARTIAL_LEVEL), PLAYER_INITIAL_MAX_POSTURE, PLAYER_MAX_POSTURE)
	if heal_full:
		player_hp = player_max_hp
		player_posture = player_max_posture
	else:
		player_hp = clampi(player_hp, 0, player_max_hp)
		player_posture = clampi(player_posture, 0, player_max_posture)

static func _grant_martial_rewards_between(old_level: int, new_level: int) -> void:
	for level in range(max(PLAYER_INITIAL_MARTIAL_LEVEL, old_level) + 1, max(old_level, new_level) + 1):
		for card_id: String in _martial_reward_cards_for_level(level):
			if not card_id.is_empty():
				player_owned_card_ids.append(card_id)
	_sanitize_player_card_state()

static func _martial_reward_cards_for_level(level: int) -> Array[String]:
	var rewards: Array[String] = []
	match player_role:
		"blademaster":
			match level:
				2: rewards.append("blade_press_break")
				3: rewards.append("blade_hook_pull")
				4: rewards.append("blade_body_press")
				5: rewards.append("reward_pull")
				6: rewards.append("reward_guard")
		_:
			match level:
				2: rewards.append("spear_retreat_sting")
				3: rewards.append("spear_step_thrust")
				4: rewards.append("reward_push")
				5: rewards.append("reward_guard")
				6: rewards.append("reward_pull")
	return rewards

static func _sanitize_player_card_state() -> void:
	player_owned_card_ids = _unique_string_array(player_owned_card_ids)
	if player_owned_card_ids.is_empty() and not player_role.is_empty():
		player_owned_card_ids = _default_owned_cards_for_role(player_role)
	if player_deck_slots.is_empty():
		player_deck_slots = _default_deck_slots_from_loadout(player_selected_loadout_ids)
	var sanitized_slots: Array = []
	for i in range(PLAYER_DECK_SLOT_COUNT):
		var source: Array[String] = _string_array(player_deck_slots[i]) if i < player_deck_slots.size() else []
		sanitized_slots.append(_sanitize_deck_slot(source))
	player_deck_slots = sanitized_slots
	player_active_deck_index = clampi(player_active_deck_index, 0, PLAYER_DECK_SLOT_COUNT - 1)
	player_selected_loadout_ids = (player_deck_slots[player_active_deck_index] as Array).duplicate()

static func _default_owned_cards_for_role(role_id: String) -> Array[String]:
	var cards: Array[String] = []
	if role_id == "blademaster":
		cards.append_array(["blade_front_cut", "blade_chase_cut", "blade_breathe", "blade_press_break"])
	else:
		cards.append_array(["spear_mid_thrust", "spear_line_press", "spear_focus", "spear_guard_horse"])
	return cards

static func _default_loadout_for_role(role_id: String) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in _default_owned_cards_for_role(role_id):
		result.append(card_id)
		result.append(card_id)
	return _first_card_ids(result, PLAYER_LOADOUT_SIZE)

static func _default_deck_slots_from_loadout(loadout: Array[String]) -> Array:
	var slots: Array = []
	slots.append(_sanitize_deck_slot(loadout))
	for _i in range(PLAYER_DECK_SLOT_COUNT - 1):
		slots.append([])
	return slots

static func _deck_slots_from_variant(value) -> Array:
	var slots: Array = []
	if value is Array:
		for slot_variant in value:
			slots.append(_string_array(slot_variant))
	return slots

static func _sanitize_deck_slot(card_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in card_ids:
		if result.size() >= PLAYER_LOADOUT_SIZE:
			break
		if not (card_id in player_owned_card_ids):
			continue
		if _card_id_count(result, card_id) >= PLAYER_DECK_CARD_COPY_LIMIT:
			continue
		result.append(card_id)
	return result

static func _first_card_ids(card_ids: Array[String], count: int) -> Array[String]:
	var result: Array[String] = []
	for card_id: String in card_ids:
		if result.size() >= count:
			break
		result.append(card_id)
	return result

static func _unique_string_array(value) -> Array[String]:
	var result: Array[String] = []
	for item: String in _string_array(value):
		if not (item in result):
			result.append(item)
	return result

static func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text := str(item)
			if not text.is_empty():
				result.append(text)
	elif value is String:
		var text := str(value)
		if not text.is_empty():
			result.append(text)
	return result

static func _card_id_count(cards: Array[String], card_id: String) -> int:
	var count := 0
	for item: String in cards:
		if item == card_id:
			count += 1
	return count

static func player_profile_debug_text() -> String:
	_pull_meta()
	if not has_player_profile(): return "玩家数据=未初始化"
	_sanitize_player_card_state()
	return "玩家数据=%s｜职业=%s｜武器=%s｜HP=%d/%d｜势=%d/%d｜轻功=%d｜武境=%d｜胜场=%d｜牌库=%d｜启用牌组=%d｜入战=%d/%d" % [player_role, player_career, player_weapon, player_hp, player_max_hp, player_posture, player_max_posture, player_qinggong, player_martial_level, player_battles_won, player_owned_card_ids.size(), player_active_deck_index + 1, player_selected_loadout_ids.size(), PLAYER_LOADOUT_SIZE]

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
	return "encounter_id=%s｜battle_id=%s｜enemy_source=%s｜source_node_id=%s｜override_player_profile=%s｜return_after_battle=%s｜last_result=%s｜%s" % [encounter_id, get_battle_id(), enemy_source_text(), source_node_id, str(override_player_profile), str(return_after_battle), last_result, player_profile_debug_text()]

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
	Engine.set_meta(META_OVERRIDE_PLAYER_PROFILE, override_player_profile)
	Engine.set_meta(META_BATTLE_OVERRIDES, battle_overrides.duplicate(true))
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
	Engine.set_meta(META_PLAYER_QINGGONG, player_qinggong)
	Engine.set_meta(META_PLAYER_OWNED_CARD_IDS, player_owned_card_ids.duplicate())
	Engine.set_meta(META_PLAYER_SELECTED_LOADOUT_IDS, player_selected_loadout_ids.duplicate())
	Engine.set_meta(META_PLAYER_DECK_SLOTS, player_deck_slots.duplicate(true))
	Engine.set_meta(META_PLAYER_ACTIVE_DECK_INDEX, player_active_deck_index)

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
	if Engine.has_meta(META_OVERRIDE_PLAYER_PROFILE): override_player_profile = bool(Engine.get_meta(META_OVERRIDE_PLAYER_PROFILE))
	if Engine.has_meta(META_BATTLE_OVERRIDES):
		var overrides_variant = Engine.get_meta(META_BATTLE_OVERRIDES)
		if overrides_variant is Dictionary:
			battle_overrides = (overrides_variant as Dictionary).duplicate(true)
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
	if Engine.has_meta(META_PLAYER_QINGGONG): player_qinggong = int(Engine.get_meta(META_PLAYER_QINGGONG))
	if Engine.has_meta(META_PLAYER_OWNED_CARD_IDS): player_owned_card_ids = _string_array(Engine.get_meta(META_PLAYER_OWNED_CARD_IDS))
	if Engine.has_meta(META_PLAYER_SELECTED_LOADOUT_IDS): player_selected_loadout_ids = _string_array(Engine.get_meta(META_PLAYER_SELECTED_LOADOUT_IDS))
	if Engine.has_meta(META_PLAYER_DECK_SLOTS): player_deck_slots = _deck_slots_from_variant(Engine.get_meta(META_PLAYER_DECK_SLOTS))
	if Engine.has_meta(META_PLAYER_ACTIVE_DECK_INDEX): player_active_deck_index = int(Engine.get_meta(META_PLAYER_ACTIVE_DECK_INDEX))
	if player_ready:
		_sanitize_player_card_state()
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
	for key in [META_ENCOUNTER_ID, META_SOURCE_NODE_ID, META_SOURCE_SCENE, META_RETURN_AFTER_BATTLE, META_LAST_RESULT, META_RESULT_READY, META_BATTLE_ID, META_OVERRIDE_PLAYER_PROFILE, META_BATTLE_OVERRIDES]:
		if Engine.has_meta(key): Engine.remove_meta(key)

static func _clear_player_meta() -> void:
	for key in [META_PLAYER_READY, META_PLAYER_ROLE, META_PLAYER_CAREER, META_PLAYER_WEAPON, META_PLAYER_MAX_HP, META_PLAYER_HP, META_PLAYER_MAX_POSTURE, META_PLAYER_POSTURE, META_PLAYER_MARTIAL_LEVEL, META_PLAYER_BATTLES_WON, META_PLAYER_QINGGONG, META_PLAYER_OWNED_CARD_IDS, META_PLAYER_SELECTED_LOADOUT_IDS, META_PLAYER_DECK_SLOTS, META_PLAYER_ACTIVE_DECK_INDEX]:
		if Engine.has_meta(key): Engine.remove_meta(key)

static func _clear_narrative_state_meta() -> void:
	for key in [META_NARRATIVE_STATE_READY, META_NARRATIVE_STATE]:
		if Engine.has_meta(key): Engine.remove_meta(key)
