extends Node

const BattleProfileBuilder := preload("res://scripts/narrative/battle_profile_builder.gd")
const BattleContextBridge := preload("res://scripts/narrative/battle_context_bridge.gd")
const BattleContextMetaStore := preload("res://scripts/narrative/battle_context_meta_store.gd")

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
	battle_id = p_battle_id if not p_battle_id.is_empty() else BattleContextBridge.battle_id_for_encounter(p_encounter_id, p_source_node_id)
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

static func get_battle_id() -> String:
	_pull_meta()
	if battle_id.is_empty():
		battle_id = BattleContextBridge.battle_id_for_encounter(encounter_id, source_node_id)
	return battle_id

static func should_override_player_profile() -> bool:
	_pull_meta()
	return override_player_profile

static func get_battle_overrides() -> Dictionary:
	_pull_meta()
	return battle_overrides.duplicate(true)

static func is_ui_debug_visible() -> bool:
	ui_debug_visible = BattleContextMetaStore.pull_ui_debug_visible(ui_debug_visible)
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
	if battle_id.is_empty():
		battle_id = BattleContextBridge.battle_id_for_encounter(encounter_id, source_node_id)
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
		player_owned_card_ids = BattleProfileBuilder.string_array(profile.get("owned_card_ids", []))
	else:
		player_owned_card_ids = BattleProfileBuilder.default_owned_cards_for_role(player_role)
	if profile.has("selected_loadout_ids"):
		player_selected_loadout_ids = BattleProfileBuilder.string_array(profile.get("selected_loadout_ids", []))
	elif profile.has("loadout_card_ids"):
		player_selected_loadout_ids = BattleProfileBuilder.string_array(profile.get("loadout_card_ids", []))
	else:
		player_selected_loadout_ids = BattleProfileBuilder.default_loadout_for_role(player_role, PLAYER_LOADOUT_SIZE)
	if profile.has("deck_slots"):
		player_deck_slots = BattleProfileBuilder.deck_slots_from_variant(profile.get("deck_slots", []))
	else:
		player_deck_slots = BattleProfileBuilder.default_deck_slots_from_loadout(player_selected_loadout_ids, PLAYER_DECK_SLOT_COUNT, PLAYER_LOADOUT_SIZE, PLAYER_DECK_CARD_COPY_LIMIT, player_owned_card_ids)
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
	player_owned_card_ids = BattleProfileBuilder.string_array(owned_card_ids)
	player_selected_loadout_ids = BattleProfileBuilder.string_array(selected_loadout_ids)
	if not deck_slots.is_empty():
		player_deck_slots = BattleProfileBuilder.deck_slots_from_variant(deck_slots)
	elif not player_selected_loadout_ids.is_empty():
		player_deck_slots = BattleProfileBuilder.default_deck_slots_from_loadout(player_selected_loadout_ids, PLAYER_DECK_SLOT_COUNT, PLAYER_LOADOUT_SIZE, PLAYER_DECK_CARD_COPY_LIMIT, player_owned_card_ids)
	if active_deck_index >= 0:
		player_active_deck_index = clampi(active_deck_index, 0, PLAYER_DECK_SLOT_COUNT - 1)
	_sanitize_player_card_state()
	_write_player_meta()

static func set_player_selected_loadout(card_ids: Array) -> void:
	_pull_meta()
	if not has_player_profile():
		return
	player_selected_loadout_ids = BattleProfileBuilder.string_array(card_ids)
	if player_deck_slots.is_empty():
		player_deck_slots = BattleProfileBuilder.default_deck_slots_from_loadout(player_selected_loadout_ids, PLAYER_DECK_SLOT_COUNT, PLAYER_LOADOUT_SIZE, PLAYER_DECK_CARD_COPY_LIMIT, player_owned_card_ids)
	else:
		player_deck_slots[player_active_deck_index] = player_selected_loadout_ids.duplicate()
	_sanitize_player_card_state()
	_write_player_meta()

