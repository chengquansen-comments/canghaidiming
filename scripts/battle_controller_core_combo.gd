extends "res://scripts/battle_controller_core_feedback.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _combo_chains_for_profession(profession_id: String) -> Array:
	return combo_registry.get(profession_id, [])

func _combo_for_starter(profession_id: String, starter_card_id: String) -> Dictionary:
	for combo in _combo_chains_for_profession(profession_id):
		if combo.get("starter_card_id", "") == starter_card_id:
			return combo
	return {}

func _combo_missing_cards(fighter: Fighter, combo: Dictionary) -> Array[String]:
	var owned := {}
	for card in fighter.get_session_deck():
		owned[card.id] = true
	var missing: Array[String] = []
	for required_id in combo.get("required_card_ids", PackedStringArray()):
		if not owned.has(required_id):
			missing.append(required_id)
	return missing

func _is_combo_unlocked(fighter: Fighter, combo: Dictionary) -> bool:
	return _combo_missing_cards(fighter, combo).is_empty()

func _get_triggerable_combo(fighter: Fighter, card: CardData) -> Dictionary:
	if fighter == null or card == null:
		return {}
	var combo := _combo_for_starter(fighter.data.id, card.id)
	if combo.is_empty():
		return {}
	if not _is_combo_unlocked(fighter, combo):
		return {}
	return combo

func _damage_stage_tag(card: CardData) -> String:
	if card.has_tag("终结"):
		return "终结"
	if card.has_tag("追击"):
		return "追击"
	if card.has_tag("起手"):
		return "起手"
	return ""

func _combo_marker_text(fighter: Fighter, card: CardData) -> String:
	var combo := _combo_for_starter(fighter.data.id, card.id)
	if combo.is_empty():
		return ""
	if fighter.combo_window_active:
		if _is_combo_unlocked(fighter, combo):
			return "【连招起手·可触发】%s" % combo.get("display_name", "")
		return "【连招起手·未解锁】%s" % combo.get("display_name", "")
	return "【连招起手】%s" % combo.get("display_name", "")

func _card_role_prefix(card: CardData) -> String:
	if card.is_guard_card():
		return "【守】"
	if card.is_feint_card():
		return "【变】"
	var stage := _damage_stage_tag(card)
	if stage != "":
		return "【攻/%s】" % stage
	return "【攻】"

func _card_restriction_reason(fighter: Fighter, card: CardData) -> String:
	if fighter == null or card.id == "idle":
		return ""
	if fighter.is_broken():
		return "崩势中本回合无法行动"
	return ""

func _can_play_card(fighter: Fighter, card: CardData) -> bool:
	if fighter == null:
		return false
	if card.momentum_cost > fighter.momentum:
		return false
	return _card_restriction_reason(fighter, card) == ""

func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines: Array[String] = []
	if actor == null or intent == null or intent.actual_card == null:
		return lines
	if not actor.combo_window_active:
		return lines
	var card: CardData = intent.actual_card
	if card.id == "staggered":
		return lines
	actor.consume_combo_window()
	var combo := _get_triggerable_combo(actor, card)
	if combo.is_empty():
		lines.append("[color=#7f8c8d]%s 未衔接到已解锁连招，本次连招窗口消散。[/color]" % actor.data.display_name)
		return lines
	var fx := _combo_feedback_profile(actor.data.id)
	_show_combat_banner(
		"%s：%s" % [fx.get("start_banner", "连招启动"), combo.get("display_name", "")],
		fx.get("start_fill", Color("3f2916")),
		fx.get("start_border", Color("ffd479"))
	)
	_impact_feedback(
		fx.get("start_flash", Color("ffd479")),
		float(fx.get("start_shake", 4.0)),
		bool(fx.get("start_horizontal_only", false)),
		bool(fx.get("start_extra_pulse", false))
	)
	_play_profession_shape_feedback(actor.data.id, fx.get("start_flash", Color("ffd479")), false, true)
	_flash_label(player_label if actor == player else enemy_label, fx.get("label_color", Color("ffe39c")))
	lines.append("[color=#ffd479][b]>>> %s · %s <<<[/b][/color]" % [fx.get("log_flair", "连招启动"), combo.get("display_name", "")])
	for idx in range(combo.get("followups", []).size()):
		if target.hp <= 0:
			break
		var segment: Dictionary = combo.get("followups", [])[idx]
		var segment_name: String = segment.get("name", "追击")
		var segment_type: String = segment.get("segment_type", "追击")
		var is_finisher := bool(segment.get("is_finisher", false))
		var effective_damage: int = int(segment.get("base_damage", 0))
		if target.is_broken():
			effective_damage *= 2
			lines.append("[color=#ff8c42]%s 处于崩势，%s伤害翻倍至 %d。[/color]" % [target.data.display_name, segment_name, effective_damage])
		var remaining_damage := target.absorb_damage(effective_damage)
		var blocked := effective_damage - remaining_damage
		var header := "[b][%d/%d][%s]%s[/%s][/b]" % [idx + 1, combo.get("followups", []).size(), segment_type, segment_name, segment_type]
		if blocked > 0:
			lines.append("%s 被格挡化去 %d。" % [segment_name, blocked])
		if remaining_damage > 0:
			target.hp = maxi(target.hp - remaining_damage, 0)
			if is_finisher:
				_impact_feedback(
					fx.get("finisher_flash", Color("ff4d6d")),
					float(fx.get("finisher_shake", 9.0)),
					bool(fx.get("finisher_horizontal_only", false)),
					bool(fx.get("finisher_extra_pulse", false))
				)
				_play_profession_shape_feedback(actor.data.id, fx.get("finisher_flash", Color("ff4d6d")), true, false)
				_show_target_receive_feedback(target, actor.data.id, fx.get("finisher_flash", Color("ff4d6d")), true)
			else:
				_impact_feedback(
					fx.get("segment_flash", Color("ffc7c7")),
					float(fx.get("segment_shake", 3.0)),
					bool(fx.get("segment_horizontal_only", false)),
					bool(fx.get("segment_extra_pulse", false))
				)
				_play_profession_shape_feedback(actor.data.id, fx.get("segment_flash", Color("ffc7c7")), false, false)
				_show_target_receive_feedback(target, actor.data.id, fx.get("segment_flash", Color("ffc7c7")), false)
			lines.append("%s %s 命中，造成 %d 伤害。%s。" % [header, actor.data.display_name, remaining_damage, fx.get("segment_flair", "气势压上")])
		else:
			lines.append("%s 被完全格挡。" % header)
			if is_finisher:
				_show_combat_banner(
					"%s：%s" % [fx.get("finisher_banner", "终结"), segment_name],
					fx.get("finisher_fill", Color("4a1626")),
					fx.get("finisher_border", Color("ff4d6d"))
				)
				_flash_label(enemy_label if target == enemy else player_label, fx.get("label_color", Color("ff7a7a")))
				lines.append("[color=#ff4d6d][b]!!! %s 以 %s 完成终结 · %s !!![/b][/color]" % [actor.data.display_name, segment_name, fx.get("log_flair", "")])
	return lines
