extends "res://scripts/battle_controller_visual_settlement_mode.gd"

# Auto-return + pressure-profile layer for story battles.
#
# v0.4.4 routes pressure_profile writes through BattleEffectApplier so this
# visual layer decides timing and displays feedback, but no longer directly
# mutates combat values for pressure rules.
#
# BattleEffectApplier is declared in the parent controller; do not redeclare it
# here, otherwise GDScript raises a member-name conflict in the inheritance chain.

const PRESSURE_NONE := BattleEffectApplier.PRESSURE_NONE
const PRESSURE_EDGE := BattleEffectApplier.PRESSURE_EDGE
const PRESSURE_BREAK_RESIST := BattleEffectApplier.PRESSURE_BREAK_RESIST

var _returning_to_story_selection := false
var _pressure_profile := PRESSURE_NONE
var _break_resist_available := false
var _last_edge_positions: Dictionary = {}
var _battle_reward_choices: Array[CardData] = []
var _selected_battle_reward_card_id := ""
var _battle_result_confirm_button: Button


func _apply_selected_story_battle_to_current_battle() -> void:
	super._apply_selected_story_battle_to_current_battle()
	_setup_pressure_profile_for_current_encounter()


func _apply_battle_loadout_once(loadout: Dictionary) -> void:
	super._apply_battle_loadout_once(loadout)
	_setup_pressure_profile_for_current_encounter()


func _refresh_ui() -> void:
	_apply_pressure_profile_runtime_rules()
	super()
	_try_auto_return_after_battle_result()
	_append_pressure_profile_to_status()


