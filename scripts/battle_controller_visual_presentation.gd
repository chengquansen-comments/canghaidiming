extends "res://scripts/battle_controller_visual_scene_manifest.gd"

# Lightweight battle presentation layer.
# This wrapper does not resolve damage or change battle rules. It only consumes
# the already selected player/enemy intents and plays Tween-based feedback:
# lunge, attack FX, hit reaction, floating text, and death fade.

const PRESENTATION_BUSY_META := &"battle_presentation_busy"
const PLAYER_OFFSET_META := &"player_presentation_offset"
const ENEMY_OFFSET_META := &"enemy_presentation_offset"
const PRESENTATION_LUNGE_SLASH := 70.0
const PRESENTATION_LUNGE_THRUST := 92.0
const PRESENTATION_LUNGE_FOCUS := 20.0
const PRESENTATION_HIT_KNOCKBACK := 26.0

func _confirm_player_intent() -> void:
	var selected_player_card = _intent_card(draft_player_intent)
	if selected_player_card == null:
		selected_player_card = _intent_card(player_intent)
	var visible_enemy_card = _enemy_preview_card()
	var p_intent = draft_player_intent if draft_player_intent != null else player_intent
	var order: Array[String] = _preview_resolution_order(p_intent, enemy_intent)
	_start_presentation_exchange(selected_player_card, visible_enemy_card, order)
	super()

func _force_real_actor_positions() -> void:
	super()
	_apply_presentation_offsets()

func _start_presentation_exchange(player_card, enemy_card, order: Array[String]) -> void:
	if _presentation_busy():
		return
	if player == null or enemy == null or not battle_active:
		return
	if player_card == null and enemy_card == null:
		return
	_set_presentation_busy(true)
	var safe_order: Array[String] = order.duplicate()
	if safe_order.is_empty():
		safe_order = ["player", "enemy"]
	call_deferred("_run_presentation_exchange", player_card, enemy_card, safe_order)

func _run_presentation_exchange(player_card, enemy_card, order: Array[String]) -> void:
	_reset_presentation_offsets()
	for side in order:
		if side == "player" and player_card != null:
			await _play_one_presentation_action(true, player_card)
		elif side == "enemy" and enemy_card != null:
			await _play_one_presentation_action(false, enemy_card)
	if enemy != null and enemy.hp <= 0:
		await _play_presentation_death(false)
	if player != null and player.hp <= 0:
		await _play_presentation_death(true)
	_reset_presentation_offsets()
	_set_presentation_busy(false)

func _play_one_presentation_action(is_player_actor: bool, card) -> void:
	if card == null:
		return
	var style: String = _presentation_style_for_card(card)
	if style == "guard":
		await _play_guard_presentation(is_player_actor, card)
		return
	if style == "focus":
		await _play_focus_presentation(is_player_actor, card)
		return
	await _play_attack_presentation(is_player_actor, card, style)

