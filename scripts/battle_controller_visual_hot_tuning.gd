extends "res://scripts/battle_controller_visual_tuning_panel.gd"

const AutoBattleSampler = preload("res://scripts/auto_battle_sampler.gd")

var _hot_controls_root: VBoxContainer
var _last_sample_report := "未采样"
var _number_configs: Array[Dictionary] = []
var _active_number_config_index := -1
var _number_config_select: OptionButton
var _target_select: OptionButton
var _number_config_status := "未生成数值方案"
var _number_config_serial := 1

func _build_ui() -> void:
	super()
	_isolate_tuning_panel_input()
	_build_hot_tuning_controls()
	_refresh_tuning_panel()

func _unhandled_input(event: InputEvent) -> void:
	# F9 is handled in parent _input so it works even when panel controls have focus.
	# Keep this empty to avoid duplicate toggles.
	pass

func _isolate_tuning_panel_input() -> void:
	if tuning_panel == null:
		return
	tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if tuning_content_root != null:
		tuning_content_root.mouse_filter = Control.MOUSE_FILTER_STOP
	if tuning_label != null:
		tuning_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not tuning_panel.gui_input.is_connected(_on_tuning_panel_gui_input):
		tuning_panel.gui_input.connect(_on_tuning_panel_gui_input)

func _on_tuning_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()

func _build_hot_tuning_controls() -> void:
	if tuning_panel == null or tuning_label == null or _hot_controls_root != null:
		return
	var parent_container: VBoxContainer = tuning_content_root if tuning_content_root != null else null
	if parent_container == null:
		return
	tuning_label.custom_minimum_size = Vector2(392, 300)
	tuning_panel.offset_right = 452
	tuning_panel.offset_bottom = 640
	parent_container.custom_minimum_size = Vector2(412, 596)
	_hot_controls_root = VBoxContainer.new()
	_hot_controls_root.name = "HotTuningControls"
	_hot_controls_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_controls_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hot_controls_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hot_controls_root.add_theme_constant_override("separation", 4)
	parent_container.add_child(_hot_controls_root)
	_add_sample_buttons()
	_add_number_config_controls()

func _add_sample_buttons() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn100 := Button.new()
	btn100.text = "采样当前100局"
	btn100.mouse_filter = Control.MOUSE_FILTER_STOP
	btn100.pressed.connect(func(): _run_sampling(100))
	row.add_child(btn100)
	_hot_controls_root.add_child(row)

func _add_number_config_controls() -> void:
	var title := Label.new()
	title.text = "数值方案"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_controls_root.add_child(title)

	var target_row := HBoxContainer.new()
	target_row.mouse_filter = Control.MOUSE_FILTER_STOP
	target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target_label := Label.new()
	target_label.text = "目标"
	target_label.custom_minimum_size = Vector2(44, 24)
	target_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_select = OptionButton.new()
	_target_select.custom_minimum_size = Vector2(292, 24)
	_target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_select.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_select.add_item("均衡：接近五五开", 0)
	_target_select.add_item("偏易：玩家优势", 1)
	_target_select.add_item("偏难：敌人压迫", 2)
	_target_select.add_item("持久：更多回合", 3)
	_target_select.add_item("速战：更短回合", 4)
	target_row.add_child(target_label)
	target_row.add_child(_target_select)
	_hot_controls_root.add_child(target_row)

	var select_row := HBoxContainer.new()
	select_row.mouse_filter = Control.MOUSE_FILTER_STOP
	select_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_number_config_select = OptionButton.new()
	_number_config_select.custom_minimum_size = Vector2(236, 24)
	_number_config_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_number_config_select.mouse_filter = Control.MOUSE_FILTER_STOP
	_number_config_select.item_selected.connect(_on_number_config_selected)
	var apply_button := Button.new()
	apply_button.text = "切换"
	apply_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_button.pressed.connect(_apply_selected_number_config)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_button.pressed.connect(_delete_selected_number_config)
	select_row.add_child(_number_config_select)
	select_row.add_child(apply_button)
	select_row.add_child(delete_button)
	_hot_controls_root.add_child(select_row)

	var action_row := HBoxContainer.new()
	action_row.mouse_filter = Control.MOUSE_FILTER_STOP
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var capture_button := Button.new()
	capture_button.text = "保存当前"
	capture_button.mouse_filter = Control.MOUSE_FILTER_STOP
	capture_button.pressed.connect(_save_current_number_config)
	var sample_button := Button.new()
	sample_button.text = "采样当前"
	sample_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sample_button.pressed.connect(func(): _sample_current_number_config(120))
	var generate_button := Button.new()
	generate_button.text = "按目标生成"
	generate_button.mouse_filter = Control.MOUSE_FILTER_STOP
	generate_button.pressed.connect(_generate_number_configs)
	action_row.add_child(capture_button)
	action_row.add_child(sample_button)
	action_row.add_child(generate_button)
	_hot_controls_root.add_child(action_row)
	_refresh_number_config_select()

