extends "res://scripts/battle_controller_visual_scene_manifest.gd"

const PresentationQueueBuilder = preload("res://scripts/visual/presentation_queue_builder.gd")
const PresentationTextFormatter = preload("res://scripts/visual/presentation_text_formatter.gd")
const PresentationFxView = preload("res://scripts/visual/presentation_fx_view.gd")

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
const PRESENTATION_LUNGE_FOCUS := 20.0
const PRESENTATION_HIT_KNOCKBACK := 26.0
const PRESENTATION_SLOT_SETTLE_DURATION := 0.20
const PRESENTATION_WATCHDOG_SECONDS := 8.0
const PRESENTATION_WATCHDOG_TOKEN_META := &"battle_presentation_watchdog_token"
var _presentation_watchdog_token := 0
var _presentation_queue_builder
var _presentation_fx_view

func _queue_builder():
	if _presentation_queue_builder == null:
		_presentation_queue_builder = PresentationQueueBuilder.new(self)
	return _presentation_queue_builder

func _fx_view():
	if _presentation_fx_view == null:
		_presentation_fx_view = PresentationFxView.new(self)
	return _presentation_fx_view

func _confirm_player_intent() -> void:
	var request: Dictionary = _queue_builder().build_exchange_request()
	_start_presentation_exchange(
		request.get("player_card", null),
		request.get("enemy_card", null),
		request.get("order", []),
		int(request.get("old_player_slot", -1)),
		int(request.get("old_enemy_slot", -1)),
		request.get("preview_sim", {})
	)
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
	var safe_order: Array[String] = PresentationQueueBuilder.normalized_order(order)
	call_deferred("_run_presentation_exchange", player_card, enemy_card, safe_order, old_player_slot, old_enemy_slot, preview_sim)

func _run_presentation_exchange(player_card: CardData, enemy_card: CardData, order: Array[String], old_player_slot: int, old_enemy_slot: int, preview_sim: Dictionary) -> void:
	_begin_presentation_watchdog("base-exchange")
	_reset_presentation_offsets()
	_apply_pre_resolution_slot_offsets(old_player_slot, old_enemy_slot)
	for side: String in order:
		if side == "player" and player_card != null:
			await _play_one_presentation_action(true, player_card, PresentationQueueBuilder.result_for_side(preview_sim, "player"))
		elif side == "enemy" and enemy_card != null:
			await _play_one_presentation_action(false, enemy_card, PresentationQueueBuilder.result_for_side(preview_sim, "enemy"))
	await _settle_committed_slot_offsets()
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_finish_presentation_exchange()

