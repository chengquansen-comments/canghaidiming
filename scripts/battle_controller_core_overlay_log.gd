extends "res://scripts/battle_controller_core_ui_shell.gd"

# Split from battle_controller_core.gd; keep behavior-compatible with the original controller.

func _show_overlay(title: String, body: String, actions: Array) -> void:
	if overlay_title == null or overlay_body == null or overlay_actions == null:
		return
	_set_overlay_standard_size()
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = true
	for child in overlay_actions.get_children():
		child.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = action["text"]
		button.pressed.connect(action["callback"])
		button.disabled = bool(action.get("disabled", false))
		overlay_actions.add_child(button)
	overlay_scrim.visible = true
	overlay_panel.visible = true
	overlay_scrim.move_to_front()
	overlay_panel.move_to_front()

func _set_overlay_standard_size() -> void:
	if overlay_panel == null:
		return
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.12
	overlay_panel.offset_left = -340
	overlay_panel.offset_right = 340
	overlay_panel.offset_top = 0
	overlay_panel.offset_bottom = 0

func _set_overlay_deck_builder_size() -> void:
	if overlay_panel == null:
		return
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_top = 0.06
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_bottom = 0.85
	overlay_panel.offset_left = -570
	overlay_panel.offset_right = 570
	overlay_panel.offset_top = 0
	overlay_panel.offset_bottom = 0

func _hide_overlay() -> void:
	if overlay_scrim != null:
		overlay_scrim.visible = false
	if overlay_panel != null:
		overlay_panel.visible = false

func _refresh_log() -> void:
	if log_label != null:
		log_label.text = "\n".join(_recent_logs())

func _recent_logs() -> Array[String]:
	var logs: Array[String] = []
	for line in get_meta("battle_logs", []):
		logs.append(line)
	return logs.slice(maxi(logs.size() - 20, 0), logs.size())

func _log(message: String) -> void:
	var logs: Array[String] = []
	if has_meta("battle_logs"):
		logs = get_meta("battle_logs")
	logs.append(message)
	set_meta("battle_logs", logs)
	_refresh_log()
