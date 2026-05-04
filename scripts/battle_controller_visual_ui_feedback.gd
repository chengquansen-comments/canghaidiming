extends "res://scripts/battle_controller_visual_ui_stage.gd"

func _reset_battle_result_visual_state() -> void:
	for node in [player_sprite, enemy_sprite, player_fallback_actor, enemy_fallback_actor]:
		if node is CanvasItem:
			var item := node as CanvasItem
			item.visible = true
			item.modulate = Color.WHITE

func _pulse_actor_sheet_frame(actor: Fighter, frame_index: int, duration: float = 0.14) -> void:
	_set_actor_sheet_frame(actor, frame_index)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		_set_actor_sheet_frame(actor, 0)
	)

func _animate_attacker_sprite(actor: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	var sprite := player_fallback_actor if actor != null and player != null and actor.data.id == player.data.id and player_fallback_actor != null and player_fallback_actor.visible else enemy_fallback_actor if actor != null and enemy != null and actor.data.id == enemy.data.id and enemy_fallback_actor != null and enemy_fallback_actor.visible else player_sprite if actor != null and player != null and actor.data.id == player.data.id else enemy_sprite
	if sprite == null:
		return
	_pulse_actor_sheet_frame(actor, 1, 0.16 if is_finisher else 0.12)
	var start := sprite.position
	var dir := -1.0 if _actor_control_faces_left(sprite) else 1.0
	var tween := create_tween()
	if profession_id == "spearman":
		tween.tween_property(sprite, "position", start + Vector2((28 if not is_finisher else 40) * dir, 0), 0.04)
		tween.tween_property(sprite, "position", start, 0.06)
	else:
		tween.tween_property(sprite, "position", start + Vector2((20 if not is_finisher else 30) * dir, -10), 0.04)
		tween.tween_property(sprite, "position", start, 0.07)

func _resolve_combo_chain_if_any(actor: Fighter, target: Fighter, intent: IntentData) -> Array[String]:
	var lines := super._resolve_combo_chain_if_any(actor, target, intent)
	if not lines.is_empty() and actor != null and intent != null and intent.actual_card != null and intent.actual_card.damage > 0:
		var is_finisher := intent.actual_card.has_tag("终结")
		_animate_attacker_sprite(actor, actor.data.id, is_finisher)
	return lines

func _on_intent_resolved(actor: Fighter, target: Fighter, intent: IntentData, feedback: Dictionary) -> void:
	if actor == null or target == null or intent == null or intent.actual_card == null:
		return
	if not bool(feedback.get("is_attack", false)):
		return
	var card: CardData = intent.actual_card
	var is_finisher := card.has_tag("终结")
	var effect_color := _strike_feedback_color(actor.data.id, bool(feedback.get("connected", false)))
	_animate_attacker_sprite(actor, actor.data.id, is_finisher)
	_play_profession_shape_feedback(actor.data.id, effect_color, is_finisher, false)
	if bool(feedback.get("connected", false)):
		_show_target_receive_feedback(target, actor.data.id, effect_color, is_finisher)

func _strike_feedback_color(profession_id: String, connected: bool) -> Color:
	if profession_id == "spearman":
		return Color("8fd3ff") if connected else Color("6f94ad")
	return Color("ffb28f") if connected else Color("b68268")

func _spawn_fx_texture(path: String, draw_size: Vector2, at_position: Vector2, tint: Color, rotation_deg: float = 0.0, start_scale: Vector2 = Vector2.ONE) -> TextureRect:
	var texture := _safe_load_texture(path)
	if texture == null:
		return null
	return _fx_pool.acquire(path, texture, draw_size, at_position, tint, rotation_deg, start_scale)

func _release_fx_texture(path: String, fx: TextureRect) -> void:
	_fx_pool.release(path, fx)

func _show_pierce_line(color: Color, is_finisher: bool = false) -> void:
	var fx_path := "res://assets/pixel_battle/fx/pierce_streak.png"
	var fx := _spawn_fx_texture(
		fx_path,
		Vector2(320 if not is_finisher else 380, 72 if not is_finisher else 88),
		Vector2(size.x * 0.5, size.y * 0.5),
		color,
		0.0,
		Vector2(0.78, 1.0)
	)
	if fx == null:
		super(color, is_finisher)
		return
	var start_pos := fx.position + Vector2(-220 if not is_finisher else -280, 0)
	var end_pos := fx.position + Vector2(220 if not is_finisher else 280, 0)
	fx.position = start_pos
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.96), 0.03)
	tween.parallel().tween_property(fx, "position", end_pos, 0.09 if not is_finisher else 0.12)
	tween.parallel().tween_property(fx, "scale", Vector2(1.08 if not is_finisher else 1.22, 1.0 if not is_finisher else 1.16), 0.06)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.09)
	tween.finished.connect(func() -> void:
		_release_fx_texture(fx_path, fx)
	)

func _show_slash_cut(color: Color, is_finisher: bool = false) -> void:
	var fx_path := "res://assets/pixel_battle/fx/slash_arc.png"
	var fx := _spawn_fx_texture(
		fx_path,
		Vector2(260 if not is_finisher else 320, 160 if not is_finisher else 200),
		Vector2(size.x * 0.5, size.y * 0.5),
		color,
		-16.0,
		Vector2(0.84, 0.84)
	)
	if fx == null:
		super(color, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.88), 0.03)
	tween.parallel().tween_property(fx, "scale", Vector2(1.02 if not is_finisher else 1.16, 1.02 if not is_finisher else 1.16), 0.06)
	tween.parallel().tween_property(fx, "position", fx.position + Vector2(84, 18), 0.06)
	if is_finisher:
		tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.98), 0.02)
		tween.parallel().tween_property(fx, "position", fx.position + Vector2(-36, -6), 0.04)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		_release_fx_texture(fx_path, fx)
	)

func _show_target_hit_mark(target_is_enemy: bool, color: Color, profession_id: String, is_finisher: bool = false) -> void:
	var fx_path := "res://assets/pixel_battle/fx/hit_spark.png"
	var fx := _spawn_fx_texture(
		fx_path,
		Vector2(128 if not is_finisher else 156, 128 if not is_finisher else 156),
		_actor_fx_anchor(target_is_enemy) + Vector2(12 if target_is_enemy else -12, -24),
		color,
		0.0,
		Vector2(0.72, 0.72)
	)
	if fx == null:
		super(target_is_enemy, color, profession_id, is_finisher)
		return
	var tween := create_tween()
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.9 if is_finisher else 0.72), 0.03)
	tween.parallel().tween_property(fx, "scale", Vector2(1.0 if not is_finisher else 1.18, 1.0 if not is_finisher else 1.18), 0.05)
	tween.parallel().tween_property(fx, "rotation_degrees", 14.0 if profession_id == "spearman" else -18.0, 0.05)
	tween.tween_property(fx, "modulate", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		_release_fx_texture(fx_path, fx)
	)

func _show_target_receive_feedback(target: Fighter, profession_id: String, color: Color, is_finisher: bool = false) -> void:
	super(target, profession_id, color, is_finisher)
	_pulse_actor_sheet_frame(target, 2, 0.16 if is_finisher else 0.12)
