extends "res://scripts/battle_controller_core_session_rewards.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _queue_battle_result_overlay(victory: bool) -> void:
	call_deferred("_show_battle_result_overlay_after_presentation", victory)

func _show_battle_result_overlay_after_presentation(victory: bool) -> void:
	while has_method("_presentation_busy") and bool(call("_presentation_busy")):
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.30).timeout
	_show_battle_result_overlay(victory)

func _show_battle_result_overlay(victory: bool) -> void:
	if battle_result_title == null or battle_result_body == null or battle_result_actions == null:
		return
	var title := "战斗胜利" if victory else "战斗失败"
	var body := "" if victory else "重新再来"
	var callback := Callable(self, "_on_battle_result_confirm_pressed") if victory else Callable(self, "_on_battle_retry_confirm_pressed")
	battle_result_title.text = title
	battle_result_body.text = body
	for child in battle_result_actions.get_children():
		child.queue_free()
	var button := Button.new()
	button.text = "确认"
	button.custom_minimum_size = Vector2(160, 42)
	button.pressed.connect(callback)
	battle_result_actions.add_child(button)
	if battle_result_scrim != null:
		battle_result_scrim.visible = true
		battle_result_scrim.move_to_front()
	if battle_result_panel != null:
		battle_result_panel.visible = true
		battle_result_panel.move_to_front()
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")

func _on_battle_result_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	_show_node_buttons()
	_refresh_ui()

func _on_battle_retry_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	if has_method("_start_battle"):
		call("_start_battle")

func _hide_battle_result_overlay() -> void:
	if battle_result_scrim != null:
		battle_result_scrim.visible = false
	if battle_result_panel != null:
		battle_result_panel.visible = false
