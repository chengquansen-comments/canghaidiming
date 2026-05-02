extends "res://scripts/battle_controller_visual_scene_manifest.gd"

# Lightweight battle presentation layer.
# This wrapper does not resolve damage or change battle rules. It only consumes
# the already selected player/enemy intents and plays Tween-based feedback:
# lunge, attack FX, hit reaction, floating text, death fade, committed slot settling,
# resolver-preview result text, and timing polish.

const PRESENTATION_BUSY_META := &"battle_presentation_busy"
const PLAYER_OFFSET_META := &"player_presentation_offset"
const ENEMY_OFFSET_META := &"enemy_presentation_offset"
const PRESENTATION_OLD_PLAYER_SLOT_META := &"battle_presentation_old_player_slot"
const PRESENTATION_OLD_ENEMY_SLOT_META := &"battle_presentation_old_enemy_slot"
const PRESENTATION_LUNGE_SLASH := 70.0
const PRESENTATION_LUNGE_THRUST := 92.0
const PRESENTATION_LUNGE_FOCUS := 20.0
const PRESENTATION_HIT_KNOCKBACK := 26.0
const PRESENTATION_SLOT_SETTLE_DURATION := 0.20
const PRESENTATION_HIT_PAUSE_LIGHT := 0.080
const PRESENTATION_HIT_PAUSE_HEAVY := 0.130
const PRESENTATION_HIT_PAUSE_BREAK := 0.180
const PRESENTATION_WATCHDOG_SECONDS := 8.0
const PRESENTATION_WATCHDOG_TOKEN_META := &"battle_presentation_watchdog_token"
const MOMENTUM_DOT_FLASH_DURATION := 0.28
const MOMENTUM_DOT_GAIN_FLASH_DURATION := 0.44
const MOMENTUM_DOT_SETTLE_DURATION := 0.16
const MOMENTUM_DOT_GAIN_SETTLE_DURATION := 0.26
const MOMENTUM_DOT_LOSS_COLOR := Color("777a80")
const MOMENTUM_DOT_GAIN_COLOR := Color("f7fbff")

var _presentation_watchdog_token := 0

func _confirm_player_intent() -> void:
	var old_player_slot: int = player.position if player != null else -1
	var old_enemy_slot: int = enemy.position if enemy != null else -1
	var selected_player_card: CardData = _intent_card(draft_player_intent)
	if selected_player_card == null:
		selected_player_card = _intent_card(player_intent)
	var visible_enemy_card: CardData = _enemy_preview_card()
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var order: Array[String] = _preview_resolution_order(p_intent, enemy_intent)
	var preview_sim: Dictionary = {}
	if player != null and enemy != null:
		preview_sim = _ordered_preview_simulation(p_intent, enemy_intent)
	_start_presentation_exchange(selected_player_card, visible_enemy_card, order, old_player_slot, old_enemy_slot, preview_sim)
	super()

func _force_real_actor_positions() -> void:
	super()
	_apply_presentation_offsets()

func _start_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	if _presentation_busy():
		return
	if player == null or enemy == null or not battle_active:
		return
	if player_card == null and enemy_card == null:
		return
	_set_presentation_busy(true)
	set_meta(PRESENTATION_OLD_PLAYER_SLOT_META, old_player_slot)
	set_meta(PRESENTATION_OLD_ENEMY_SLOT_META, old_enemy_slot)
	var safe_order: Array[String] = order.duplicate()
	if safe_order.is_empty():
		safe_order = ["player", "enemy"]
	call_deferred("_run_presentation_exchange", player_card, enemy_card, safe_order, old_player_slot, old_enemy_slot, preview_sim)

func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_begin_presentation_watchdog("base-exchange")
	_reset_presentation_offsets()
	_apply_pre_resolution_slot_offsets(old_player_slot, old_enemy_slot)
	for side: String in order:
		if side == "player" and player_card != null:
			await _play_one_presentation_action(true, player_card, _presentation_result_for_side(preview_sim, "player"))
		elif side == "enemy" and enemy_card != null:
			await _play_one_presentation_action(false, enemy_card, _presentation_result_for_side(preview_sim, "enemy"))
	await _settle_committed_slot_offsets()
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_finish_presentation_exchange()

