extends RefCounted

const META_UI_DEBUG_VISIBLE := "canghai_ui_debug_visible"
const META_NARRATIVE_STATE_READY := "canghai_narrative_state_ready"
const META_NARRATIVE_STATE := "canghai_narrative_state"

const BATTLE_KEYS := {
	"encounter_id": "canghai_narrative_encounter_id",
	"source_node_id": "canghai_narrative_source_node_id",
	"source_scene": "canghai_narrative_source_scene",
	"return_after_battle": "canghai_narrative_return_after_battle",
	"last_result": "canghai_narrative_last_result",
	"result_ready": "canghai_narrative_result_ready",
	"battle_id": "canghai_narrative_battle_id",
	"override_player_profile": "canghai_narrative_override_player_profile",
	"battle_overrides": "canghai_narrative_battle_overrides",
}

const PLAYER_KEYS := {
	"player_ready": "canghai_player_ready",
	"player_role": "canghai_player_role",
	"player_career": "canghai_player_career",
	"player_weapon": "canghai_player_weapon",
	"player_max_hp": "canghai_player_max_hp",
	"player_hp": "canghai_player_hp",
	"player_max_posture": "canghai_player_max_posture",
	"player_posture": "canghai_player_posture",
	"player_martial_level": "canghai_player_martial_level",
	"player_battles_won": "canghai_player_battles_won",
	"player_qinggong": "canghai_player_qinggong",
	"player_owned_card_ids": "canghai_player_owned_card_ids",
	"player_selected_loadout_ids": "canghai_player_selected_loadout_ids",
	"player_deck_slots": "canghai_player_deck_slots",
	"player_active_deck_index": "canghai_player_active_deck_index",
}

const BATTLE_META_KEYS := [
	"canghai_narrative_encounter_id",
	"canghai_narrative_source_node_id",
	"canghai_narrative_source_scene",
	"canghai_narrative_return_after_battle",
	"canghai_narrative_last_result",
	"canghai_narrative_result_ready",
	"canghai_narrative_battle_id",
	"canghai_narrative_override_player_profile",
	"canghai_narrative_battle_overrides",
]

const PLAYER_META_KEYS := [
	"canghai_player_ready",
	"canghai_player_role",
	"canghai_player_career",
	"canghai_player_weapon",
	"canghai_player_max_hp",
	"canghai_player_hp",
	"canghai_player_max_posture",
	"canghai_player_posture",
	"canghai_player_martial_level",
	"canghai_player_battles_won",
	"canghai_player_qinggong",
	"canghai_player_owned_card_ids",
	"canghai_player_selected_loadout_ids",
	"canghai_player_deck_slots",
	"canghai_player_active_deck_index",
]

static func write_ui_debug_visible(visible: bool) -> void:
	Engine.set_meta(META_UI_DEBUG_VISIBLE, visible)

static func write_battle_state(values: Dictionary) -> void:
	_write_keys(BATTLE_KEYS, values)

static func write_player_state(values: Dictionary) -> void:
	_write_keys(PLAYER_KEYS, values)

static func write_narrative_state(ready: bool, state: Dictionary) -> void:
	Engine.set_meta(META_NARRATIVE_STATE_READY, ready)
	Engine.set_meta(META_NARRATIVE_STATE, state.duplicate(true))

static func pull_ui_debug_visible(fallback_visible: bool) -> bool:
	if Engine.has_meta(META_UI_DEBUG_VISIBLE):
		return bool(Engine.get_meta(META_UI_DEBUG_VISIBLE))
	write_ui_debug_visible(fallback_visible)
	return fallback_visible

static func pull_battle_state() -> Dictionary:
	return _pull_keys(BATTLE_KEYS)

static func pull_player_state() -> Dictionary:
	return _pull_keys(PLAYER_KEYS)

static func pull_narrative_state() -> Dictionary:
	var values := {
		"narrative_state_ready": false,
		"narrative_state": {},
	}
	if Engine.has_meta(META_NARRATIVE_STATE_READY):
		values["narrative_state_ready"] = bool(Engine.get_meta(META_NARRATIVE_STATE_READY))
	if Engine.has_meta(META_NARRATIVE_STATE):
		var state_variant = Engine.get_meta(META_NARRATIVE_STATE)
		if state_variant is Dictionary:
			values["narrative_state"] = (state_variant as Dictionary).duplicate(true)
	return values

static func clear_battle_state() -> void:
	_clear_keys(BATTLE_META_KEYS)

static func clear_player_state() -> void:
	_clear_keys(PLAYER_META_KEYS)

static func clear_narrative_state() -> void:
	_clear_keys([META_NARRATIVE_STATE_READY, META_NARRATIVE_STATE])

static func _write_keys(key_map: Dictionary, values: Dictionary) -> void:
	for key in key_map.keys():
		var value = values.get(key)
		if value is Dictionary:
			value = (value as Dictionary).duplicate(true)
		elif value is Array:
			value = (value as Array).duplicate(true)
		Engine.set_meta(str(key_map[key]), value)

static func _pull_keys(key_map: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for key in key_map.keys():
		var meta_key: String = str(key_map[key])
		if not Engine.has_meta(meta_key):
			continue
		var value = Engine.get_meta(meta_key)
		if value is Dictionary:
			value = (value as Dictionary).duplicate(true)
		elif value is Array:
			value = (value as Array).duplicate(true)
		values[key] = value
	return values

static func _clear_keys(meta_keys: Array) -> void:
	for key_variant in meta_keys:
		var key := str(key_variant)
		if Engine.has_meta(key):
			Engine.remove_meta(key)
