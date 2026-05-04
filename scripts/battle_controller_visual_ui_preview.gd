extends "res://scripts/battle_controller_visual_ui_hud.gd"

func _compact_effect_summary(card: CardData) -> String:
	return BattleHudHelper.compact_effect_summary(card)

func _compact_button_text(card: CardData, marker: String, reason: String) -> String:
	var text := BattleHudHelper.compact_button_text(card, _card_role_prefix(card), marker, _draft_uses_card(card))
	if reason != "":
		text += "\n限制：%s" % reason
	return text

func _card_detail_text(card: CardData) -> String:
	return BattleHudHelper.card_detail_text(card)

func _focused_card_for_detail() -> CardData:
	return BattleHudHelper.focused_card(draft_player_intent, player_intent)

func _refresh_card_detail_panel() -> void:
	if card_detail_label == null:
		return
	card_detail_label.add_theme_color_override("default_color", Color("2f2821"))
	var focused_card := _focused_card_for_detail()
	if focused_card == null:
		card_detail_label.text = BattleHudHelper.empty_detail_text()
		return
	card_detail_label.text = _card_detail_text(focused_card)

func _refresh_effect_preview_panel() -> void:
	if effect_preview_label == null:
		return
	effect_preview_label.text = _effect_preview_text()

func _effect_preview_text() -> String:
	if player == null or enemy == null or state_machine == null:
		return "[font_size=18][b]效果预览[/b][/font_size]\n等待战斗数据。"
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var player_card := _player_preview_card()
	var enemy_card := _enemy_preview_card()
	var preview_card := player_card
	var uses_wait := false
	if preview_card == null:
		preview_card = _preview_wait_card()
		uses_wait = true
	var player_target := _target_slot_for_preview(true, player_slot, enemy_slot, preview_card)
	var enemy_target_for_preview := _target_slot_for_preview(false, player_slot, enemy_slot, enemy_card)
	var player_range := _attack_range_slots(true, player_target, preview_card)
	var hits_enemy := player_range.has(enemy_target_for_preview)
	var damage := _preview_damage(preview_card, enemy, hits_enemy)
	var hp_after := maxi(enemy.hp - damage, 0)
	var self_momentum_after := clampi(player.momentum - preview_card.momentum_cost + (preview_card.gain_momentum if hits_enemy else 0), 0, player.data.max_momentum)
	var enemy_momentum_after := clampi(enemy.momentum - (preview_card.break_momentum if hits_enemy else 0), 0, enemy.data.max_momentum)
	var lines: Array[String] = []
	lines.append("[font_size=18][b]效果预览[/b][/font_size]")
	lines.append("当前：%s，距离 %d" % ["未选招，按不动预览" if uses_wait else preview_card.display_name, state_machine.current_distance])
	lines.append("我方位置：%s → %s" % [_slot_label(player_slot), _slot_label(player_target)])
	lines.append("影响格位：%s" % _slot_list_text(player_range))
	lines.append("预计命中：%s" % ("敌方" if hits_enemy and preview_card.requires_hit_check() else "无"))
	lines.append("预计伤害：%d" % damage)
	if preview_card.gain_momentum > 0 or preview_card.break_momentum > 0 or preview_card.momentum_cost > 0:
		lines.append("我方势：%d → %d" % [player.momentum, self_momentum_after])
		lines.append("敌方势：%d → %d" % [enemy.momentum, enemy_momentum_after])
	lines.append("敌方气血：%d/%d → %d/%d" % [enemy.hp, enemy.data.max_hp, hp_after, enemy.data.max_hp])
	if enemy_card != null:
		var enemy_target := enemy_target_for_preview
		var enemy_range := _attack_range_slots(false, enemy_target, enemy_card)
		var enemy_hits_player := enemy_range.has(player_target)
		var enemy_damage := _preview_damage(enemy_card, player, enemy_hits_player)
		var enemy_self_momentum_after := clampi(enemy.momentum - enemy_card.momentum_cost + (enemy_card.gain_momentum if enemy_hits_player else 0), 0, enemy.data.max_momentum)
		var player_momentum_after := clampi(player.momentum - (enemy_card.break_momentum if enemy_hits_player else 0), 0, player.data.max_momentum)
		var player_hp_after := maxi(player.hp - enemy_damage, 0)
		lines.append("")
		lines.append("[b]敌方可见意图[/b]：%s" % enemy_card.display_name)
		lines.append("敌方位置：%s → %s" % [_slot_label(enemy_slot), _slot_label(enemy_target)])
		lines.append("敌方影响格位：%s" % _slot_list_text(enemy_range))
		lines.append("敌方预计命中：%s" % ("我方" if enemy_hits_player and enemy_card.requires_hit_check() else "无"))
		lines.append("敌方预计伤害：%d" % enemy_damage)
		if enemy_card.gain_momentum > 0 or enemy_card.break_momentum > 0 or enemy_card.momentum_cost > 0:
			lines.append("敌方势：%d → %d" % [enemy.momentum, enemy_self_momentum_after])
			lines.append("我方势：%d → %d" % [player.momentum, player_momentum_after])
		lines.append("我方气血：%d/%d → %d/%d" % [player.hp, player.data.max_hp, player_hp_after, player.data.max_hp])
	return "\n".join(lines)

