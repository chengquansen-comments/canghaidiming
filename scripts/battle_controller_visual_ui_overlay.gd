extends "res://scripts/battle_controller_visual_ui_foundation.gd"

func _show_node_buttons() -> void:
	var signature := _node_buttons_state_signature()
	if signature == _node_buttons_signature:
		return
	_node_buttons_signature = signature
	super()

func _show_overlay(title: String, body: String, actions: Array) -> void:
	if overlay_title == null or overlay_body == null or overlay_actions == null:
		return
	_clear_invalid_overlay_action_buttons()
	for child in overlay_actions.get_children():
		if not (child is Button) or not (child in _overlay_action_buttons):
			child.queue_free()
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = true
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var button := _overlay_action_button(i)
		_disconnect_button_pressed(button)
		button.text = str(action["text"]) if action.has("text") else ""
		var callback: Callable = action["callback"] if action.has("callback") else Callable()
		if callback.is_valid():
			button.pressed.connect(callback)
		button.disabled = false
		button.visible = true
	for i in range(actions.size(), _overlay_action_buttons.size()):
		var button = _overlay_action_buttons[i]
		_disconnect_button_pressed(button)
		if is_instance_valid(button) and button is Button:
			button.visible = false
	if overlay_scrim != null:
		overlay_scrim.visible = true
		overlay_scrim.move_to_front()
	if overlay_panel != null:
		overlay_panel.visible = true
		overlay_panel.move_to_front()
	_apply_button_styles()

func _overlay_action_button(index: int) -> Button:
	while _overlay_action_buttons.size() <= index:
		var button := Button.new()
		button.visible = false
		overlay_actions.add_child(button)
		_overlay_action_buttons.append(button)
	var existing = _overlay_action_buttons[index]
	if not is_instance_valid(existing) or not (existing is Button):
		var replacement := Button.new()
		replacement.visible = false
		overlay_actions.add_child(replacement)
		_overlay_action_buttons[index] = replacement
		return replacement
	if existing.get_parent() == null:
		overlay_actions.add_child(existing)
	return existing

func _clear_invalid_overlay_action_buttons() -> void:
	for i in range(_overlay_action_buttons.size()):
		if not is_instance_valid(_overlay_action_buttons[i]):
			_overlay_action_buttons[i] = null

func _disconnect_button_pressed(button) -> void:
	if not is_instance_valid(button) or not (button is Button):
		return
	for connection in button.pressed.get_connections():
		var connection_data: Dictionary = connection
		if not connection_data.has("callable"):
			continue
		var callable: Callable = connection_data["callable"]
		if callable.is_valid() and button.pressed.is_connected(callable):
			button.pressed.disconnect(callable)

func _apply_button_styles() -> void:
	var groups: Array = [
		[deck_button, reset_pick_button, confirm_button],
		node_buttons_box.get_children() if node_buttons_box != null else [],
		overlay_actions.get_children() if overlay_actions != null else [],
		battle_result_actions.get_children() if battle_result_actions != null else []
	]
	for group in groups:
		for child in group:
			if is_instance_valid(child) and child is Button:
				_style_plain_button_once(child)

func _style_plain_button_once(button: Button) -> void:
	if button.has_meta(BUTTON_STYLE_META):
		return
	_style_button(button)
	button.set_meta(BUTTON_STYLE_META, true)

func _set_action_buttons_visible(visible: bool) -> void:
	if reset_pick_button != null:
		reset_pick_button.visible = visible
	if confirm_button != null:
		confirm_button.visible = visible

func _set_battle_chrome_visible(visible: bool) -> void:
	if top_hud != null:
		top_hud.visible = visible
	if center_hud != null:
		center_hud.visible = visible
	if bottom_backdrop != null:
		bottom_backdrop.visible = visible
	if bottom_root != null:
		bottom_root.visible = visible
	if stage_area_frame != null:
		stage_area_frame.visible = visible
	if stage_grid_box != null:
		stage_grid_box.visible = visible
	if stage_slot_label_box != null:
		stage_slot_label_box.visible = visible
	if player_sprite != null:
		player_sprite.visible = visible
	if enemy_sprite != null:
		enemy_sprite.visible = visible
	if player_fallback_actor != null:
		player_fallback_actor.visible = visible and player_fallback_actor.visible
	if enemy_fallback_actor != null:
		enemy_fallback_actor.visible = visible and enemy_fallback_actor.visible

func _node_buttons_state_signature() -> String:
	if player == null:
		return "no-player"
	var parts: Array[String] = []
	parts.append(player.data.id)
	parts.append(str(battle_active))
	parts.append(str(node_pick_count))
	parts.append(str(awaiting_player_input))
	parts.append(str(fusion_first_index))
	parts.append(str(state_machine.phase if state_machine != null else -1))
	return "|".join(parts)
