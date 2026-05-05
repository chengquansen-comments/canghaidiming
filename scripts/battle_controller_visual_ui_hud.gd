extends "res://scripts/battle_controller_visual_ui_overlay.gd"

func _refresh_center_labels() -> void:
	if round_label != null:
		round_label.text = ""
	if phase_label != null:
		if battle_active:
			phase_label.text = "第 %d 回合" % state_machine.round_index
		else:
			phase_label.text = ""

func _refresh_log_strip() -> void:
	if battle_log_strip == null:
		return
	var logs := _recent_logs()
	if logs.is_empty():
		battle_log_strip.text = "日志待命"
	else:
		battle_log_strip.text = logs[logs.size() - 1].replace("[b]", "").replace("[/b]", "")

func _refresh_character_visuals() -> void:
	player_sheet_source = _sheet_source_for(player, false)
	enemy_sheet_source = _sheet_source_for(enemy, true)
	var player_sheet := _sheet_frame_texture(player_sheet_source, 0)
	var enemy_sheet := _sheet_frame_texture(enemy_sheet_source, 0)
	if player_sprite != null:
		player_sprite.texture = player_sheet
		_apply_actor_anchor_meta(true, player, 0)
		player_sprite.modulate = Color(0.92, 0.95, 1.0, 0.96)
	if enemy_sprite != null:
		enemy_sprite.texture = enemy_sheet
		_apply_actor_anchor_meta(false, enemy, 0)
		enemy_sprite.modulate = Color(0.78, 0.82, 0.92, 0.94)
	if player_fallback_actor != null:
		player_fallback_actor.visible = player_sheet == null
		player_fallback_actor.modulate = Color(0.88, 0.92, 1.0, 0.94)
	if enemy_fallback_actor != null:
		enemy_fallback_actor.visible = enemy_sheet == null
		enemy_fallback_actor.modulate = Color(0.7, 0.75, 0.88, 0.92)
	var player_portrait := _portrait_texture_for(player)
	var enemy_portrait := _portrait_texture_for(enemy)
	if player_avatar != null:
		player_avatar.texture = player_portrait
	if enemy_avatar != null:
		enemy_avatar.texture = enemy_portrait
	if player_avatar_fallback != null:
		player_avatar_fallback.visible = player_portrait == null
	if enemy_avatar_fallback != null:
		enemy_avatar_fallback.visible = enemy_portrait == null
	if player_name_label != null:
		player_name_label.text = player.data.display_name if player != null else "玩家"
	if enemy_name_label != null:
		enemy_name_label.text = enemy.data.display_name if enemy != null else "敌方"
	if player_school_label != null:
		player_school_label.text = SCHOOL_NAME if player != null else ""
	if enemy_school_label != null:
		enemy_school_label.text = SCHOOL_NAME if enemy != null else ""

func _apply_actor_anchor_meta(is_player_actor: bool, actor: Fighter, frame_index: int) -> void:
	var sprite := player_sprite if is_player_actor else enemy_sprite
	var source := player_sheet_source if is_player_actor else enemy_sheet_source
	if sprite == null:
		return
	var asset_id := _sprite_anchor_asset_id_for(actor, not is_player_actor)
	var frame_size := _sprite_anchor_frame_size(asset_id, source)
	var foot_anchor := _sprite_anchor_foot_anchor(asset_id, frame_index)
	BattleActorFootHelper.apply_actor_meta_bounds(sprite, frame_size, foot_anchor, 1.0, "right")

func _sprite_anchor_asset_id_for(actor: Fighter, is_enemy_actor: bool) -> String:
	var candidates := _sprite_anchor_candidate_ids(actor, is_enemy_actor)
	for candidate in candidates:
		if BattleSpriteAnchorService.has_asset(candidate):
			return candidate
	return candidates[0] if not candidates.is_empty() else ""

func _sprite_anchor_candidate_ids(actor: Fighter, is_enemy_actor: bool) -> Array[String]:
	var result: Array[String] = []
	if actor == null or actor.data == null:
		return result
	var raw_id := str(actor.data.id)
	var visual_id := _visual_actor_role_id_for(actor)
	var prefix := "enemy_" if is_enemy_actor else ""
	_add_unique_anchor_candidate(result, "%s%s" % [prefix, raw_id])
	_add_unique_anchor_candidate(result, "%s%s" % [prefix, visual_id])
	_add_unique_anchor_candidate(result, raw_id)
	_add_unique_anchor_candidate(result, visual_id)
	return result

func _add_unique_anchor_candidate(result: Array[String], value: String) -> void:
	if value == "":
		return
	if not result.has(value):
		result.append(value)

func _sprite_anchor_frame_size(asset_id: String, source: Texture2D) -> Vector2i:
	if asset_id != "" and BattleSpriteAnchorService.has_asset(asset_id):
		return BattleSpriteAnchorService.get_frame_size(asset_id)
	if source == null:
		return BattleActorFootHelper.DEFAULT_FRAME_SIZE
	var source_width := maxi(source.get_width(), 1)
	var source_height := maxi(source.get_height(), 1)
	if source_height >= source_width:
		return Vector2i(source_width, maxi(source_height / SHEET_FRAME_COUNT, 1))
	return Vector2i(maxi(source_width / SHEET_FRAME_COUNT, 1), source_height)

func _sprite_anchor_foot_anchor(asset_id: String, frame_index: int) -> Vector2:
	if asset_id != "" and BattleSpriteAnchorService.has_asset(asset_id):
		var anchor := BattleSpriteAnchorService.get_frame_anchor(asset_id, frame_index)
		return Vector2(anchor.x, anchor.y)
	return BattleActorFootHelper.DEFAULT_FOOT_ANCHOR

