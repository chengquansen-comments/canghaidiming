extends "res://scripts/battle_controller_visual_preview_checked.gd"

# Runtime tuning panel for v0.3.3 preview/position/combat diagnostics.
# F9 only. Non-invasive wrapper: no battle rules are changed here.

var tuning_panel: PanelContainer
var tuning_layer: CanvasLayer
var tuning_content_root: VBoxContainer
var tuning_label: RichTextLabel
var tuning_visible := false
var tuning_total_checks := 0
var tuning_ok_checks := 0
var tuning_error_counts: Dictionary = {}
var tuning_last_summary := "OK"
var tuning_last_tags: Array = []
var tuning_last_snapshot: Dictionary = {}
var tuning_last_preview: Dictionary = {}


func _build_ui() -> void:
	super()
	_build_tuning_panel()
	_refresh_tuning_panel()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_toggle_tuning_panel()
			get_viewport().set_input_as_handled()


func _toggle_tuning_panel() -> void:
	tuning_visible = not tuning_visible
	if tuning_panel != null:
		tuning_panel.visible = tuning_visible
		if tuning_visible:
			_bring_tuning_panel_to_front()


func _run_preview_consistency_check() -> void:
	if player == null or enemy == null or not battle_active:
		_refresh_tuning_panel()
		return
	var p_intent: IntentData = draft_player_intent if draft_player_intent != null else player_intent
	var e_intent: IntentData = enemy_intent
	if p_intent == null and e_intent == null and not draft_player_has_position:
		_refresh_tuning_panel()
		return

	var snapshot := _build_preview_check_snapshot(p_intent, e_intent)
	var preview_signature := _build_visible_preview_signature(snapshot)
	var check := PreviewConsistencyChecker.compare(snapshot, preview_signature)
	var check_signature := JSON.stringify({
		"snapshot": snapshot,
		"preview": preview_signature,
		"ok": check.get("ok", false),
		"mismatches": check.get("mismatches", [])
	})
	if check_signature != _last_preview_check_signature:
		_last_preview_check_signature = check_signature
		_record_tuning_check(snapshot, preview_signature, check)
		if not bool(check.get("ok", false)):
			var mismatch_signature := JSON.stringify(check.get("mismatches", []))
			if mismatch_signature != _last_preview_mismatch_signature:
				_last_preview_mismatch_signature = mismatch_signature
				print(PreviewConsistencyChecker.format_report(check))
				print("[PreviewMismatch.expected] ", JSON.stringify(check.get("expected", {})))
				print("[PreviewMismatch.actual] ", JSON.stringify(check.get("actual", {})))
	_refresh_tuning_panel()


func _record_tuning_check(snapshot: Dictionary, preview_signature: Dictionary, check: Dictionary) -> void:
	tuning_total_checks += 1
	tuning_last_snapshot = snapshot
	tuning_last_preview = preview_signature
	tuning_last_summary = str(check.get("summary", "OK"))
	tuning_last_tags = check.get("tags", [])
	if bool(check.get("ok", false)):
		tuning_ok_checks += 1
		return
	for tag in tuning_last_tags:
		var key := str(tag)
		tuning_error_counts[key] = int(tuning_error_counts.get(key, 0)) + 1


