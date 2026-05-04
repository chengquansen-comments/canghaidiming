extends "res://scripts/battle_controller_core_status_formatter.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _show_combat_banner(text: String, fill_color: Color, border_color: Color = Color("ffd479")) -> void:
	if combat_banner == null or combat_banner_label == null:
		return
	combat_banner.visible = true
	combat_banner_label.text = text
	combat_banner_label.modulate = Color.WHITE
	combat_banner.add_theme_stylebox_override("panel", _make_panel_style(fill_color, border_color))
	combat_banner.scale = Vector2(0.92, 0.92)
	combat_banner.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(combat_banner, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.parallel().tween_property(combat_banner, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.28)
	tween.tween_property(combat_banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(func() -> void:
		combat_banner.visible = false
	)

func _flash_label(target_label: RichTextLabel, color: Color) -> void:
	if target_label == null:
		return
	target_label.modulate = color
	var tween := create_tween()
	tween.tween_property(target_label, "modulate", Color.WHITE, 0.22)

func _impact_feedback(flash_color: Color, shake_strength: float = 6.0, horizontal_only: bool = false, extra_pulse: bool = false) -> void:
	if screen_flash != null:
		screen_flash.visible = true
		screen_flash.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
		var flash_tween := create_tween()
		flash_tween.tween_property(screen_flash, "color", Color(flash_color.r, flash_color.g, flash_color.b, 0.18), 0.04)
		flash_tween.tween_property(screen_flash, "color", Color(flash_color.r, flash_color.g, flash_color.b, 0.0), 0.12)
		flash_tween.finished.connect(func() -> void:
			screen_flash.visible = false
		)
	var shake_tween := create_tween()
	if horizontal_only:
		shake_tween.tween_property(self, "position", Vector2(shake_strength, 0), 0.02)
		shake_tween.tween_property(self, "position", Vector2(-shake_strength, 0), 0.03)
		shake_tween.tween_property(self, "position", Vector2(shake_strength * 0.35, 0), 0.02)
		shake_tween.tween_property(self, "position", Vector2.ZERO, 0.05)
		return
	shake_tween.tween_property(self, "position", Vector2(shake_strength, 0), 0.03)
	shake_tween.tween_property(self, "position", Vector2(-shake_strength, 0), 0.03)
	shake_tween.tween_property(self, "position", Vector2(0, shake_strength * 0.5), 0.03)
	if extra_pulse:
		shake_tween.tween_property(self, "position", Vector2(shake_strength * 0.55, 0), 0.02)
		shake_tween.tween_property(self, "position", Vector2(-shake_strength * 0.4, 0), 0.02)
	shake_tween.tween_property(self, "position", Vector2.ZERO, 0.05)

func _show_pierce_line(color: Color, is_finisher: bool = false) -> void:
	if pierce_line == null:
		return
	pierce_line.visible = true
	pierce_line.color = Color(color.r, color.g, color.b, 0.0)
	pierce_line.scale = Vector2(0.75, 1.0 if not is_finisher else 1.4)
	pierce_line.position = Vector2(-260 if not is_finisher else -360, 0)
	var tween := create_tween()
	tween.tween_property(pierce_line, "color", Color(color.r, color.g, color.b, 0.95), 0.025)
	tween.parallel().tween_property(pierce_line, "position", Vector2(260 if not is_finisher else 360, 0), 0.07 if not is_finisher else 0.1)
	tween.parallel().tween_property(pierce_line, "scale", Vector2(1.2 if not is_finisher else 1.45, 1.0 if not is_finisher else 1.6), 0.05)
	tween.tween_property(pierce_line, "color", Color(color.r, color.g, color.b, 0.0), 0.08)
	tween.finished.connect(func() -> void:
		pierce_line.visible = false
		pierce_line.position = Vector2.ZERO
		pierce_line.scale = Vector2.ONE
	)

func _show_slash_cut(color: Color, is_finisher: bool = false) -> void:
	if slash_cut == null:
		return
	slash_cut.visible = true
	slash_cut.color = Color(color.r, color.g, color.b, 0.0)
	slash_cut.scale = Vector2(0.82, 0.82)
	slash_cut.position = Vector2(-90, -20)
	var tween := create_tween()
	tween.tween_property(slash_cut, "color", Color(color.r, color.g, color.b, 0.78), 0.03)
	tween.parallel().tween_property(slash_cut, "position", Vector2(90, 20), 0.06)
	tween.parallel().tween_property(slash_cut, "scale", Vector2(1.05, 1.0), 0.05)
	if is_finisher:
		tween.tween_property(slash_cut, "color", Color(color.r, color.g, color.b, 0.95), 0.02)
		tween.parallel().tween_property(slash_cut, "position", Vector2(-40, -8), 0.03)
		tween.parallel().tween_property(slash_cut, "scale", Vector2(1.18, 1.05), 0.03)
	tween.tween_property(slash_cut, "color", Color(color.r, color.g, color.b, 0.0), 0.09)
	tween.finished.connect(func() -> void:
		slash_cut.visible = false
		slash_cut.position = Vector2.ZERO
		slash_cut.scale = Vector2.ONE
	)

func _play_profession_shape_feedback(profession_id: String, color: Color, is_finisher: bool = false, is_start: bool = false) -> void:
	if profession_id == "spearman":
		_show_pierce_line(color, is_finisher)
		return
	_show_slash_cut(color, is_finisher or is_start)

func _show_target_hit_mark(target_is_enemy: bool, color: Color, profession_id: String, is_finisher: bool = false) -> void:
	var mark := right_hit_mark if target_is_enemy else left_hit_mark
	if mark == null:
		return
	mark.visible = true
	mark.color = Color(color.r, color.g, color.b, 0.0)
	mark.scale = Vector2(0.72, 0.72)
	mark.position = Vector2.ZERO
	var is_spear := profession_id == "spearman"
	if is_spear:
		mark.rotation_degrees = 6.0 if target_is_enemy else -6.0
	else:
		mark.rotation_degrees = 18.0 if target_is_enemy else -18.0
	var tween := create_tween()
	if is_spear:
		mark.pivot_offset = Vector2(10, 120)
		tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.52 if not is_finisher else 0.72), 0.025)
		tween.parallel().tween_property(mark, "scale", Vector2(0.18 if not is_finisher else 0.14, 1.0 if not is_finisher else 1.18), 0.035)
		tween.parallel().tween_property(mark, "position", Vector2(-18, 0) if target_is_enemy else Vector2(18, 0), 0.04)
	else:
		mark.pivot_offset = Vector2(72, 120)
		tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.42 if not is_finisher else 0.65), 0.03)
		tween.parallel().tween_property(mark, "scale", Vector2(1.08, 0.28 if not is_finisher else 0.34), 0.04)
		tween.parallel().tween_property(mark, "position", Vector2(-10, -6) if target_is_enemy else Vector2(10, -6), 0.04)
	if is_finisher:
		tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.78 if is_spear else 0.88), 0.025)
		tween.parallel().tween_property(mark, "scale", Vector2(0.08, 1.22) if is_spear else Vector2(1.15, 0.18), 0.03)
		tween.parallel().tween_property(mark, "position", Vector2(-30, 0) if target_is_enemy else Vector2(30, 0), 0.03)
	tween.tween_property(mark, "color", Color(color.r, color.g, color.b, 0.0), 0.1)
	tween.finished.connect(func() -> void:
		mark.visible = false
		mark.position = Vector2.ZERO
		mark.scale = Vector2.ONE
	)