func _play_attack_presentation(is_player_actor: bool, card, style: String) -> void:
	var dir := 1.0 if is_player_actor else -1.0
	var lunge_distance := PRESENTATION_LUNGE_THRUST if style == "thrust" else PRESENTATION_LUNGE_SLASH
	var lunge_offset := Vector2(dir * lunge_distance, -5.0)
	var target_is_enemy := is_player_actor
	_tween_actor_offset(is_player_actor, Vector2.ZERO, lunge_offset, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await get_tree().create_timer(0.08).timeout
	_play_presentation_attack_fx(is_player_actor, card, style)
	await get_tree().create_timer(0.04).timeout
	_play_presentation_hit_reaction(not is_player_actor, card, dir)
	_tween_actor_offset(is_player_actor, lunge_offset, Vector2.ZERO, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	_show_presentation_result_text(target_is_enemy, card)
	await get_tree().create_timer(0.24).timeout

func _play_guard_presentation(is_player_actor: bool, card) -> void:
	_tween_actor_offset(is_player_actor, Vector2.ZERO, Vector2(0, 9), 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
	_show_presentation_float_text("守", is_player_actor, Color("d8c9a5"))
	_play_presentation_guard_flash(is_player_actor)
	await get_tree().create_timer(0.10).timeout
	_tween_actor_offset(is_player_actor, Vector2(0, 9), Vector2.ZERO, 0.13, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(0.14).timeout

func _play_focus_presentation(is_player_actor: bool, card) -> void:
	var dir := 1.0 if is_player_actor else -1.0
	_tween_actor_offset(is_player_actor, Vector2.ZERO, Vector2(dir * PRESENTATION_LUNGE_FOCUS, -2), 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
	_show_presentation_float_text("势", is_player_actor, Color("d9b66c"))
	_play_presentation_guard_flash(is_player_actor)
	await get_tree().create_timer(0.10).timeout
	_tween_actor_offset(is_player_actor, Vector2(dir * PRESENTATION_LUNGE_FOCUS, -2), Vector2.ZERO, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(0.12).timeout

func _play_presentation_attack_fx(is_player_actor: bool, card, style: String) -> void:
	var is_finisher := _card_has_tag(card, "终结")
	var color := Color("9fd8ff") if style == "thrust" else Color("ff9f73")
	if style == "thrust":
		_show_pierce_line(color, is_finisher)
	else:
		_show_slash_cut(color, is_finisher)
	var profession_id := "spearman" if style == "thrust" else "blademaster"
	_show_target_hit_mark(is_player_actor, color, profession_id, is_finisher)
	_impact_feedback(color, 3.8 if not is_finisher else 6.2, style == "thrust", is_finisher)

func _play_presentation_hit_reaction(target_is_player: bool, card, attack_dir: float) -> void:
	var target_node := _presentation_visual_node(target_is_player)
	var target_start_modulate := Color.WHITE
	if target_node != null:
		target_start_modulate = target_node.modulate
		var flash_tween := create_tween()
		flash_tween.tween_property(target_node, "modulate", Color(1.0, 0.35, 0.28, target_start_modulate.a), 0.04)
		flash_tween.tween_property(target_node, "modulate", target_start_modulate, 0.10)
	var knock := Vector2(attack_dir * PRESENTATION_HIT_KNOCKBACK, 0)
	_tween_actor_offset(target_is_player, Vector2.ZERO, knock, 0.05, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await get_tree().create_timer(0.06).timeout
	_tween_actor_offset(target_is_player, knock, Vector2.ZERO, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT)

func _play_presentation_guard_flash(is_player_actor: bool) -> void:
	var target_node := _presentation_visual_node(is_player_actor)
	if target_node == null:
		return
	var start_modulate := target_node.modulate
	var tween := create_tween()
	tween.tween_property(target_node, "modulate", start_modulate.lightened(0.28), 0.05)
	tween.tween_property(target_node, "modulate", start_modulate, 0.12)

func _show_presentation_result_text(target_is_enemy: bool, card) -> void:
	if card == null:
		return
	var parts: Array[String] = []
	if int(card.damage) > 0:
		parts.append("-%d" % int(card.damage))
	if int(card.break_momentum) > 0:
		parts.append("势-%d" % int(card.break_momentum))
	if parts.is_empty():
		return
	_show_presentation_float_text(" / ".join(parts), not target_is_enemy, Color("c44a3f"))

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

func _play_presentation_death(is_player_actor: bool) -> void:
	var node := _presentation_visual_node(is_player_actor)
	if node == null:
		return
	var start_modulate := node.modulate
	var start_offset := _presentation_offset(is_player_actor)
	var end_offset := start_offset + Vector2(0, 30)
	_tween_actor_offset(is_player_actor, start_offset, end_offset, 0.26, Tween.TRANS_QUAD, Tween.EASE_IN)
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.26)
	await get_tree().create_timer(0.28).timeout
	node.modulate = start_modulate

func _presentation_style_for_card(card) -> String:
	if card == null:
		return "idle"
	if card.is_guard_card():
		return "guard"
	if card.is_momentum_card() and int(card.damage) <= 0:
		return "focus"
	var weapon_style := str(card.weapon_style)
	if weapon_style.findn("枪") >= 0 or weapon_style.findn("spear") >= 0:
		return "thrust"
	if str(card.id).findn("spear") >= 0:
		return "thrust"
	return "slash"

func _presentation_visual_node(is_player_actor: bool) -> CanvasItem:
	var sprite := player_sprite if is_player_actor else enemy_sprite
	if sprite != null and sprite.visible and sprite.texture != null:
		return sprite
	var fallback := player_fallback_actor if is_player_actor else enemy_fallback_actor
	if fallback != null and fallback.visible:
		return fallback
	return sprite

func _presentation_float_position(target_is_player: bool) -> Vector2:
	var node := _presentation_visual_node(target_is_player)
	if node is Control:
		var control := node as Control
		return control.position + Vector2(control.size.x * 0.44, 18.0)
	return Vector2(size.x * (0.32 if target_is_player else 0.68), STAGE_AREA_TOP + 210.0)

func _apply_presentation_offsets() -> void:
	var player_offset := _presentation_offset(true)
	var enemy_offset := _presentation_offset(false)
	if player_sprite != null:
		player_sprite.position += player_offset
	if player_fallback_actor != null:
		player_fallback_actor.position += player_offset
	if enemy_sprite != null:
		enemy_sprite.position += enemy_offset
	if enemy_fallback_actor != null:
		enemy_fallback_actor.position += enemy_offset

func _tween_actor_offset(is_player_actor: bool, from_offset: Vector2, to_offset: Vector2, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	var setter := Callable(self, "_set_player_presentation_offset") if is_player_actor else Callable(self, "_set_enemy_presentation_offset")
	var tween := create_tween()
	tween.tween_method(setter, from_offset, to_offset, duration).set_trans(trans_type).set_ease(ease_type)

func _reset_presentation_offsets() -> void:
	_set_player_presentation_offset(Vector2.ZERO)
	_set_enemy_presentation_offset(Vector2.ZERO)

func _set_player_presentation_offset(value: Vector2) -> void:
	set_meta(PLAYER_OFFSET_META, value)

func _set_enemy_presentation_offset(value: Vector2) -> void:
	set_meta(ENEMY_OFFSET_META, value)

func _presentation_offset(is_player_actor: bool) -> Vector2:
	var key := PLAYER_OFFSET_META if is_player_actor else ENEMY_OFFSET_META
	var value = get_meta(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO

func _presentation_busy() -> bool:
	return bool(get_meta(PRESENTATION_BUSY_META, false))

func _set_presentation_busy(value: bool) -> void:
	set_meta(PRESENTATION_BUSY_META, value)
