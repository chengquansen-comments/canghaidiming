extends "res://scripts/battle_controller_visual_hot_tuning_sampler.gd"

# Extracted from battle_controller_visual_hot_tuning.gd.
# Layer responsibility: battle_controller_visual_hot_tuning_config.gd.

func _save_current_number_config() -> void:
	var config := _snapshot_number_config("手动方案 %02d" % _number_config_serial)
	_number_config_serial += 1
	_number_configs.append(config)
	_active_number_config_index = _number_configs.size() - 1
	_number_config_status = "已保存当前数值：%s" % str(config.get("name", "方案"))
	_save_number_configs()
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _sample_current_number_config(count: int) -> void:
	var result := _sample_active_or_current_number_config(count, int(Time.get_ticks_usec() % 1000000))
	_last_sample_report = AutoBattleSampler.format_report(result)
	if _active_number_config_index >= 0 and _active_number_config_index < _number_configs.size():
		_number_configs[_active_number_config_index]["sample"] = result
		_number_config_status = "已采样选中方案：%s" % str(_number_configs[_active_number_config_index].get("name", "方案"))
		_save_number_configs()
	else:
		_number_config_status = "已采样当前战斗"
	_refresh_tuning_panel()

func _generate_number_configs() -> void:
	if player == null or enemy == null:
		_number_config_status = "生成失败：尚未进入战斗"
		_refresh_tuning_panel()
		return
	var base := _snapshot_number_config("基准")
	var target := _selected_generation_target()
	var candidates: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	for i in range(12):
		var candidate := _mutate_number_config(base, rng, "%s方案 %02d" % [str(target.get("label", "目标")), _number_config_serial])
		var result := _sample_number_config(candidate, 60, 9000 + i)
		candidate["sample"] = result
		candidate["target"] = target.duplicate(true)
		candidate["score"] = _number_config_score(result, target)
		candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 999.0)) < float(b.get("score", 999.0))
	)
	var added := 0
	for candidate in candidates:
		if added >= 4:
			break
		_number_config_serial += 1
		_number_configs.append(candidate)
		added += 1
	_active_number_config_index = _number_configs.size() - added if added > 0 else _active_number_config_index
	var best: Dictionary = candidates[0] if not candidates.is_empty() else {}
	if best.is_empty():
		_number_config_status = "未生成有效方案"
	else:
		var sample: Dictionary = best.get("sample", {})
		_number_config_status = "目标[%s] 已生成%d个方案；最佳 %s：%s胜 %.1f%% / %s胜 %.1f%% / %.1f回合" % [
			str(target.get("label", "目标")),
			added,
			str(best.get("name", "")),
			_fighter_label(player, "玩家"),
			float(sample.get("player_win_rate", 0.0)) * 100.0,
			_fighter_label(enemy, "敌人"),
			float(sample.get("enemy_win_rate", 0.0)) * 100.0,
			float(sample.get("avg_turns", 0.0))
		]
	_save_number_configs()
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _selected_generation_target() -> Dictionary:
	var selected_id := _target_select.get_selected_id() if _target_select != null else 0
	match selected_id:
		1:
			return {"id": "easy", "label": "偏易", "player_win_rate": 0.72, "turn_target": 6.0, "draw_weight": 0.6}
		2:
			return {"id": "hard", "label": "偏难", "player_win_rate": 0.42, "turn_target": 7.0, "draw_weight": 0.6}
		3:
			return {"id": "long", "label": "持久", "player_win_rate": 0.55, "turn_target": 10.0, "draw_weight": 0.4}
		4:
			return {"id": "short", "label": "速战", "player_win_rate": 0.6, "turn_target": 4.5, "draw_weight": 0.8}
		_:
			return {"id": "balanced", "label": "均衡", "player_win_rate": 0.55, "turn_target": 7.0, "draw_weight": 0.5}

