extends "res://scripts/battle_controller_visual_settlement_mode.gd"

# Auto-return layer for story battles.
# When either side reaches 0 HP, the current battle is considered settled and
# the scene returns to story encounter selection instead of staying on the
# battle screen.

var _returning_to_story_selection := false


func _refresh_ui() -> void:
	super()
	_try_auto_return_after_battle_result()


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