static func grant_player_cards(card_ids: Array) -> void:
	_pull_meta()
	if not has_player_profile():
		return
	for card_id: String in BattleProfileBuilder.string_array(card_ids):
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
	var numbers := BattleProfileBuilder.build_player_numbers(
		player_martial_level,
		player_hp,
		player_posture,
		PLAYER_INITIAL_HP,
		PLAYER_INITIAL_MARTIAL_LEVEL,
		PLAYER_INITIAL_QINGGONG,
		PLAYER_MAX_QINGGONG,
		PLAYER_INITIAL_MAX_POSTURE,
		PLAYER_MAX_POSTURE,
		heal_full
	)
	player_martial_level = int(numbers.get("martial_level", player_martial_level))
	player_max_hp = int(numbers.get("max_hp", player_max_hp))
	player_hp = int(numbers.get("hp", player_hp))
	player_qinggong = int(numbers.get("qinggong", player_qinggong))
	player_max_posture = int(numbers.get("max_posture", player_max_posture))
	player_posture = int(numbers.get("posture", player_posture))

static func _grant_martial_rewards_between(old_level: int, new_level: int) -> void:
	player_owned_card_ids = BattleProfileBuilder.grant_martial_rewards_between(player_role, player_owned_card_ids, old_level, new_level, PLAYER_INITIAL_MARTIAL_LEVEL)
	_sanitize_player_card_state()

static func _sanitize_player_card_state() -> void:
	var sanitized := BattleProfileBuilder.sanitize_player_card_state(player_role, player_owned_card_ids, player_selected_loadout_ids, player_deck_slots, player_active_deck_index, PLAYER_LOADOUT_SIZE, PLAYER_DECK_SLOT_COUNT, PLAYER_DECK_CARD_COPY_LIMIT)
	player_owned_card_ids = sanitized.get("owned_card_ids", []).duplicate()
	player_selected_loadout_ids = sanitized.get("selected_loadout_ids", []).duplicate()
	player_deck_slots = sanitized.get("deck_slots", []).duplicate(true)
	player_active_deck_index = int(sanitized.get("active_deck_index", player_active_deck_index))

static func player_profile_debug_text() -> String:
	_pull_meta()
	if not has_player_profile(): return "玩家数据=未初始化"
	_sanitize_player_card_state()
	return BattleProfileBuilder.profile_debug_text(get_player_profile(), PLAYER_LOADOUT_SIZE)

static func has_request() -> bool:
	_pull_meta()
	return not encounter_id.is_empty()

static func has_result() -> bool:
	_pull_meta()
	return result_ready and not last_result.is_empty()

static func enemy_source_text() -> String:
	return BattleContextBridge.enemy_source_text(encounter_id, get_battle_id())

static func debug_text() -> String:
	_pull_meta()
	return BattleContextBridge.debug_text(encounter_id, get_battle_id(), source_node_id, override_player_profile, return_after_battle, last_result, player_profile_debug_text())

static func get_battle_mapping() -> Dictionary:
	_pull_meta()
	return BattleContextBridge.battle_mapping(encounter_id, get_battle_id(), get_player_profile() if has_player_profile() else {})

static func get_enemy_config() -> Dictionary:
	var mapping := get_battle_mapping()
	return mapping.get("enemy_config", {})

static func battle_mapping_debug_text() -> String:
	return BattleContextBridge.battle_mapping_debug_text(get_battle_mapping(), get_battle_id(), encounter_id, player_profile_debug_text())

static func enemy_config_debug_text() -> String:
	return BattleContextBridge.enemy_config_debug_text(get_enemy_config(), encounter_id, get_battle_id())

static func enemy_config_full_text() -> String:
	return BattleContextBridge.enemy_config_full_text(get_enemy_config(), encounter_id, get_battle_id(), player_profile_debug_text())

static func _write_meta() -> void:
	BattleContextMetaStore.write_battle_state({
		"encounter_id": encounter_id,
		"source_node_id": source_node_id,
		"source_scene": source_scene,
		"return_after_battle": return_after_battle,
		"last_result": last_result,
		"result_ready": result_ready,
		"battle_id": battle_id,
		"override_player_profile": override_player_profile,
		"battle_overrides": battle_overrides,
	})
	_write_ui_debug_meta()
	_write_player_meta()
	_write_narrative_state_meta()

static func _write_ui_debug_meta() -> void:
	BattleContextMetaStore.write_ui_debug_visible(ui_debug_visible)