func _on_continue_narrative_pressed() -> void:
	if NarrativeBattleContext.has_request():
		super._on_continue_narrative_pressed()
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]返回战斗测试。[/color]")
	_show_combat_banner("返回战斗测试", Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _setup_pressure_profile_for_current_encounter() -> void:
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_edge_positions = {}
	var encounter: Dictionary = {}
	if not _pending_story_battle.is_empty():
		encounter = _pending_story_battle.get("encounter", {}) as Dictionary
	elif not battle_loadout.is_empty():
		encounter = battle_loadout.get("encounter_config", {}) as Dictionary
	if encounter.is_empty():
		return
	_pressure_profile = str(encounter.get("pressure_profile", PRESSURE_NONE))
	if not BattleEffectApplier.is_valid_pressure_profile(_pressure_profile):
		push_warning("Invalid pressure_profile, fallback to none: %s" % _pressure_profile)
		_pressure_profile = PRESSURE_NONE
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	if log_label != null and _pressure_profile != PRESSURE_NONE:
		log_label.append_text("\n[color=#ffd479]压力规则：%s[/color]" % _pressure_profile)


func _apply_pressure_profile_runtime_rules() -> void:
	if not battle_active:
		return
	if player == null or enemy == null or state_machine == null:
		return
	var context: Dictionary = {
		"break_resist_available": _break_resist_available,
		"last_edge_positions": _last_edge_positions
	}
	var result: Dictionary = BattleEffectApplier.apply_pressure_profile(_pressure_profile, player, enemy, state_machine, context)
	_break_resist_available = bool(context.get("break_resist_available", _break_resist_available))
	var edge_positions_value: Variant = context.get("last_edge_positions", _last_edge_positions)
	if edge_positions_value is Dictionary:
		_last_edge_positions = edge_positions_value as Dictionary
	if not bool(result.get("applied", false)):
		return
	var events_value: Variant = result.get("events", [])
	if not (events_value is Array):
		return
	var events: Array = events_value as Array
	for i in range(events.size()):
		var event_value: Variant = events[i]
		if event_value is Dictionary:
			_log_pressure_event(event_value as Dictionary)


func _log_pressure_event(event: Dictionary) -> void:
	var event_type: String = str(event.get("type", ""))
	if event_type == PRESSURE_EDGE:
		if log_label != null:
			log_label.append_text("\n[color=#ffd479]边界压迫：%s被逼至%s，额外失1势。[/color]" % [str(event.get("label", "角色")), _slot_label_safe(int(event.get("position", 0)))])
	elif event_type == PRESSURE_BREAK_RESIST:
		if log_label != null:
			log_label.append_text("\n[color=#ffd479]稳势：对手强行稳住身形，本次崩势中断被抵消，势保留为1。[/color]")
		_show_combat_banner("稳势：崩势被抵消", Color("2a2018"), Color("ffd479"))


func _append_pressure_profile_to_status() -> void:
	if status_label == null:
		return
	if _pressure_profile == PRESSURE_NONE:
		return
	status_label.append_text("\n压力规则：%s" % _pressure_profile)


func _try_auto_return_after_battle_result() -> void:
	pass


func _show_battle_result_overlay(victory: bool) -> void:
	if battle_result_title == null or battle_result_body == null or battle_result_actions == null:
		return
	_battle_reward_choices.clear()
	_selected_battle_reward_card_id = ""
	_battle_result_confirm_button = null
	var title: String = "战斗胜利" if victory else "战斗失败"
	battle_result_title.text = title
	_set_battle_result_body_text(_battle_result_body_text(victory, ""))
	for child: Node in battle_result_actions.get_children():
		child.queue_free()
	if victory and _battle_result_should_offer_player_reward():
		_battle_reward_choices = _sample_battle_reward_choices(3)
		for card: CardData in _battle_reward_choices:
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
	return NarrativeBattleContext.has_request() and not NarrativeBattleContext.should_override_player_profile()


func _battle_result_should_offer_player_reward() -> bool:
	return NarrativeBattleContext.has_request() and not _battle_result_is_proxy_player()


func _battle_result_should_use_story_size() -> bool:
	return NarrativeBattleContext.has_request() and not _battle_result_is_proxy_player()


func _projected_player_growth_text() -> String:
	if not NarrativeBattleContext.has_player_profile():
		if player == null or player.data == null:
			return "胜利结算：玩家数值将在返回剧情后更新。"
		var fallback_level: int = int(player.realm)
		var fallback_next_level: int = fallback_level + 1
		var fallback_new_hp: int = NarrativeBattleContext.PLAYER_INITIAL_HP + maxi(0, fallback_next_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) * 2
		var fallback_new_posture: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE + maxi(0, fallback_next_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL), NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE, NarrativeBattleContext.PLAYER_MAX_POSTURE)
		var fallback_new_qinggong: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_QINGGONG + int(maxi(0, fallback_next_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) / 3), NarrativeBattleContext.PLAYER_INITIAL_QINGGONG, NarrativeBattleContext.PLAYER_MAX_QINGGONG)
		return "数值变化：武境 %d -> %d｜HP上限 %d -> %d｜势上限 %d -> %d｜轻功 %d -> %d｜胜场 +1" % [fallback_level, fallback_next_level, player.data.max_hp, fallback_new_hp, player.data.max_momentum, fallback_new_posture, player.qinggong, fallback_new_qinggong]
	var profile: Dictionary = NarrativeBattleContext.get_player_profile() as Dictionary
	var old_level: int = int(profile.get("martial_level", 1))
	var new_level: int = old_level + 1
	var old_hp: int = int(profile.get("max_hp", NarrativeBattleContext.PLAYER_INITIAL_HP))
	var old_current_hp: int = int(profile.get("hp", old_hp))
	var old_posture: int = int(profile.get("max_posture", NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE))
	var old_current_posture: int = int(profile.get("posture", old_posture))
	var old_qinggong: int = int(profile.get("qinggong", NarrativeBattleContext.PLAYER_INITIAL_QINGGONG))
	var old_wins: int = int(profile.get("battles_won", 0))
	var new_hp: int = NarrativeBattleContext.PLAYER_INITIAL_HP + maxi(0, new_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) * 2
	var new_posture: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE + maxi(0, new_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL), NarrativeBattleContext.PLAYER_INITIAL_MAX_POSTURE, NarrativeBattleContext.PLAYER_MAX_POSTURE)
	var new_qinggong: int = clampi(NarrativeBattleContext.PLAYER_INITIAL_QINGGONG + int(maxi(0, new_level - NarrativeBattleContext.PLAYER_INITIAL_MARTIAL_LEVEL) / 3), NarrativeBattleContext.PLAYER_INITIAL_QINGGONG, NarrativeBattleContext.PLAYER_MAX_QINGGONG)
	return "数值变化：武境 %d -> %d｜HP %d/%d -> %d/%d｜势 %d/%d -> %d/%d｜轻功 %d -> %d｜胜场 %d -> %d" % [old_level, new_level, old_current_hp, old_hp, new_hp, new_hp, old_current_posture, old_posture, new_posture, new_posture, old_qinggong, new_qinggong, old_wins, old_wins + 1]