func _mutate_number_config(base: Dictionary, rng: RandomNumberGenerator, label: String) -> Dictionary:
	var candidate := base.duplicate(true)
	candidate["name"] = label
	var enemy_numbers: Dictionary = candidate.get("enemy", {})
	if not enemy_numbers.is_empty():
		enemy_numbers["max_hp"] = maxi(8, int(enemy_numbers.get("max_hp", 20)) + rng.randi_range(-6, 6))
		enemy_numbers["max_momentum"] = clampi(int(enemy_numbers.get("max_momentum", 10)) + rng.randi_range(-1, 1), 6, 14)
		enemy_numbers["momentum"] = clampi(int(enemy_numbers.get("momentum", 4)) + rng.randi_range(-2, 1), 0, int(enemy_numbers.get("max_momentum", 10)))
		enemy_numbers["realm"] = clampi(int(enemy_numbers.get("realm", 1)) + (1 if rng.randf() < 0.08 else 0), 1, 4)
		enemy_numbers["qinggong"] = clampi(int(enemy_numbers.get("qinggong", 1)) + rng.randi_range(-1, 1), 1, 4)
	var cards: Dictionary = candidate.get("cards", {})
	for card_id in cards.keys():
		if rng.randf() > 0.45:
			continue
		var card: Dictionary = cards[card_id]
		if int(card.get("damage", 0)) > 0:
			card["damage"] = maxi(1, int(card.get("damage", 0)) + rng.randi_range(-2, 2))
		if int(card.get("break_momentum", 0)) > 0:
			card["break_momentum"] = maxi(0, int(card.get("break_momentum", 0)) + rng.randi_range(-1, 1))
		if int(card.get("guard", 0)) > 0:
			card["guard"] = maxi(1, int(card.get("guard", 0)) + rng.randi_range(-2, 2))
		if rng.randf() < 0.08:
			card["momentum_cost"] = maxi(0, int(card.get("momentum_cost", 0)) + rng.randi_range(-1, 1))
	_mutate_deck_entries(candidate, rng, "enemy_deck")
	if rng.randf() < 0.22:
		_mutate_deck_entries(candidate, rng, "player_deck")
	candidate["diff"] = _number_config_diff(base, candidate)
	return candidate

func _on_number_config_selected(index: int) -> void:
	_active_number_config_index = index
	_refresh_tuning_panel()

func _apply_selected_number_config() -> void:
	if _active_number_config_index < 0 or _active_number_config_index >= _number_configs.size():
		return
	_apply_number_config(_number_configs[_active_number_config_index])
	_number_config_status = "已切换到：%s" % str(_number_configs[_active_number_config_index].get("name", "方案"))
	_refresh_tuning_panel()

func _delete_selected_number_config() -> void:
	if _active_number_config_index < 0 or _active_number_config_index >= _number_configs.size():
		return
	var removed := str(_number_configs[_active_number_config_index].get("name", "方案"))
	_number_configs.remove_at(_active_number_config_index)
	_active_number_config_index = mini(_active_number_config_index, _number_configs.size() - 1)
	_number_config_status = "已删除：%s" % removed
	_save_number_configs()
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _duplicate_selected_number_config() -> void:
	if _active_number_config_index < 0 or _active_number_config_index >= _number_configs.size():
		return
	var source: Dictionary = _number_configs[_active_number_config_index]
	var copy: Dictionary = source.duplicate(true)
	copy["id"] = _new_number_config_id()
	copy["name"] = "%s 副本%02d" % [str(source.get("name", "方案")), _number_config_serial]
	copy["created_msec"] = Time.get_ticks_msec()
	_number_config_serial += 1
	_number_configs.append(copy)
	_active_number_config_index = _number_configs.size() - 1
	_number_config_status = "已复制方案：%s" % str(copy.get("name", "方案"))
	_save_number_configs()
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _apply_number_config(config: Dictionary) -> void:
	_apply_fighter_deck(player, config.get("player_deck", []))
	_apply_fighter_deck(enemy, config.get("enemy_deck", []))
	_apply_fighter_numbers(player, config.get("player", {}))
	_apply_fighter_numbers(enemy, config.get("enemy", {}))
	var cards: Dictionary = config.get("cards", {})
	for runtime_card: CardData in _all_runtime_cards():
		if runtime_card != null and cards.has(runtime_card.id):
			_apply_card_numbers(runtime_card, cards[runtime_card.id])
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	if state_machine != null and player != null and enemy != null:
		state_machine.update_distance_from_positions(player, enemy)
	_refresh_hand_buttons()
	_refresh_effect_preview_panel()
	if has_method("_safe_refresh_runtime_ui"):
		call("_safe_refresh_runtime_ui")

func _apply_fighter_deck(fighter: Fighter, deck_entries: Array) -> void:
	if fighter == null or fighter.data == null or deck_entries.is_empty():
		return
	var old_hp := fighter.hp
	var old_momentum := fighter.momentum
	var old_realm := fighter.realm
	var old_qinggong := fighter.qinggong
	var old_position := fighter.position
	var old_facing := fighter.facing
	fighter.data.starting_deck = _cards_from_deck_entries(deck_entries, _export_cards(fighter))
	if fighter == player:
		fighter.set_battle_deck_limit(PLAYER_BATTLE_DECK_SIZE)
	else:
		fighter.set_battle_deck_limit(0)
	fighter.reset_battle_deck_to_default()
	fighter.reset_for_battle(HAND_SIZE)
	fighter.hp = clampi(old_hp, 1, fighter.data.max_hp)
	fighter.momentum = clampi(old_momentum, 0, fighter.data.max_momentum)
	fighter.session_realm = maxi(1, old_realm)
	fighter.realm = fighter.session_realm
	fighter.qinggong = maxi(1, old_qinggong)
	fighter.position = old_position
	fighter.facing = old_facing