func _all_runtime_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for key in fighter_catalog.keys():
		var data: FighterData = fighter_catalog[key]
		if data == null:
			continue
		for deck_card: CardData in data.starting_deck:
			if deck_card != null:
				cards.append(deck_card)
	for reward_card: CardData in reward_pool:
		if reward_card != null:
			cards.append(reward_card)
	_collect_fighter_cards(player, cards)
	_collect_fighter_cards(enemy, cards)
	return cards

func _collect_fighter_cards(fighter: Fighter, cards: Array[CardData]) -> void:
	if fighter == null:
		return
	for hand_card: CardData in fighter.hand:
		if hand_card != null:
			cards.append(hand_card)
	for draw_card: CardData in fighter.draw_pile:
		if draw_card != null:
			cards.append(draw_card)
	for discard_card: CardData in fighter.discard_pile:
		if discard_card != null:
			cards.append(discard_card)

func _run_sampling(count: int) -> void:
	var player_cards: Array[CardData] = _export_cards(player)
	var enemy_cards: Array[CardData] = _export_cards(enemy)
	var result := AutoBattleSampler.run_batch(player_cards, enemy_cards, _sampler_options_for_current_state(count))
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

func _fighter_label(fighter: Fighter, fallback: String) -> String:
	if fighter != null and fighter.data != null and not fighter.data.display_name.is_empty():
		return fighter.data.display_name
	return fallback

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

func _style_for_fighter(fighter: Fighter, fallback: String) -> String:
	if fighter == null or fighter.data == null:
		return fallback
	var weapon := fighter.data.weapon_name
	if weapon.findn("枪") >= 0 or weapon.findn("spear") >= 0:
		return "spear"
	return "blade"

func _preferred_for_fighter(fighter: Fighter, style: String) -> Array:
	if fighter != null and fighter.data != null and fighter.data.preferred_distances.size() > 0:
		var out: Array[int] = []
		for distance in fighter.data.preferred_distances:
			out.append(int(distance))
		return out
	return [3, 4, 5] if style == "spear" else [0, 1, 2]

func _save_current_number_config() -> void:
	var config := _snapshot_number_config("手动方案 %02d" % _number_config_serial)
	_number_config_serial += 1
	_number_configs.append(config)
	_active_number_config_index = _number_configs.size() - 1
	_number_config_status = "已保存当前数值：%s" % str(config.get("name", "方案"))
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _sample_current_number_config(count: int) -> void:
	_run_sampling(count)

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

func _snapshot_number_config(label: String) -> Dictionary:
	return {
		"name": label,
		"player": _fighter_number_snapshot(player),
		"enemy": _fighter_number_snapshot(enemy),
		"cards": _card_number_snapshot(),
		"created_msec": Time.get_ticks_msec()
	}

func _fighter_number_snapshot(fighter: Fighter) -> Dictionary:
	if fighter == null or fighter.data == null:
		return {}
	return {
		"max_hp": fighter.data.max_hp,
		"hp": fighter.hp,
		"max_momentum": fighter.data.max_momentum,
		"momentum": fighter.momentum,
		"realm": fighter.realm,
		"qinggong": maxi(1, fighter.qinggong),
		"preferred": _preferred_for_fighter(fighter, _style_for_fighter(fighter, "spear")),
		"style": _style_for_fighter(fighter, "spear")
	}