static func _write_player_meta() -> void:
	BattleContextMetaStore.write_player_state({
		"player_ready": player_ready,
		"player_role": player_role,
		"player_career": player_career,
		"player_weapon": player_weapon,
		"player_max_hp": player_max_hp,
		"player_hp": player_hp,
		"player_max_posture": player_max_posture,
		"player_posture": player_posture,
		"player_martial_level": player_martial_level,
		"player_battles_won": player_battles_won,
		"player_qinggong": player_qinggong,
		"player_owned_card_ids": player_owned_card_ids.duplicate(),
		"player_selected_loadout_ids": player_selected_loadout_ids.duplicate(),
		"player_deck_slots": player_deck_slots.duplicate(true),
		"player_active_deck_index": player_active_deck_index,
	})

static func _write_narrative_state_meta() -> void:
	BattleContextMetaStore.write_narrative_state(narrative_state_ready, narrative_state)

static func _pull_meta() -> void:
	ui_debug_visible = BattleContextMetaStore.pull_ui_debug_visible(ui_debug_visible)
	var battle_values := BattleContextMetaStore.pull_battle_state()
	if battle_values.has("encounter_id"): encounter_id = str(battle_values["encounter_id"])
	if battle_values.has("source_node_id"): source_node_id = str(battle_values["source_node_id"])
	if battle_values.has("source_scene"): source_scene = str(battle_values["source_scene"])
	if battle_values.has("return_after_battle"): return_after_battle = bool(battle_values["return_after_battle"])
	if battle_values.has("last_result"): last_result = str(battle_values["last_result"])
	if battle_values.has("result_ready"): result_ready = bool(battle_values["result_ready"])
	if battle_values.has("battle_id"): battle_id = str(battle_values["battle_id"])
	if battle_values.has("override_player_profile"): override_player_profile = bool(battle_values["override_player_profile"])
	if battle_values.has("battle_overrides") and battle_values["battle_overrides"] is Dictionary:
		battle_overrides = (battle_values["battle_overrides"] as Dictionary).duplicate(true)
	var player_values := BattleContextMetaStore.pull_player_state()
	if player_values.has("player_ready"): player_ready = bool(player_values["player_ready"])
	if player_values.has("player_role"): player_role = str(player_values["player_role"])
	if player_values.has("player_career"): player_career = str(player_values["player_career"])
	if player_values.has("player_weapon"): player_weapon = str(player_values["player_weapon"])
	if player_values.has("player_max_hp"): player_max_hp = int(player_values["player_max_hp"])
	if player_values.has("player_hp"): player_hp = int(player_values["player_hp"])
	if player_values.has("player_max_posture"): player_max_posture = int(player_values["player_max_posture"])
	if player_values.has("player_posture"): player_posture = int(player_values["player_posture"])
	if player_values.has("player_martial_level"): player_martial_level = int(player_values["player_martial_level"])
	if player_values.has("player_battles_won"): player_battles_won = int(player_values["player_battles_won"])
	if player_values.has("player_qinggong"): player_qinggong = int(player_values["player_qinggong"])
	if player_values.has("player_owned_card_ids"): player_owned_card_ids = BattleProfileBuilder.string_array(player_values["player_owned_card_ids"])
	if player_values.has("player_selected_loadout_ids"): player_selected_loadout_ids = BattleProfileBuilder.string_array(player_values["player_selected_loadout_ids"])
	if player_values.has("player_deck_slots"): player_deck_slots = BattleProfileBuilder.deck_slots_from_variant(player_values["player_deck_slots"])
	if player_values.has("player_active_deck_index"): player_active_deck_index = int(player_values["player_active_deck_index"])
	if player_ready:
		_sanitize_player_card_state()
	var state_values := BattleContextMetaStore.pull_narrative_state()
	narrative_state_ready = bool(state_values.get("narrative_state_ready", false))
	narrative_state = (state_values.get("narrative_state", {}) as Dictionary).duplicate(true)

static func _clear_battle_meta() -> void:
	BattleContextMetaStore.clear_battle_state()

static func _clear_player_meta() -> void:
	BattleContextMetaStore.clear_player_state()

static func _clear_narrative_state_meta() -> void:
	BattleContextMetaStore.clear_narrative_state()
