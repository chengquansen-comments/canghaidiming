extends "res://scripts/battle_controller_visual_settlement_mode.gd"

# Story battle pressure-profile layer.
# Keeps parser-time dependencies local instead of relying on deep ancestor consts.

const StoryReturnNarrativeBattleContext := preload("res://scripts/narrative_battle_context.gd")
const BattleEffectApplierForStoryReturn := preload("res://scripts/battle_effect_applier.gd")
const PRESSURE_NONE := BattleEffectApplierForStoryReturn.PRESSURE_NONE
const PRESSURE_EDGE := BattleEffectApplierForStoryReturn.PRESSURE_EDGE
const PRESSURE_BREAK_RESIST := BattleEffectApplierForStoryReturn.PRESSURE_BREAK_RESIST

var _returning_to_story_selection := false
var _pressure_profile := PRESSURE_NONE
var _break_resist_available := false
var _last_edge_positions: Dictionary = {}
var _battle_reward_choices: Array[CardData] = []
var _selected_battle_reward_card_id := ""
var _battle_result_confirm_button: Button

func _apply_selected_story_battle_to_current_battle() -> void:
	super._apply_selected_story_battle_to_current_battle()
	_setup_pressure_profile_for_current_encounter()

func _apply_battle_loadout_once(loadout: Dictionary) -> void:
	super._apply_battle_loadout_once(loadout)
	_setup_pressure_profile_for_current_encounter()

func _refresh_ui() -> void:
	_apply_pressure_profile_runtime_rules()
	super()
	_try_auto_return_after_battle_result()
	_append_pressure_profile_to_status()

func _on_continue_narrative_pressed() -> void:
	if StoryReturnNarrativeBattleContext.has_request():
		super._on_continue_narrative_pressed()
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]返回战斗测试。[/color]")
	_show_combat_banner("返回战斗测试", Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false

func _setup_pressure_profile_for_current_encounter() -> void:
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_edge_positions = {}
	var encounter: Dictionary = {}
	if not _pending_story_battle.is_empty():
		encounter = _pending_story_battle.get("encounter", {}) as Dictionary
	elif not battle_loadout.is_empty():
		encounter = battle_loadout.get("encounter_config", {}) as Dictionary
	if encounter.is_empty():
		return
	_pressure_profile = str(encounter.get("pressure_profile", PRESSURE_NONE))
	if not BattleEffectApplierForStoryReturn.is_valid_pressure_profile(_pressure_profile):
		push_warning("Invalid pressure_profile, fallback to none: %s" % _pressure_profile)
		_pressure_profile = PRESSURE_NONE
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	if log_label != null and _pressure_profile != PRESSURE_NONE:
		log_label.append_text("\n[color=#ffd479]压力规则：%s[/color]" % _pressure_profile)

func _apply_pressure_profile_runtime_rules() -> void:
	if not battle_active:
		return
	if player == null or enemy == null or state_machine == null:
		return
	var context: Dictionary = {
		"break_resist_available": _break_resist_available,
		"last_edge_positions": _last_edge_positions
	}
	var result: Dictionary = BattleEffectApplierForStoryReturn.apply_pressure_profile(_pressure_profile, player, enemy, state_machine, context)
	_break_resist_available = bool(context.get("break_resist_available", _break_resist_available))
	var edge_positions_value: Variant = context.get("last_edge_positions", _last_edge_positions)
	if edge_positions_value is Dictionary:
		_last_edge_positions = edge_positions_value as Dictionary
	if not bool(result.get("applied", false)):
		return
	var events_value: Variant = result.get("events", [])
	if not (events_value is Array):
		return
	var events: Array = events_value as Array
	for i in range(events.size()):
		var event_value: Variant = events[i]
		if event_value is Dictionary:
			_log_pressure_event(event_value as Dictionary)

func _log_pressure_event(event: Dictionary) -> void:
	var event_type: String = str(event.get("type", ""))
	if event_type == PRESSURE_EDGE:
		if log_label != null:
			log_label.append_text("\n[color=#ffd479]边界压迫：%s被逼至%s，额外失1势。[/color]" % [str(event.get("label", "角色")), _slot_label_safe(int(event.get("position", 0)))])
	elif event_type == PRESSURE_BREAK_RESIST:
		if log_label != null:
			log_label.append_text("\n[color=#ffd479]稳势：对手强行稳住身形，本次崩势中断被抵消，势保留为1。[/color]")
		_show_combat_banner("稳势：崩势被抵消", Color("2a2018"), Color("ffd479"))

func _append_pressure_profile_to_status() -> void:
	if status_label == null:
		return
	if _pressure_profile == PRESSURE_NONE:
		return
	status_label.append_text("\n压力规则：%s" % _pressure_profile)

func _try_auto_return_after_battle_result() -> void:
	pass
