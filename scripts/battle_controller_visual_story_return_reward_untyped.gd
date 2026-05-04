extends "res://scripts/battle_controller_visual_story_return_pressure.gd"

# Story battle result reward layer without parser-time CardData type references.

const StoryReturnRewardContext := preload("res://scripts/narrative_battle_context.gd")

func _show_battle_result_overlay(victory: bool) -> void:
	if battle_result_title == null or battle_result_body == null or battle_result_actions == null:
		return
	_battle_reward_choices.clear()
	_selected_battle_reward_card_id = ""
	_battle_result_confirm_button = null
	battle_result_title.text = "战斗胜利" if victory else "战斗失败"
	_set_battle_result_body_text(_battle_result_body_text(victory, ""))
	for child: Node in battle_result_actions.get_children():
		child.queue_free()
	if victory and _battle_result_should_offer_player_reward():
		_battle_reward_choices = _sample_battle_reward_choices(3)
		for card in _battle_reward_choices:
			var card_button: Button = Button.new()
			card_button.text = card.short_summary()
			card_button.custom_minimum_size = Vector2(360, 46)
			card_button.pressed.connect(_select_battle_reward_card.bind(card.id))
			battle_result_actions.add_child(card_button)
	var button: Button = Button.new()
	button.text = "确认"
	button.custom_minimum_size = Vector2(160, 42)
	button.pressed.connect(Callable(self, "_on_battle_result_confirm_pressed") if victory else Callable(self, "_on_battle_retry_confirm_pressed"))
	if victory and _battle_result_should_offer_player_reward() and not _battle_reward_choices.is_empty():
		button.disabled = true
	_battle_result_confirm_button = button
	battle_result_actions.add_child(button)
	if battle_result_scrim != null:
		battle_result_scrim.visible = true
		battle_result_scrim.move_to_front()
	if battle_result_panel != null:
		if victory and _battle_result_should_use_story_size():
			battle_result_panel.offset_left = -390
			battle_result_panel.offset_right = 390
			battle_result_panel.offset_top = -230
			battle_result_panel.offset_bottom = 260
		else:
			battle_result_panel.offset_left = -240
			battle_result_panel.offset_right = 240
			battle_result_panel.offset_top = -120
			battle_result_panel.offset_bottom = 120
		battle_result_panel.visible = true
		battle_result_panel.move_to_front()
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")

func _battle_result_body_text(victory: bool, selected_card_id: String) -> String:
	if not victory:
		return "重新再来"
	if _battle_result_is_proxy_player():
		return ""
	var lines: Array[String] = []
	lines.append(_projected_player_growth_text())
	if _battle_result_should_offer_player_reward():
		if selected_card_id.is_empty():
			lines.append("选择 1 张新招式加入长期牌库。")
		else:
			lines.append("已选择：%s" % _card_display_name(selected_card_id))
	return "\n".join(lines)

func _battle_result_is_proxy_player() -> bool:
	return StoryReturnRewardContext.has_request() and not StoryReturnRewardContext.should_override_player_profile()

func _battle_result_should_offer_player_reward() -> bool:
	return StoryReturnRewardContext.has_request() and not _battle_result_is_proxy_player()

func _battle_result_should_use_story_size() -> bool:
	return StoryReturnRewardContext.has_request() and not _battle_result_is_proxy_player()

