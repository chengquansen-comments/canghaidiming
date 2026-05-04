extends "res://scripts/battle_controller_visual_story_return_reward_untyped.gd"

# Story battle result confirmation and return flow layer with local parser-time context alias.

const StoryReturnFlowNarrativeContext := preload("res://scripts/narrative_battle_context.gd")

func _on_battle_result_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	var result_text: String = "战斗胜利"
	var result_key: String = "win"
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
	if StoryReturnFlowNarrativeContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.35).timeout
		var source_scene: String = StoryReturnFlowNarrativeContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		if result_key == "win" and not _selected_battle_reward_card_id.is_empty():
			StoryReturnFlowNarrativeContext.grant_player_cards([_selected_battle_reward_card_id])
		StoryReturnFlowNarrativeContext.set_result(result_key)
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
	var result_text: String = "战斗结束"
	var result_key: String = "draw"
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
	if StoryReturnFlowNarrativeContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.45).timeout
		var source_scene: String = StoryReturnFlowNarrativeContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		StoryReturnFlowNarrativeContext.set_result(result_key)
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