func _play_one_presentation_action(is_player_actor: bool, card: CardData, result: Dictionary) -> void:
	if card == null:
		return
	var style: String = _presentation_style_for_card(card)
	if style == "guard":
		await _play_guard_presentation(is_player_actor, card, result)
		await _play_momentum_delta_presentation(is_player_actor, result)
		return
	if style == "focus":
		await _play_focus_presentation(is_player_actor, card, result)
		await _play_momentum_delta_presentation(is_player_actor, result)
		return
	await _play_attack_presentation(is_player_actor, card, style, result)

func _play_attack_presentation(is_player_actor: bool, card: CardData, style: String, result: Dictionary) -> void:
	var dir: float = 1.0 if is_player_actor else -1.0
	var lunge_distance: float = _presentation_lunge_distance(style, result)
	var lunge_offset := Vector2(dir * lunge_distance, -5.0)
	var target_is_enemy: bool = is_player_actor
	var should_hit: bool = _presentation_result_should_hit(card, result)
	var target_will_break: bool = _presentation_target_will_break(not is_player_actor, result)
	var base_offset: Vector2 = _presentation_offset(is_player_actor)
	_tween_actor_offset(is_player_actor, base_offset, base_offset + lunge_offset, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await get_tree().create_timer(0.08).timeout
	_play_presentation_attack_fx(is_player_actor, card, style, result)
	await get_tree().create_timer(0.04).timeout
	if should_hit:
		_play_presentation_hit_reaction(not is_player_actor, card, dir, result)
		if target_will_break:
			_play_break_ink_fx(not is_player_actor)
		var pause_duration: float = _presentation_hit_pause_duration(result, target_will_break)
		if pause_duration > 0.0:
			await get_tree().create_timer(pause_duration).timeout
	else:
		_play_presentation_miss_feedback(not is_player_actor, result)
	_tween_actor_offset(is_player_actor, base_offset + lunge_offset, base_offset, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	await _play_momentum_delta_presentation(is_player_actor, result)
	_show_presentation_result_text(target_is_enemy, card, result)
	await get_tree().create_timer(0.45).timeout

func _play_guard_presentation(is_player_actor: bool, _card: CardData, result: Dictionary) -> void:
	var base_offset: Vector2 = _presentation_offset(is_player_actor)
	_tween_actor_offset(is_player_actor, base_offset, base_offset + Vector2(0, 9), 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
	var guard_value: int = int(result.get("guard", 0))
	var label: String = "守+%d" % guard_value if guard_value > 0 else "守"
	_show_presentation_float_text(label, is_player_actor, Color("d8c9a5"))
	_play_presentation_guard_flash(is_player_actor)
	await get_tree().create_timer(0.10).timeout
	_tween_actor_offset(is_player_actor, base_offset + Vector2(0, 9), base_offset, 0.13, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(0.14).timeout

func _play_focus_presentation(is_player_actor: bool, _card: CardData, result: Dictionary) -> void:
	var dir: float = 1.0 if is_player_actor else -1.0
	var base_offset: Vector2 = _presentation_offset(is_player_actor)
	var focus_offset := Vector2(dir * PRESENTATION_LUNGE_FOCUS, -2)
	_tween_actor_offset(is_player_actor, base_offset, base_offset + focus_offset, 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
	var gain_value: int = int(result.get("gain", 0))
	var label: String = "势+%d" % gain_value if gain_value > 0 else "势"
	_show_presentation_float_text(label, is_player_actor, Color("d9b66c"))
	_play_presentation_guard_flash(is_player_actor)
	await get_tree().create_timer(0.10).timeout
	_tween_actor_offset(is_player_actor, base_offset + focus_offset, base_offset, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(0.12).timeout

func _play_presentation_attack_fx(is_player_actor: bool, card: CardData, style: String, result: Dictionary) -> void:
	var is_finisher: bool = _card_has_tag(card, "终结")
	var color: Color = _presentation_attack_color(style, result)
	var range_result: String = str(result.get("range", "hit"))
	var should_hit: bool = _presentation_result_should_hit(card, result)
	if style == "firearm":
		_show_presentation_firearm_flash(is_player_actor, color, should_hit, is_finisher)
	elif style == "thrust":
		_show_pierce_line(color, is_finisher)
	else:
		_show_slash_cut(color, is_finisher)
	if should_hit:
		var profession_id: String = "spearman" if style == "thrust" else "blademaster"
		_show_target_hit_mark(is_player_actor, color, profession_id, is_finisher)
		var shake_amount: float = 4.2
		if is_finisher:
			shake_amount = 7.0
		elif range_result == "graze":
			shake_amount = 2.2
		_impact_feedback(color, shake_amount, style == "thrust" or style == "firearm", is_finisher)

func _play_presentation_hit_reaction(target_is_player: bool, _card: CardData, attack_dir: float, result: Dictionary) -> void:
	var target_node: CanvasItem = _presentation_visual_node(target_is_player)
	var target_start_modulate := Color.WHITE
	var range_result: String = str(result.get("range", "hit"))
	var target_will_break: bool = _presentation_target_will_break(target_is_player, result)
	if target_node != null:
		target_start_modulate = target_node.modulate
		var hit_color := Color(1.0, 0.35, 0.28, target_start_modulate.a)
		if range_result == "graze":
			hit_color = Color(0.95, 0.76, 0.38, target_start_modulate.a)
		if target_will_break:
			hit_color = Color(0.95, 0.15, 0.12, target_start_modulate.a)
		var flash_tween := create_tween()
		flash_tween.tween_property(target_node, "modulate", hit_color, 0.04)
		flash_tween.tween_property(target_node, "modulate", target_start_modulate, 0.12)
	var base_offset: Vector2 = _presentation_offset(target_is_player)
	var knock_scale: float = 0.58 if range_result == "graze" else 1.0
	if target_will_break:
		knock_scale = 1.35
	var knock := base_offset + Vector2(attack_dir * PRESENTATION_HIT_KNOCKBACK * knock_scale, 0)
	_tween_actor_offset(target_is_player, base_offset, knock, 0.05, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await get_tree().create_timer(0.06).timeout
	_tween_actor_offset(target_is_player, knock, base_offset, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT)

func _play_presentation_miss_feedback(target_is_player: bool, result: Dictionary) -> void:
	var label: String = "未中"
	var range_result: String = str(result.get("range", "hit"))
	if range_result == "miss_range":
		label = "距外"
	elif range_result == "miss_facing":
		label = "背向"
	_show_presentation_float_text(label, target_is_player, Color(0.72, 0.72, 0.68, 0.9))
	_show_miss_wisp(target_is_player)

func _play_presentation_guard_flash(is_player_actor: bool) -> void:
	var target_node: CanvasItem = _presentation_visual_node(is_player_actor)
	if target_node == null:
		return
	var start_modulate: Color = target_node.modulate
	var tween := create_tween()
	tween.tween_property(target_node, "modulate", start_modulate.lightened(0.28), 0.05)
	tween.tween_property(target_node, "modulate", start_modulate, 0.12)

func _show_presentation_result_text(target_is_enemy: bool, card: CardData, result: Dictionary) -> void:
	if card == null:
		return
	var parts: Array[String] = []
	var range_result: String = str(result.get("range", "hit"))
	var damage_value: int = int(result.get("damage", card.damage))
	var break_value: int = int(result.get("break", card.break_momentum))
	var gain_value: int = int(result.get("gain", card.gain_momentum))
	if range_result == "graze":
		parts.append("擦中")
	elif range_result == "miss_range":
		parts.append("距外")
	elif range_result == "miss_facing":
		parts.append("背向")
	if damage_value > 0:
		parts.append("-%d" % damage_value)
	if break_value > 0:
		parts.append("势-%d" % break_value)
	if damage_value <= 0 and break_value <= 0 and gain_value > 0 and not target_is_enemy:
		parts.append("势+%d" % gain_value)
	if parts.is_empty():
		return
	var color: Color = Color("c44a3f")
	if range_result == "graze":
		color = Color("d9b66c")
	elif range_result == "miss_range" or range_result == "miss_facing":
		color = Color(0.72, 0.72, 0.68, 0.9)
	_show_presentation_float_text(" / ".join(parts), not target_is_enemy, color)

func _show_presentation_float_text(text: String, target_is_player: bool, color: Color) -> void:
	var layer: Control = center_fx_layer if center_fx_layer != null else self
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 120
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = _presentation_float_position(target_is_player)
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.48)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.48)
	tween.finished.connect(func() -> void:
		label.queue_free()
	)

func _play_momentum_delta_presentation(is_player_actor: bool, result: Dictionary) -> void:
	var break_value: int = max(0, int(result.get("break", 0)))
	var gain_value: int = max(0, int(result.get("gain", 0)))
	if break_value > 0:
		var target_before: int = int(result.get("target_momentum_before", -1))
		var target_after: int = int(result.get("target_momentum_after", -1))
		if target_before >= 0 and target_after >= 0:
			await _animate_momentum_dots_between(not is_player_actor, target_before, target_after, false)
		else:
			await _animate_momentum_dots(not is_player_actor, -break_value)
	if gain_value > 0:
		var actor_before: int = int(result.get("actor_momentum_before", -1))
		var actor_after: int = int(result.get("actor_momentum_after", -1))
		if actor_before >= 0 and actor_after >= 0:
			await _animate_momentum_dots_between(is_player_actor, actor_before, actor_after, true)
		else:
			await _animate_momentum_dots(is_player_actor, gain_value)

func _animate_momentum_dots(is_player_side: bool, delta: int) -> void:
	if delta == 0:
		return
	var fighter: Fighter = player if is_player_side else enemy
	if fighter == null:
		return
	var maximum: int = clampi(fighter.data.max_momentum, 1, 12)
	var final_value: int = clampi(fighter.momentum, 0, maximum)
	var before_value: int = final_value
	if delta > 0:
		before_value = clampi(final_value - delta, 0, maximum)
	else:
		before_value = clampi(final_value + absi(delta), 0, maximum)
	await _animate_momentum_dots_between(is_player_side, before_value, final_value, delta > 0)

func _animate_momentum_dots_between(is_player_side: bool, before_value: int, final_value: int, is_gain: bool) -> void:
	var fighter: Fighter = player if is_player_side else enemy
	var container: HBoxContainer = player_momentum_dots if is_player_side else enemy_momentum_dots
	if fighter == null or container == null:
		return
	var maximum: int = clampi(fighter.data.max_momentum, 1, 12)
	if before_value < 0 or final_value < 0:
		final_value = clampi(fighter.momentum, 0, maximum)
		before_value = clampi(final_value - 1, 0, maximum) if is_gain else clampi(final_value + 1, 0, maximum)
	else:
		before_value = clampi(before_value, 0, maximum)
		final_value = clampi(final_value, 0, maximum)
	if before_value == final_value:
		return
	set_meta(MOMENTUM_DOT_ANIMATING_META, true)
	_refresh_momentum_dots(container, before_value, maximum)
	await get_tree().process_frame
	if is_gain:
		_apply_momentum_dot_flash(container, before_value, final_value, _make_transient_momentum_dot_style(MOMENTUM_DOT_GAIN_COLOR, Color("ffffff")))
		_pulse_momentum_dot_range(container, before_value, final_value, 1.42, MOMENTUM_DOT_GAIN_FLASH_DURATION)
	else:
		_apply_momentum_dot_flash(container, final_value, before_value, _make_transient_momentum_dot_style(MOMENTUM_DOT_LOSS_COLOR, Color("3d4148")))
		_pulse_momentum_dot_range(container, final_value, before_value, 1.26, MOMENTUM_DOT_FLASH_DURATION)
	var flash_duration: float = MOMENTUM_DOT_GAIN_FLASH_DURATION if is_gain else MOMENTUM_DOT_FLASH_DURATION
	await get_tree().create_timer(flash_duration).timeout
	_refresh_momentum_dots(container, final_value, maximum)
	if is_gain:
		_pulse_momentum_dot_range(container, before_value, final_value, 1.18, MOMENTUM_DOT_GAIN_SETTLE_DURATION)
	var settle_duration: float = MOMENTUM_DOT_GAIN_SETTLE_DURATION if is_gain else MOMENTUM_DOT_SETTLE_DURATION
	await get_tree().create_timer(settle_duration).timeout
	remove_meta(MOMENTUM_DOT_ANIMATING_META)
	_refresh_hud_bars(true)

func _apply_momentum_dot_flash(container: HBoxContainer, from_index: int, to_index: int, style: StyleBox) -> void:
	if container == null:
		return
	var start_index: int = clampi(min(from_index, to_index), 0, container.get_child_count())
	var end_index: int = clampi(max(from_index, to_index), 0, container.get_child_count())
	for i in range(start_index, end_index):
		var dot := container.get_child(i)
		if dot is PanelContainer:
			dot.add_theme_stylebox_override("panel", style)

func _pulse_momentum_dot_range(container: HBoxContainer, from_index: int, to_index: int, pulse_scale: float, duration: float) -> void:
	if container == null:
		return
	var start_index: int = clampi(min(from_index, to_index), 0, container.get_child_count())
	var end_index: int = clampi(max(from_index, to_index), 0, container.get_child_count())
	for i in range(start_index, end_index):
		var dot := container.get_child(i)
		if dot is Control:
			var control := dot as Control
			control.pivot_offset = control.size * 0.5
			control.scale = Vector2.ONE
			var tween := create_tween()
			tween.tween_property(control, "scale", Vector2(pulse_scale, pulse_scale), duration * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(control, "scale", Vector2.ONE, duration * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _make_transient_momentum_dot_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	return style

func _play_presentation_death(is_player_actor: bool) -> void:
	var node: CanvasItem = _presentation_visual_node(is_player_actor)
	if node == null:
		return
	var start_modulate: Color = node.modulate
	var start_offset: Vector2 = _presentation_offset(is_player_actor)
	var end_offset := start_offset + Vector2(0, 30)
	_tween_actor_offset(is_player_actor, start_offset, end_offset, 0.26, Tween.TRANS_QUAD, Tween.EASE_IN)
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.26)
	await get_tree().create_timer(0.28).timeout
	node.modulate = start_modulate

func _presentation_style_for_card(card: CardData) -> String:
	if card == null:
		return "idle"
	if card.is_guard_card():
		return "guard"
	if card.is_momentum_card() and int(card.damage) <= 0:
		return "focus"
	var weapon_style: String = str(card.weapon_style)
	var card_id: String = str(card.id)
	var card_name: String = str(card.display_name)
	if weapon_style.findn("火") >= 0 or weapon_style.findn("fire") >= 0 or card_id.findn("fire") >= 0 or card_name.findn("铳") >= 0 or card_name.findn("火") >= 0:
		return "firearm"
	if weapon_style.findn("枪") >= 0 or weapon_style.findn("spear") >= 0:
		return "thrust"
	if card_id.findn("spear") >= 0:
		return "thrust"
	return "slash"

func _presentation_result_for_side(preview_sim: Dictionary, side: String) -> Dictionary:
	var fallback := {"range": "hit", "damage": 0, "break": 0, "gain": 0, "guard": 0}
	var steps_value = preview_sim.get("steps", [])
	if not (steps_value is Array):
		return fallback
	for step_value in steps_value:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if str(step.get("side", "")) != side:
			continue
		if str(step.get("phase", "")) != "effect":
			continue
		return {
			"range": str(step.get("range", "hit")),
			"damage": int(step.get("damage", 0)),
			"break": int(step.get("break", 0)),
			"gain": int(step.get("gain", 0)),
			"guard": int(step.get("guard", 0))
		}
	return fallback

func _presentation_result_should_hit(card: CardData, result: Dictionary) -> bool:
	if card == null:
		return false
	if not card.requires_hit_check():
		return true
	var range_result: String = str(result.get("range", "hit"))
	return range_result == "hit" or range_result == "graze"

func _presentation_lunge_distance(style: String, result: Dictionary) -> float:
	if style == "firearm":
		return 26.0
	var base_distance: float = PRESENTATION_LUNGE_THRUST if style == "thrust" else PRESENTATION_LUNGE_SLASH
	if str(result.get("range", "hit")) == "graze":
		return base_distance * 0.78
	return base_distance

func _presentation_attack_color(style: String, result: Dictionary) -> Color:
	var color: Color = Color("9fd8ff") if style == "thrust" else Color("ff9f73")
	if style == "firearm":
		color = Color("e4572e")
	var range_result: String = str(result.get("range", "hit"))
	if range_result == "graze":
		return color.darkened(0.22)
	if range_result == "miss_range" or range_result == "miss_facing":
		return Color(0.72, 0.72, 0.68, 0.62)
	return color

func _presentation_hit_pause_duration(result: Dictionary, target_will_break: bool) -> float:
	if target_will_break:
		return PRESENTATION_HIT_PAUSE_BREAK
	var damage_value: int = int(result.get("damage", 0))
	var break_value: int = int(result.get("break", 0))
	if damage_value >= 6 or break_value >= 4:
		return PRESENTATION_HIT_PAUSE_HEAVY
	if damage_value > 0 or break_value > 0:
		return PRESENTATION_HIT_PAUSE_LIGHT
	return 0.0

func _presentation_target_will_break(target_is_player: bool, result: Dictionary) -> bool:
	var break_value: int = int(result.get("break", 0))
	if break_value <= 0:
		return false
	var target_fighter: Fighter = player if target_is_player else enemy
	if target_fighter == null:
		return false
	return target_fighter.momentum > 0 and target_fighter.momentum - break_value <= 0

func _show_presentation_firearm_flash(is_player_actor: bool, color: Color, should_hit: bool, is_finisher: bool) -> void:
	var layer: Control = center_fx_layer if center_fx_layer != null else self
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 90
	flash.color = color
	flash.modulate.a = 0.70 if should_hit else 0.35
	flash.size = Vector2(46, 46) if not is_finisher else Vector2(64, 64)
	var origin := _presentation_float_position(is_player_actor) + Vector2(10 if is_player_actor else -38, 18)
	flash.position = origin
	layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.09)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.finished.connect(func() -> void:
		flash.queue_free()
	)

func _show_miss_wisp(target_is_player: bool) -> void:
	var layer: Control = center_fx_layer if center_fx_layer != null else self
	var wisp := ColorRect.new()
	wisp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wisp.z_index = 88
	wisp.color = Color(0.72, 0.72, 0.68, 0.40)
	wisp.size = Vector2(76, 5)
	wisp.position = _presentation_float_position(target_is_player) + Vector2(-26, 32)
	layer.add_child(wisp)
	var tween := create_tween()
	tween.tween_property(wisp, "position:x", wisp.position.x + (-34.0 if target_is_player else 34.0), 0.18)
	tween.parallel().tween_property(wisp, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		wisp.queue_free()
	)

func _play_break_ink_fx(target_is_player: bool) -> void:
	var layer: Control = center_fx_layer if center_fx_layer != null else self
	var center := _presentation_float_position(target_is_player) + Vector2(28, 38)
	for i in range(3):
		var crack := ColorRect.new()
		crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crack.z_index = 95
		crack.color = Color(0.08, 0.07, 0.06, 0.78)
		crack.size = Vector2(70.0 - i * 10.0, 5.0)
		crack.position = center + Vector2(-35.0 + i * 12.0, -10.0 + i * 10.0)
		crack.rotation = -0.55 + i * 0.45
		layer.add_child(crack)
		var tween := create_tween()
		tween.tween_property(crack, "scale:x", 1.45, 0.12)
		tween.parallel().tween_property(crack, "modulate:a", 0.0, 0.22)
		tween.finished.connect(func() -> void:
			crack.queue_free()
		)
	_show_presentation_float_text("破势", target_is_player, Color("c44a3f"))

func _presentation_visual_node(is_player_actor: bool) -> CanvasItem:
	var sprite: TextureRect = player_sprite if is_player_actor else enemy_sprite
	if sprite != null and sprite.visible and sprite.texture != null:
		return sprite
	var fallback: Control = player_fallback_actor if is_player_actor else enemy_fallback_actor
	if fallback != null and fallback.visible:
		return fallback
	return sprite

func _presentation_float_position(target_is_player: bool) -> Vector2:
	var node: CanvasItem = _presentation_visual_node(target_is_player)
	if node is Control:
		var control := node as Control
		return control.position + Vector2(control.size.x * 0.44, 18.0)
	return Vector2(size.x * (0.32 if target_is_player else 0.68), STAGE_AREA_TOP + 210.0)

func _apply_pre_resolution_slot_offsets(old_player_slot: int, old_enemy_slot: int) -> void:
	if player != null and old_player_slot >= 0 and old_player_slot < GRID_SLOT_COUNT:
		_set_player_presentation_offset(_slot_offset_between(true, old_player_slot, player.position))
	if enemy != null and old_enemy_slot >= 0 and old_enemy_slot < GRID_SLOT_COUNT:
		_set_enemy_presentation_offset(_slot_offset_between(false, old_enemy_slot, enemy.position))

func _settle_committed_slot_offsets() -> void:
	var has_settle := false
	var player_offset: Vector2 = _presentation_offset(true)
	var enemy_offset: Vector2 = _presentation_offset(false)
	if player_offset.length() > 0.5:
		has_settle = true
		_tween_actor_offset(true, player_offset, Vector2.ZERO, PRESENTATION_SLOT_SETTLE_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
	if enemy_offset.length() > 0.5:
		has_settle = true
		_tween_actor_offset(false, enemy_offset, Vector2.ZERO, PRESENTATION_SLOT_SETTLE_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
	if has_settle:
		await get_tree().create_timer(PRESENTATION_SLOT_SETTLE_DURATION + 0.02).timeout

func _slot_offset_between(is_player_actor: bool, from_slot: int, to_slot: int) -> Vector2:
	return _slot_top_left(from_slot, is_player_actor) - _slot_top_left(to_slot, is_player_actor)

func _apply_presentation_offsets() -> void:
	if player != null:
		var player_offset: Vector2 = _presentation_offset(true)
		if player_sprite != null:
			player_sprite.position = _slot_top_left(player.position, true) + player_offset
		if player_fallback_actor != null:
			player_fallback_actor.position = _slot_top_left(player.position, true) + player_offset
	if enemy != null:
		var enemy_offset: Vector2 = _presentation_offset(false)
		if enemy_sprite != null:
			enemy_sprite.position = _slot_top_left(enemy.position, false) + enemy_offset
		if enemy_fallback_actor != null:
			enemy_fallback_actor.position = _slot_top_left(enemy.position, false) + enemy_offset

func _tween_actor_offset(is_player_actor: bool, from_offset: Vector2, to_offset: Vector2, duration: float, trans_type, ease_type) -> void:
	var setter: Callable = Callable(self, "_set_player_presentation_offset") if is_player_actor else Callable(self, "_set_enemy_presentation_offset")
	var tween := create_tween()
	tween.tween_method(setter, from_offset, to_offset, duration).set_trans(trans_type).set_ease(ease_type)

func _reset_presentation_offsets() -> void:
	_set_player_presentation_offset(Vector2.ZERO)
	_set_enemy_presentation_offset(Vector2.ZERO)

func _set_player_presentation_offset(value: Vector2) -> void:
	set_meta(PLAYER_OFFSET_META, value)
	_apply_presentation_offsets()

func _set_enemy_presentation_offset(value: Vector2) -> void:
	set_meta(ENEMY_OFFSET_META, value)
	_apply_presentation_offsets()

func _presentation_offset(is_player_actor: bool) -> Vector2:
	var key: StringName = PLAYER_OFFSET_META if is_player_actor else ENEMY_OFFSET_META
	var value = get_meta(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO

func _presentation_busy() -> bool:
	return bool(get_meta(PRESENTATION_BUSY_META, false))

func _set_presentation_busy(value: bool) -> void:
	set_meta(PRESENTATION_BUSY_META, value)
	if not value:
		remove_meta(PRESENTATION_OLD_PLAYER_SLOT_META)
		remove_meta(PRESENTATION_OLD_ENEMY_SLOT_META)
		remove_meta(PRESENTATION_WATCHDOG_TOKEN_META)

func _begin_presentation_watchdog(label: String) -> void:
	_presentation_watchdog_token += 1
	var token := _presentation_watchdog_token
	set_meta(PRESENTATION_WATCHDOG_TOKEN_META, token)
	call_deferred("_presentation_watchdog_after_delay", token, label)

func _presentation_watchdog_after_delay(token: int, label: String) -> void:
	await get_tree().create_timer(PRESENTATION_WATCHDOG_SECONDS).timeout
	if not _presentation_busy():
		return
	if int(get_meta(PRESENTATION_WATCHDOG_TOKEN_META, -1)) != token:
		return
	_finish_presentation_exchange("watchdog:%s" % label)

func _finish_presentation_exchange(reason: String = "done") -> void:
	if reason != "done":
		_log("[color=#ffb86b]表现流程兜底收尾：%s[/color]" % reason)
	_reset_presentation_offsets()
	if has_method("_clear_actor_action_glows"):
		call("_clear_actor_action_glows")
	if has_meta(MOMENTUM_DOT_ANIMATING_META):
		remove_meta(MOMENTUM_DOT_ANIMATING_META)
	_set_presentation_busy(false)
	_refresh_hud_bars(true)