func _refresh_intent_bubbles(force: bool = false) -> void:
	_refresh_single_intent_bubble(true, force)
	_refresh_single_intent_bubble(false, force)

func _refresh_single_intent_bubble(is_player: bool, force: bool = false) -> void:
	var bubble := player_intent_bubble if is_player else enemy_intent_bubble
	var label := player_intent_bubble_label if is_player else enemy_intent_bubble_label
	if bubble == null or label == null:
		return
	if not battle_active:
		bubble.visible = false
		_set_intent_bubble_signature(is_player, "")
		return
	var card := _player_preview_card() if is_player else _enemy_preview_card()
	var positions := _current_grid_positions()
	var player_slot: int = positions.get("player", 0)
	var enemy_slot: int = positions.get("enemy", 0)
	var actor_slot := player_slot if is_player else enemy_slot
	var opponent_slot := enemy_slot if is_player else player_slot
	var target_slot := _target_slot_for_preview(is_player, player_slot, enemy_slot, card)
	var bubble_text := _intent_bubble_text(card, actor_slot, opponent_slot, target_slot)
	var signature := _intent_bubble_state_signature(is_player, card, actor_slot, opponent_slot, target_slot, bubble_text)
	if not force and signature == _intent_bubble_signature(is_player):
		_position_intent_bubble(is_player)
		return
	_set_intent_bubble_signature(is_player, signature)
	label.text = bubble_text
	bubble.size = bubble.custom_minimum_size
	bubble.visible = true
	_position_intent_bubble(is_player)

func _position_intent_bubble(is_player: bool) -> void:
	var bubble := player_intent_bubble if is_player else enemy_intent_bubble
	var sprite := player_sprite if is_player else enemy_sprite
	if bubble == null or sprite == null:
		return
	var foot_point := _actor_foot_point(is_player)
	var bubble_x := foot_point.x - bubble.size.x * 0.5
	var bubble_y := sprite.position.y - bubble.size.y - 12.0
	bubble.position = Vector2(
		clamp(bubble_x, 24.0, maxf(24.0, size.x - bubble.size.x - 24.0)),
		maxf(STAGE_AREA_TOP + 8.0, bubble_y)
	)

func _actor_foot_point(is_player: bool) -> Vector2:
	var sprite := player_sprite if is_player else enemy_sprite
	if sprite == null:
		return Vector2.ZERO
	return sprite.position + BattleActorFootHelper.frame_foot_offset(sprite)

func _intent_bubble_state_signature(is_player: bool, card: CardData, actor_slot: int, opponent_slot: int, target_slot: int, bubble_text: String) -> String:
	var card_id := card.id if card != null else "-"
	var bubble := player_intent_bubble if is_player else enemy_intent_bubble
	var bubble_width := int(round(bubble.custom_minimum_size.x)) if bubble != null else 0
	return "%s|%d|%d|%d|%s|%d|%d" % [
		card_id,
		actor_slot,
		opponent_slot,
		target_slot,
		bubble_text,
		bubble_width,
		int(round(size.x))
	]

func _intent_bubble_signature(is_player: bool) -> String:
	return _player_intent_bubble_signature if is_player else _enemy_intent_bubble_signature

func _set_intent_bubble_signature(is_player: bool, signature: String) -> void:
	if is_player:
		_player_intent_bubble_signature = signature
	else:
		_enemy_intent_bubble_signature = signature

func _intent_bubble_text(card: CardData, actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	if card == null:
		return "观察中"
	var parts: Array[String] = []
	parts.append(_intent_move_text(actor_slot, opponent_slot, target_slot))
	parts.append(card.display_name)
	parts.append_array(_intent_effect_parts(card))
	return "｜".join(parts)

func _intent_move_text(actor_slot: int, opponent_slot: int, target_slot: int) -> String:
	var delta := target_slot - actor_slot
	if delta == 0:
		return "原地"
	var facing_dir := signi(opponent_slot - actor_slot)
	if facing_dir == 0:
		return "原地"
	var steps := absi(delta)
	return "进%d" % steps if signi(delta) == facing_dir else "退%d" % steps

func _intent_effect_parts(card: CardData) -> Array[String]:
	var parts: Array[String] = []
	if card.guard > 0:
		parts.append("格挡%d" % card.guard)
	if card.gain_momentum > 0:
		parts.append("势+%d" % card.gain_momentum)
	if card.break_momentum > 0:
		parts.append("势-%d" % card.break_momentum)
	if card.damage > 0:
		parts.append("伤害%d" % card.damage)
	if parts.is_empty():
		parts.append("无效果")
	return parts
