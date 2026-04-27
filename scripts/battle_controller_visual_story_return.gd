extends "res://scripts/battle_controller_visual_settlement_mode.gd"

# Auto-return + pressure-profile layer for story battles.
#
# v0.4.3 pressure_profile supports:
# - none: no extra pressure rule.
# - edge_pressure: edge position causes extra momentum loss.
# - break_resist: opponent has one steady-posture charge; first pending break is reduced to 1 momentum and does not interrupt.

const PRESSURE_NONE := "none"
const PRESSURE_EDGE := "edge_pressure"
const PRESSURE_BREAK_RESIST := "break_resist"

var _returning_to_story_selection := false
var _pressure_profile := PRESSURE_NONE
var _break_resist_available := false
var _last_pressure_round := -1
var _last_edge_positions: Dictionary = {}


func _apply_selected_story_battle_to_current_battle() -> void:
	super._apply_selected_story_battle_to_current_battle()
	_setup_pressure_profile_for_current_encounter()


func _refresh_ui() -> void:
	_apply_pressure_profile_runtime_rules()
	super()
	_try_auto_return_after_battle_result()


func _setup_pressure_profile_for_current_encounter() -> void:
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_pressure_round = -1
	_last_edge_positions = {}
	if _pending_story_battle.is_empty():
		return
	var encounter: Dictionary = _pending_story_battle.get("encounter", {})
	_pressure_profile = str(encounter.get("pressure_profile", PRESSURE_NONE))
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	if log_label != null and _pressure_profile != PRESSURE_NONE:
		log_label.append_text("\n[color=#ffd479]压力规则：%s[/color]" % _pressure_profile)


func _apply_pressure_profile_runtime_rules() -> void:
	if not battle_active:
		return
	if player == null or enemy == null or state_machine == null:
		return
	match _pressure_profile:
		PRESSURE_EDGE:
			_apply_edge_pressure_once_per_position()
		PRESSURE_BREAK_RESIST:
			_apply_break_resist_once()
		_:
			return


func _apply_edge_pressure_once_per_position() -> void:
	# 9格轴边界：0位或8位。进入边界且当前回合/位置未惩罚过时，额外失1势。
	_apply_edge_pressure_to_fighter(player, "我方")
	_apply_edge_pressure_to_fighter(enemy, "对手")


func _apply_edge_pressure_to_fighter(fighter: Fighter, label: String) -> void:
	if fighter == null:
		return
	if fighter.position != 0 and fighter.position != BATTLE_SLOT_COUNT - 1:
		return
	var key := "%s_%d_%d" % [fighter.data.id, state_machine.round_index, fighter.position]
	if _last_edge_positions.has(key):
		return
	_last_edge_positions[key] = true
	if fighter.momentum <= 0:
		return
	fighter.momentum = maxi(fighter.momentum - 1, 0)
	if fighter.momentum == 0:
		fighter.queue_broken_state()
	if log_label != null:
		log_label.append_text("\n[color=#ffd479]边界压迫：%s被逼至%s，额外失1势。[/color]" % [label, _slot_label_safe(fighter.position)])


func _apply_break_resist_once() -> void:
	# 精英稳势：对手第一次被打到 pending 崩势时，保留1势并取消本次 pending break。
	if not _break_resist_available:
		return
	if enemy == null:
		return
	if enemy.pending_control_state != Fighter.CONTROL_BROKEN:
		return
	_break_resist_available = false
	enemy.pending_control_state = ""
	enemy.momentum = maxi(enemy.momentum, 1)
	if log_label != null:
		log_label.append_text("\n[color=#ffd479]稳势：对手强行稳住身形，本次崩势中断被抵消，势保留为1。[/color]")
	_show_combat_banner("稳势：崩势被抵消", Color("2a2018"), Color("ffd479"))


func _try_auto_return_after_battle_result() -> void:
	if _returning_to_story_selection:
		return
	if not battle_active:
		return
	if player == null or enemy == null:
		return
	if player.hp > 0 and enemy.hp > 0:
		return
	_returning_to_story_selection = true
	call_deferred("_return_to_story_encounter_selection_after_battle")


func _return_to_story_encounter_selection_after_battle() -> void:
	var result_text := "战斗结束"
	if player != null and enemy != null:
		if enemy.hp <= 0 and player.hp > 0:
			result_text = "战斗胜利"
		elif player.hp <= 0 and enemy.hp > 0:
			result_text = "战斗失败"
		else:
			result_text = "两败俱伤"
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
	_last_pressure_round = -1
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
