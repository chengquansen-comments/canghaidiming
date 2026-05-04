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
		player_sprite.modulate = Color(0.92, 0.95, 1.0, 0.96)
	if enemy_sprite != null:
		enemy_sprite.texture = enemy_sheet
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
	if container == null:
		return
	var safe_max := clampi(maximum, 1, 12)
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
			dot.add_theme_stylebox_override("panel", _make_momentum_dot_style(i < current))