func _card_number_snapshot() -> Dictionary:
	var result := {}
	for runtime_card: CardData in _all_runtime_cards():
		if runtime_card == null:
			continue
		result[runtime_card.id] = _card_numbers(runtime_card)
	return result

func _card_numbers(card: CardData) -> Dictionary:
	return {
		"min_distance": card.min_distance,
		"max_distance": card.max_distance,
		"momentum_cost": card.momentum_cost,
		"gain_momentum": card.gain_momentum,
		"break_momentum": card.break_momentum,
		"damage": card.damage,
		"guard": card.guard,
		"self_move_after": card.self_move_after,
		"target_push_after": card.target_push_after,
		"target_pull_after": card.target_pull_after,
		"move_condition": card.move_condition
	}

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
	candidate["diff"] = _number_config_diff(base, candidate)
	return candidate

func _sample_number_config(config: Dictionary, count: int, seed: int) -> Dictionary:
	var player_cards := _cards_from_config(config, _export_cards(player))
	var enemy_cards := _cards_from_config(config, _export_cards(enemy))
	var p_numbers: Dictionary = config.get("player", {})
	var e_numbers: Dictionary = config.get("enemy", {})
	return AutoBattleSampler.run_batch(player_cards, enemy_cards, {
		"sample_count": count,
		"seed": seed,
		"max_turns": 24,
		"player_label": _fighter_label(player, "玩家"),
		"enemy_label": _fighter_label(enemy, "敌人"),
		"player_state": _sampler_state_from_numbers(p_numbers, {"position": player.position if player != null else 2, "facing": "right"}),
		"enemy_state": _sampler_state_from_numbers(e_numbers, {"position": enemy.position if enemy != null else 6, "facing": "left"}),
		"player_preferred": p_numbers.get("preferred", [3, 4, 5]),
		"enemy_preferred": e_numbers.get("preferred", [0, 1, 2])
	})

func _cards_from_config(config: Dictionary, source_cards: Array[CardData]) -> Array[CardData]:
	var cards: Array[CardData] = []
	var card_numbers: Dictionary = config.get("cards", {})
	for source: CardData in source_cards:
		if source == null:
			continue
		var copy := source.duplicate_card()
		if card_numbers.has(copy.id):
			_apply_card_numbers(copy, card_numbers[copy.id])
		cards.append(copy)
	return cards

func _sampler_state_from_numbers(numbers: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"hp": int(numbers.get("max_hp", 24)),
		"max_momentum": int(numbers.get("max_momentum", 10)),
		"momentum": int(numbers.get("momentum", 6)),
		"realm": int(numbers.get("realm", 1)),
		"qinggong": maxi(1, int(numbers.get("qinggong", 1))),
		"position": int(fallback.get("position", 2)),
		"facing": str(fallback.get("facing", "right")),
		"style": str(numbers.get("style", "spear"))
	}

func _number_config_score(result: Dictionary, target: Dictionary) -> float:
	var target_win := float(target.get("player_win_rate", 0.55))
	var turn_target := float(target.get("turn_target", 7.0))
	var draw_weight := float(target.get("draw_weight", 0.5))
	return abs(float(result.get("player_win_rate", 0.0)) - target_win) * 3.0 + abs(float(result.get("avg_turns", 0.0)) - turn_target) / 10.0 + float(result.get("draw_rate", 0.0)) * draw_weight

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
	_refresh_number_config_select()
	_refresh_tuning_panel()

func _apply_number_config(config: Dictionary) -> void:
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

