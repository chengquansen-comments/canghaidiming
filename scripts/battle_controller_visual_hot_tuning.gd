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

func _build_hot_tuning_controls() -> void:
	if tuning_panel == null or tuning_label == null or _hot_controls_root != null:
		return
	tuning_label.custom_minimum_size = Vector2(360, 140)
	tuning_panel.offset_bottom = 480
	_hot_controls_root = VBoxContainer.new()
	tuning_panel.add_child(_hot_controls_root)
	_add_slider_row("伤害倍率", 0.5, 2.0, 0.05, damage_multiplier, _on_damage_multiplier_changed)
	_add_slider_row("削势倍率", 0.5, 2.0, 0.05, break_multiplier, _on_break_multiplier_changed)
	_add_slider_row("耗势修正", -1.0, 2.0, 1.0, float(cost_delta), _on_cost_delta_changed)
	_add_toggle_row("启用位移", movement_enabled, _on_movement_enabled_toggled)
	_add_sample_buttons()

func _add_sample_buttons() -> void:
	var row := HBoxContainer.new()
	var btn100 := Button.new()
	btn100.text = "采样100局"
	btn100.pressed.connect(func(): _run_sampling(100))
	var btn1000 := Button.new()
	btn1000.text = "采样1000局"
	btn1000.pressed.connect(func(): _run_sampling(1000))
	row.add_child(btn100)
	row.add_child(btn1000)
	_hot_controls_root.add_child(row)

func _run_sampling(count: int) -> void:
	var player_cards := _export_cards(player)
	var enemy_cards := _export_cards(enemy)
	var result := AutoBattleSampler.run_batch(player_cards, enemy_cards, {"sample_count": count})
	_last_sample_report = AutoBattleSampler.format_report(result)
	_refresh_tuning_panel()

func _export_cards(fighter) -> Array:
	var out := []
	if fighter == null:
		return out
	for card in fighter.hand:
		out.append(_card_to_dict(card))
	for card in fighter.draw_pile:
		out.append(_card_to_dict(card))
	return out

func _card_to_dict(card) -> Dictionary:
	return {
		"id": card.id,
		"damage": card.damage,
		"break_momentum": card.break_momentum,
		"gain_momentum": card.gain_momentum,
		"guard": card.guard,
		"min_distance": card.min_distance,
		"max_distance": card.max_distance,
		"self_move_after": card.self_move_after,
		"target_push_after": card.target_push_after,
		"target_pull_after": card.target_pull_after,
		"move_condition": card.move_condition
	}

func _refresh_tuning_panel() -> void:
	super()
	tuning_label.text += "\n[b]自动对局采样[/b]\n"
	tuning_label.text += _last_sample_report