func _animate_target_status_reaction(target: Fighter, profession_id: String, is_finisher: bool = false) -> void:
	if target == null:
		return
	var target_is_enemy := enemy != null and target.data.id == enemy.data.id
	var label := enemy_label if target_is_enemy else player_label
	if label == null:
		return
	label.position = Vector2.ZERO
	label.scale = Vector2.ONE
	var dir := 1.0 if target_is_enemy else -1.0
	var tween := create_tween()
	if profession_id == "spearman":
		var stab_push := (18.0 if not is_finisher else 28.0) * dir
		tween.tween_property(label, "position", Vector2(stab_push, 0), 0.025)
		tween.tween_interval(0.025 if not is_finisher else 0.04)
		tween.tween_property(label, "position", Vector2(stab_push * 0.55, 0), 0.04)
		tween.tween_property(label, "position", Vector2.ZERO, 0.07)
	else:
		var slash_x := (10.0 if not is_finisher else 16.0) * dir
		var slash_y := -8.0 if not is_finisher else -12.0
		tween.tween_property(label, "position", Vector2(slash_x, slash_y), 0.03)
		tween.parallel().tween_property(label, "scale", Vector2(1.02, 0.98), 0.03)
		tween.tween_property(label, "position", Vector2(-slash_x * 0.45, 6.0 if not is_finisher else 9.0), 0.04)
		tween.parallel().tween_property(label, "scale", Vector2(0.99, 1.01), 0.04)
		tween.tween_property(label, "position", Vector2.ZERO, 0.08)
		tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.08)

