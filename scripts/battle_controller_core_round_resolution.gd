extends "res://scripts/battle_controller_core_battle_flow.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _build_intent_feedback(actor: Fighter, target: Fighter, intent: IntentData, resolution_distance: int, target_hp_before: int, target_guard_before: int) -> Dictionary:
	var feedback := {
		"is_attack": false,
		"was_in_range": false,
		"connected": false,
		"blocked_only": false,
		"missed": false,
		"range_result": BattleStateMachine.RANGE_HIT,
		"hp_damage": 0,
		"guard_damage": 0
	}
	if actor == null or target == null or intent == null or intent.actual_card == null:
		return feedback
	var card: CardData = intent.actual_card
	if card.damage <= 0:
		return feedback
	var hp_damage := maxi(target_hp_before - target.hp, 0)
	var guard_damage := maxi(target_guard_before - target.guard_points, 0)
	var range_result := state_machine.evaluate_card_range(card, actor, target)
	var was_in_range := range_result == BattleStateMachine.RANGE_HIT or (CombatResolver.ENABLE_GRAZE and range_result == BattleStateMachine.RANGE_GRAZE)
	feedback["is_attack"] = true
	feedback["was_in_range"] = was_in_range
	feedback["connected"] = was_in_range and (hp_damage > 0 or guard_damage > 0)
	feedback["blocked_only"] = was_in_range and hp_damage == 0 and guard_damage > 0
	feedback["missed"] = not was_in_range
	feedback["range_result"] = range_result
	feedback["hp_damage"] = hp_damage
	feedback["guard_damage"] = guard_damage
	return feedback

func _on_intent_resolved(_actor: Fighter, _target: Fighter, _intent: IntentData, _feedback: Dictionary) -> void:
	pass

func _actor_for_intent(intent: IntentData) -> Fighter:
	if intent == null:
		return null
	if intent.actor_side == IntentData.SIDE_PLAYER:
		return player
	if intent.actor_side == IntentData.SIDE_ENEMY:
		return enemy
	if intent.source_fighter == player:
		return player
	if intent.source_fighter == enemy:
		return enemy
	if player != null and intent.actor_id == player.data.id:
		return player
	if enemy != null and intent.actor_id == enemy.data.id:
		return enemy
	return null

func _target_for_actor(actor: Fighter) -> Fighter:
	if actor == player:
		return enemy
	if actor == enemy:
		return player
	return null

func _resolve_round() -> void:
	state_machine.phase = BattleStateMachine.BattlePhase.RESOLUTION
	if not state_machine.is_reactive_mode():
		_apply_symmetric_declared_stances()
	var order: Array[IntentData] = state_machine.get_resolution_order(player, enemy, player_intent, enemy_intent)
	_log_declared_stances()
	_log("[b]结算顺序：[/b] %s -> %s" % [order[0].get_actual_name(), order[1].get_actual_name()])
	for intent in order:
		var actor := _actor_for_intent(intent)
		var target := _target_for_actor(actor)
		if actor == null or target == null:
			_log("[b]结算跳过：[/b] 无法识别行动方。")
			continue
		if actor.hp <= 0:
			break
		var resolution_distance := state_machine.update_distance_from_positions(player, enemy)
		var target_hp_before := target.hp
		var target_guard_before := target.guard_points
		var target_was_pending_broken := target.pending_control_state == Fighter.CONTROL_BROKEN
		var actor_action_canceled := state_machine.is_reactive_mode() and actor.pending_control_state == Fighter.CONTROL_BROKEN
		var lines := state_machine.resolve_intent(intent, actor, target)
		var feedback := _build_intent_feedback(actor, target, intent, resolution_distance, target_hp_before, target_guard_before)
		if not target_was_pending_broken and target.pending_control_state == Fighter.CONTROL_BROKEN:
			_show_combat_banner("崩势", Color("4a1f24"), Color("ff6b6b"))
			_impact_feedback(Color("ff6b6b"), 8.0)
			_flash_label(enemy_label if target == enemy else player_label, Color("ff8a8a"))
		for line in lines:
			_log(line)
		if not actor_action_canceled:
			_on_intent_resolved(actor, target, intent, feedback)
			var combo_lines := _resolve_combo_chain_if_any(actor, target, intent)
			for line in combo_lines:
				_log(line)
		_refresh_ui()
		if target.hp <= 0:
			break

	player.discard_cards(player_intent.get_consumed_cards())
	enemy.discard_cards(enemy_intent.get_consumed_cards())
	player.draw_to(HAND_SIZE)
	enemy.draw_to(HAND_SIZE)
	if player.hp <= 0 or enemy.hp <= 0:
		_finish_battle()
		return
	state_machine.finish_round(player, enemy)
	_log("[b]回合势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
	_begin_round()

func _log_declared_stances() -> void:
	var player_position: int = _intent_target_position_or_current(player, player_intent)
	var enemy_position: int = _intent_target_position_or_current(enemy, enemy_intent)
	var player_facing: String = _intent_target_facing_or_current(player, player_intent)
	var enemy_facing: String = _intent_target_facing_or_current(enemy, enemy_intent)
	_log("[b]身位宣告：[/b] 玩家 %d 朝%s，敌方 %d 朝%s，宣告距离 %d。" % [
		player_position,
		"左" if player_facing == "left" else "右",
		enemy_position,
		"左" if enemy_facing == "left" else "右",
		absi(enemy_position - player_position)
	])

func _apply_symmetric_declared_stances() -> void:
	_apply_intent_stance(player, player_intent)
	_apply_intent_stance(enemy, enemy_intent)
	state_machine.update_distance_from_positions(player, enemy)

func _apply_intent_stance(fighter: Fighter, intent: IntentData) -> void:
	if fighter == null or intent == null:
		return
	var target_position := _intent_target_position_or_current(fighter, intent)
	var target_facing := _intent_target_facing_or_current(fighter, intent)
	fighter.set_stance(target_position, target_facing)

func _intent_target_position_or_current(fighter: Fighter, intent: IntentData) -> int:
	if fighter == null:
		return 0
	if intent == null or intent.target_position < 0:
		return fighter.position
	return intent.target_position

func _intent_target_facing_or_current(fighter: Fighter, intent: IntentData) -> String:
	if fighter == null:
		return "right"
	if intent == null or intent.target_facing == "":
		return fighter.facing
	return intent.target_facing

func _finish_battle() -> void:
	battle_active = false
	awaiting_player_input = false
	state_machine.phase = BattleStateMachine.BattlePhase.RESULT
	completed_battle_count += 1
	_sync_player_realm_from_completed_battles()
	var result_text := "玩家落败。"
	if enemy.hp <= 0:
		result_text = "玩家获胜。"
	_show_combat_banner(
		result_text,
		Color("1f3f2a") if enemy.hp <= 0 else Color("4a1f24"),
		Color("8be28b") if enemy.hp <= 0 else Color("ff8a8a")
	)
	_impact_feedback(Color("8be28b") if enemy.hp <= 0 else Color("ff8a8a"), 5.0)
	_log("[b]演武结束。[/b] %s" % result_text)
	_show_node_buttons()
	_refresh_ui()
	_queue_battle_result_overlay(enemy.hp <= 0 and player.hp > 0)