func _number_config_diff(base: Dictionary, candidate: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var base_enemy: Dictionary = base.get("enemy", {})
	var next_enemy: Dictionary = candidate.get("enemy", {})
	for field in ["max_hp", "max_momentum", "momentum", "realm", "qinggong"]:
		if int(base_enemy.get(field, 0)) != int(next_enemy.get(field, 0)):
			lines.append("敌%s %d→%d" % [field, int(base_enemy.get(field, 0)), int(next_enemy.get(field, 0))])
	var base_cards: Dictionary = base.get("cards", {})
	var next_cards: Dictionary = candidate.get("cards", {})
	for card_id in next_cards.keys():
		if not base_cards.has(card_id):
			continue
		var b: Dictionary = base_cards[card_id]
		var n: Dictionary = next_cards[card_id]
		var parts: Array[String] = []
		for field in ["momentum_cost", "gain_momentum", "break_momentum", "damage", "guard", "min_distance", "max_distance"]:
			if int(b.get(field, 0)) != int(n.get(field, 0)):
				parts.append("%s %d→%d" % [field, int(b.get(field, 0)), int(n.get(field, 0))])
		if not parts.is_empty():
			lines.append("%s: %s" % [card_id, ", ".join(parts)])
	return lines

func _refresh_number_config_select() -> void:
	if _number_config_select == null:
		return
	_number_config_select.clear()
	for i in range(_number_configs.size()):
		var config: Dictionary = _number_configs[i]
		_number_config_select.add_item(str(config.get("name", "方案%d" % i)), i)
	if _active_number_config_index >= 0 and _active_number_config_index < _number_configs.size():
		_number_config_select.select(_active_number_config_index)

func _refresh_tuning_panel() -> void:
	super()
	if tuning_label == null:
		return
	tuning_label.text += "\n[b]实时调参[/b]\n"
	tuning_label.text += "当前目标: %s\n" % str(_selected_generation_target().get("label", "均衡"))
	tuning_label.text += "\n[b]战斗采样[/b]\n"
	tuning_label.text += _format_sampler_binding()
	tuning_label.text += _last_sample_report
	tuning_label.text += "\n\n[b]数值方案[/b]\n"
	tuning_label.text += _number_config_status + "\n"
	tuning_label.text += _format_active_number_config()

func _format_active_number_config() -> String:
	if _active_number_config_index < 0 or _active_number_config_index >= _number_configs.size():
		return "当前未选中方案\n"
	var config: Dictionary = _number_configs[_active_number_config_index]
	var sample: Dictionary = config.get("sample", {})
	var lines: Array[String] = []
	lines.append("选中：%s" % str(config.get("name", "方案")))
	var target: Dictionary = config.get("target", {})
	if not target.is_empty():
		lines.append("目标：%s  胜率%.0f%%  回合%.1f" % [str(target.get("label", "目标")), float(target.get("player_win_rate", 0.0)) * 100.0, float(target.get("turn_target", 0.0))])
	if not sample.is_empty():
		lines.append("采样：%s胜 %.1f%% / %s胜 %.1f%% / 平 %.1f%% / %.1f回合" % [
			_fighter_label(player, "玩家"),
			float(sample.get("player_win_rate", 0.0)) * 100.0,
			_fighter_label(enemy, "敌人"),
			float(sample.get("enemy_win_rate", 0.0)) * 100.0,
			float(sample.get("draw_rate", 0.0)) * 100.0,
			float(sample.get("avg_turns", 0.0))
		])
	var diff: Array = config.get("diff", [])
	if diff.is_empty():
		lines.append("改动：无")
	else:
		lines.append("改动：%s" % "；".join(diff.slice(0, 5)))
	return "\n".join(lines) + "\n"

func _format_sampler_binding() -> String:
	if player == null or enemy == null or player.data == null or enemy.data == null:
		return "采样绑定：未进入当前战斗\n"
	return "采样绑定：%s HP%d 势%d/%d 武境%d 轻功%d 牌%d  vs  %s HP%d 势%d/%d 武境%d 轻功%d 牌%d\n" % [
		_fighter_label(player, "玩家"),
		player.data.max_hp,
		player.momentum,
		player.data.max_momentum,
		player.realm,
		maxi(1, player.qinggong),
		_export_cards(player).size(),
		_fighter_label(enemy, "敌人"),
		enemy.data.max_hp,
		enemy.momentum,
		enemy.data.max_momentum,
		enemy.realm,
		maxi(1, enemy.qinggong),
		_export_cards(enemy).size()
	]