func _show_target_receive_feedback(target: Fighter, profession_id: String, color: Color, is_finisher: bool = false) -> void:
	if target == null:
		return
	var target_is_enemy := enemy != null and target.data.id == enemy.data.id
	_show_target_hit_mark(target_is_enemy, color, profession_id, is_finisher)
	_animate_target_status_reaction(target, profession_id, is_finisher)
	if profession_id == "spearman":
		_flash_label(enemy_label if target_is_enemy else player_label, Color("bfe9ff") if not is_finisher else Color("e0f4ff"))
	else:
		_flash_label(enemy_label if target_is_enemy else player_label, Color("ffb28f") if not is_finisher else Color("ffd0b5"))

func _combo_feedback_profile(profession_id: String) -> Dictionary:
	if profession_id == "spearman":
		return {
			"start_banner": "枪势连携",
			"start_fill": Color("21334a"),
			"start_border": Color("8fd3ff"),
			"start_flash": Color("8fd3ff"),
			"start_shake": 2.4,
			"start_horizontal_only": true,
			"segment_flash": Color("b7e3ff"),
			"segment_shake": 2.0,
			"segment_horizontal_only": true,
			"segment_extra_pulse": false,
			"finisher_banner": "穿枪贯甲",
			"finisher_fill": Color("1f2d47"),
			"finisher_border": Color("79c7ff"),
			"finisher_flash": Color("9cd8ff"),
			"finisher_shake": 6.2,
			"finisher_horizontal_only": true,
			"finisher_extra_pulse": false,
			"label_color": Color("a9dbff"),
			"log_flair": "枪锋一顿，长驱贯心",
			"segment_flair": "一点即穿"
		}
	return {
		"start_banner": "刀势连携",
		"start_fill": Color("3a2418"),
		"start_border": Color("ffb36b"),
		"start_flash": Color("ffd08a"),
		"start_shake": 4.2,
		"start_horizontal_only": false,
		"segment_flash": Color("ffb48a"),
		"segment_shake": 4.8,
		"segment_horizontal_only": false,
		"segment_extra_pulse": true,
		"finisher_banner": "断流绝斩",
		"finisher_fill": Color("4a1626"),
		"finisher_border": Color("ff7b54"),
		"finisher_flash": Color("ff8a63"),
		"finisher_shake": 10.0,
		"finisher_horizontal_only": false,
		"finisher_extra_pulse": true,
		"label_color": Color("ffb18b"),
		"log_flair": "刀光连斩，势如断流",
		"segment_flair": "连斩压上"
	}
