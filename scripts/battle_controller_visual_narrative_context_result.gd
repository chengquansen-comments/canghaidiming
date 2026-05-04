extends "res://scripts/battle_controller_visual_narrative_context_apply.gd"

# Narrative context result layer.

func _update_battle_result_debug() -> void:
	if battle_result_label == null:
		return
	if enemy_config_strip != null:
		enemy_config_strip.text = _enemy_full_config_text()
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()
	if battle_mapping_label != null:
		battle_mapping_label.text = _mapping_debug_text()
	if enemy_config_label != null:
		enemy_config_label.text = _enemy_config_debug_text()
	if state_machine == null:
		_set_battle_result_debug_text("战斗结果：state_machine=null｜可点击返回剧情")
		return
	if player == null or enemy == null:
		_set_battle_result_debug_text("战斗结果：等待角色创建｜可点击返回剧情")
		return
	var hp_result_ready: bool = player.hp <= 0 or enemy.hp <= 0
	var phase_result_ready: bool = state_machine.phase == BattleStateMachineScript.BattlePhase.RESULT
	if not hp_result_ready and not phase_result_ready:
		_set_battle_result_debug_text("战斗结果：phase=%s｜player_hp=%d｜enemy_hp=%d｜未结算，可点击返回剧情" % [str(state_machine.phase), player.hp, enemy.hp])
		return
	var narrative_result: String = _get_narrative_result()
	_record_result_once(narrative_result)
	var result_state: String = "RESULT" if phase_result_ready else "HP_ZERO"
	_set_battle_result_debug_text("战斗结果：state=%s｜phase=%s｜player_hp=%d｜enemy_hp=%d｜narrative_result=%s" % [result_state, str(state_machine.phase), player.hp, enemy.hp, narrative_result])

func _record_result_once(narrative_result: String) -> void:
	if result_recorded:
		return
	if player != null and player.data != null:
		NarrativeBattleContext.set_player_card_state(_card_ids_from_cards(player.data.starting_deck), _card_ids_from_cards(player.get_selected_battle_deck()), _card_id_slots_from_fighter(player), player.get_active_battle_deck_index())
	NarrativeBattleContext.set_result(narrative_result)
	result_recorded = true
	if narrative_context_label != null:
		narrative_context_label.text = _context_debug_text()

func _on_continue_narrative_pressed() -> void:
	battle_active = false
	awaiting_player_input = false
	if state_machine != null:
		state_machine.phase = BattleStateMachineScript.BattlePhase.RESULT
	_set_battle_result_debug_text("战斗结果：debug 强制胜利，进入结算确认")
	_show_battle_result_overlay(true)