func _play_one_presentation_action(is_player_actor: bool, card: CardData, result: Dictionary) -> void:
	if card == null:
		return
	var style: String = PresentationTextFormatter.style_for_card(card)
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
	var lunge_distance: float = PresentationTextFormatter.lunge_distance(style, result)
	var lunge_offset := Vector2(dir * lunge_distance, -5.0)
	var target_is_enemy: bool = is_player_actor
	var should_hit: bool = PresentationTextFormatter.result_should_hit(card, result)
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
		var pause_duration: float = PresentationTextFormatter.hit_pause_duration(result, target_will_break)
		if pause_duration > 0.0:
			await get_tree().create_timer(pause_duration).timeout
	else:
		_play_presentation_miss_feedback(not is_player_actor, result)
	_tween_actor_offset(is_player_actor, base_offset + lunge_offset, base_offset, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	await _play_momentum_delta_presentation(is_player_actor, result)
	_show_presentation_result_text(target_is_enemy, card, result)
	_maybe_show_shoushi_presentation(is_player_actor, result)
	await get_tree().create_timer(0.45).timeout

func _play_guard_presentation(is_player_actor: bool, _card: CardData, result: Dictionary) -> void:
	var base_offset: Vector2 = _presentation_offset(is_player_actor)
	_tween_actor_offset(is_player_actor, base_offset, base_offset + Vector2(0, 9), 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
	_show_presentation_float_text(PresentationTextFormatter.guard_label(result), is_player_actor, Color("d8c9a5"))
	_maybe_show_shoushi_presentation(is_player_actor, result)
	_play_presentation_guard_flash(is_player_actor)
	await get_tree().create_timer(0.10).timeout
	_tween_actor_offset(is_player_actor, base_offset + Vector2(0, 9), base_offset, 0.13, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(0.14).timeout

func _play_focus_presentation(is_player_actor: bool, _card: CardData, result: Dictionary) -> void:
	var dir: float = 1.0 if is_player_actor else -1.0
	var base_offset: Vector2 = _presentation_offset(is_player_actor)
	var focus_offset := Vector2(dir * PRESENTATION_LUNGE_FOCUS, -2)
	_tween_actor_offset(is_player_actor, base_offset, base_offset + focus_offset, 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
	_show_presentation_float_text(PresentationTextFormatter.focus_label(result), is_player_actor, Color("d9b66c"))
	_maybe_show_shoushi_presentation(is_player_actor, result)
	_play_presentation_guard_flash(is_player_actor)
	await get_tree().create_timer(0.10).timeout
	_tween_actor_offset(is_player_actor, base_offset + focus_offset, base_offset, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(0.12).timeout

func _play_presentation_attack_fx(is_player_actor: bool, card: CardData, style: String, result: Dictionary) -> void:
	var is_finisher: bool = _card_has_tag(card, "终结")
	var color: Color = PresentationTextFormatter.attack_color(style, result)
	var range_result: String = PresentationTextFormatter.normalized_range_for_display(str(result.get("range", "hit")))
	var should_hit: bool = PresentationTextFormatter.result_should_hit(card, result)
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
		elif range_result == CombatResolver.RANGE_GRAZE:
			shake_amount = 2.2
		_impact_feedback(color, shake_amount, style == "thrust" or style == "firearm", is_finisher)

func _play_presentation_hit_reaction(target_is_player: bool, _card: CardData, attack_dir: float, result: Dictionary) -> void:
	var target_node: CanvasItem = _presentation_visual_node(target_is_player)
	var target_start_modulate := Color.WHITE
	var range_result: String = PresentationTextFormatter.normalized_range_for_display(str(result.get("range", "hit")))
	var target_will_break: bool = _presentation_target_will_break(target_is_player, result)
	if target_node != null:
		target_start_modulate = target_node.modulate
		var hit_color := Color(1.0, 0.35, 0.28, target_start_modulate.a)
		if range_result == CombatResolver.RANGE_GRAZE:
			hit_color = Color(0.95, 0.76, 0.38, target_start_modulate.a)
		if target_will_break:
			hit_color = Color(0.95, 0.15, 0.12, target_start_modulate.a)
		var flash_tween := create_tween()
		flash_tween.tween_property(target_node, "modulate", hit_color, 0.04)
		flash_tween.tween_property(target_node, "modulate", target_start_modulate, 0.12)
	var base_offset: Vector2 = _presentation_offset(target_is_player)
	var knock_scale: float = 0.58 if range_result == CombatResolver.RANGE_GRAZE else 1.0
	if target_will_break:
		knock_scale = 1.35
	var knock := base_offset + Vector2(attack_dir * PRESENTATION_HIT_KNOCKBACK * knock_scale, 0)
	_tween_actor_offset(target_is_player, base_offset, knock, 0.05, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await get_tree().create_timer(0.06).timeout
	_tween_actor_offset(target_is_player, knock, base_offset, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT)

func _play_presentation_miss_feedback(target_is_player: bool, result: Dictionary) -> void:
	_show_presentation_float_text(PresentationTextFormatter.miss_label(result), target_is_player, Color(0.72, 0.72, 0.68, 0.9))
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
	var data: Dictionary = PresentationTextFormatter.result_text_data(target_is_enemy, card, result)
	if not bool(data.get("visible", false)):
		return
	_show_presentation_float_text(str(data.get("text", "")), bool(data.get("target_is_player", false)), data.get("color", Color.WHITE))

func _show_presentation_float_text(text: String, target_is_player: bool, color: Color) -> void:
	_fx_view().show_float_text(text, target_is_player, color)

func _play_momentum_delta_presentation(is_player_actor: bool, result: Dictionary) -> void:
	await _fx_view().play_momentum_delta(is_player_actor, result)

func _animate_momentum_dots(is_player_side: bool, delta: int) -> void:
	await _fx_view().animate_momentum_dots(is_player_side, delta)

func _animate_momentum_dots_between(is_player_side: bool, before_value: int, final_value: int, is_gain: bool) -> void:
	await _fx_view().animate_momentum_dots_between(is_player_side, before_value, final_value, is_gain)

func _apply_momentum_dot_flash(container: HBoxContainer, from_index: int, to_index: int, style: StyleBox) -> void:
	PresentationFxView.apply_momentum_dot_flash(container, from_index, to_index, style)

func _pulse_momentum_dot_range(container: HBoxContainer, from_index: int, to_index: int, pulse_scale: float, duration: float) -> void:
	_fx_view().pulse_momentum_dot_range(container, from_index, to_index, pulse_scale, duration)

func _make_transient_momentum_dot_style(fill: Color, border: Color) -> StyleBoxFlat:
	return PresentationFxView.make_transient_momentum_dot_style(fill, border)

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

func _maybe_show_shoushi_presentation(is_player_actor: bool, result: Dictionary) -> void:
	var text: String = PresentationTextFormatter.shoushi_text(result)
	if text.is_empty():
		return
	_show_presentation_float_text(text, is_player_actor, Color("f2d089"))

func _presentation_style_for_card(card: CardData) -> String:
	return PresentationTextFormatter.style_for_card(card)

func _presentation_result_for_side(preview_sim: Dictionary, side: String) -> Dictionary:
	return PresentationQueueBuilder.result_for_side(preview_sim, side)

func _presentation_result_should_hit(card: CardData, result: Dictionary) -> bool:
	return PresentationTextFormatter.result_should_hit(card, result)

func _presentation_lunge_distance(style: String, result: Dictionary) -> float:
	return PresentationTextFormatter.lunge_distance(style, result)

func _presentation_hit_pause_duration(result: Dictionary, target_will_break: bool) -> float:
	return PresentationTextFormatter.hit_pause_duration(result, target_will_break)

func _presentation_target_will_break(target_is_player: bool, result: Dictionary) -> bool:
	var break_value: int = int(result.get("break", 0))
	if break_value <= 0:
		return false
	var target_fighter: Fighter = player if target_is_player else enemy
	if target_fighter == null:
		return false
	return target_fighter.momentum > 0 and target_fighter.momentum - break_value <= 0

func _show_presentation_firearm_flash(is_player_actor: bool, color: Color, should_hit: bool, is_finisher: bool) -> void:
	_fx_view().show_firearm_flash(is_player_actor, color, should_hit, is_finisher)

func _show_miss_wisp(target_is_player: bool) -> void:
	_fx_view().show_miss_wisp(target_is_player)

func _play_break_ink_fx(target_is_player: bool) -> void:
	_fx_view().play_break_ink_fx(target_is_player)

func _presentation_visual_node(is_player_actor: bool) -> CanvasItem:
	return _fx_view().presentation_visual_node(is_player_actor)

func _presentation_float_position(target_is_player: bool) -> Vector2:
	return _fx_view().presentation_float_position(target_is_player)

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