func _build_tuning_panel() -> void:
	if tuning_panel != null:
		return
	tuning_layer = CanvasLayer.new()
	tuning_layer.name = "TuningDebugCanvasLayer"
	tuning_layer.layer = 300
	add_child(tuning_layer)

	tuning_panel = PanelContainer.new()
	tuning_panel.name = "TuningDebugPanel"
	tuning_panel.z_index = 3000
	tuning_panel.visible = tuning_visible
	tuning_panel.anchor_left = 0.0
	tuning_panel.anchor_top = 0.0
	tuning_panel.anchor_right = 0.0
	tuning_panel.anchor_bottom = 0.0
	tuning_panel.offset_left = 12
	tuning_panel.offset_top = 12
	tuning_panel.offset_right = 432
	tuning_panel.offset_bottom = 560
	tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.82)
	style.border_color = Color(0.36, 0.55, 0.78, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	tuning_panel.add_theme_stylebox_override("panel", style)

	tuning_content_root = VBoxContainer.new()
	tuning_content_root.name = "TuningContentRoot"
	tuning_content_root.mouse_filter = Control.MOUSE_FILTER_STOP
	tuning_content_root.add_theme_constant_override("separation", 6)
	tuning_content_root.custom_minimum_size = Vector2(392, 520)
	tuning_panel.add_child(tuning_content_root)

	tuning_label = RichTextLabel.new()
	tuning_label.fit_content = false
	tuning_label.scroll_active = true
	tuning_label.bbcode_enabled = true
	tuning_label.custom_minimum_size = Vector2(392, 300)
	tuning_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuning_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tuning_label.add_theme_font_size_override("normal_font_size", 13)
	tuning_content_root.add_child(tuning_label)
	tuning_layer.add_child(tuning_panel)
	_bring_tuning_panel_to_front()


func _refresh_tuning_panel() -> void:
	if tuning_label == null:
		return
	if tuning_visible:
		_bring_tuning_panel_to_front()
	var distance := absi(enemy.position - player.position) if player != null and enemy != null else -1
	var p_card := _card_name_from_snapshot(tuning_last_snapshot.get("player_card", {}))
	var e_card := _card_name_from_snapshot(tuning_last_snapshot.get("enemy_card", {}))
	var ok_rate := 0.0
	if tuning_total_checks > 0:
		ok_rate = float(tuning_ok_checks) / float(tuning_total_checks) * 100.0
	var text := ""
	text += "[b]调参 / 预览诊断面板[/b]  [color=#9cc7ff]F9隐藏/显示[/color]\n"
	text += "真实距离: %s    检查: %d    OK: %.1f%%\n" % [str(distance), tuning_total_checks, ok_rate]
	if player != null and enemy != null:
		text += "玩家: pos=%d face=%s HP=%d 势=%d guard=%d\n" % [player.position, player.facing, player.hp, player.momentum, player.guard_points]
		text += "敌人: pos=%d face=%s HP=%d 势=%d guard=%d\n" % [enemy.position, enemy.facing, enemy.hp, enemy.momentum, enemy.guard_points]
	text += "\n[b]当前预演[/b]\n"
	text += "玩家牌: %s\n敌方牌: %s\n" % [p_card, e_card]
	text += "顺序: %s\n" % JSON.stringify(tuning_last_snapshot.get("order", []))
	text += "预览终点: 玩家 %s / 敌人 %s\n" % [str(tuning_last_preview.get("player_final", "-")), str(tuning_last_preview.get("enemy_final", "-"))]
	text += "命中: 玩家 %s / 敌人 %s\n" % [str(tuning_last_preview.get("player_range_result", "-")), str(tuning_last_preview.get("enemy_range_result", "-"))]
	text += "\n[b]Mismatch[/b]\n"
	text += "最近: %s\n" % tuning_last_summary
	text += _format_error_counts()
	tuning_label.text = text


func _bring_tuning_panel_to_front() -> void:
	if tuning_layer != null and tuning_layer.get_parent() != null:
		tuning_layer.get_parent().move_child(tuning_layer, tuning_layer.get_parent().get_child_count() - 1)
	if tuning_panel != null:
		tuning_panel.move_to_front()


func _format_error_counts() -> String:
	if tuning_error_counts.is_empty():
		return "暂无错误\n"
	var total := 0
	for key in tuning_error_counts.keys():
		total += int(tuning_error_counts[key])
	var lines: Array[String] = []
	for key in tuning_error_counts.keys():
		var count := int(tuning_error_counts[key])
		var pct := float(count) / float(maxi(total, 1)) * 100.0
		lines.append("%s: %d / %.1f%%" % [key, count, pct])
	return "\n".join(lines) + "\n"


func _card_name_from_snapshot(card_value) -> String:
	if typeof(card_value) != TYPE_DICTIONARY:
		return "无"
	var card: Dictionary = card_value
	if card.is_empty():
		return "无"
	return str(card.get("display_name", card.get("id", "未知")))
