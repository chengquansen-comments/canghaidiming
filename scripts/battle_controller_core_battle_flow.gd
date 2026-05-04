extends "res://scripts/battle_controller_core_result_overlay.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _start_battle() -> void:
	if player == null or enemy == null:
		return
	if not _player_battle_deck_ready():
		_log("入战牌组需要正好 %d 张，请先用【牌组】调整；开始战斗不会自动打开牌库。" % PLAYER_BATTLE_DECK_SIZE)
		return
	_hide_battle_result_overlay()
	battle_active = true
	battle_count += 1
	player.reset_for_battle(HAND_SIZE)
	enemy.reset_for_battle(HAND_SIZE)
	state_machine.begin_battle(absi(enemy.position - player.position))
	state_machine.update_distance_from_positions(player, enemy)
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	declaration_index = 0
	fusion_first_index = -1
	_log("[b]演武开始。[/b] 第 %d 场，对距固定从 2 开始。玩家会话武境 %d，敌方会话武境 %d。" % [battle_count, player.session_realm, enemy.session_realm])
	_show_node_buttons()
	_begin_round()

func _begin_round() -> void:
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	_reset_player_stance_draft()
	state_machine.update_distance_from_positions(player, enemy)
	if state_machine.round_index > 1:
		var player_gain := player.recover_momentum(ROUND_MOMENTUM_RECOVERY)
		var enemy_gain := enemy.recover_momentum(ROUND_MOMENTUM_RECOVERY)
		if player_gain > 0 or enemy_gain > 0:
			_log("[b]回合调息。[/b] 玩家 +%d 势，敌方 +%d 势。" % [player_gain, enemy_gain])
	if player.control_state != Fighter.CONTROL_NONE or enemy.control_state != Fighter.CONTROL_NONE or player.combo_window_active or enemy.combo_window_active:
		_log("[b]当前势态：[/b] %s" % state_machine.pressure_state_text(player, enemy))
	declaration_order = _battle_declaration_side_order()
	declaration_index = 0
	awaiting_player_input = false
	_update_phase_label()
	_advance_declaration()
	_refresh_ui()

func _battle_declaration_side_order() -> PackedStringArray:
	if state_machine.is_reactive_mode():
		return PackedStringArray([IntentData.SIDE_ENEMY, IntentData.SIDE_PLAYER])
	if player.is_broken() and not enemy.is_broken():
		return PackedStringArray([IntentData.SIDE_PLAYER, IntentData.SIDE_ENEMY])
	if enemy.is_broken() and not player.is_broken():
		return PackedStringArray([IntentData.SIDE_ENEMY, IntentData.SIDE_PLAYER])
	if player.realm < enemy.realm:
		return PackedStringArray([IntentData.SIDE_PLAYER, IntentData.SIDE_ENEMY])
	if player.realm > enemy.realm:
		return PackedStringArray([IntentData.SIDE_ENEMY, IntentData.SIDE_PLAYER])
	if state_machine.player_tie_advantage:
		return PackedStringArray([IntentData.SIDE_ENEMY, IntentData.SIDE_PLAYER])
	return PackedStringArray([IntentData.SIDE_PLAYER, IntentData.SIDE_ENEMY])

func _declaration_side_for_token(value: String) -> String:
	if value == IntentData.SIDE_PLAYER or (player != null and value == player.data.id and (enemy == null or value != enemy.data.id)):
		return IntentData.SIDE_PLAYER
	if value == IntentData.SIDE_ENEMY or (enemy != null and value == enemy.data.id and (player == null or value != player.data.id)):
		return IntentData.SIDE_ENEMY
	return IntentData.SIDE_NONE

func _tag_intent_side(intent: IntentData, side: String) -> IntentData:
	if intent != null:
		intent.set_actor_side(side)
	return intent

func _advance_declaration() -> void:
	if state_machine.is_reactive_mode():
		_advance_reactive_declaration()
		return
	_advance_symmetric_declaration()

func _advance_reactive_declaration() -> void:
	if enemy_intent == null:
		_declare_enemy_intent()
		if player.is_broken():
			_declare_player_stagger()
			awaiting_player_input = false
			declaration_index = declaration_order.size()
			if has_method("_resolve_round"):
				call("_resolve_round")
			return
		_enter_player_declaration()
		return
	if player_intent == null:
		if player.is_broken():
			_declare_player_stagger()
			awaiting_player_input = false
			declaration_index = declaration_order.size()
			if has_method("_resolve_round"):
				call("_resolve_round")
			return
		_enter_player_declaration()
		return
	awaiting_player_input = false
	declaration_index = declaration_order.size()
	if has_method("_resolve_round"):
		call("_resolve_round")

