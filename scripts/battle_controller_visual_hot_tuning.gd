extends "res://scripts/battle_controller_visual_tuning_panel.gd"

const AutoBattleSampler = preload("res://scripts/auto_battle_sampler.gd")

var hot_tuning_enabled := true
var damage_multiplier := 1.0
var break_multiplier := 1.0
var cost_delta := 0
var movement_enabled := true
var _card_base_values: Dictionary = {}
var _hot_controls_root: VBoxContainer
var _hot_tuning_dirty := false
var _last_sample_report := "未采样"

func _build_ui() -> void:
	super()
	_isolate_tuning_panel_input()
	_build_hot_tuning_controls()
	_capture_card_base_values()
	_apply_hot_tuning()
	_refresh_tuning_panel()

func _unhandled_input(event: InputEvent) -> void:
	# Debug input is isolated. Only F9 is handled globally; normal battle input is untouched.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			tuning_visible = not tuning_visible
			if tuning_panel != null:
				tuning_panel.visible = tuning_visible
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	super(delta)
	if _hot_tuning_dirty:
		_hot_tuning_dirty = false
		_apply_hot_tuning()
		_refresh_tuning_panel()

func _isolate_tuning_panel_input() -> void:
	if tuning_panel == null:
		return
	tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not tuning_panel.gui_input.is_connected(_on_tuning_panel_gui_input):
		tuning_panel.gui_input.connect(_on_tuning_panel_gui_input)

func _on_tuning_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()

func _build_hot_tuning_controls() -> void:
	if tuning_panel == null or tuning_label == null or _hot_controls_root != null:
		return
	tuning_label.custom_minimum_size = Vector2(360, 140)
	tuning_panel.offset_bottom = 560
	_hot_controls_root = VBoxContainer.new()
	_hot_controls_root.name = "HotTuningControls"
	_hot_controls_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_hot_controls_root.add_theme_constant_override("separation", 4)
	tuning_panel.add_child(_hot_controls_root)
	_add_slider_row("伤害倍率", 0.5, 2.0, 0.05, damage_multiplier, _on_damage_multiplier_changed)
	_add_slider_row("削势倍率", 0.5, 2.0, 0.05, break_multiplier, _on_break_multiplier_changed)
	_add_slider_row("耗势修正", -1.0, 2.0, 1.0, float(cost_delta), _on_cost_delta_changed)
	_add_toggle_row("启用位移", movement_enabled, _on_movement_enabled_toggled)
	_add_sample_buttons()

func _add_slider_row(label_text: String, min_value: float, max_value: float, step: float, value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(72, 22)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(190, 22)
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	var value_label := Label.new()
	value_label.text = _format_slider_value(value, step)
	value_label.custom_minimum_size = Vector2(54, 22)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _format_slider_value(v, step)
		callback.call(v)
	)
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	_hot_controls_root.add_child(row)

func _add_toggle_row(label_text: String, initial: bool, callback: Callable) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = initial
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	check.toggled.connect(func(v: bool) -> void:
		callback.call(v)
	)
	_hot_controls_root.add_child(check)

func _add_sample_buttons() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn100 := Button.new()
	btn100.text = "采样100局"
	btn100.mouse_filter = Control.MOUSE_FILTER_STOP
	btn100.pressed.connect(func(): _run_sampling(100))
	var btnSweep := Button.new()
	btnSweep.text = "参数扫描"
	btnSweep.mouse_filter = Control.MOUSE_FILTER_STOP
	btnSweep.pressed.connect(_run_sweep)
	var btnOptimize := Button.new()
	btnOptimize.text = "自动优化"
	btnOptimize.mouse_filter = Control.MOUSE_FILTER_STOP
	btnOptimize.pressed.connect(_run_auto_optimize)
	row.add_child(btn100)
	row.add_child(btnSweep)
	row.add_child(btnOptimize)
	_hot_controls_root.add_child(row)

func _format_slider_value(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(value)))
	return "%.2f" % value

func _on_damage_multiplier_changed(value: float) -> void:
	damage_multiplier = value
	_mark_hot_tuning_dirty()

func _on_break_multiplier_changed(value: float) -> void:
	break_multiplier = value
	_mark_hot_tuning_dirty()

func _on_cost_delta_changed(value: float) -> void:
	cost_delta = int(round(value))
	_mark_hot_tuning_dirty()

func _on_movement_enabled_toggled(value: bool) -> void:
	movement_enabled = value
	_mark_hot_tuning_dirty()

func _mark_hot_tuning_dirty() -> void:
	_hot_tuning_dirty = true

func _capture_card_base_values(force: bool = false) -> void:
	if not force and not _card_base_values.is_empty():
		return
	_card_base_values.clear()
	for card in _all_runtime_cards():
		if card == null:
			continue
		_card_base_values[card.id] = {
			"damage": card.damage,
			"break_momentum": card.break_momentum,
			"momentum_cost": card.momentum_cost,
			"self_move_after": card.self_move_after,
			"target_push_after": card.target_push_after,
			"target_pull_after": card.target_pull_after,
			"move_condition": card.move_condition
		}

