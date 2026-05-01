extends "res://scripts/battle_controller_visual_settlement_mode.gd"

# Auto-return + pressure-profile layer for story battles.
#
# v0.4.4 routes pressure_profile writes through BattleEffectApplier so this
# visual layer decides timing and displays feedback, but no longer directly
# mutates combat values for pressure rules.
#
# BattleEffectApplier is declared in the parent controller; do not redeclare it
# here, otherwise GDScript raises a member-name conflict in the inheritance chain.

const PRESSURE_NONE := BattleEffectApplier.PRESSURE_NONE
const PRESSURE_EDGE := BattleEffectApplier.PRESSURE_EDGE
const PRESSURE_BREAK_RESIST := BattleEffectApplier.PRESSURE_BREAK_RESIST

var _returning_to_story_selection := false
var _pressure_profile := PRESSURE_NONE
var _break_resist_available := false
var _last_edge_positions: Dictionary = {}


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
	if NarrativeBattleContext.has_request():
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
		encounter = _pending_story_battle.get("encounter", {})
	elif not battle_loadout.is_empty():
		encounter = battle_loadout.get("encounter_config", {})
	if encounter.is_empty():
		return
	_pressure_profile = str(encounter.get("pressure_profile", PRESSURE_NONE))
	if not BattleEffectApplier.is_valid_pressure_profile(_pressure_profile):
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
	var context := {
		"break_resist_available": _break_resist_available,
		"last_edge_positions": _last_edge_positions
	}
	var result: Dictionary = BattleEffectApplier.apply_pressure_profile(_pressure_profile, player, enemy, state_machine, context)
	_break_resist_available = bool(context.get("break_resist_available", _break_resist_available))
	_last_edge_positions = context.get("last_edge_positions", _last_edge_positions)
	if not bool(result.get("applied", false)):
		return
	for event in result.get("events", []):
		_log_pressure_event(event)


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


func _on_battle_result_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	var result_text := "战斗胜利"
	var result_key := "win"
	if player != null and enemy != null and player.hp <= 0 and enemy.hp <= 0:
		result_text = "两败俱伤"
		result_key = "draw"
	if _story_encounter_selected:
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
		_show_combat_banner("%s，返回战斗测试" % result_text, Color("1c2a36"), Color("8fd3ff"))
		_reset_story_battle_runtime_state()
		_show_story_encounter_selection()
		_returning_to_story_selection = false
		return
	if NarrativeBattleContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.35).timeout
		var source_scene: String = NarrativeBattleContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		NarrativeBattleContext.set_result(result_key)
		get_tree().change_scene_to_file(source_scene)
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
	_show_combat_banner("%s，返回地图" % result_text, Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _on_battle_retry_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	_returning_to_story_selection = false
	_reactive_pre_move_round = -1
	_reactive_pre_move_animation_round = -1
	_reactive_pre_move_animating = false
	_last_edge_positions = {}
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	_start_battle()


func _return_to_story_encounter_selection_after_battle() -> void:
	var result_text := "战斗结束"
	var result_key := "draw"
	if player != null and enemy != null:
		if enemy.hp <= 0 and player.hp > 0:
			result_text = "战斗胜利"
			result_key = "win"
		elif player.hp <= 0 and enemy.hp > 0:
			result_text = "战斗失败"
			result_key = "lose"
		else:
			result_text = "两败俱伤"
			result_key = "draw"
	while _presentation_busy():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.15).timeout
	if _story_encounter_selected:
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
		_show_combat_banner("%s，返回战斗测试" % result_text, Color("1c2a36"), Color("8fd3ff"))
		_reset_story_battle_runtime_state()
		_show_story_encounter_selection()
		_returning_to_story_selection = false
		return
	if NarrativeBattleContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.45).timeout
		var source_scene: String = NarrativeBattleContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		NarrativeBattleContext.set_result(result_key)
		get_tree().change_scene_to_file(source_scene)
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]%s，返回剧情遭遇选择。[/color]" % result_text)
	_show_combat_banner("%s，返回地图" % result_text, Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _reset_story_battle_runtime_state() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	_story_encounter_selected = false
	_reactive_pre_move_round = -1
	_pending_story_battle = {}
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_edge_positions = {}
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false
	declaration_order = PackedStringArray()
	declaration_index = 0
	fusion_first_index = -1
	state_machine.reset_for_session()