func _refresh_hud_bars(force: bool = false) -> void:
	var signature := _hud_state_signature()
	if not force and signature == _hud_signature:
		return
	_hud_signature = signature
	if player != null and player_hp_fill != null and player_hp_bg != null:
		var player_hp_width := _hud_bar_width(player_hp_bg)
		player_hp_fill.size = Vector2(player_hp_width * clamp(float(player.hp) / max(1.0, float(player.data.max_hp)), 0.0, 1.0), player_hp_bg.size.y if player_hp_bg.size.y > 0.0 else 14.0)
		if player_hp_value_label != null:
			player_hp_value_label.text = "%d / %d" % [player.hp, player.data.max_hp]
		if not bool(get_meta(MOMENTUM_DOT_ANIMATING_META, false)):
			_refresh_momentum_dots(player_momentum_dots, player.momentum, player.data.max_momentum)
	if enemy != null and enemy_hp_fill != null and enemy_hp_bg != null:
		var enemy_hp_width := _hud_bar_width(enemy_hp_bg)
		enemy_hp_fill.size = Vector2(enemy_hp_width * clamp(float(enemy.hp) / max(1.0, float(enemy.data.max_hp)), 0.0, 1.0), enemy_hp_bg.size.y if enemy_hp_bg.size.y > 0.0 else 14.0)
		if enemy_hp_value_label != null:
			enemy_hp_value_label.text = "%d / %d" % [enemy.hp, enemy.data.max_hp]
		if not bool(get_meta(MOMENTUM_DOT_ANIMATING_META, false)):
			_refresh_momentum_dots(enemy_momentum_dots, enemy.momentum, enemy.data.max_momentum)

func _refresh_momentum_dots(container: HBoxContainer, current: int, maximum: int) -> void:
	_set_momentum_dot_value(container, current, maximum)

func _set_momentum_dot_value(container: HBoxContainer, current: int, maximum: int) -> void:
	if container == null:
		return
	var safe_max := clampi(maximum, 1, 12)
	var safe_current := clampi(current, 0, safe_max)
	if container.get_child_count() != safe_max:
		for child in container.get_children():
			child.free()
		for i in range(safe_max):
			var dot := PanelContainer.new()
			dot.custom_minimum_size = Vector2(19, 19)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(dot)
	for i in range(container.get_child_count()):
		var dot := container.get_child(i)
		if dot is PanelContainer:
			dot.add_theme_stylebox_override("panel", _make_momentum_dot_style(i < safe_current))
	_cache_momentum_dot_value(container, safe_current)

func _cache_momentum_dot_value(container: HBoxContainer, value: int) -> void:
	if container == player_momentum_dots:
		_player_momentum_dot_value = value
	elif container == enemy_momentum_dots:
		_enemy_momentum_dot_value = value

func _cached_momentum_dot_value(container: HBoxContainer, fallback: int) -> int:
	if container == player_momentum_dots and _player_momentum_dot_value >= 0:
		return _player_momentum_dot_value
	if container == enemy_momentum_dots and _enemy_momentum_dot_value >= 0:
		return _enemy_momentum_dot_value
	return fallback

func _step_momentum_dot_value(start_value: int, target_value: int, step_index: int) -> int:
	if start_value == target_value:
		return target_value
	var direction := 1 if target_value > start_value else -1
	return start_value + direction * mini(step_index, absi(target_value - start_value))

func _queue_momentum_dot_transition_to_current_state(delay: float = 0.1) -> void:
	if player == null or enemy == null:
		return
	var player_target := clampi(player.momentum, 0, player.data.max_momentum)
	var enemy_target := clampi(enemy.momentum, 0, enemy.data.max_momentum)
	var player_start := _cached_momentum_dot_value(player_momentum_dots, player_target)
	var enemy_start := _cached_momentum_dot_value(enemy_momentum_dots, enemy_target)
	var player_delta := absi(player_target - player_start)
	var enemy_delta := absi(enemy_target - enemy_start)
	var max_steps := maxi(player_delta, enemy_delta)
	if max_steps <= 0:
		return
	_momentum_dot_animation_serial += 1
	var serial := _momentum_dot_animation_serial
	set_meta(MOMENTUM_DOT_ANIMATING_META, true)
	_set_momentum_dot_value(player_momentum_dots, player_start, player.data.max_momentum)
	_set_momentum_dot_value(enemy_momentum_dots, enemy_start, enemy.data.max_momentum)
	var tween := create_tween()
	tween.tween_interval(delay)
	for step_index in range(1, max_steps + 1):
		var p_value := _step_momentum_dot_value(player_start, player_target, step_index)
		var e_value := _step_momentum_dot_value(enemy_start, enemy_target, step_index)
		tween.tween_callback(func() -> void:
			_set_momentum_dot_value(player_momentum_dots, p_value, player.data.max_momentum)
			_set_momentum_dot_value(enemy_momentum_dots, e_value, enemy.data.max_momentum)
		)
		tween.tween_interval(0.045)
	tween.finished.connect(func() -> void:
		if serial != _momentum_dot_animation_serial:
			return
		_set_momentum_dot_value(player_momentum_dots, player_target, player.data.max_momentum)
		_set_momentum_dot_value(enemy_momentum_dots, enemy_target, enemy.data.max_momentum)
		set_meta(MOMENTUM_DOT_ANIMATING_META, false)
		_hud_signature = ""
	)