func _all_runtime_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for key in fighter_catalog.keys():
		var data: FighterData = fighter_catalog[key]
		if data == null:
			continue
		for card in data.base_deck:
			if card != null:
				cards.append(card)
	for card in reward_pool:
		if card != null:
			cards.append(card)
	_collect_fighter_cards(player, cards)
	_collect_fighter_cards(enemy, cards)
	return cards

func _collect_fighter_cards(fighter: Fighter, cards: Array[CardData]) -> void:
	if fighter == null:
		return
	for card in fighter.hand:
		if card != null:
			cards.append(card)
	for card in fighter.draw_pile:
		if card != null:
			cards.append(card)
	for card in fighter.discard_pile:
		if card != null:
			cards.append(card)

func _apply_hot_tuning() -> void:
	_capture_card_base_values()
	for card in _all_runtime_cards():
		if card == null or not _card_base_values.has(card.id):
			continue
		var base: Dictionary = _card_base_values[card.id]
		card.damage = maxi(0, int(round(float(base.get("damage", 0)) * damage_multiplier)))
		card.break_momentum = maxi(0, int(round(float(base.get("break_momentum", 0)) * break_multiplier)))
		card.momentum_cost = maxi(0, int(base.get("momentum_cost", 0)) + cost_delta)
		if movement_enabled:
			card.self_move_after = int(base.get("self_move_after", 0))
			card.target_push_after = int(base.get("target_push_after", 0))
			card.target_pull_after = int(base.get("target_pull_after", 0))
			card.move_condition = str(base.get("move_condition", CardData.MOVE_NONE))
		else:
			card.self_move_after = 0
			card.target_push_after = 0
			card.target_pull_after = 0
			card.move_condition = CardData.MOVE_NONE
	_stage_grid_signature = ""
	_stage_actor_signature = ""
	_refresh_hand_buttons()
	_refresh_effect_preview_panel()

func _run_sampling(count: int) -> void:
	var player_cards := _export_cards(player)
	var enemy_cards := _export_cards(enemy)
	var result := AutoBattleSampler.run_batch(player_cards, enemy_cards, {"sample_count": count})
	_last_sample_report = AutoBattleSampler.format_report(result)
	_refresh_tuning_panel()

func _run_sweep() -> void:
	var player_cards := _export_cards(player)
	var enemy_cards := _export_cards(enemy)
	var sweep := AutoBattleSampler.run_parameter_sweep(player_cards, enemy_cards, {"samples_per_config": 40})
	_last_sample_report = AutoBattleSampler.format_sweep_report(sweep)
	_refresh_tuning_panel()

func _run_auto_optimize() -> void:
	var player_cards := _export_cards(player)
	var enemy_cards := _export_cards(enemy)
	var opt := AutoBattleSampler.run_auto_optimize(player_cards, enemy_cards, {"iterations": 4, "candidates_per_iter": 10, "samples_per_config": 40})
	_last_sample_report = AutoBattleSampler.format_optimize_report(opt)
	_refresh_tuning_panel()

func _export_cards(fighter) -> Array:
	var out := []
	if fighter == null:
		return out
	for card in fighter.hand:
		out.append(_card_to_dict(card))
	for card in fighter.draw_pile:
		out.append(_card_to_dict(card))
	for card in fighter.discard_pile:
		out.append(_card_to_dict(card))
	return out

func _card_to_dict(card) -> Dictionary:
	return {
		"id": card.id,
		"display_name": card.display_name,
		"momentum_cost": card.momentum_cost,
		"damage": card.damage,
		"break_momentum": card.break_momentum,
		"gain_momentum": card.gain_momentum,
		"guard": card.guard,
		"min_distance": card.min_distance,
		"max_distance": card.max_distance,
		"requires_facing": card.requires_facing,
		"requires_hit_check": card.requires_hit_check(),
		"tags": Array(card.tags),
		"self_move_after": card.self_move_after,
		"target_push_after": card.target_push_after,
		"target_pull_after": card.target_pull_after,
		"move_condition": card.move_condition
	}

func _refresh_tuning_panel() -> void:
	super()
	if tuning_label == null:
		return
	tuning_label.text += "\n[b]实时调参[/b]\n"
	tuning_label.text += "伤害倍率: %.2f / 削势倍率: %.2f / 耗势修正: %+d\n" % [damage_multiplier, break_multiplier, cost_delta]
	tuning_label.text += "位移: %s\n" % ("启用" if movement_enabled else "关闭")
	tuning_label.text += "\n[b]自动对局/参数扫描/优化[/b]\n"
	tuning_label.text += _last_sample_report