func _sample_battle_reward_choices(count: int) -> Array[CardData]:
	var owned: Array[String] = []
	if NarrativeBattleContext.has_player_profile():
		var card_state: Dictionary = NarrativeBattleContext.get_player_card_state() as Dictionary
		var owned_values: Array = card_state.get("owned_card_ids", []) as Array
		for i in range(owned_values.size()):
			owned.append(str(owned_values[i]))
	var pool: Array[CardData] = []
	var fallback_pool: Array[CardData] = []
	for template: CardData in reward_pool:
		var card: CardData = template.duplicate_card()
		fallback_pool.append(card)
		if not (card.id in owned):
			pool.append(card)
	if pool.is_empty():
		pool = fallback_pool
	pool.shuffle()
	var selected: Array[CardData] = []
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
	for card: CardData in _battle_reward_choices:
		if clean == card.short_summary():
			return "✓ %s" % clean if card.id == selected_card_id else clean
	return current_text


func _card_display_name(card_id: String) -> String:
	for card: CardData in _battle_reward_choices:
		if card.id == card_id:
			return card.display_name
	return card_id


func _on_battle_result_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	var result_text: String = "战斗胜利"
	var result_key: String = "win"
	if player != null and enemy != null and player.hp <= 0 and enemy.hp <= 0:
		result_text = "两败俱伤"
		result_key = "draw"
	if _story_encounter_selected:
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
		_show_combat_banner("%s，返回战斗测试" % result_text, Color("1c2a36"), Color("8fd3ff"))
		_reset_story_battle_runtime_state()
		_show_story_encounter_selection()
		_returning_to_story_selection = false
		return
	if NarrativeBattleContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.35).timeout
		var source_scene: String = NarrativeBattleContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		if result_key == "win" and not _selected_battle_reward_card_id.is_empty():
			NarrativeBattleContext.grant_player_cards([_selected_battle_reward_card_id])
		NarrativeBattleContext.set_result(result_key)
		get_tree().change_scene_to_file(source_scene)
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
	_show_combat_banner("%s，返回地图" % result_text, Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _on_battle_retry_confirm_pressed() -> void:
	_hide_battle_result_overlay()
	_returning_to_story_selection = false
	_reactive_pre_move_round = -1
	_reactive_pre_move_animation_round = -1
	_reactive_pre_move_animating = false
	_last_edge_positions = {}
	_break_resist_available = _pressure_profile == PRESSURE_BREAK_RESIST
	_start_battle()


func _return_to_story_encounter_selection_after_battle() -> void:
	var result_text: String = "战斗结束"
	var result_key: String = "draw"
	if player != null and enemy != null:
		if enemy.hp <= 0 and player.hp > 0:
			result_text = "战斗胜利"
			result_key = "win"
		elif player.hp <= 0 and enemy.hp > 0:
			result_text = "战斗失败"
			result_key = "lose"
		else:
			result_text = "两败俱伤"
			result_key = "draw"
	while _presentation_busy():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.15).timeout
	if _story_encounter_selected:
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回战斗测试。[/color]" % result_text)
		_show_combat_banner("%s，返回战斗测试" % result_text, Color("1c2a36"), Color("8fd3ff"))
		_reset_story_battle_runtime_state()
		_show_story_encounter_selection()
		_returning_to_story_selection = false
		return
	if NarrativeBattleContext.has_request():
		if log_label != null:
			log_label.append_text("\n[color=#8fd3ff]%s，返回剧情流程。[/color]" % result_text)
		_show_combat_banner("%s，返回剧情" % result_text, Color("1c2a36"), Color("8fd3ff"))
		await get_tree().create_timer(0.45).timeout
		var source_scene: String = NarrativeBattleContext.source_scene
		if source_scene.is_empty():
			source_scene = "res://scenes/NarrativeDemo.tscn"
		NarrativeBattleContext.set_result(result_key)
		get_tree().change_scene_to_file(source_scene)
		return
	if log_label != null:
		log_label.append_text("\n[color=#8fd3ff]%s，返回剧情遭遇选择。[/color]" % result_text)
	_show_combat_banner("%s，返回地图" % result_text, Color("1c2a36"), Color("8fd3ff"))
	_reset_story_battle_runtime_state()
	_show_story_encounter_selection()
	_returning_to_story_selection = false


func _reset_story_battle_runtime_state() -> void:
	battle_active = false
	awaiting_player_input = false
	player_role_id = ""
	_story_encounter_selected = false
	_reactive_pre_move_round = -1
	_pending_story_battle = {}
	_pressure_profile = PRESSURE_NONE
	_break_resist_available = false
	_last_edge_positions = {}
	player_intent = null
	enemy_intent = null
	draft_player_intent = null
	draft_player_position = -1
	draft_player_facing = ""
	draft_player_has_position = false
	declaration_order = PackedStringArray()
	declaration_index = 0
	fusion_first_index = -1
	state_machine.reset_for_session()