func _advance_symmetric_declaration() -> void:
	while declaration_index < declaration_order.size():
		var actor_side := _declaration_side_for_token(declaration_order[declaration_index])
		if actor_side == IntentData.SIDE_PLAYER:
			if player.is_broken():
				_declare_player_stagger()
				declaration_index += 1
				continue
			_enter_player_declaration()
			return
		if actor_side == IntentData.SIDE_ENEMY:
			if enemy.is_broken():
				_declare_enemy_stagger()
				declaration_index += 1
				continue
			_declare_enemy_intent()
			declaration_index += 1
			continue
		_log("[b]声明跳过：[/b] 无法识别行动方。")
		declaration_index += 1
	awaiting_player_input = false
	if has_method("_resolve_round"):
		call("_resolve_round")

func _declare_player_stagger() -> void:
	player_intent = _tag_intent_side(IntentData.from_card(player, _stagger_card(), IntentData.SIDE_PLAYER), IntentData.SIDE_PLAYER)
	_show_combat_banner("玩家崩势", Color("4a1f24"), Color("ff6b6b"))
	_impact_feedback(Color("ff6b6b"), 7.0)
	_flash_label(player_label, Color("ff9f9f"))
	_log("玩家崩势未稳，本回合无法行动。")

func _declare_enemy_stagger() -> void:
	enemy_intent = _tag_intent_side(IntentData.from_card(enemy, _stagger_card(), IntentData.SIDE_ENEMY), IntentData.SIDE_ENEMY)
	_show_combat_banner("敌方崩势", Color("4a1f24"), Color("ff6b6b"))
	_impact_feedback(Color("ff6b6b"), 7.0)
	_flash_label(enemy_label, Color("ff9f9f"))
	_log("敌方崩势未稳，本回合无法行动。")

func _declare_enemy_intent() -> void:
	var seen_intent: IntentData = player_intent if player_intent != null else null
	enemy_intent = _tag_intent_side(enemy_ai.choose_intent(enemy, player, state_machine.current_distance, seen_intent), IntentData.SIDE_ENEMY)
	if enemy_intent.actual_card.id != "idle" and enemy_intent.actual_card.id != "staggered":
		enemy.spend_momentum(enemy_intent.actual_card.momentum_cost)
	_log("敌方定招：%s。" % state_machine.get_visible_intent_text(enemy_intent, player))
	declaration_index = maxi(declaration_index, 1)

func _enter_player_declaration() -> void:
	awaiting_player_input = true
	declaration_index = maxi(declaration_index, 1)
	if has_method("_invalidate_stage_preview"):
		call("_invalidate_stage_preview")
	_refresh_hand_buttons()
	_refresh_ui()

func _reset_draft_intent() -> void:
	draft_player_intent = null
	_reset_player_stance_draft()
	_refresh_ui()

func _refresh_hand_buttons() -> void:
	pass

func _on_player_card_pressed(card: CardData) -> void:
	if not awaiting_player_input:
		return
	var reason := _card_restriction_reason(player, card)
	if reason != "":
		_log(reason)
		return
	if card.momentum_cost > player.momentum:
		_log("势不足，无法选用 %s。" % card.display_name)
		return
	draft_player_intent = IntentData.from_card(player, card, IntentData.SIDE_PLAYER)
	_apply_player_stance_draft_to_intent()
	var combo_marker := _combo_marker_text(player, card)
	if combo_marker != "":
		_log("已选定%s [color=#95e1d3]%s[/color]。%s" % [_card_role_prefix(card), card.display_name, combo_marker])
	else:
		_log("已选定%s [color=#95e1d3]%s[/color]，请确认出招。" % [_card_role_prefix(card), card.display_name])
	_refresh_ui()

func _confirm_player_intent() -> void:
	if not awaiting_player_input or draft_player_intent == null:
		return
	_apply_player_stance_draft_to_intent()
	if draft_player_intent.actual_card.id != "idle" and draft_player_intent.actual_card.id != "staggered" and not player.spend_momentum(draft_player_intent.actual_card.momentum_cost):
		_log("你的势不足，无法确认这招。")
		_refresh_ui()
		return
	player_intent = _tag_intent_side(draft_player_intent, IntentData.SIDE_PLAYER)
	draft_player_intent = null
	_finish_player_declaration()

func _finish_player_declaration() -> void:
	awaiting_player_input = false
	declaration_index += 1
	_log("玩家定招：%s。" % state_machine.get_visible_intent_text(player_intent, enemy))
	_advance_declaration()
	_refresh_ui()