func _apply_fighter_numbers(fighter: Fighter, numbers: Dictionary) -> void:
	if fighter == null or fighter.data == null or numbers.is_empty():
		return
	fighter.data.max_hp = maxi(1, int(numbers.get("max_hp", fighter.data.max_hp)))
	fighter.hp = clampi(int(numbers.get("hp", fighter.hp)), 1, fighter.data.max_hp)
	fighter.data.max_momentum = maxi(1, int(numbers.get("max_momentum", fighter.data.max_momentum)))
	fighter.momentum = clampi(int(numbers.get("momentum", fighter.momentum)), 0, fighter.data.max_momentum)
	fighter.data.starting_realm = maxi(1, int(numbers.get("realm", fighter.data.starting_realm)))
	fighter.session_realm = fighter.data.starting_realm
	fighter.realm = fighter.session_realm
	fighter.data.qinggong = maxi(1, int(numbers.get("qinggong", fighter.data.qinggong)))
	fighter.qinggong = fighter.data.qinggong

func _apply_card_numbers(card: CardData, numbers: Dictionary) -> void:
	if numbers.is_empty():
		return
	card.min_distance = clampi(int(numbers.get("min_distance", card.min_distance)), 0, 8)
	card.max_distance = clampi(int(numbers.get("max_distance", card.max_distance)), card.min_distance, 8)
	card.momentum_cost = maxi(0, int(numbers.get("momentum_cost", card.momentum_cost)))
	card.gain_momentum = maxi(0, int(numbers.get("gain_momentum", card.gain_momentum)))
	card.break_momentum = maxi(0, int(numbers.get("break_momentum", card.break_momentum)))
	card.damage = maxi(0, int(numbers.get("damage", card.damage)))
	card.guard = maxi(0, int(numbers.get("guard", card.guard)))
	card.self_move_after = clampi(int(numbers.get("self_move_after", card.self_move_after)), -1, 1)
	card.target_push_after = clampi(int(numbers.get("target_push_after", card.target_push_after)), 0, 1)
	card.target_pull_after = clampi(int(numbers.get("target_pull_after", card.target_pull_after)), 0, 1)
	card.move_condition = str(numbers.get("move_condition", card.move_condition))

func _refresh_number_config_select() -> void:
	if _number_config_select == null:
		return
	_number_config_select.clear()
	for i in range(_number_configs.size()):
		var config: Dictionary = _number_configs[i]
		var sample: Dictionary = config.get("sample", {})
		var suffix := ""
		if not sample.is_empty():
			suffix = "｜胜%.0f%% %.1f回合" % [float(sample.get("player_win_rate", 0.0)) * 100.0, float(sample.get("avg_turns", 0.0))]
		_number_config_select.add_item("%s%s" % [str(config.get("name", "方案%d" % i)), suffix], i)
	if _active_number_config_index >= 0 and _active_number_config_index < _number_configs.size():
		_number_config_select.select(_active_number_config_index)

func _mutate_deck_entries(config: Dictionary, rng: RandomNumberGenerator, deck_key: String) -> void:
	var deck_entries: Array = config.get(deck_key, [])
	if deck_entries.is_empty():
		return
	var catalog := _card_catalog_by_id()
	if rng.randf() < 0.35 and deck_entries.size() > 3:
		deck_entries.remove_at(rng.randi_range(0, deck_entries.size() - 1))
	if rng.randf() < 0.55 and deck_entries.size() < 8:
		var pool: Array[CardData] = []
		for card_id in catalog.keys():
			var card: CardData = catalog[card_id]
			if card != null:
				pool.append(card)
		if not pool.is_empty():
			var picked: CardData = pool[rng.randi_range(0, pool.size() - 1)]
			deck_entries.append({"card_id": picked.id, "name": picked.display_name, "numbers": _card_numbers(picked)})
	for i in range(deck_entries.size()):
		if rng.randf() > 0.24:
			continue
		var entry: Dictionary = deck_entries[i]
		var numbers: Dictionary = entry.get("numbers", {})
		if int(numbers.get("damage", 0)) > 0:
			numbers["damage"] = maxi(1, int(numbers.get("damage", 0)) + rng.randi_range(-1, 2))
		if int(numbers.get("break_momentum", 0)) > 0:
			numbers["break_momentum"] = maxi(0, int(numbers.get("break_momentum", 0)) + rng.randi_range(-1, 1))
		if int(numbers.get("guard", 0)) > 0:
			numbers["guard"] = maxi(1, int(numbers.get("guard", 0)) + rng.randi_range(-1, 2))
		if rng.randf() < 0.08:
			numbers["momentum_cost"] = maxi(0, int(numbers.get("momentum_cost", 0)) + rng.randi_range(-1, 1))
		entry["numbers"] = numbers
		deck_entries[i] = entry
	config[deck_key] = deck_entries