func _projected_player_growth_text() -> String:
	if not StoryReturnRewardContext.has_player_profile():
		if player == null or player.data == null:
			return "胜利结算：玩家数值将在返回剧情后更新。"
		var fallback_level: int = int(player.realm)
		var fallback_next_level: int = fallback_level + 1
		var fallback_new_hp: int = StoryReturnRewardContext.PLAYER_INITIAL_HP + maxi(0, fallback_next_level - StoryReturnRewardContext.PLAYER_INITIAL_MARTIAL_LEVEL) * 2
		var fallback_new_posture: int = clampi(StoryReturnRewardContext.PLAYER_INITIAL_MAX_POSTURE + maxi(0, fallback_next_level - StoryReturnRewardContext.PLAYER_INITIAL_MARTIAL_LEVEL), StoryReturnRewardContext.PLAYER_INITIAL_MAX_POSTURE, StoryReturnRewardContext.PLAYER_MAX_POSTURE)
		var fallback_new_qinggong: int = clampi(StoryReturnRewardContext.PLAYER_INITIAL_QINGGONG + int(maxi(0, fallback_next_level - StoryReturnRewardContext.PLAYER_INITIAL_MARTIAL_LEVEL) / 3), StoryReturnRewardContext.PLAYER_INITIAL_QINGGONG, StoryReturnRewardContext.PLAYER_MAX_QINGGONG)
		return "数值变化：武境 %d -> %d｜HP上限 %d -> %d｜势上限 %d -> %d｜轻功 %d -> %d｜胜场 +1" % [fallback_level, fallback_next_level, player.data.max_hp, fallback_new_hp, player.data.max_momentum, fallback_new_posture, player.qinggong, fallback_new_qinggong]
	var profile: Dictionary = StoryReturnRewardContext.get_player_profile() as Dictionary
	var old_level: int = int(profile.get("martial_level", 1))
	var new_level: int = old_level + 1
	var old_hp: int = int(profile.get("max_hp", StoryReturnRewardContext.PLAYER_INITIAL_HP))
	var old_current_hp: int = int(profile.get("hp", old_hp))
	var old_posture: int = int(profile.get("max_posture", StoryReturnRewardContext.PLAYER_INITIAL_MAX_POSTURE))
	var old_current_posture: int = int(profile.get("posture", old_posture))
	var old_qinggong: int = int(profile.get("qinggong", StoryReturnRewardContext.PLAYER_INITIAL_QINGGONG))
	var old_wins: int = int(profile.get("battles_won", 0))
	var new_hp: int = StoryReturnRewardContext.PLAYER_INITIAL_HP + maxi(0, new_level - StoryReturnRewardContext.PLAYER_INITIAL_MARTIAL_LEVEL) * 2
	var new_posture: int = clampi(StoryReturnRewardContext.PLAYER_INITIAL_MAX_POSTURE + maxi(0, new_level - StoryReturnRewardContext.PLAYER_INITIAL_MARTIAL_LEVEL), StoryReturnRewardContext.PLAYER_INITIAL_MAX_POSTURE, StoryReturnRewardContext.PLAYER_MAX_POSTURE)
	var new_qinggong: int = clampi(StoryReturnRewardContext.PLAYER_INITIAL_QINGGONG + int(maxi(0, new_level - StoryReturnRewardContext.PLAYER_INITIAL_MARTIAL_LEVEL) / 3), StoryReturnRewardContext.PLAYER_INITIAL_QINGGONG, StoryReturnRewardContext.PLAYER_MAX_QINGGONG)
	return "数值变化：武境 %d -> %d｜HP %d/%d -> %d/%d｜势 %d/%d -> %d/%d｜轻功 %d -> %d｜胜场 %d -> %d" % [old_level, new_level, old_current_hp, old_hp, new_hp, new_hp, old_current_posture, old_posture, new_posture, new_posture, old_qinggong, new_qinggong, old_wins, old_wins + 1]

func _sample_battle_reward_choices(count: int) -> Array:
	var owned: Array[String] = []
	if StoryReturnRewardContext.has_player_profile():
		var card_state: Dictionary = StoryReturnRewardContext.get_player_card_state() as Dictionary
		var owned_values: Array = card_state.get("owned_card_ids", []) as Array
		for i in range(owned_values.size()):
			owned.append(str(owned_values[i]))
	var pool: Array = []
	var fallback_pool: Array = []
	for template in reward_pool:
		var card = template.duplicate_card()
		fallback_pool.append(card)
		if not (card.id in owned):
			pool.append(card)
	if pool.is_empty():
		pool = fallback_pool
	pool.shuffle()
	var selected: Array = []
	var selected_count: int = mini(count, pool.size())
	for i in range(selected_count):
		selected.append(pool[i])
	return selected

func _select_battle_reward_card(card_id: String) -> void:
	_selected_battle_reward_card_id = card_id
	_set_battle_result_body_text(_battle_result_body_text(true, card_id))
	if _battle_result_confirm_button != null:
		_battle_result_confirm_button.disabled = false
	for child: Node in battle_result_actions.get_children():
		if child is Button and child != _battle_result_confirm_button:
			var button: Button = child as Button
			button.disabled = false
			button.text = _battle_reward_button_text(button.text, card_id)
	if has_method("_apply_button_styles"):
		call("_apply_button_styles")

func _set_battle_result_body_text(text: String) -> void:
	if battle_result_body == null:
		return
	battle_result_body.text = text
	battle_result_body.visible = not text.is_empty()

func _battle_reward_button_text(current_text: String, selected_card_id: String) -> String:
	var clean: String = current_text.trim_prefix("✓ ")
	for card in _battle_reward_choices:
		if clean == card.short_summary():
			return "✓ %s" % clean if card.id == selected_card_id else clean
	return current_text

func _card_display_name(card_id: String) -> String:
	for card in _battle_reward_choices:
		if card.id == card_id:
			return card.display_name
	return card_id
