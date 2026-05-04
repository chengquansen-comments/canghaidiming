extends "res://scripts/battle_controller_visual_hot_tuning_profile.gd"

# Extracted sampler orchestration layer.

func _run_sampling(count: int) -> void:
	var result := _sample_active_or_current_number_config(count, int(Time.get_ticks_usec() % 1000000))
	_last_sample_report = AutoBattleSampler.format_report(result)
	_number_config_status = "当前战斗采样：%s胜 %.1f%% / %s胜 %.1f%% / 平 %.1f%% / %.1f回合" % [
		_fighter_label(player, "玩家"),
		float(result.get("player_win_rate", 0.0)) * 100.0,
		_fighter_label(enemy, "敌人"),
		float(result.get("enemy_win_rate", 0.0)) * 100.0,
		float(result.get("draw_rate", 0.0)) * 100.0,
		float(result.get("avg_turns", 0.0))
	]
	_refresh_tuning_panel()

func _export_cards(fighter: Fighter) -> Array[CardData]:
	var out: Array[CardData] = []
	if fighter == null:
		return out
	for hand_card: CardData in fighter.hand:
		if hand_card != null:
			out.append(hand_card)
	for draw_card: CardData in fighter.draw_pile:
		if draw_card != null:
			out.append(draw_card)
	for discard_card: CardData in fighter.discard_pile:
		if discard_card != null:
			out.append(discard_card)
	if out.is_empty() and fighter.data != null:
		for deck_card: CardData in fighter.data.starting_deck:
			if deck_card != null:
				out.append(deck_card)
	return out

func _sampler_options_for_current_state(sample_count: int) -> Dictionary:
	var p_style := _style_for_fighter(player, "spear")
	var e_style := _style_for_fighter(enemy, "blade")
	return {
		"sample_count": sample_count,
		"max_turns": 24,
		"player_label": _fighter_label(player, "玩家"),
		"enemy_label": _fighter_label(enemy, "敌人"),
		"player_state": _sampler_state(player, p_style, {"hp": 24, "max_momentum": 10, "momentum": 6, "realm": 1, "qinggong": 1, "position": 2, "facing": "right"}),
		"enemy_state": _sampler_state(enemy, e_style, {"hp": 22, "max_momentum": 10, "momentum": 6, "realm": 1, "qinggong": 1, "position": 6, "facing": "left"}),
		"player_preferred": _preferred_for_fighter(player, p_style),
		"enemy_preferred": _preferred_for_fighter(enemy, e_style)
	}

func _sampler_state(fighter: Fighter, style: String, fallback: Dictionary) -> Dictionary:
	if fighter == null or fighter.data == null:
		var empty := fallback.duplicate(true)
		empty["style"] = style
		return empty
	return {
		"hp": maxi(1, fighter.data.max_hp),
		"max_momentum": maxi(1, fighter.data.max_momentum),
		"momentum": clampi(fighter.momentum, 0, maxi(1, fighter.data.max_momentum)),
		"realm": maxi(1, fighter.realm),
		"qinggong": maxi(1, fighter.qinggong),
		"position": fighter.position,
		"facing": fighter.facing,
		"style": style
	}

func _sample_number_config(config: Dictionary, count: int, seed: int) -> Dictionary:
	var player_cards := _cards_from_config(config, _export_cards(player), "player")
	var enemy_cards := _cards_from_config(config, _export_cards(enemy), "enemy")
	var p_numbers: Dictionary = config.get("player", {})
	var e_numbers: Dictionary = config.get("enemy", {})
	return AutoBattleSampler.run_batch(player_cards, enemy_cards, {
		"sample_count": count,
		"seed": seed,
		"max_turns": 24,
		"settlement_mode": _current_sampler_settlement_mode(),
		"pressure_profile": _current_sampler_pressure_profile(),
		"player_label": _fighter_label(player, "玩家"),
		"enemy_label": _fighter_label(enemy, "敌人"),
		"player_state": _sampler_state_from_numbers(p_numbers, {"position": player.position if player != null else 2, "facing": "right"}),
		"enemy_state": _sampler_state_from_numbers(e_numbers, {"position": enemy.position if enemy != null else 6, "facing": "left"}),
		"player_preferred": p_numbers.get("preferred", [3, 4, 5]),
		"enemy_preferred": e_numbers.get("preferred", [0, 1, 2])
	})

func _current_sampler_settlement_mode() -> String:
	if state_machine != null and state_machine.has_method("settlement_mode_id"):
		return state_machine.settlement_mode_id()
	if get("settlement_mode_id") != null:
		return str(get("settlement_mode_id"))
	return "reactive"

func _current_sampler_pressure_profile() -> String:
	var value = get("_pressure_profile")
	return str(value) if value != null and str(value) != "" else "none"

func _sample_active_or_current_number_config(count: int, seed: int) -> Dictionary:
	if _active_number_config_index >= 0 and _active_number_config_index < _number_configs.size():
		return _sample_number_config(_number_configs[_active_number_config_index], count, seed)
	var config := _snapshot_number_config("当前战斗临时采样")
	return _sample_number_config(config, count, seed)
